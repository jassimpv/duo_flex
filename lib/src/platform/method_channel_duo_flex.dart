import 'dart:async';

import 'package:flutter/services.dart';

import '../models/duo_capabilities.dart';
import '../models/duo_device_info.dart';
import '../models/duo_display_info.dart';
import '../models/duo_display_region.dart';
import '../models/duo_fold_posture.dart';
import '../models/duo_model_parser.dart';
import '../models/duo_screen_info.dart';
import 'duo_flex_platform.dart';

/// Method and event channel implementation of [DuoFlexPlatform].
class MethodChannelDuoFlex extends DuoFlexPlatform
    implements DuoFlexDataPlatform {
  /// Method channel used for point-in-time API requests.
  final MethodChannel methodChannel = const MethodChannel('duo_flex/methods');
  static const EventChannel _hinge = EventChannel('duo_flex/hinge_angle');
  static const EventChannel _posture = EventChannel('duo_flex/fold_posture');
  static const EventChannel _screen = EventChannel('duo_flex/screen_info');
  static const EventChannel _display = EventChannel('duo_flex/display_changes');

  late final Stream<double?> _hingeAngleEvents = _events<double?>(
    _hinge,
    (value) => DuoModelParser.optionalNumber(value, 'hinge angle event'),
    'hinge angle',
  );
  late final Stream<DuoFoldPosture> _foldPostureEvents =
      _events<DuoFoldPosture>(_posture, (value) {
        if (value != null && value is! String) {
          throw const FormatException('Expected posture string.');
        }
        return fromNativePosture(value as String?);
      }, 'fold posture');
  late final Stream<DuoScreenInfo> _screenInfoEvents = _events<DuoScreenInfo>(
    _screen,
    (value) => DuoScreenInfo.fromMap(_responseMap(value, 'screen info')),
    'screen info',
  );
  late final Stream<DuoDisplayInfo> _displayChangesEvents =
      _events<DuoDisplayInfo>(
        _display,
        (value) => DuoDisplayInfo.fromMap(_responseMap(value, 'display info')),
        'display info',
      );

  Future<Object?> _invoke(String method) async {
    return methodChannel.invokeMethod<Object?>(method);
  }

  Map<Object?, Object?> _responseMap(Object? value, String method) {
    try {
      return DuoModelParser.map(value, method);
    } on FormatException catch (error) {
      throw PlatformException(
        code: 'invalid_response',
        message: error.message,
        details: method,
      );
    }
  }

  T _decode<T>(T Function() decoder, String context) {
    try {
      return decoder();
    } on FormatException catch (error) {
      throw PlatformException(
        code: 'invalid_response',
        message: error.message,
        details: context,
      );
    } on ArgumentError catch (error) {
      throw PlatformException(
        code: 'invalid_response',
        message: error.message?.toString(),
        details: context,
      );
    }
  }

  @override
  Future<String?> getPlatformVersion() =>
      methodChannel.invokeMethod<String>('getPlatformVersion');

  @override
  Future<DuoCapabilities> getCapabilities() async {
    final value = await _invoke('getCapabilities');
    return _decode(
      () => DuoCapabilities.fromMap(_responseMap(value, 'getCapabilities')),
      'getCapabilities',
    );
  }

  @override
  Future<DuoDeviceInfo> getDeviceInfo() async {
    final value = await _invoke('getDeviceInfo');
    return _decode(
      () => DuoDeviceInfo.fromMap(_responseMap(value, 'getDeviceInfo')),
      'getDeviceInfo',
    );
  }

  @override
  Future<DuoScreenInfo?> getScreenInfo() async {
    final value = await _invoke('getScreenInfo');
    return value == null
        ? null
        : _decode(
            () => DuoScreenInfo.fromMap(_responseMap(value, 'getScreenInfo')),
            'getScreenInfo',
          );
  }

  @override
  Future<DuoDisplayInfo?> getDisplayInfo() async {
    final value = await _invoke('getDisplayInfo');
    return value == null
        ? null
        : _decode(
            () => DuoDisplayInfo.fromMap(_responseMap(value, 'getDisplayInfo')),
            'getDisplayInfo',
          );
  }

  @override
  Future<List<DuoDisplayRegion>> getDisplayRegions() async {
    final value = await _invoke('getDisplayRegions');
    if (value is! List<Object?>) {
      throw PlatformException(
        code: 'invalid_response',
        message: 'Expected display region list.',
      );
    }
    return value
        .map(
          (item) => _decode(
            () =>
                DuoDisplayRegion.fromMap(_responseMap(item, 'display region')),
            'display region',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<double?> getHingeAngle() async {
    final value = await _invoke('getHingeAngle');
    if (value == null) return null;
    return _decode(
      () => DuoModelParser.optionalNumber(value, 'hinge angle'),
      'getHingeAngle',
    );
  }

  @override
  Future<DuoFoldPosture> getFoldPosture() async {
    final value = await _invoke('getFoldPosture');
    if (value != null && value is! String) {
      throw PlatformException(
        code: 'invalid_response',
        message: 'Expected posture string.',
      );
    }
    return fromNativePosture(value as String?);
  }

  Stream<T> _events<T>(
    EventChannel channel,
    T Function(Object?) decode,
    String name,
  ) {
    return channel.receiveBroadcastStream().map((Object? event) {
      try {
        return decode(event);
      } on FormatException catch (error) {
        throw PlatformException(
          code: 'invalid_event',
          message: error.message,
          details: name,
        );
      } on ArgumentError catch (error) {
        throw PlatformException(
          code: 'invalid_event',
          message: error.message?.toString(),
          details: name,
        );
      }
    });
  }

  @override
  Stream<double?> get hingeAngleStream => _hingeAngleEvents;
  @override
  Stream<DuoFoldPosture> get foldPostureStream => _foldPostureEvents;
  @override
  Stream<DuoScreenInfo> get screenInfoStream => _screenInfoEvents;
  @override
  Stream<DuoDisplayInfo> get displayChangesStream => _displayChangesEvents;
}
