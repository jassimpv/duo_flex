/// Logical and physical dimensions reported by the platform display.
class ScreenDimensions {
  const ScreenDimensions({
    required this.width,
    required this.height,
    required this.devicePixelRatio,
  });

  final double width;
  final double height;
  final double devicePixelRatio;

  factory ScreenDimensions.fromMap(Map<Object?, Object?> map) {
    return ScreenDimensions(
      width: _asDouble(map['width']),
      height: _asDouble(map['height']),
      devicePixelRatio: _asDouble(map['devicePixelRatio']),
    );
  }

  Map<String, Object> toMap() => <String, Object>{
    'width': width,
    'height': height,
    'devicePixelRatio': devicePixelRatio,
  };

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    throw FormatException('Expected a numeric display value, got $value.');
  }
}
