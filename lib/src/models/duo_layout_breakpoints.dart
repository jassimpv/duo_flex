/// Configurable responsive width thresholds, measured in Flutter logical pixels.
///
/// Defaults are general layout choices, not device or hardware classifications.
/// Assertions validate thresholds in debug mode; Dart assertions are disabled in
/// release mode.
class DuoLayoutBreakpoints {
  /// Creates responsive thresholds. Both values must be finite and non-negative,
  /// and [expanded] must be greater than [medium].
  const DuoLayoutBreakpoints({this.medium = 600, this.expanded = 840})
    : assert(medium >= 0 && medium < double.infinity),
      assert(expanded >= 0 && expanded < double.infinity),
      assert(expanded > medium);

  /// Minimum width for a medium layout.
  final double medium;

  /// Minimum width for an expanded layout.
  final double expanded;
}
