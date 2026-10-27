import '../models/display_info.dart' as legacy;
import '../models/duo_capabilities.dart';
import '../models/duo_device_info.dart';
import '../models/duo_display_info.dart';
import '../models/duo_display_region.dart';
import '../models/duo_fold_posture.dart';
import '../models/duo_screen_info.dart';
import '../platform/duo_flex_platform.dart';

/// Thin application-facing delegation layer for DuoFlex platform data.
class DuoFlexService {
  DuoFlexService({DuoFlexPlatform? platform})
    : _platform = platform ?? DuoFlexPlatform.instance;
  final DuoFlexPlatform _platform;

  DuoFlexDataPlatform get _dataPlatform {
    final platform = _platform;
    if (platform is DuoFlexDataPlatform) return platform;
    throw const DuoFlexUnsupportedException('current typed platform API');
  }

  Future<String?> getPlatformVersion() => _platform.getPlatformVersion();

  Future<DuoCapabilities> getCapabilities() => _dataPlatform.getCapabilities();

  Future<DuoDeviceInfo> getDeviceInfo() => _dataPlatform.getDeviceInfo();

  Future<DuoScreenInfo?> getScreenInfo() => _dataPlatform.getScreenInfo();

  Future<DuoDisplayInfo?> getDisplayInfo() async {
    final value = await _platform.getDisplayInfo();
    if (value == null || value is DuoDisplayInfo) {
      return value as DuoDisplayInfo?;
    }
    if (value is legacy.DisplayInfo) {
      return DuoDisplayInfo(
        width: value.dimensions.width,
        height: value.dimensions.height,
        scale: value.dimensions.devicePixelRatio,
        isActive: true,
        regions: [
          for (var index = 0; index < value.regions.length; index++)
            DuoDisplayRegion(
              id: 'legacy-$index',
              x: value.regions[index].bounds.left,
              y: value.regions[index].bounds.top,
              width: value.regions[index].bounds.width,
              height: value.regions[index].bounds.height,
              isActive: true,
              type: DuoDisplayRegionType.unknown,
            ),
        ],
      );
    }
    throw const DuoFlexUnsupportedException('typed display information');
  }

  Future<List<DuoDisplayRegion>> getDisplayRegions() =>
      _dataPlatform.getDisplayRegions();

  Future<double?> getHingeAngle() => _dataPlatform.getHingeAngle();

  Future<DuoFoldPosture> getFoldPosture() => _dataPlatform.getFoldPosture();

  Stream<double?> get hingeAngleStream => _dataPlatform.hingeAngleStream;

  Stream<DuoFoldPosture> get foldPostureStream =>
      _dataPlatform.foldPostureStream;

  Stream<DuoScreenInfo> get screenInfoStream => _dataPlatform.screenInfoStream;

  Stream<DuoDisplayInfo> get displayChangesStream =>
      _dataPlatform.displayChangesStream;
}
