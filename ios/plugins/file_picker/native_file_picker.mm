/**************************************************************************/
/*  native_file_picker.mm                                                 */
/*  Part of pokerecomp. Licensed under the project's own terms.            */
/**************************************************************************/

#include "native_file_picker.h"

#include "core/object/class_db.h"
#include "core/os/os.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// Where a picked file is left for the caller to read. Swept on every pick, so
// one import's copy is the only one on disk and nothing accumulates in a
// player's storage.
static NSString *const kImportsDirectory = @"picked";

@interface GodotDocumentPicker : NSObject <UIDocumentPickerDelegate>
+ (void)cancel;
@end

@implementation GodotDocumentPicker

// The controller to present from: the topmost thing already on screen, so the
// picker is not put underneath a sheet the game happens to have open.
- (UIViewController *)topController {
	UIWindow *window = [UIApplication sharedApplication].delegate.window;
	if (!window) {
		for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
			if (![scene isKindOfClass:[UIWindowScene class]]) {
				continue;
			}
			for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
				if (candidate.isKeyWindow) {
					window = candidate;
					break;
				}
			}
		}
	}
	UIViewController *controller = window.rootViewController;
	while (controller.presentedViewController) {
		controller = controller.presentedViewController;
	}
	return controller;
}

- (void)presentWithTypes:(NSArray<UTType *> *)types {
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *root = [self topController];
		if (!root) {
			[GodotDocumentPicker cancel];
			return;
		}
		// asCopy leaves iOS to hand over a file the app already owns, in its own
		// temporary directory. Without it the URL is security scoped, has to be
		// opened and released around every read, and may still be in iCloud.
		UIDocumentPickerViewController *picker =
				[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types
																			asCopy:YES];
		picker.delegate = self;
		picker.allowsMultipleSelection = NO;
		[root presentViewController:picker animated:YES completion:nil];
	});
}

// The app's own directory for picked files, emptied first.
- (NSURL *)freshImportsDirectory {
	NSString *user_data = [NSString stringWithUTF8String:OS::get_singleton()->get_user_data_dir().utf8().get_data()];
	NSURL *directory = [[NSURL fileURLWithPath:user_data] URLByAppendingPathComponent:kImportsDirectory];
	NSFileManager *files = [NSFileManager defaultManager];
	[files removeItemAtURL:directory error:nil];
	[files createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
	return directory;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
		didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	if (urls.count == 0) {
		[GodotDocumentPicker cancel];
		return;
	}
	NSURL *picked = urls.firstObject;
	NSURL *destination = [[self freshImportsDirectory] URLByAppendingPathComponent:picked.lastPathComponent];
	NSError *error = nil;
	// A move rather than a copy: the source is the app's own temporary copy, and
	// iOS is free to reclaim that directory whenever it likes.
	if (![[NSFileManager defaultManager] moveItemAtURL:picked toURL:destination error:&error]) {
		if (![[NSFileManager defaultManager] copyItemAtURL:picked toURL:destination error:&error]) {
			ERR_PRINT(vformat("Could not take the picked file: %s",
					String::utf8(error.localizedDescription.UTF8String)));
			[GodotDocumentPicker cancel];
			return;
		}
	}
	NativeFilePicker *picker = NativeFilePicker::get_singleton();
	if (picker) {
		picker->_deliver_file(String::utf8(destination.path.UTF8String));
	}
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
	[GodotDocumentPicker cancel];
}

// The singleton is gone once the engine has torn the plugin down, and a picker
// still on screen can answer after that.
+ (void)cancel {
	NativeFilePicker *picker = NativeFilePicker::get_singleton();
	if (picker) {
		picker->_deliver_cancelled();
	}
}

@end

NativeFilePicker *NativeFilePicker::singleton = nullptr;

NativeFilePicker *NativeFilePicker::get_singleton() {
	return singleton;
}

Error NativeFilePicker::open_file(const String &p_title, const PackedStringArray &p_extensions) {
	NSMutableArray<UTType *> *types = [NSMutableArray array];
	for (int i = 0; i < p_extensions.size(); i++) {
		String extension = p_extensions[i].trim_prefix("*").trim_prefix(".");
		if (extension.is_empty()) {
			continue;
		}
		UTType *type = [UTType typeWithFilenameExtension:[NSString stringWithUTF8String:extension.utf8().get_data()]];
		if (type) {
			[types addObject:type];
		}
	}
	// A cartridge extension is not a type any system knows, so the list it
	// resolves to cannot be trusted to contain the player's own file. Data is
	// always offered alongside, which is what keeps every file reachable.
	[types addObject:UTTypeData];
	[(GodotDocumentPicker *)delegate presentWithTypes:types];
	return OK;
}

void NativeFilePicker::_deliver_file(const String &p_path) {
	// Deferred rather than emitted here: this is a UIKit callback, and the
	// launcher rebuilds itself out of the signal.
	call_deferred(SNAME("emit_signal"), SNAME("file_selected"), p_path);
}

void NativeFilePicker::_deliver_cancelled() {
	call_deferred(SNAME("emit_signal"), SNAME("canceled"));
}

void NativeFilePicker::_bind_methods() {
	ClassDB::bind_method(D_METHOD("open_file", "title", "extensions"), &NativeFilePicker::open_file);

	// Named for FileDialog's own, so the one seam that opens a picker can treat
	// the two the same way round.
	ADD_SIGNAL(MethodInfo("file_selected", PropertyInfo(Variant::STRING, "path")));
	ADD_SIGNAL(MethodInfo("canceled"));
}

NativeFilePicker::NativeFilePicker() {
	singleton = this;
	delegate = [[GodotDocumentPicker alloc] init];
}

NativeFilePicker::~NativeFilePicker() {
	delegate = nullptr;
	singleton = nullptr;
}
