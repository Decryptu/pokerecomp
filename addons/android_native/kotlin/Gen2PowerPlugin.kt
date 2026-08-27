package io.github.decryptu.pokerecomp.androidnative

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot

/**
 * The device's charge, which the engine reports on no platform.
 *
 * `ACTION_BATTERY_CHANGED` is a sticky broadcast, so registering a null receiver
 * for it returns the last Intent the system sent without subscribing to
 * anything. That is a field read rather than a listener, which is what lets the
 * launcher ask for the charge on its own cadence and keep nothing alive between
 * two questions. No permission is declared or needed.
 */
class Gen2PowerPlugin(godot: Godot) : GodotPlugin(godot) {

    // Not "Gen2LauncherBattery": a plugin singleton becomes a global identifier
    // in GDScript, and that one is already the widget's own class.
    override fun getPluginName() = "Gen2PlatformPower"

    /** The charge as a percentage, or -1 where the device does not report one. */
    @UsedByGodot
    fun battery_percent(): Int {
        val status = sticky() ?: return -1
        val level = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level < 0 || scale <= 0) return -1
        return (level * 100) / scale
    }

    /**
     * Whether something is putting charge in. `BATTERY_STATUS_FULL` counts: a
     * full battery on the mains is not a cell quietly draining, and the launcher
     * draws the two differently.
     */
    @UsedByGodot
    fun battery_charging(): Boolean {
        val state = sticky()?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: return false
        return state == BatteryManager.BATTERY_STATUS_CHARGING ||
            state == BatteryManager.BATTERY_STATUS_FULL
    }

    private fun sticky(): Intent? {
        val context: Context = activity ?: return null
        return context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    }
}
