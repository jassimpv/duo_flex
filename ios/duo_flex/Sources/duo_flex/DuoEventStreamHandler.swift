import Flutter
import UIKit

/// Lazily observes UIKit lifecycle and geometry signals while Flutter listens.
final class DuoEventStreamHandler: NSObject, FlutterStreamHandler {
  private let payload: () throws -> [String: Any]?
  private let onStart: () -> Void
  private let onStop: () -> Void
  private let isSceneActive: () -> Bool
  private var eventSink: FlutterEventSink?
  private var observers: [NSObjectProtocol] = []
  private var lastPayload: String?
  private var isListening = false
  private var observationActive = false

  init(
    onStart: @escaping () -> Void = {},
    onStop: @escaping () -> Void = {},
    isSceneActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active },
    payload: @escaping () throws -> [String: Any]?
  ) {
    self.onStart = onStart
    self.onStop = onStop
    self.isSceneActive = isSceneActive
    self.payload = payload
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    dispatchPrecondition(condition: .onQueue(.main))
    cancelObservation()
    eventSink = events
    isListening = true
    let center = NotificationCenter.default
    let names: [Notification.Name] = [
      UIApplication.didBecomeActiveNotification,
      UIApplication.willEnterForegroundNotification,
      UIApplication.didEnterBackgroundNotification,
      UIScene.didActivateNotification,
      UIScene.willDeactivateNotification,
      UIScreen.modeDidChangeNotification,
      UIScreen.didConnectNotification,
      UIScreen.didDisconnectNotification,
    ]
    observers = names.map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.refreshActivity()
      }
    }
    refreshActivity(forceInitial: true)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    dispatchPrecondition(condition: .onQueue(.main))
    cancelObservation()
    return nil
  }

  func emitCurrent() {
    if Thread.isMainThread {
      // Geometry callbacks also signal view attachment and detachment. Recheck
      // scene activity here so an initially unattached view can start emitting
      // as soon as UIKit attaches it to an active window.
      refreshActivity()
    } else {
      DispatchQueue.main.async { [weak self] in self?.refreshActivity() }
    }
  }

  func dispose() {
    cancelObservation()
  }

  private func emitIfChanged(force: Bool = false) {
    guard isListening, observationActive, let eventSink else { return }
    let value: [String: Any]?
    do {
      value = try payload()
    } catch DuoFlexNativeError.viewUnavailable {
      return
    } catch DuoFlexNativeError.windowUnavailable {
      return
    } catch let error as DuoFlexNativeError {
      eventSink(FlutterError(code: error.code, message: error.message, details: nil))
      cancelObservation()
      return
    } catch {
      eventSink(FlutterError(code: "NATIVE_OBSERVER_FAILED", message: error.localizedDescription, details: nil))
      cancelObservation()
      return
    }
    guard let value else { return }
    let fingerprint = (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]))
      .map { String(decoding: $0, as: UTF8.self) } ?? String(describing: value)
    guard force || fingerprint != lastPayload else { return }
    lastPayload = fingerprint
    eventSink(value)
  }

  private func cancelObservation() {
    isListening = false
    eventSink = nil
    lastPayload = nil
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers.removeAll()
    if observationActive {
      observationActive = false
      onStop()
    }
  }

  private func refreshActivity(forceInitial: Bool = false) {
    guard isListening else { return }
    let active = isSceneActive()
    if active == observationActive {
      if observationActive { emitIfChanged(force: forceInitial) }
      return
    }
    if active {
      observationActive = true
      onStart()
      emitIfChanged(force: forceInitial)
    } else {
      // Send a final active-display snapshot before suspending observations.
      emitIfChanged()
      observationActive = false
      onStop()
    }
  }

  deinit {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }
}
