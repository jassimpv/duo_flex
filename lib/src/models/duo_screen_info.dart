import 'duo_model_parser.dart';
import 'duo_safe_area.dart';

/// Application window dimensions in Flutter logical pixels, not physical display bounds.
class DuoScreenInfo {
  DuoScreenInfo({required this.width, required this.height, required this.devicePixelRatio,
    required this.orientation, required this.safeArea}) {
    if (!width.isFinite || width < 0 || !height.isFinite || height < 0) {
      throw ArgumentError('Screen dimensions must be finite and non-negative.');
    }
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) {
      throw ArgumentError.value(devicePixelRatio, 'devicePixelRatio', 'Must be positive and finite.');
    }
  }
  final double width;
  final double height;
  final double devicePixelRatio;
  /// Platform orientation label; unknown values are retained as `unknown`.
  final String orientation;
  final DuoSafeArea safeArea;
  factory DuoScreenInfo.fromMap(Map<Object?, Object?> map) => DuoScreenInfo(
    width: DuoModelParser.number(map['width'], 'width'),
    height: DuoModelParser.number(map['height'], 'height'),
    devicePixelRatio: DuoModelParser.number(map['devicePixelRatio'], 'devicePixelRatio'),
    orientation: DuoModelParser.optionalString(map['orientation'], 'orientation') ?? 'unknown',
    safeArea: DuoSafeArea.fromMap(DuoModelParser.map(map['safeArea'], 'safeArea')),
  );
  Map<String, Object> toMap() => {'width': width, 'height': height, 'devicePixelRatio': devicePixelRatio,
    'orientation': orientation, 'safeArea': safeArea.toMap()};
  @override
  bool operator ==(Object other) => other is DuoScreenInfo && width == other.width && height == other.height &&
    devicePixelRatio == other.devicePixelRatio && orientation == other.orientation && safeArea == other.safeArea;
  @override
  int get hashCode => Object.hash(width, height, devicePixelRatio, orientation, safeArea);
}
