import 'duo_model_parser.dart';

/// Safe-area insets in logical points; these are not hinge geometry.
class DuoSafeArea {
  const DuoSafeArea({required this.top, required this.bottom, required this.left, required this.right});
  final double top;
  final double bottom;
  final double left;
  final double right;

  factory DuoSafeArea.fromMap(Map<Object?, Object?> map) => DuoSafeArea(
    top: DuoModelParser.number(map['top'], 'top'),
    bottom: DuoModelParser.number(map['bottom'], 'bottom'),
    left: DuoModelParser.number(map['left'], 'left'),
    right: DuoModelParser.number(map['right'], 'right'),
  );

  Map<String, Object> toMap() => {'top': top, 'bottom': bottom, 'left': left, 'right': right};
  DuoSafeArea copyWith({double? top, double? bottom, double? left, double? right}) => DuoSafeArea(
    top: top ?? this.top, bottom: bottom ?? this.bottom, left: left ?? this.left, right: right ?? this.right);
  @override
  bool operator ==(Object other) => other is DuoSafeArea && top == other.top && bottom == other.bottom && left == other.left && right == other.right;
  @override
  int get hashCode => Object.hash(top, bottom, left, right);
  @override
  String toString() => 'DuoSafeArea(top: $top, bottom: $bottom, left: $left, right: $right)';
}
