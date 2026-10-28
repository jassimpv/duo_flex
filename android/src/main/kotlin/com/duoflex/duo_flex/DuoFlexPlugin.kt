package com.duoflex.duo_flex

import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.graphics.Rect
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.view.View
import android.view.WindowInsets
import androidx.window.java.layout.WindowInfoTrackerCallbackAdapter
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import androidx.window.layout.WindowLayoutInfo
import androidx.core.util.Consumer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

class DuoFlexPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var appContext: Context
    private lateinit var methodChannel: MethodChannel
    private var screenChannel: EventChannel? = null
    private var displayChannel: EventChannel? = null
    private var hingeChannel: EventChannel? = null
    private var postureChannel: EventChannel? = null
    private var activity: Activity? = null
    private var windowTracker: WindowInfoTrackerCallbackAdapter? = null
    private var windowLayoutListener: Consumer<WindowLayoutInfo>? = null
    private var latestFoldingFeature: FoldingFeature? = null
    private val mainExecutor: Executor by lazy { Executor { command -> android.os.Handler(android.os.Looper.getMainLooper()).post(command) } }
    private var screenSink: EventChannel.EventSink? = null
    private var displaySink: EventChannel.EventSink? = null
    private var hingeSink: EventChannel.EventSink? = null
    private var postureSink: EventChannel.EventSink? = null
    private var screenObserver: View.OnLayoutChangeListener? = null
    private var sensorManager: SensorManager? = null
    private var hingeSensor: Sensor? = null
    private var hingeSensorListener: SensorEventListener? = null
    private var lastHingeAngleRadians: Double? = null
    private var sensorStarted = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        sensorManager = appContext.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        hingeSensor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            sensorManager?.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE)
        } else null
        methodChannel = MethodChannel(binding.binaryMessenger, "duo_flex/methods")
        methodChannel.setMethodCallHandler(this)
        screenChannel = EventChannel(binding.binaryMessenger, "duo_flex/screen_info").also {
            it.setStreamHandler(streamHandler({ screenSink = it; emitScreen() }, { screenSink = null }))
        }
        displayChannel = EventChannel(binding.binaryMessenger, "duo_flex/display_changes").also {
            it.setStreamHandler(streamHandler({ displaySink = it; emitDisplay() }, { displaySink = null }))
        }
        hingeChannel = EventChannel(binding.binaryMessenger, "duo_flex/hinge_angle").also {
            it.setStreamHandler(streamHandler({
                hingeSink = it
                startHingeSensor()
                lastHingeAngleRadians?.let(it::success)
            }, {
                hingeSink = null
                stopHingeSensor()
            }))
        }
        postureChannel = EventChannel(binding.binaryMessenger, "duo_flex/fold_posture").also {
            it.setStreamHandler(streamHandler({ postureSink = it; emitPosture() }, { postureSink = null }))
        }
    }

    private fun streamHandler(onListen: (EventChannel.EventSink) -> Unit, onCancel: () -> Unit) =
        object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) = onListen(events)
            override fun onCancel(arguments: Any?) = onCancel()
        }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
                "getCapabilities" -> result.success(capabilities())
                "getDeviceInfo" -> result.success(mapOf(
                    "model" to Build.MODEL,
                    "systemName" to "Android",
                    "systemVersion" to Build.VERSION.RELEASE,
                    // Android has no general public device-wide foldability API.
                    // Only claim foldability once WindowManager reports a feature.
                    "isFoldable" to if (latestFoldingFeature != null) true else null,
                ))
                "getScreenInfo" -> result.success(screenInfo())
                "getDisplayInfo" -> result.success(displayInfo())
                "getDisplayRegions" -> result.success(displayRegions())
                "getHingeAngle" -> result.success(lastHingeAngleRadians)
                "getFoldPosture" -> result.success(foldPosture())
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("NATIVE_OPERATION_FAILED", error.message, null)
        }
    }

    private fun capabilities() = mapOf(
        "supportsHingeAngle" to (hingeSensor != null),
        "supportsFoldPosture" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && latestFoldingFeature != null),
        "supportsDisplayRegions" to true,
        "supportsDisplayChanges" to true,
        "supportsMultipleDisplays" to false,
        "supportsSafeAreaInsets" to (activity?.window?.decorView != null),
    )

    private fun screenInfo(): Map<String, Any> {
        val view = activity?.window?.decorView
        val density = appContext.resources.displayMetrics.density.coerceAtLeast(0.1f)
        val bounds = Rect()
        if (view != null) view.getWindowVisibleDisplayFrame(bounds)
        val width = if (view != null && view.width > 0) view.width else appContext.resources.displayMetrics.widthPixels
        val height = if (view != null && view.height > 0) view.height else appContext.resources.displayMetrics.heightPixels
        val insets = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && view != null) view.rootWindowInsets else null
        val safe = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && insets != null) {
            insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
        } else null
        val left: Int
        val top: Int
        val right: Int
        val bottom: Int
        if (safe != null) {
            left = safe.left
            top = safe.top
            right = safe.right
            bottom = safe.bottom
        } else if (view != null && view.width > 0 && view.height > 0) {
            left = maxOf(bounds.left, 0)
            top = maxOf(bounds.top, 0)
            right = maxOf(width - bounds.right, 0)
            bottom = maxOf(height - bounds.bottom, 0)
        } else {
            left = 0
            top = 0
            right = 0
            bottom = 0
        }
        val orientation = when (appContext.resources.configuration.orientation) {
            Configuration.ORIENTATION_LANDSCAPE -> "landscape"
            Configuration.ORIENTATION_PORTRAIT -> "portrait"
            else -> "unknown"
        }
        return mapOf(
            "width" to width / density.toDouble(), "height" to height / density.toDouble(),
            "devicePixelRatio" to density.toDouble(), "orientation" to orientation,
            "safeArea" to mapOf("top" to top / density.toDouble(), "bottom" to bottom / density.toDouble(),
                "left" to left / density.toDouble(), "right" to right / density.toDouble()),
        )
    }

    private fun displayInfo(): Map<String, Any?> {
        val metrics = appContext.resources.displayMetrics
        val regions = displayRegions()
        return mapOf(
            "identifier" to "android-primary-display", "width" to metrics.widthPixels.toDouble(),
            "height" to metrics.heightPixels.toDouble(), "scale" to metrics.density.toDouble(),
            "isActive" to (activity != null), "regions" to regions, "displayType" to "builtIn",
        )
    }

    private fun displayRegions(): List<Map<String, Any>> {
        val screen = screenInfo()
        val density = appContext.resources.displayMetrics.density.coerceAtLeast(0.1f)
        val view = activity?.window?.decorView
        val screenX = if (view != null && view.width > 0) view.left / density.toDouble() else 0.0
        val screenY = if (view != null && view.height > 0) view.top / density.toDouble() else 0.0
        val regions = mutableListOf(mapOf(
            "id" to "application-window", "x" to screenX, "y" to screenY,
            "width" to screen.getValue("width") as Double,
            "height" to screen.getValue("height") as Double,
            "isActive" to (activity != null), "type" to "applicationWindow",
        ))
        val feature = latestFoldingFeature
        if (feature != null) {
            val bounds = feature.bounds
            regions.add(mapOf(
                "id" to "folding-feature", "x" to (bounds.left - (view?.left ?: 0)) / density.toDouble(),
                "y" to (bounds.top - (view?.top ?: 0)) / density.toDouble(), "width" to bounds.width() / density.toDouble(),
                "height" to bounds.height() / density.toDouble(), "isActive" to feature.isSeparating,
                "type" to when {
                    feature.occlusionType == FoldingFeature.OcclusionType.FULL -> "hingeExclusion"
                    feature.isSeparating -> "reservedDivision"
                    else -> "unknown"
                },
            ))
        }
        return regions
    }

    private fun foldPosture(): String {
        val feature = latestFoldingFeature ?: return "unknown"
        return when (feature.state) {
            FoldingFeature.State.FLAT -> "fullyOpen"
            FoldingFeature.State.HALF_OPENED -> when (feature.orientation) {
                FoldingFeature.Orientation.HORIZONTAL -> "tabletop"
                FoldingFeature.Orientation.VERTICAL -> "book"
                else -> "halfOpen"
            }
            else -> "unknown"
        }
    }

    private fun emitScreen() { screenSink?.success(screenInfo()) }
    private fun emitDisplay() { displaySink?.success(displayInfo()) }
    private fun emitPosture() { postureSink?.success(foldPosture()) }

    private fun startHingeSensor() {
        if (sensorStarted) return
        val manager = sensorManager ?: return
        val sensor = hingeSensor ?: return
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val degrees = event.values.firstOrNull()?.toDouble() ?: return
                if (!degrees.isFinite() || degrees !in 0.0..180.0) return
                val radians = Math.toRadians(degrees)
                val previous = lastHingeAngleRadians
                if (previous != null && kotlin.math.abs(radians - previous) < HINGE_NOISE_THRESHOLD_RADIANS) return
                lastHingeAngleRadians = radians
                hingeSink?.success(radians)
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        if (manager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)) {
            hingeSensorListener = listener
            sensorStarted = true
        }
    }

    private fun stopHingeSensor() {
        val listener = hingeSensorListener ?: return
        sensorManager?.unregisterListener(listener)
        hingeSensorListener = null
        sensorStarted = false
    }

    private fun startWindowTracking() {
        val current = activity ?: return
        if (hingeSink != null) startHingeSensor()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val tracker = WindowInfoTrackerCallbackAdapter(WindowInfoTracker.getOrCreate(appContext))
            windowTracker = tracker
            val layoutListener = Consumer<WindowLayoutInfo> { info ->
                latestFoldingFeature = info.displayFeatures.filterIsInstance<FoldingFeature>().firstOrNull()
                emitScreen(); emitDisplay(); emitPosture()
            }
            windowLayoutListener = layoutListener
            tracker.addWindowLayoutInfoListener(current, mainExecutor, layoutListener)
        }
        val view = current.window.decorView
        view.post {
            if (screenSink != null) emitScreen()
            if (displaySink != null) emitDisplay()
        }
        val listener = View.OnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            emitScreen(); emitDisplay()
        }
        screenObserver = listener
        view.addOnLayoutChangeListener(listener)
    }

    private fun stopWindowTracking() {
        val listener = screenObserver
        activity?.window?.decorView?.let { if (listener != null) it.removeOnLayoutChangeListener(listener) }
        screenObserver = null
        val layoutListener = windowLayoutListener
        if (layoutListener != null) windowTracker?.removeWindowLayoutInfoListener(layoutListener)
        windowLayoutListener = null
        windowTracker = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        startWindowTracking()
    }
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() {
        stopWindowTracking()
        stopHingeSensor()
        activity = null
        latestFoldingFeature = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopWindowTracking()
        methodChannel.setMethodCallHandler(null)
        screenChannel?.setStreamHandler(null); displayChannel?.setStreamHandler(null)
        hingeChannel?.setStreamHandler(null); postureChannel?.setStreamHandler(null)
    }
}

private const val HINGE_NOISE_THRESHOLD_RADIANS = 0.005235987755982988
