package com.duoflex.duo_flex

import android.app.Activity
import android.content.Context
import android.graphics.Rect
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.view.View
import android.view.ViewTreeObserver
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterView
import android.view.WindowInsets
import androidx.window.java.layout.WindowInfoTrackerCallbackAdapter
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import androidx.window.layout.WindowLayoutInfo
import androidx.core.util.Consumer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
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
    private var messenger: BinaryMessenger? = null
    private var windowTracker: WindowInfoTrackerCallbackAdapter? = null
    private var windowLayoutListener: Consumer<WindowLayoutInfo>? = null
    private var latestFoldingFeature: FoldingFeature? = null
    private val mainExecutor: Executor by lazy { Executor { command -> android.os.Handler(android.os.Looper.getMainLooper()).post(command) } }
    private var screenSink: EventChannel.EventSink? = null
    private var displaySink: EventChannel.EventSink? = null
    private var hingeSink: EventChannel.EventSink? = null
    private var postureSink: EventChannel.EventSink? = null
    private var screenObserver: ViewTreeObserver.OnGlobalLayoutListener? = null
    private var observedDecorView: View? = null
    private var sensorManager: SensorManager? = null
    private var hingeSensor: Sensor? = null
    private var hingeSensorListener: SensorEventListener? = null
    private var lastHingeAngleRadians: Double? = null
    private var sensorStarted = false
    private var lastScreenInfo: Map<String, Any>? = null
    private var lastDisplayInfo: Map<String, Any?>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        messenger = binding.binaryMessenger
        sensorManager = appContext.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        hingeSensor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            sensorManager?.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE)
        } else null
        methodChannel = MethodChannel(binding.binaryMessenger, "duo_flex/methods")
        methodChannel.setMethodCallHandler(this)
        screenChannel = EventChannel(binding.binaryMessenger, "duo_flex/screen_info").also {
            it.setStreamHandler(streamHandler({ screenSink = it; lastScreenInfo = null; emitScreen() }, { screenSink = null }))
        }
        displayChannel = EventChannel(binding.binaryMessenger, "duo_flex/display_changes").also {
            it.setStreamHandler(streamHandler({ displaySink = it; lastDisplayInfo = null; emitDisplay() }, { displaySink = null }))
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
        val view = findFlutterView(activity?.window?.decorView) ?: activity?.window?.decorView
        val density = appContext.resources.displayMetrics.density.coerceAtLeast(0.1f)
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
        } else if (insets != null) {
            // Stable insets exclude transient IME occlusion on older Android.
            val cutout = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) insets.displayCutout else null
            left = maxOf(insets.stableInsetLeft, cutout?.safeInsetLeft ?: 0)
            top = maxOf(insets.stableInsetTop, cutout?.safeInsetTop ?: 0)
            right = maxOf(insets.stableInsetRight, cutout?.safeInsetRight ?: 0)
            bottom = maxOf(insets.stableInsetBottom, cutout?.safeInsetBottom ?: 0)
        } else {
            left = 0
            top = 0
            right = 0
            bottom = 0
        }
        val orientation = if (width > height) "landscape" else "portrait"
        val location = IntArray(2)
        view?.getLocationInWindow(location)
        val decor = activity?.window?.decorView
        val localLeft = (left - location[0]).coerceIn(0, width)
        val localTop = (top - location[1]).coerceIn(0, height)
        val localRight = (right - ((decor?.width ?: width) - location[0] - width)).coerceIn(0, width)
        val localBottom = (bottom - ((decor?.height ?: height) - location[1] - height)).coerceIn(0, height)
        return mapOf(
            "width" to width / density.toDouble(), "height" to height / density.toDouble(),
            "devicePixelRatio" to density.toDouble(), "orientation" to orientation,
            "safeArea" to mapOf("top" to localTop / density.toDouble(), "bottom" to localBottom / density.toDouble(),
                "left" to localLeft / density.toDouble(), "right" to localRight / density.toDouble()),
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
        val view = findFlutterView(activity?.window?.decorView) ?: return emptyList()
        val density = view.resources.displayMetrics.density.coerceAtLeast(0.1f).toDouble()
        val location = IntArray(2)
        view.getLocationInWindow(location)
        val regions = mutableListOf(mapOf<String, Any>(
            "id" to "application-window", "x" to 0.0, "y" to 0.0,
            "width" to view.width / density, "height" to view.height / density,
            "isActive" to true, "type" to "applicationWindow",
        ))
        val feature = latestFoldingFeature
        if (feature != null) {
            val bounds = Rect(feature.bounds)
            bounds.offset(-location[0], -location[1])
            // Keep zero-width/height separating folds; Rect.intersect drops them.
            if (bounds.right < 0 || bounds.bottom < 0 ||
                bounds.left > view.width || bounds.top > view.height) return regions
            bounds.left = bounds.left.coerceIn(0, view.width)
            bounds.right = bounds.right.coerceIn(0, view.width)
            bounds.top = bounds.top.coerceIn(0, view.height)
            bounds.bottom = bounds.bottom.coerceIn(0, view.height)
            regions.add(mapOf(
                "id" to "folding-feature", "x" to bounds.left / density,
                "y" to bounds.top / density, "width" to bounds.width() / density,
                "height" to bounds.height() / density,
                "isActive" to (feature.isSeparating ||
                    feature.occlusionType == FoldingFeature.OcclusionType.FULL),
                "type" to when {
                    feature.occlusionType == FoldingFeature.OcclusionType.FULL -> "hingeExclusion"
                    feature.isSeparating -> "reservedDivision"
                    else -> "unknown"
                },
            ))
        }
        return regions
    }

    private fun findFlutterView(view: View?): FlutterView? {
        if (view is FlutterView &&
            view.attachedFlutterEngine?.dartExecutor?.binaryMessenger === messenger) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findFlutterView(view.getChildAt(index))?.let { return it }
            }
        }
        return null
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

    private fun emitScreen() {
        val sink = screenSink ?: return
        val snapshot = screenInfo()
        if (snapshot == lastScreenInfo) return
        lastScreenInfo = snapshot
        sink.success(snapshot)
    }
    private fun emitDisplay() {
        val sink = displaySink ?: return
        val snapshot = displayInfo()
        if (snapshot == lastDisplayInfo) return
        lastDisplayInfo = snapshot
        sink.success(snapshot)
    }
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
        val listener = ViewTreeObserver.OnGlobalLayoutListener {
            emitScreen(); emitDisplay()
        }
        screenObserver = listener
        observedDecorView = view
        view.viewTreeObserver.addOnGlobalLayoutListener(listener)
    }

    private fun stopWindowTracking() {
        val listener = screenObserver
        observedDecorView?.viewTreeObserver?.let {
            if (listener != null && it.isAlive) it.removeOnGlobalLayoutListener(listener)
        }
        observedDecorView = null
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
        stopHingeSensor()
        screenSink = null
        displaySink = null
        hingeSink = null
        postureSink = null
        activity = null
        latestFoldingFeature = null
        lastHingeAngleRadians = null
        messenger = null
        methodChannel.setMethodCallHandler(null)
        screenChannel?.setStreamHandler(null); displayChannel?.setStreamHandler(null)
        hingeChannel?.setStreamHandler(null); postureChannel?.setStreamHandler(null)
    }
}

private const val HINGE_NOISE_THRESHOLD_RADIANS = 0.005235987755982988
