import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../models/duo_capabilities.dart';
import '../models/duo_device_info.dart';
import '../models/duo_display_info.dart';
import '../models/duo_display_region.dart';
import '../models/duo_fold_posture.dart';
import '../models/duo_screen_info.dart';
import 'method_channel_duo_flex.dart';

/// Exception indicating an API or stream is not implemented by the host.
class DuoFlexUnsupportedException implements Exception {
  const DuoFlexUnsupportedException(this.feature);
  final String feature;
  @override
  String toString() => 'DuoFlexUnsupportedException: $feature is unsupported.';
}

/// Legacy platform contract retained for existing platform implementations.
abstract class DuoFlexPlatform extends PlatformInterface {
  DuoFlexPlatform() : super(token: _token);
  static final Object _token = Object();
  static DuoFlexPlatform _instance = MethodChannelDuoFlex();
  static DuoFlexPlatform get instance => _instance;
  static set instance(DuoFlexPlatform value) {
    PlatformInterface.verifyToken(value, _token);
    _instance = value;
  }

  Future<String?> getPlatformVersion();

  /// Legacy display method retained for platform fakes and older adapters.
  /// New implementations should also implement [DuoFlexDataPlatform] to expose
  /// the strongly typed display model and the rest of the current API.
  Future<Object?> getDisplayInfo();
}

/// Current typed platform contract used by the plugin service.
///
/// Keeping this separate allows older platform implementations of
/// [DuoFlexPlatform] to continue supporting the original API surface.
/// Implement this interface for all current capabilities and event streams.
abstract interface class DuoFlexDataPlatform implements DuoFlexPlatform {
  Future<DuoCapabilities> getCapabilities();
  Future<DuoDeviceInfo> getDeviceInfo();
  Future<DuoScreenInfo?> getScreenInfo();
  @override
  Future<DuoDisplayInfo?> getDisplayInfo();
  Future<List<DuoDisplayRegion>> getDisplayRegions();
  Future<double?> getHingeAngle();
  Future<DuoFoldPosture> getFoldPosture();
  Stream<double?> get hingeAngleStream;
  Stream<DuoFoldPosture> get foldPostureStream;
  Stream<DuoScreenInfo> get screenInfoStream;
  Stream<DuoDisplayInfo> get displayChangesStream;
}
