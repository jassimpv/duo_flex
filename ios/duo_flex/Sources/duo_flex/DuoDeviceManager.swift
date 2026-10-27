import UIKit

/// Reads device details available from public UIKit APIs.
final class DuoDeviceManager {
  func deviceInfo(isFoldable: Bool?) -> [String: Any] {
    let device = UIDevice.current
    let foldability: Any = isFoldable.map { $0 as Any } ?? NSNull()
    return [
      "model": device.model,
      "systemName": device.systemName,
      "systemVersion": device.systemVersion,
      "isFoldable": foldability,
    ]
  }
}
