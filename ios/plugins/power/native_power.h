/**************************************************************************/
/*  native_power.h                                                        */
/*  Part of pokerecomp. Licensed under the project's own terms.            */
/**************************************************************************/

#ifndef NATIVE_POWER_H
#define NATIVE_POWER_H

#include "core/object/object.h"

// The device's charge, which the engine reports on no platform. UIDevice has
// it, and only once battery monitoring is switched on, so this owns that switch
// for the life of the app and answers two questions off the field it keeps
// updated.
class NativePower : public Object {
	GDCLASS(NativePower, Object);

	static NativePower *singleton;

protected:
	static void _bind_methods();

public:
	static NativePower *get_singleton();

	// The charge as a percentage, or -1 where iOS does not report one, which is
	// what the simulator answers.
	int battery_percent() const;
	// Whether something is putting charge in. A full battery on the mains counts:
	// it is not a cell quietly draining, and the launcher draws the two
	// differently.
	bool battery_charging() const;

	NativePower();
	~NativePower();
};

#endif // NATIVE_POWER_H
