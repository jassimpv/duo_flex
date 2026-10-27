import UIKit

/// A transparent, non-interactive view that observes geometry lifecycle callbacks.
final class DuoViewGeometryObserver: UIView {
  var onGeometryChange: (() -> Void)?
  private var updateScheduled = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    accessibilityElementsHidden = true
    backgroundColor = .clear
    isOpaque = false
    clipsToBounds = false
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    scheduleGeometryChange()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    scheduleGeometryChange()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    scheduleGeometryChange()
  }

  private func scheduleGeometryChange() {
    guard !updateScheduled else { return }
    updateScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.updateScheduled = false
      self.onGeometryChange?()
    }
  }
}
