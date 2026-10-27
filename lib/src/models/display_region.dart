import 'dart:ui';

/// A display region in logical Flutter coordinates.
class DisplayRegion {
  const DisplayRegion({required this.bounds});

  final Rect bounds;

  factory DisplayRegion.fromMap(Map<Object?, Object?> map) {
    final left = _asDouble(map['left']);
    final top = _asDouble(map['top']);
    final width = _asDouble(map['width']);
    final height = _asDouble(map['height']);
    return DisplayRegion(bounds: Rect.fromLTWH(left, top, width, height));
  }

  Map<String, Object> toMap() => <String, Object>{
    'left': bounds.left,
    'top': bounds.top,
    'width': bounds.width,
    'height': bounds.height,
  };

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    throw FormatException('Expected a numeric region value, got $value.');
  }
}
