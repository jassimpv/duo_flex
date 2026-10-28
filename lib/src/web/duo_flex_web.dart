import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import '../models/duo_capabilities.dart';
import '../models/duo_device_info.dart';
import '../models/duo_display_info.dart';
import '../models/duo_display_region.dart';
import '../models/duo_fold_posture.dart';
import '../models/duo_safe_area.dart';
import '../models/duo_screen_info.dart';
import '../platform/duo_flex_platform.dart';
import 'device_posture_interop.dart' as posture_api;

/// Browser implementation using viewport events and the Device Posture API.
class DuoFlexWeb extends DuoFlexPlatform implements DuoFlexDataPlatform {
  DuoFlexWeb() {
    _screenListener = ((web.Event _) {
      _screenEvents.add(_screenSnapshot());
    }).toJS;
    _displayListener = ((web.Event _) {
      _displayEvents.add(_displaySnapshot());
    }).toJS;
    _postureListener = ((web.Event _) {
      _postureEvents.add(_reportedPosture());
    }).toJS;
    _screenEvents = StreamController<DuoScreenInfo>.broadcast(
      onListen: () {
        web.window.addEventListener('resize', _screenListener);
        _screenEvents.add(_screenSnapshot());
      },
      onCancel: () => web.window.removeEventListener('resize', _screenListener),
    );
    _displayEvents = StreamController<DuoDisplayInfo>.broadcast(
      onListen: () {
        web.window.addEventListener('resize', _displayListener);
        _displayEvents.add(_displaySnapshot());
      },
      onCancel: () =>
          web.window.removeEventListener('resize', _displayListener),
    );
    _postureEvents = StreamController<DuoFoldPosture>.broadcast(
      onListen: () {
        posture_api.devicePosture?.addEventListener(
          'change',
          _postureListener,
        );
        _postureEvents.add(_reportedPosture());
      },
      onCancel: () => posture_api.devicePosture?.removeEventListener(
        'change',
        _postureListener,
      ),
    );
  }

  static void registerWith(Registrar registrar) {
    DuoFlexPlatform.instance = DuoFlexWeb();
  }

  late final web.EventListener _screenListener;
  late final web.EventListener _displayListener;
  late final web.EventListener _postureListener;
  late final StreamController<DuoScreenInfo> _screenEvents;
  late final StreamController<DuoDisplayInfo> _displayEvents;
  late final StreamController<DuoFoldPosture> _postureEvents;

  bool get _hasPostureApi => posture_api.devicePosture != null;

  DuoFoldPosture _reportedPosture() {
    final value = posture_api.devicePosture?.type.toDart;
    return switch (value) {
      'continuous' => DuoFoldPosture.continuous,
      'folded' => DuoFoldPosture.folded,
      _ => DuoFoldPosture.unknown,
    };
  }

  DuoScreenInfo _screenSnapshot() {
    final width = web.window.innerWidth.toDouble();
    final height = web.window.innerHeight.toDouble();
    final pixelRatio = web.window.devicePixelRatio;
    return DuoScreenInfo(
      width: width,
      height: height,
      devicePixelRatio: pixelRatio.isFinite && pixelRatio > 0 ? pixelRatio : 1,
      orientation: width > height ? 'landscape' : 'portrait',
      safeArea: const DuoSafeArea(top: 0, bottom: 0, left: 0, right: 0),
    );
  }

  DuoDisplayInfo _displaySnapshot() => DuoDisplayInfo(
    identifier: 'browser-window',
    width: web.window.screen.width.toDouble(),
    height: web.window.screen.height.toDouble(),
    scale: web.window.devicePixelRatio,
    isActive: true,
    regions: const <DuoDisplayRegion>[],
    displayType: 'browser',
  );

  @override
  Future<String?> getPlatformVersion() async => 'Web';

  @override
  Future<DuoCapabilities> getCapabilities() async => DuoCapabilities(
    supportsHingeAngle: false,
    supportsFoldPosture: _hasPostureApi,
    supportsDisplayRegions: false,
    supportsDisplayChanges: true,
    supportsMultipleDisplays: false,
    supportsSafeAreaInsets: false,
  );

  @override
  Future<DuoDeviceInfo> getDeviceInfo() async => const DuoDeviceInfo(
    systemName: 'Web',
    isFoldable: null,
  );

  @override
  Future<DuoScreenInfo> getScreenInfo() async => _screenSnapshot();

  @override
  Future<DuoDisplayInfo> getDisplayInfo() async => _displaySnapshot();

  @override
  Future<List<DuoDisplayRegion>> getDisplayRegions() async =>
      const <DuoDisplayRegion>[];

  @override
  Future<double?> getHingeAngle() async => null;

  @override
  Future<DuoFoldPosture> getFoldPosture() async =>
      _hasPostureApi ? _reportedPosture() : DuoFoldPosture.unknown;

  @override
  Stream<double?> get hingeAngleStream => const Stream<double?>.empty();

  @override
  Stream<DuoFoldPosture> get foldPostureStream => _hasPostureApi
      ? _postureEvents.stream
      : const Stream<DuoFoldPosture>.empty();

  @override
  Stream<DuoScreenInfo> get screenInfoStream => _screenEvents.stream;

  @override
  Stream<DuoDisplayInfo> get displayChangesStream => _displayEvents.stream;
}
