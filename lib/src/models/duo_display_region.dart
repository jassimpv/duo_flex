import 'duo_model_parser.dart';

/// Semantic type of a platform-reported display region.
enum DuoDisplayRegionType {
  unknown,
  applicationWindow,
  mainDisplay,
  secondaryDisplay,
  cameraSideDisplay,
  hingeExclusion,
  cutout,
  reservedDivision,
  reservedOcclusion,
}

DuoDisplayRegionType _regionType(Object? value) {
  if (value is! String) return DuoDisplayRegionType.unknown;
  for (final type in DuoDisplayRegionType.values) {
    final canonical = type.name.toLowerCase();
    final normalized = value
        .replaceAll('_', '')
        .replaceAll('-', '')
        .toLowerCase();
    if (canonical == normalized) return type;
  }
  return DuoDisplayRegionType.unknown;
}

/// A native-reported rectangle in the coordinate system supplied by the platform.
class DuoDisplayRegion {
  DuoDisplayRegion({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.isActive,
    required this.type,
  }) {
    if (!x.isFinite ||
        !y.isFinite ||
        !width.isFinite ||
        !height.isFinite ||
        width < 0 ||
        height < 0) {
      throw ArgumentError(
        'Region coordinates must be finite and dimensions non-negative.',
      );
    }
  }
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool isActive;
  final DuoDisplayRegionType type;
  factory DuoDisplayRegion.fromMap(Map<Object?, Object?> map) =>
      DuoDisplayRegion(
        id: DuoModelParser.optionalString(map['id'], 'id') ?? '',
        x: DuoModelParser.number(map['x'], 'x'),
        y: DuoModelParser.number(map['y'], 'y'),
        width: DuoModelParser.number(map['width'], 'width'),
        height: DuoModelParser.number(map['height'], 'height'),
        isActive: DuoModelParser.boolean(
          map['isActive'],
          'isActive',
          fallback: true,
        ),
        type: _regionType(map['type']),
      );
  Map<String, Object> toMap() => {
    'id': id,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'isActive': isActive,
    'type': type.name,
  };
  @override
  bool operator ==(Object other) =>
      other is DuoDisplayRegion &&
      id == other.id &&
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height &&
      isActive == other.isActive &&
      type == other.type;
  @override
  int get hashCode => Object.hash(id, x, y, width, height, isActive, type);
}
