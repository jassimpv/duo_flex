import Flutter

/// Adapts one fold-related EventChannel subscription to the shared provider.
final class DuoFoldEventStreamHandler: NSObject, FlutterStreamHandler {
  private let onListen: (@escaping FlutterEventSink) -> Void
  private let onCancel: () -> Void
  private let isSupported: () -> Bool
  private var isListening = false

  init(
    isSupported: @escaping () -> Bool,
    onListen: @escaping (@escaping FlutterEventSink) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.isSupported = isSupported
    self.onListen = onListen
    self.onCancel = onCancel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    dispatchPrecondition(condition: .onQueue(.main))
    guard isSupported() else {
      return FlutterError(
        code: "UNSUPPORTED_FEATURE",
        message: "Hinge updates require UIKit's iOS 27.1 hinge API.",
        details: nil
      )
    }
    if isListening { onCancel() }
    isListening = true
    onListen(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    dispatchPrecondition(condition: .onQueue(.main))
    if isListening {
      isListening = false
      onCancel()
    }
    return nil
  }

  func dispose() {
    if isListening {
      isListening = false
      onCancel()
    }
  }
}
