import 'package:flutter/widgets.dart';

import 'duo_layout_size.dart';

/// Local layout measurements in Flutter logical pixels.
///
/// [width] and [height] describe the constraints available to the widget, not
/// physical display bounds or fold posture.
@immutable
class DuoLayoutInfo {
  /// Creates a responsive layout description.
  const DuoLayoutInfo({
    required this.width,
    required this.height,
    required this.size,
    required this.orientation,
  });

  /// Available local width in logical pixels.
  final double width;

  /// Available local height in logical pixels.
  final double height;

  /// Responsive category determined from [width].
  final DuoLayoutSize size;

  /// Orientation derived from the reported local dimensions.
  final Orientation orientation;

  /// Whether this is a compact responsive layout.
  bool get isCompact => size == DuoLayoutSize.compact;

  /// Whether this is a medium responsive layout.
  bool get isMedium => size == DuoLayoutSize.medium;

  /// Whether this is an expanded responsive layout.
  bool get isExpanded => size == DuoLayoutSize.expanded;

  /// Whether the local dimensions are landscape.
  bool get isLandscape => orientation == Orientation.landscape;

  /// Whether the local dimensions are portrait.
  bool get isPortrait => orientation == Orientation.portrait;

  @override
  bool operator ==(Object other) =>
      other is DuoLayoutInfo &&
      width == other.width &&
      height == other.height &&
      size == other.size &&
      orientation == other.orientation;

  @override
  int get hashCode => Object.hash(width, height, size, orientation);

  @override
  String toString() =>
      'DuoLayoutInfo(width: $width, height: $height, '
      'size: $size, orientation: $orientation)';
}
