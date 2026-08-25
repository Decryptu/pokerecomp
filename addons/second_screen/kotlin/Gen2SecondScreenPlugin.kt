package io.github.decryptu.pokerecomp.secondscreen

import android.app.Presentation
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.view.Display
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.nio.ByteBuffer

/**
 * The lower display of a dual-screen Android handheld, as a bitmap the game
 * hands over and a touch it hands back.
 *
 * This is not a second rendering context. The game draws its lower screen into a
 * small offscreen viewport and copies the pixels here, and this scales that
 * picture by a whole number with filtering off. That is what keeps the port on
 * the compatibility renderer: a shared context would mean a swapchain per
 * display and a graphics backend that has one.
 *
 * Nothing about the AYN Thor is hardcoded. Any secondary display the platform
 * offers for a Presentation is used, which is the same answer on a Retroid
 * Pocket 5 or an RG DS, and no display at all is not an error.
 */
class Gen2SecondScreenPlugin(godot: Godot) : GodotPlugin(godot) {

    private var presentation: PanelPresentation? = null
    private var listening = false

    /** Whether the game asked for the panel, so a resume can put it back. */
    private var requested = false

    // Not "Gen2SecondScreen": a plugin singleton becomes a global name in
    // GDScript, and that one is already the screen's own class.
    override fun getPluginName() = "Gen2SecondScreenPanel"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("panel_connected", Integer::class.java, Integer::class.java),
        SignalInfo("panel_disconnected"),
        SignalInfo(
            "panel_touched",
            java.lang.Float::class.java,
            java.lang.Float::class.java
        )
    )

    /**
     * The secondary display's own pixels as `[width, height]`, or an empty array
     * where there is no second display. The game reads this before it decides on
     * a canvas, so it is answered without showing anything.
     */
    @UsedByGodot
    fun panel_size(): IntArray {
        val display = findPanel() ?: return IntArray(0)
        val mode = display.mode
        return intArrayOf(mode.physicalWidth, mode.physicalHeight)
    }

    /** Puts the panel up. Answers false when there is nothing to put it on. */
    @UsedByGodot
    fun open(): Boolean {
        if (findPanel() == null) return false
        requested = true
        activity?.runOnUiThread { show() }
        return true
    }

    @UsedByGodot
    fun close() {
        requested = false
        activity?.runOnUiThread { dismiss() }
    }

    /**
     * One frame, as [width] x [height] pixels of RGBA8, which is the byte order
     * an ARGB_8888 bitmap already stores.
     *
     * Called from the game thread; the copy happens here and the draw on the UI
     * thread, so a frame is never half-written while it is being scaled.
     */
    @UsedByGodot
    fun present(pixels: ByteArray, width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        if (pixels.size < width * height * BYTES_PER_PIXEL) return
        val panel = presentation ?: return
        panel.submit(pixels, width, height)
    }

    /**
     * Resolved on demand rather than kept from `onMainCreate`: the game asks
     * whether there is a panel as soon as its first world is built, and on some
     * devices that is the same frame the activity is still being set up on.
     */
    private fun displays(): DisplayManager? {
        val manager =
            activity?.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager ?: return null
        if (!listening) {
            listening = true
            manager.registerDisplayListener(displayListener, null)
        }
        return manager
    }

    override fun onMainResume() {
        super.onMainResume()
        if (requested) activity?.runOnUiThread { show() }
    }

    override fun onMainPause() {
        super.onMainPause()
        activity?.runOnUiThread { dismiss() }
    }

    override fun onMainDestroy() {
        if (listening) {
            displays()?.unregisterDisplayListener(displayListener)
            listening = false
        }
        close()
        super.onMainDestroy()
    }

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {
            if (requested) activity?.runOnUiThread { show() }
        }

        override fun onDisplayChanged(displayId: Int) {}

        override fun onDisplayRemoved(displayId: Int) {
            if (presentation?.display?.displayId != displayId) return
            activity?.runOnUiThread { dismiss() }
            emitSignal("panel_disconnected")
        }
    }

    /**
     * The display a Presentation may be put on: the platform's own list first,
     * since that is the one that excludes mirrors and untrusted displays, and
     * any display that is not the default after it.
     */
    private fun findPanel(): Display? {
        val manager = displays() ?: return null
        val offered = manager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
        if (offered.isNotEmpty()) return offered[0]
        return manager.displays.firstOrNull { it.displayId != Display.DEFAULT_DISPLAY }
    }

    private fun show() {
        if (presentation != null || !requested) return
        val host = activity ?: return
        val display = findPanel() ?: return
        val panel = PanelPresentation(host, display)
        try {
            panel.show()
        } catch (_: WindowManager.BadTokenException) {
            return
        } catch (_: WindowManager.InvalidDisplayException) {
            return
        }
        presentation = panel
        val mode = display.mode
        emitSignal("panel_connected", mode.physicalWidth, mode.physicalHeight)
    }

    private fun dismiss() {
        presentation?.dismiss()
        presentation = null
    }

    private inner class PanelPresentation(context: Context, display: Display) :
        Presentation(context, display) {

        private lateinit var surface: PanelView

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            setCancelable(false)
            surface = PanelView(context)
            setContentView(surface)
            window?.setBackgroundDrawableResource(android.R.color.black)
            window?.decorView?.systemUiVisibility =
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }

        fun submit(pixels: ByteArray, width: Int, height: Int) {
            if (!::surface.isInitialized) return
            surface.submit(pixels, width, height)
        }
    }

    /**
     * The panel itself: one bitmap, scaled by the largest whole number that fits
     * and centred, with the leftover painted black.
     *
     * Whole numbers only, and filtering off, for the reason the game's own
     * screen gives: a hardware pixel drawn as a fraction of a panel pixel
     * crawls when the picture moves.
     */
    private inner class PanelView(context: Context) : View(context) {
        private var bitmap: Bitmap? = null
        private val paint = Paint().apply {
            isFilterBitmap = false
            isAntiAlias = false
            isDither = false
        }
        private val source = Rect()
        private val target = Rect()

        fun submit(pixels: ByteArray, width: Int, height: Int) {
            synchronized(this) {
                var image = bitmap
                if (image == null || image.width != width || image.height != height) {
                    image = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    bitmap = image
                    source.set(0, 0, width, height)
                }
                image.copyPixelsFromBuffer(ByteBuffer.wrap(pixels))
            }
            postInvalidateOnAnimation()
        }

        override fun onDraw(canvas: Canvas) {
            canvas.drawColor(Color.BLACK)
            val image = synchronized(this) { bitmap } ?: return
            layoutTarget(image.width, image.height)
            canvas.drawBitmap(image, source, target, paint)
        }

        private fun layoutTarget(imageWidth: Int, imageHeight: Int) {
            val scale = maxOf(1, minOf(width / imageWidth, height / imageHeight))
            val drawnWidth = imageWidth * scale
            val drawnHeight = imageHeight * scale
            val left = (width - drawnWidth) / 2
            val top = (height - drawnHeight) / 2
            target.set(left, top, left + drawnWidth, top + drawnHeight)
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            if (event.actionMasked != MotionEvent.ACTION_DOWN &&
                event.actionMasked != MotionEvent.ACTION_POINTER_DOWN
            ) {
                return true
            }
            val image = synchronized(this) { bitmap } ?: return true
            layoutTarget(image.width, image.height)
            val scale = maxOf(1, target.width() / image.width)
            // Reported in the presented picture's own pixels: the game laid its
            // tab row out in those and knows nothing about this panel's size.
            val x = (event.getX(event.actionIndex) - target.left) / scale
            val y = (event.getY(event.actionIndex) - target.top) / scale
            if (x < 0f || y < 0f || x >= image.width || y >= image.height) return true
            emitSignal("panel_touched", x, y)
            return true
        }
    }

    private companion object {
        const val BYTES_PER_PIXEL = 4
    }
}
