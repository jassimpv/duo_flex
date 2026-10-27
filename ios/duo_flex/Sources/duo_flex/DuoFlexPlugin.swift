import Flutter
import UIKit

public final class DuoFlexPlugin: NSObject, FlutterPlugin {
  private let deviceManager = DuoDeviceManager()
  private let screenManager: DuoScreenManager
  private let displayManager: DuoDisplayManager
  private let foldManager: DuoFoldManager
  private var screenStream: DuoEventStreamHandler!
  private var displayStream: DuoEventStreamHandler!
  private var hingeStream: DuoFoldEventStreamHandler!
  private var postureStream: DuoFoldEventStreamHandler!
  private var screenChannel: FlutterEventChannel?
  private var displayChannel: FlutterEventChannel?
  private var hingeChannel: FlutterEventChannel?
  private var postureChannel: FlutterEventChannel?

  private init(registrar: FlutterPluginRegistrar) {
    let viewControllerProvider: () -> UIViewController? = { [weak registrar] in
      registrar?.viewController
    }
    screenManager = DuoScreenManager(viewControllerProvider: viewControllerProvider)
    displayManager = DuoDisplayManager(screenManager: screenManager)
    foldManager = DuoFoldManager(viewControllerProvider: viewControllerProvider)
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = DuoFlexPlugin(registrar: registrar)
    let methodChannel = FlutterMethodChannel(name: "duo_flex/methods", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    let screenEvents = DuoEventStreamHandler(onStart: { [weak instance] in
      instance?.screenManager.addGeometryListener()
    }, onStop: { [weak instance] in
      instance?.screenManager.removeGeometryListener()
    }, isSceneActive: { [weak instance] in
      instance?.screenManager.isActiveScene ?? false
    }) { [weak instance] in
      try instance?.screenManager.screenInfo()
    }
    let displayEvents = DuoEventStreamHandler(onStart: { [weak instance] in
      instance?.screenManager.addGeometryListener()
    }, onStop: { [weak instance] in
      instance?.screenManager.removeGeometryListener()
    }, isSceneActive: { [weak instance] in
      instance?.screenManager.isActiveScene ?? false
    }) { [weak instance] in
      try instance?.displayManager.displayInfo()
    }
    instance.screenStream = screenEvents
    instance.displayStream = displayEvents
    instance.screenManager.onGeometryChange = { [weak screenEvents, weak displayEvents] in
      screenEvents?.emitCurrent()
      displayEvents?.emitCurrent()
    }
    instance.foldManager.onStateChange = { [weak screenEvents, weak displayEvents] in
      displayEvents?.emitCurrent()
    }

    let screenChannel = FlutterEventChannel(name: "duo_flex/screen_info", binaryMessenger: registrar.messenger())
    screenChannel.setStreamHandler(screenEvents)
    instance.screenChannel = screenChannel

    let hingeEvents = DuoFoldEventStreamHandler(
      isSupported: { [weak instance] in instance?.foldManager.supportsUIKitHingeAPI ?? false },
      onListen: { [weak instance] sink in instance?.foldManager.setHingeSink(sink) },
      onCancel: { [weak instance] in instance?.foldManager.setHingeSink(nil) }
    )
    instance.hingeStream = hingeEvents
    let hingeChannel = FlutterEventChannel(name: "duo_flex/hinge_angle", binaryMessenger: registrar.messenger())
    hingeChannel.setStreamHandler(hingeEvents)
    instance.hingeChannel = hingeChannel

    let postureEvents = DuoFoldEventStreamHandler(
      isSupported: { [weak instance] in instance?.foldManager.supportsUIKitHingeAPI ?? false },
      onListen: { [weak instance] sink in instance?.foldManager.setPostureSink(sink) },
      onCancel: { [weak instance] in instance?.foldManager.setPostureSink(nil) }
    )
    instance.postureStream = postureEvents
    let postureChannel = FlutterEventChannel(name: "duo_flex/fold_posture", binaryMessenger: registrar.messenger())
    postureChannel.setStreamHandler(postureEvents)
    instance.postureChannel = postureChannel

    let displayChannel = FlutterEventChannel(name: "duo_flex/display_changes", binaryMessenger: registrar.messenger())
    displayChannel.setStreamHandler(displayEvents)
    instance.displayChannel = displayChannel
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    dispatchPrecondition(condition: .onQueue(.main))
    do {
      switch call.method {
      case "getPlatformVersion":
        result("iOS " + UIDevice.current.systemVersion)
      case "getCapabilities":
        foldManager.getCapabilities { [weak self] supportsHinge, supportsPosture in
          result([
            "supportsHingeAngle": supportsHinge,
            "supportsFoldPosture": supportsPosture,
            "supportsDisplayRegions": true,
            "supportsDisplayChanges": true,
            "supportsMultipleDisplays": false,
            "supportsSafeAreaInsets": self?.screenManager.hasActiveView ?? false,
          ])
        }
      case "getDeviceInfo":
        foldManager.getDeviceFoldability { [weak self] isFoldable in
          guard let self else { return }
          result(self.deviceManager.deviceInfo(isFoldable: isFoldable))
        }
      case "getScreenInfo":
        result(try screenManager.screenInfo())
      case "getDisplayInfo":
        result(try displayManager.displayInfo())
      case "getDisplayRegions":
        result(try displayManager.displayRegions())
      case "getHingeAngle":
        foldManager.getHingeAngle { angle in result(angle) }
      case "getFoldPosture":
        foldManager.getFoldPosture { posture in result(posture) }
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch let error as DuoFlexNativeError {
      result(FlutterError(code: error.code, message: error.message, details: nil))
    } catch {
      result(FlutterError(code: "NATIVE_OPERATION_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    screenStream?.dispose()
    displayStream?.dispose()
    hingeStream?.dispose()
    postureStream?.dispose()
    foldManager.dispose()
    screenManager.onGeometryChange = nil
    foldManager.onStateChange = nil
    screenChannel?.setStreamHandler(nil)
    displayChannel?.setStreamHandler(nil)
    hingeChannel?.setStreamHandler(nil)
    postureChannel?.setStreamHandler(nil)
  }
}
