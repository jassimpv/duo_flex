import 'duo_fold_posture.dart';
import 'duo_model_parser.dart';

const Object _unchangedAngle = Object();

/// A timestamped snapshot of posture and any available hinge measurement.
class DuoFoldState {
  DuoFoldState({
    required this.posture,
    required this.hingeAngle,
    required this.timestamp,
  }) {
    if (hingeAngle != null && !hingeAngle!.isFinite) {
      throw ArgumentError.value(hingeAngle, 'hingeAngle', 'Must be finite.');
    }
  }
  final DuoFoldPosture posture;
  final double? hingeAngle;
  final DateTime timestamp;
  factory DuoFoldState.fromMap(Map<Object?, Object?> map) => DuoFoldState(
    posture: fromNativePosture(
      DuoModelParser.optionalString(map['posture'], 'posture'),
    ),
    hingeAngle: DuoModelParser.optionalNumber(map['hingeAngle'], 'hingeAngle'),
    timestamp: DuoModelParser.dateTime(map['timestamp'], 'timestamp'),
  );
  Map<String, Object?> toMap() => {
    'posture': toNativePosture(posture),
    'hingeAngle': hingeAngle,
    'timestamp': timestamp.toIso8601String(),
  };
  DuoFoldState copyWith({
    DuoFoldPosture? posture,
    Object? hingeAngle = _unchangedAngle,
    DateTime? timestamp,
  }) => DuoFoldState(
    posture: posture ?? this.posture,
    hingeAngle: identical(hingeAngle, _unchangedAngle)
        ? this.hingeAngle
        : hingeAngle == null
        ? null
        : DuoModelParser.number(hingeAngle, 'hingeAngle'),
    timestamp: timestamp ?? this.timestamp,
  );
  @override
  bool operator ==(Object other) =>
      other is DuoFoldState &&
      posture == other.posture &&
      hingeAngle == other.hingeAngle &&
      timestamp == other.timestamp;
  @override
  int get hashCode => Object.hash(posture, hingeAngle, timestamp);
}
