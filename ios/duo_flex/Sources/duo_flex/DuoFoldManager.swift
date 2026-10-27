import Flutter
import UIKit

/// Coordinates point-in-time fold queries and lazy event subscriptions.
final class DuoFoldManager {
  private let provider: DuoFoldCapabilityProvider

  init(viewControllerProvider: @escaping () -> UIViewController?) {
    provider = makeDuoFoldCapabilityProvider(
      viewControllerProvider: viewControllerProvider
    )
  }

  var supportsUIKitHingeAPI: Bool { provider.supportsUIKitHingeAPI }
  var onStateChange: (() -> Void)? {
    didSet { provider.setStateChangeHandler(onStateChange) }
  }

  func getCapabilities(_ completion: @escaping (Bool, Bool) -> Void) {
    provider.requestSnapshot { snapshot in
      let supported = snapshot.hasVerifiedHinge
      completion(supported, supported)
    }
  }

  func getDeviceFoldability(_ completion: @escaping (Bool?) -> Void) {
    provider.requestSnapshot { snapshot in
      completion(snapshot.hasVerifiedHinge ? true : nil)
    }
  }

  func getHingeAngle(_ completion: @escaping (Double?) -> Void) {
    provider.requestSnapshot { snapshot in
      completion(snapshot.hasVerifiedHinge ? snapshot.hingeAngleRadians : nil)
    }
  }

  func getFoldPosture(_ completion: @escaping (String) -> Void) {
    provider.requestSnapshot { snapshot in
      completion(snapshot.hasVerifiedHinge ? snapshot.posture : "unknown")
    }
  }

  func setHingeSink(_ sink: FlutterEventSink?) {
    provider.setHingeSink(sink)
  }

  func setPostureSink(_ sink: FlutterEventSink?) {
    provider.setPostureSink(sink)
  }

  func dispose() {
    provider.dispose()
  }
}
