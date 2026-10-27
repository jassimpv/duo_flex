import 'duo_display_region.dart';
import 'duo_model_parser.dart';

/// Physical or externally reported display data, distinct from the app window.
/// Coordinates are preserved in the native coordinate system without conversion.
class DuoDisplayInfo {
  DuoDisplayInfo({this.identifier, required this.width, required this.height, required this.scale,
    required this.isActive, required List<DuoDisplayRegion> regions, this.displayType})
    : regions = List.unmodifiable(regions) {
    if (!width.isFinite || width < 0 || !height.isFinite || height < 0 || !scale.isFinite || scale <= 0) {
      throw ArgumentError('Display dimensions must be non-negative and scale positive and finite.');
    }
  }
  final String? identifier;
  final double width;
  final double height;
  final double scale;
  final bool isActive;
  final List<DuoDisplayRegion> regions;
  final String? displayType;
  factory DuoDisplayInfo.fromMap(Map<Object?, Object?> map) {
    final raw = map['regions'] ?? const <Object?>[];
    if (raw is! List<Object?>) throw const FormatException('Expected regions to be a list.');
    return DuoDisplayInfo(identifier: DuoModelParser.optionalString(map['identifier'], 'identifier'),
      width: DuoModelParser.number(map['width'], 'width'), height: DuoModelParser.number(map['height'], 'height'),
      scale: DuoModelParser.number(map['scale'], 'scale'), isActive: DuoModelParser.boolean(map['isActive'], 'isActive', fallback: true),
      regions: raw.map((Object? item) => DuoDisplayRegion.fromMap(DuoModelParser.map(item, 'region'))).toList(),
      displayType: DuoModelParser.optionalString(map['displayType'], 'displayType'));
  }
  Map<String, Object?> toMap() => {'identifier': identifier, 'width': width, 'height': height, 'scale': scale,
    'isActive': isActive, 'regions': regions.map((r) => r.toMap()).toList(), 'displayType': displayType};
  DuoDisplayInfo copyWith({String? identifier, double? width, double? height, double? scale, bool? isActive,
    List<DuoDisplayRegion>? regions, String? displayType}) => DuoDisplayInfo(identifier: identifier ?? this.identifier,
      width: width ?? this.width, height: height ?? this.height, scale: scale ?? this.scale,
      isActive: isActive ?? this.isActive, regions: regions ?? this.regions, displayType: displayType ?? this.displayType);
  @override
  bool operator ==(Object other) => other is DuoDisplayInfo && identifier == other.identifier && width == other.width && height == other.height && scale == other.scale && isActive == other.isActive && _listEquals(regions, other.regions) && displayType == other.displayType;
  static bool _listEquals(List<Object?> a, List<Object?> b) { if (a.length != b.length) return false; for (var i = 0; i < a.length; i++) { if (a[i] != b[i]) return false; } return true; }
  @override
  int get hashCode => Object.hash(identifier, width, height, scale, isActive, Object.hashAll(regions), displayType);
}
