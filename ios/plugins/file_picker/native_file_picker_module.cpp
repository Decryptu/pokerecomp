/**************************************************************************/
/*  native_file_picker_module.cpp                                         */
/*  Part of pokerecomp. Licensed under the project's own terms.            */
/**************************************************************************/

#include "native_file_picker.h"

#include "core/config/engine.h"
#include "core/object/class_db.h"

static NativeFilePicker *native_file_picker = nullptr;

// Named in native_file_picker.gdip, which is what the iOS exporter calls these
// from the generated Xcode project.
void godot_native_file_picker_init() {
	// Nothing else registers the class, and an unregistered one has no bound
	// methods for a script to call.
	NativeFilePicker::initialize_class();
	native_file_picker = memnew(NativeFilePicker);
	Engine::get_singleton()->add_singleton(Engine::Singleton("NativeFilePicker", native_file_picker));
}

void godot_native_file_picker_deinit() {
	if (native_file_picker) {
		memdelete(native_file_picker);
		native_file_picker = nullptr;
	}
}
