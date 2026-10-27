import UIKit

/// Reports the Flutter window and any generic UIKit reserved regions.
final class DuoDisplayManager {
  private let screenManager: DuoScreenManager

  init(screenManager: DuoScreenManager) {
    self.screenManager = screenManager
  }

  func displayInfo() throws -> [String: Any] {
    let geometry = try screenManager.currentGeometry()
    let regions = try displayRegions()
    return [
      "identifier": NSNull(),
      "width": Double(geometry.screen.bounds.width),
      "height": Double(geometry.screen.bounds.height),
      "scale": Double(geometry.screen.scale),
      "isActive": geometry.window.windowScene?.activationState == .foregroundActive,
      "regions": regions,
      "displayType": NSNull(),
    ]
  }

  func displayRegions() throws -> [[String: Any]] {
    let geometry = try screenManager.currentGeometry()
    let bounds = geometry.view.bounds
    var regions: [[String: Any]] = [[
      "id": "application_window",
      "x": Double(bounds.minX),
      "y": Double(bounds.minY),
      "width": Double(bounds.width),
      "height": Double(bounds.height),
      "isActive": geometry.window.windowScene?.activationState == .foregroundActive,
      "type": "applicationWindow",
    ]]
    if #available(iOS 27.1, *) {
      regions.append(contentsOf: reservedRegions(in: geometry.view))
    }
    return regions
  }

  @available(iOS 27.1, *)
  private func reservedRegions(in view: UIView) -> [[String: Any]] {
    let divisionRegions = view.reservedRegions(kind: .division)
    let occlusionRegions = view.reservedRegions(kind: .occlusion)
    return (divisionRegions.map { ($0, "reservedDivision") } +
      occlusionRegions.map { ($0, "reservedOcclusion") }).map { entry in
        let (region, type) = entry
        return [
          "id": region.id.description,
          "x": Double(region.frame.minX),
          "y": Double(region.frame.minY),
          "width": Double(region.frame.width),
          "height": Double(region.frame.height),
          "isActive": region.isActive,
          "type": type,
        ]
      }
  }
}
