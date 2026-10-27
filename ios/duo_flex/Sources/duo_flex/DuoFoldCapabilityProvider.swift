import Flutter
import UIKit

struct DuoFoldSnapshot: Equatable {
  let hingeAngleRadians: Double?
  let posture: String
  let hasVerifiedHinge: Bool

  static let unsupported = DuoFoldSnapshot(
    hingeAngleRadians: nil,
    posture: "unknown",
    hasVerifiedHinge: false
  )
}

/// Provides fold state only when UIKit reports an actual hinge for the view.
protocol DuoFoldCapabilityProvider: AnyObject {
  var supportsUIKitHingeAPI: Bool { get }
  func requestSnapshot(_ completion: @escaping (DuoFoldSnapshot) -> Void)
  func setHingeSink(_ sink: FlutterEventSink?)
  func setPostureSink(_ sink: FlutterEventSink?)
  func setStateChangeHandler(_ handler: (() -> Void)?)
  func dispose()
}

/// Safe fallback for iOS versions before the public UIKit hinge API.
final class UnsupportedDuoFoldCapabilityProvider: DuoFoldCapabilityProvider {
  var supportsUIKitHingeAPI: Bool { false }
  func requestSnapshot(_ completion: @escaping (DuoFoldSnapshot) -> Void) {
    completion(.unsupported)
  }

  func setHingeSink(_ sink: FlutterEventSink?) {}
  func setPostureSink(_ sink: FlutterEventSink?) {}
  func setStateChangeHandler(_ handler: (() -> Void)?) {}

  func dispose() {}
}

@available(iOS 27.1, *)
final class UIKitDuoFoldCapabilityProvider: DuoFoldCapabilityProvider {
  var supportsUIKitHingeAPI: Bool { true }
  private let viewControllerProvider: () -> UIViewController?
  private var viewController: UIViewController? { viewControllerProvider() }
  private var interaction: UIHingeInteraction?
  private var pendingRequests: [(DuoFoldSnapshot) -> Void] = []
  private var hingeSink: FlutterEventSink?
  private var postureSink: FlutterEventSink?
  private var stateChangeHandler: (() -> Void)?
  private var lifecycleObservers: [NSObjectProtocol] = []
  private var lastSnapshot = DuoFoldSnapshot.unsupported
  private var hasReceivedUpdate = false

  init(viewControllerProvider: @escaping () -> UIViewController?) {
    self.viewControllerProvider = viewControllerProvider
  }

  deinit {
    for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
  }

  func requestSnapshot(_ completion: @escaping (DuoFoldSnapshot) -> Void) {
    if hasReceivedUpdate {
      completion(lastSnapshot)
      return
    }
    guard let controller = viewController,
          controller.isViewLoaded,
          controller.view != nil else {
      completion(.unsupported)
      return
    }
    pendingRequests.append(completion)
    if !installInteractionIfNeeded() {
      let requests = pendingRequests
      pendingRequests.removeAll()
      for request in requests { request(.unsupported) }
    }
  }

  func setHingeSink(_ sink: FlutterEventSink?) {
    hingeSink = sink
    updateObservation()
  }

  func setPostureSink(_ sink: FlutterEventSink?) {
    postureSink = sink
    updateObservation()
  }

  func setStateChangeHandler(_ handler: (() -> Void)?) {
    stateChangeHandler = handler
  }

  private func updateObservation() {
    if hingeSink != nil || postureSink != nil {
      installInteractionIfNeeded()
    } else if pendingRequests.isEmpty {
      removeInteraction()
    }
  }

  func dispose() {
    let requests = pendingRequests
    pendingRequests.removeAll()
    for request in requests { request(.unsupported) }
    hingeSink = nil
    postureSink = nil
    removeInteraction()
  }

  @discardableResult
  private func installInteractionIfNeeded() -> Bool {
    if interaction != nil { return true }
    guard let controller = viewController,
          controller.isViewLoaded,
          let view = controller.view else { return false }

    let interaction = UIHingeInteraction { [weak self] _, update in
      guard let self else { return }
      self.receive(update.hinge)
    }
    self.interaction = interaction
    view.addInteraction(interaction)
    let center = NotificationCenter.default
    lifecycleObservers = [UIApplication.didBecomeActiveNotification, UIScene.didActivateNotification].map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        guard let self, self.isViewInActiveScene, let interaction = self.interaction else { return }
        interaction.isEnabled = false
        interaction.isEnabled = true
      }
    }
    return true
  }

  private func receive(_ hinge: UIHinge?) {
    guard isViewInActiveScene else { return }
    let snapshot: DuoFoldSnapshot
    if let hinge {
      let angle = Double(hinge.angle)
      snapshot = DuoFoldSnapshot(
        hingeAngleRadians: angle.isFinite ? angle : nil,
        posture: Self.postureName(hinge.status),
        hasVerifiedHinge: true
      )
    } else {
      snapshot = .unsupported
    }

    if hasReceivedUpdate && snapshot == lastSnapshot { return }

    lastSnapshot = snapshot
    hasReceivedUpdate = true
    stateChangeHandler?()
    let requests = pendingRequests
    pendingRequests.removeAll()
    for request in requests { request(snapshot) }

    if snapshot.hasVerifiedHinge {
      hingeSink?(snapshot.hingeAngleRadians)
      postureSink?(snapshot.posture)
    } else {
      let error = FlutterError(
        code: "UNSUPPORTED_FEATURE",
        message: "UIKit did not report a hinge for the active Flutter view.",
        details: nil
      )
      hingeSink?(error)
      postureSink?(error)
      hingeSink = nil
      postureSink = nil
    }

    if hingeSink == nil && postureSink == nil && pendingRequests.isEmpty {
      removeInteraction()
    }
  }

  private func removeInteraction() {
    for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
    lifecycleObservers.removeAll()
    if let interaction,
       let controller = viewController,
       controller.isViewLoaded,
       let view = controller.view {
      view.removeInteraction(interaction)
    }
    interaction = nil
    hasReceivedUpdate = false
    lastSnapshot = .unsupported
  }

  private var isViewInActiveScene: Bool {
    guard let controller = viewController,
          controller.isViewLoaded,
          let view = controller.view,
          let window = view.window else { return false }
    if let scene = window.windowScene { return scene.activationState == .foregroundActive }
    return UIApplication.shared.applicationState == .active
  }

  private static func postureName(_ status: UIHinge.Status) -> String {
    switch status {
    case .closed: return "closed"
    case .partiallyOpen: return "partiallyOpen"
    case .fullyOpen: return "fullyOpen"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
  }
}

func makeDuoFoldCapabilityProvider(
  viewControllerProvider: @escaping () -> UIViewController?
) -> DuoFoldCapabilityProvider {
  if #available(iOS 27.1, *) {
    return UIKitDuoFoldCapabilityProvider(
      viewControllerProvider: viewControllerProvider
    )
  }
  return UnsupportedDuoFoldCapabilityProvider()
}
