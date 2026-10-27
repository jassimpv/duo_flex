import 'src/services/duo_flex_service.dart';
import 'src/models/duo_capabilities.dart';
import 'src/models/duo_device_info.dart';
import 'src/models/duo_display_info.dart';
import 'src/models/duo_display_region.dart';
import 'src/models/duo_fold_posture.dart';
import 'src/models/duo_screen_info.dart';
import 'src/platform/duo_flex_platform.dart' show DuoFlexPlatform;

export 'src/models/duo_capabilities.dart';
export 'src/models/duo_device_info.dart';
export 'src/models/duo_display_info.dart';
export 'src/models/duo_display_region.dart';
export 'src/models/duo_fold_posture.dart';
export 'src/models/duo_fold_state.dart';
export 'src/models/duo_hinge_info.dart';
export 'src/models/duo_layout_breakpoints.dart';
export 'src/models/duo_layout_info.dart';
export 'src/models/duo_layout_size.dart';
export 'src/models/duo_safe_area.dart';
export 'src/models/duo_screen_info.dart';
export 'src/models/duo_screen_layout_info.dart';
export 'src/models/display_info.dart';
export 'src/models/display_region.dart';
export 'src/models/screen_dimensions.dart';
export 'src/platform/duo_flex_platform.dart'
    show DuoFlexPlatform, DuoFlexDataPlatform, DuoFlexUnsupportedException;
export 'src/widgets/duo_adaptive_layout.dart';
export 'src/widgets/duo_fold_aware_layout.dart';
export 'src/widgets/duo_fold_builder.dart';
export 'src/widgets/duo_screen_builder.dart';

/// Static public API for display data and platform-reported fold capabilities.
class DuoFlex {
  DuoFlex({DuoFlexPlatform? platform})
    : _instanceService = DuoFlexService(platform: platform);

  final DuoFlexService _instanceService;

  /// Legacy instance API retained for compatibility with earlier releases.
  Future<String?> getPlatformVersion() => _instanceService.getPlatformVersion();

  static final DuoFlexService _service = DuoFlexService();
  static Future<DuoCapabilities> getCapabilities() =>
      _service.getCapabilities();
  static Future<DuoDeviceInfo> getDeviceInfo() => _service.getDeviceInfo();
  static Future<DuoScreenInfo?> getScreenInfo() => _service.getScreenInfo();
  static Future<DuoDisplayInfo?> getDisplayInfo() => _service.getDisplayInfo();
  static Future<List<DuoDisplayRegion>> getDisplayRegions() =>
      _service.getDisplayRegions();

  /// Reads the native hinge angle; UIKit reports this value in radians.
  static Future<double?> getHingeAngle() => _service.getHingeAngle();
  static Future<DuoFoldPosture> getFoldPosture() => _service.getFoldPosture();

  /// Broadcast stream of native hinge angles in the platform's documented unit.
  static Stream<double?> get hingeAngleStream => _service.hingeAngleStream;

  /// Broadcast stream of native posture changes; unsupported hosts report a stream error.
  static Stream<DuoFoldPosture> get foldPostureStream =>
      _service.foldPostureStream;

  /// Emits an initial window snapshot and subsequent meaningful geometry changes.
  static Stream<DuoScreenInfo> get screenInfoStream =>
      _service.screenInfoStream;

  /// Emits full snapshots of the display associated with the active Flutter view.
  static Stream<DuoDisplayInfo> get displayChangesStream =>
      _service.displayChangesStream;
}
