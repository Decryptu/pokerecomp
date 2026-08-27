/**************************************************************************/
/*  native_power.mm                                                       */
/*  Part of pokerecomp. Licensed under the project's own terms.            */
/**************************************************************************/

#include "native_power.h"

#include "core/object/class_db.h"

#import <UIKit/UIKit.h>

NativePower *NativePower::singleton = nullptr;

NativePower *NativePower::get_singleton() {
	return singleton;
}

void NativePower::_bind_methods() {
	// Named as the Android plugin's two are, so the one widget that reads a
	// charge calls the same thing on both platforms.
	ClassDB::bind_method(D_METHOD("battery_percent"), &NativePower::battery_percent);
	ClassDB::bind_method(D_METHOD("battery_charging"), &NativePower::battery_charging);
}

int NativePower::battery_percent() const {
	// -1.0 is UIDevice's own "unknown", which is what the simulator reports and
	// what the field says before the first update lands.
	float level = [UIDevice currentDevice].batteryLevel;
	if (level < 0.0f) {
		return -1;
	}
	return (int)(level * 100.0f + 0.5f);
}

bool NativePower::battery_charging() const {
	UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
	return state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull;
}

NativePower::NativePower() {
	singleton = this;
	// Without this every read answers unknown. It costs one notification
	// observer inside UIKit and nothing here subscribes to it: the launcher asks
	// on its own cadence rather than being told.
	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
}

NativePower::~NativePower() {
	[UIDevice currentDevice].batteryMonitoringEnabled = NO;
	if (singleton == this) {
		singleton = nullptr;
	}
}
