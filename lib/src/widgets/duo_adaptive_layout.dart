import 'package:flutter/widgets.dart';

import '../models/duo_layout_breakpoints.dart';
import '../models/duo_layout_info.dart';
import '../models/duo_layout_size.dart';

/// Selects a child from the available local width.
///
/// Breakpoints use logical pixels and classify layout space only. When width is
/// unbounded, the nearest view width is used as a fallback so scrollable
/// parents do not classify a full-width child as compact. Unbounded height uses
/// the nearest view height for the layout orientation reported in
/// [DuoLayoutInfo].
class DuoAdaptiveLayout extends StatelessWidget {
  /// Creates a layout with optional medium and expanded fallbacks.
  const DuoAdaptiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
    this.breakpoints = const DuoLayoutBreakpoints(),
  }) : builder = null;

  /// Creates a layout from the current local measurements.
  const DuoAdaptiveLayout.builder({
    super.key,
    required this.builder,
    this.breakpoints = const DuoLayoutBreakpoints(),
  }) : compact = null,
       medium = null,
       expanded = null;

  /// Compact child used below the medium threshold.
  final Widget? compact;

  /// Medium child, falling back to [compact] when omitted.
  final Widget? medium;

  /// Expanded child, falling back to [medium] and then [compact].
  final Widget? expanded;

  /// Width thresholds in logical pixels.
  final DuoLayoutBreakpoints breakpoints;

  /// Optional callback used by [DuoAdaptiveLayout.builder].
  final Widget Function(BuildContext context, DuoLayoutInfo layout)? builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = _finiteExtent(
        constraints.maxWidth,
        constraints.minWidth,
        fallback: MediaQuery.sizeOf(context).width,
      );
      final height = _finiteExtent(
        constraints.maxHeight,
        constraints.minHeight,
        fallback: MediaQuery.sizeOf(context).height,
      );
      final size = width >= breakpoints.expanded
          ? DuoLayoutSize.expanded
          : width >= breakpoints.medium
          ? DuoLayoutSize.medium
          : DuoLayoutSize.compact;
      final layout = DuoLayoutInfo(
        width: width,
        height: height,
        size: size,
        orientation: width > height
            ? Orientation.landscape
            : Orientation.portrait,
      );

      final layoutBuilder = builder;
      if (layoutBuilder != null) return layoutBuilder(context, layout);
      return switch (size) {
        DuoLayoutSize.compact => compact!,
        DuoLayoutSize.medium => medium ?? compact!,
        DuoLayoutSize.expanded => expanded ?? medium ?? compact!,
      };
    },
  );

  static double _finiteExtent(
    double maximum,
    double minimum, {
    double fallback = 0,
  }) => maximum.isFinite
      ? maximum
      : (minimum.isFinite && minimum > 0 ? minimum : fallback);
}
