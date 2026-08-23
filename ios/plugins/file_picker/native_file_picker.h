/**************************************************************************/
/*  native_file_picker.h                                                  */
/*  Part of pokerecomp. Licensed under the project's own terms.            */
/**************************************************************************/

#ifndef NATIVE_FILE_PICKER_H
#define NATIVE_FILE_PICKER_H

#include "core/error/error_list.h"
#include "core/object/object.h"
#include "core/variant/variant.h"

#ifdef __OBJC__
@class GodotDocumentPicker;
#else
typedef void GodotDocumentPicker;
#endif

// The system document picker, which the engine itself does not reach on this
// platform: DisplayServerIOS implements no file_dialog_show, so FileDialog
// falls back to browsing a sandbox the app is then refused every read of.
//
// One call, two answers. The file is handed over already copied into the app's
// own storage, so the caller reads an ordinary path and nothing has to be told
// when to let go of it.
class NativeFilePicker : public Object {
	GDCLASS(NativeFilePicker, Object);

	static NativeFilePicker *singleton;
	GodotDocumentPicker *delegate = nullptr;

protected:
	static void _bind_methods();

public:
	static NativeFilePicker *get_singleton();

	// Opens the picker. p_extensions are bare extensions ("gbc", "zip"); an
	// empty list offers every file.
	Error open_file(const String &p_title, const PackedStringArray &p_extensions);

	// Called by the Objective-C delegate, on the main thread.
	void _deliver_file(const String &p_path);
	void _deliver_cancelled();

	NativeFilePicker();
	~NativeFilePicker();
};

#endif // NATIVE_FILE_PICKER_H
