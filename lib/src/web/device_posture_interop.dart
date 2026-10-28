@JS()
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS()
extension type DevicePosture._(JSObject _) implements JSObject {
  external JSString get type;
  external void addEventListener(String type, web.EventListener? callback);
  external void removeEventListener(String type, web.EventListener? callback);
}

@JS('navigator.devicePosture')
external DevicePosture? get devicePosture;
