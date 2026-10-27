import Flutter
import UIKit

enum DuoFlexNativeError: Error {
  case viewUnavailable
  case windowUnavailable
  case displayUnavailable

  var code: String {
    switch self {
    case .viewUnavailable: return "VIEW_UNAVAILABLE"
    case .windowUnavailable: return "WINDOW_UNAVAILABLE"
    case .displayUnavailable: return "DISPLAY_UNAVAILABLE"
    }
  }

  var message: String {
    switch self {
    case .viewUnavailable: return "The Flutter view is not currently available."
    case .windowUnavailable: return "The Flutter view is not attached to a window."
    case .displayUnavailable: return "The active Flutter window has no associated screen."
    }
  }
}

/// Resolves geometry from the Flutter controller and its currently attached view.
final class DuoScreenManager {
  private let viewControllerProvider: () -> UIViewController?
  private var viewController: UIViewController? { viewControllerProvider() }
  private var geometryObserver: DuoViewGeometryObserver?
  private var observerConstraints: [NSLayoutConstraint] = []
  private var geometryListenerCount = 0
  private var lastGeometry: GeometrySnapshot?

  private struct GeometrySnapshot: Equatable {
    let bounds: CGRect
    let scale: CGFloat
    let orientation: UIInterfaceOrientation?
    let safeAreaInsets: UIEdgeInsets
  }

  init(viewControllerProvider: @escaping () -> UIViewController?) {
    self.viewControllerProvider = viewControllerProvider
  }

  var onGeometryChange: (() -> Void)?

  var hasActiveView: Bool {
    guard let controller = viewController,
          controller.isViewLoaded,
          let view = controller.view else { return false }
    return view.window != nil
  }

  var isActiveScene: Bool {
    guard let controller = viewController,
          controller.isViewLoaded,
          let view = controller.view else {
      return UIApplication.shared.applicationState == .active
    }
    guard let window = view.window else {
      // Keep the lightweight geometry observer alive while a subscribed view
      // is temporarily detached, so didMoveToWindow can detect reattachment.
      return UIApplication.shared.applicationState == .active
    }
    return window.windowScene?.activationState == .foregroundActive
  }

  func screenInfo() throws -> [String: Any] {
    guard let controller = viewController,
          controller.isViewLoaded,
          let view = controller.view else {
      throw DuoFlexNativeError.viewUnavailable
    }
    guard let window = view.window else { throw DuoFlexNativeError.windowUnavailable }
    view.layoutIfNeeded()
    let screen = window.screen
    let bounds = view.bounds
    let insets = view.safeAreaInsets
    let safeArea: [String: Double] = [
      "top": Double(insets.top),
      "bottom": Double(insets.bottom),
      "left": Double(insets.left),
      "right": Double(insets.right),
    ]
    let info: [String: Any] = [
      "width": Double(bounds.width),
      "height": Double(bounds.height),
      "devicePixelRatio": Double(screen.scale),
      "orientation": orientation(for: interfaceOrientation(of: window)),
      "safeArea": safeArea,
    ]
    return info
  }

  func currentGeometry() throws -> (view: UIView, window: UIWindow, screen: UIScreen) {
    guard let controller = viewController,
          controller.isViewLoaded,
          let view = controller.view else {
      throw DuoFlexNativeError.viewUnavailable
    }
    guard let window = view.window else { throw DuoFlexNativeError.windowUnavailable }
    view.layoutIfNeeded()
    return (view, window, window.screen)
  }

  func addGeometryListener() {
    geometryListenerCount += 1
    guard geometryObserver == nil,
          let controller = viewController,
          controller.isViewLoaded,
          let view = controller.view else { return }
    lastGeometry = geometrySnapshot(for: view)
    let observer = DuoViewGeometryObserver(frame: .zero)
    observer.translatesAutoresizingMaskIntoConstraints = false
    observer.onGeometryChange = { [weak self] in self?.geometryDidChange() }
    view.addSubview(observer)
    observerConstraints = [
      observer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      observer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      observer.topAnchor.constraint(equalTo: view.topAnchor),
      observer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ]
    NSLayoutConstraint.activate(observerConstraints)
    geometryObserver = observer
  }

  func removeGeometryListener() {
    geometryListenerCount = max(0, geometryListenerCount - 1)
    guard geometryListenerCount == 0 else { return }
    geometryObserver?.onGeometryChange = nil
    geometryObserver?.removeFromSuperview()
    geometryObserver = nil
    NSLayoutConstraint.deactivate(observerConstraints)
    observerConstraints.removeAll()
    lastGeometry = nil
  }

  private func geometryDidChange() {
    guard geometryListenerCount > 0,
          let controller = viewController,
          controller.isViewLoaded,
          let view = controller.view else { return }
    let current = geometrySnapshot(for: view)
    guard current != lastGeometry else { return }
    lastGeometry = current
    onGeometryChange?()
  }

  private func geometrySnapshot(for view: UIView) -> GeometrySnapshot? {
    guard let window = view.window else { return nil }
    return GeometrySnapshot(
      bounds: view.bounds,
      scale: window.screen.scale,
      orientation: interfaceOrientation(of: window),
      safeAreaInsets: view.safeAreaInsets
    )
  }

  private func orientation(for orientation: UIInterfaceOrientation?) -> String {
    switch orientation {
    case .portrait: return "portrait"
    case .portraitUpsideDown: return "portraitUpsideDown"
    case .landscapeLeft: return "landscapeLeft"
    case .landscapeRight: return "landscapeRight"
    default: return "unknown"
    }
  }

  private func interfaceOrientation(of window: UIWindow) -> UIInterfaceOrientation? {
    guard let scene = window.windowScene else { return nil }
    if #available(iOS 26.0, *) {
      return scene.effectiveGeometry.interfaceOrientation
    }
    return scene.interfaceOrientation
  }
}
