import 'duo_model_parser.dart';

/// A hinge measurement, if the platform exposes one through public APIs.
class DuoHingeInfo {
  DuoHingeInfo({
    required double? angle,
    required bool isAvailable,
    this.timestamp,
  }) : angle = angle == null ? null : _finite(angle),
       isAvailable = angle != null && isAvailable;

  /// Native hinge measurement; UIKit's current API reports radians.
  final double? angle;
  final bool isAvailable;
  final DateTime? timestamp;
  static double _finite(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'angle', 'Must be finite.');
    }
    return value;
  }

  factory DuoHingeInfo.fromMap(Map<Object?, Object?> map) {
    final value = DuoModelParser.optionalNumber(map['angle'], 'angle');
    return DuoHingeInfo(
      angle: value,
      isAvailable: value != null && map['isAvailable'] == true,
      timestamp: map['timestamp'] == null
          ? null
          : DuoModelParser.dateTime(map['timestamp'], 'timestamp'),
    );
  }
  Map<String, Object?> toMap() => {
    'angle': angle,
    'isAvailable': isAvailable,
    'timestamp': timestamp?.toIso8601String(),
  };
  @override
  bool operator ==(Object other) =>
      other is DuoHingeInfo &&
      angle == other.angle &&
      isAvailable == other.isAvailable &&
      timestamp == other.timestamp;
  @override
  int get hashCode => Object.hash(angle, isAvailable, timestamp);
}
