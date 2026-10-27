import 'package:flutter/widgets.dart';

/// Local Flutter viewport information for adaptive widget layout.
///
/// Dimensions are constrained local logical pixels. [viewPadding] describes
/// system intrusions, [padding] is the currently unobscured safe area, and
/// [viewInsets] describes fully obscured areas such as the on-screen keyboard.
/// These values do not describe hinge geometry. They come from [MediaQuery],
/// which already accounts for framework safe-area adjustments.
@immutable
class DuoScreenLayoutInfo {
  /// Creates local Flutter viewport information.
  const DuoScreenLayoutInfo({
    required this.width,
    required this.height,
    required this.devicePixelRatio,
    required this.orientation,
    required this.viewPadding,
    required this.padding,
    required this.viewInsets,
  });

  /// Local viewport width in logical pixels.
  final double width;

  /// Local viewport height in logical pixels.
  final double height;

  /// Device pixel ratio from the nearest [MediaQuery].
  final double devicePixelRatio;

  /// Orientation of the current Flutter view.
  final Orientation orientation;

  /// System intrusions, including physical cutouts, in logical pixels.
  final EdgeInsets viewPadding;

  /// Safe padding currently available after obscured insets are applied.
  final EdgeInsets padding;

  /// Obscured insets such as the on-screen keyboard; not safe-area padding.
  final EdgeInsets viewInsets;
}
