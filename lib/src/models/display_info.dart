import 'display_region.dart';
import 'screen_dimensions.dart';

/// Display information currently available from the platform.
class DisplayInfo {
  const DisplayInfo({required this.dimensions, required this.regions});

  final ScreenDimensions dimensions;
  final List<DisplayRegion> regions;

  factory DisplayInfo.fromMap(Map<Object?, Object?> map) {
    final rawRegions = map['regions'];
    if (rawRegions is! List<Object?>) {
      throw const FormatException('Expected a display regions list.');
    }

    return DisplayInfo(
      dimensions: ScreenDimensions.fromMap(_asMap(map['dimensions'])),
      regions: rawRegions
          .map((Object? region) => DisplayRegion.fromMap(_asMap(region)))
          .toList(growable: false),
    );
  }

  static Map<Object?, Object?> _asMap(Object? value) {
    if (value is Map<Object?, Object?>) return value;
    throw FormatException('Expected a display information map, got $value.');
  }
}
