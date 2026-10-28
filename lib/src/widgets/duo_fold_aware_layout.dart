import 'package:flutter/widgets.dart';

import '../models/duo_capabilities.dart';
import '../models/duo_fold_posture.dart';
import '../models/duo_fold_state.dart';
import 'duo_fold_builder.dart';

/// Selects an optional child only for a posture reported by the native API.
///
/// Unsupported, unknown, or failed fold data uses [defaultLayout]. Responsive
/// width selection remains independent; a [DuoAdaptiveLayout] can be supplied
/// as the default child.
class DuoFoldAwareLayout extends StatelessWidget {
  /// Creates a posture-aware layout with safe default fallbacks.
  const DuoFoldAwareLayout({
    super.key,
    required this.defaultLayout,
    this.closedLayout,
    this.partiallyOpenLayout,
    this.halfOpenLayout,
    this.fullyOpenLayout,
    this.tabletopLayout,
    this.tentLayout,
    this.loadingBuilder,
  });

  /// Layout used when physical posture is unknown or unsupported.
  final Widget defaultLayout;

  /// Optional layout for a native `closed` status.
  final Widget? closedLayout;

  /// Optional layout for native `partiallyOpen` status.
  final Widget? partiallyOpenLayout;

  /// Optional layout for a `halfOpen` status if a platform reports one.
  final Widget? halfOpenLayout;

  /// Optional layout for a native `fullyOpen` status.
  final Widget? fullyOpenLayout;

  /// Optional layout for a native `tabletop` status, when available.
  final Widget? tabletopLayout;

  /// Optional layout for a native `tent` status, when available.
  final Widget? tentLayout;

  /// Optional loading UI; the default layout is used while loading.
  final WidgetBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) => DuoFoldBuilder(
    loadingBuilder: loadingBuilder ?? (_) => defaultLayout,
    unsupportedBuilder: _unsupported,
    errorBuilder: (_, _, _, _) => defaultLayout,
    builder: (_, state, capabilities) => _layoutFor(state, capabilities),
  );

  Widget _unsupported(BuildContext _, DuoCapabilities _) => defaultLayout;

  Widget _layoutFor(DuoFoldState state, DuoCapabilities capabilities) {
    final posture = state.posture;
    if (posture == DuoFoldPosture.unknown ||
        !(capabilities.supportsFoldPosture)) {
      return defaultLayout;
    }
    return switch (posture) {
      DuoFoldPosture.closed => closedLayout ?? defaultLayout,
      DuoFoldPosture.partiallyOpen =>
        partiallyOpenLayout ?? halfOpenLayout ?? defaultLayout,
      DuoFoldPosture.halfOpen =>
        halfOpenLayout ?? partiallyOpenLayout ?? defaultLayout,
      DuoFoldPosture.fullyOpen => fullyOpenLayout ?? defaultLayout,
      DuoFoldPosture.tabletop => tabletopLayout ?? defaultLayout,
      DuoFoldPosture.book => defaultLayout,
      DuoFoldPosture.tent => tentLayout ?? defaultLayout,
      DuoFoldPosture.continuous => defaultLayout,
      DuoFoldPosture.folded => defaultLayout,
      DuoFoldPosture.unknown => defaultLayout,
    };
  }
}
