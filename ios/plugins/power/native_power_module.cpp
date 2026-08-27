/**************************************************************************/
/*  native_power_module.cpp                                               */
/*  Part of pokerecomp. Licensed under the project's own terms.            */
/**************************************************************************/

#include "native_power.h"

#include "core/config/engine.h"
#include "core/object/class_db.h"

static NativePower *native_power = nullptr;

// Named in native_power.gdip, which is what the iOS exporter calls these from
// the generated Xcode project.
void godot_native_power_init() {
	// Nothing else registers the class, and an unregistered one has no bound
	// methods for a script to call.
	NativePower::initialize_class();
	native_power = memnew(NativePower);
	Engine::get_singleton()->add_singleton(Engine::Singleton("NativePower", native_power));
}

void godot_native_power_deinit() {
	if (native_power) {
		memdelete(native_power);
		native_power = nullptr;
	}
}
