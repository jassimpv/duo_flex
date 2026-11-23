import 'package:flutter/widgets.dart';

import '../models/duo_capabilities.dart';
import '../models/duo_fold_posture.dart';
import '../models/duo_fold_state.dart';
import 'duo_fold_builder.dart';

/// Facets exposed by [DuoMediaQuery] for selective widget rebuilds.
enum DuoMediaAspect { posture, hingeAngle, capabilities }

/// Installs fold data in the widget tree, similar to Flutter's `MediaQuery`.
///
/// Only widgets that request a changed [DuoMediaAspect] rebuild when native
/// fold data changes.
class DuoFoldProvider extends StatelessWidget {
  const DuoFoldProvider({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DuoFoldBuilder(
    loadingBuilder: (_) => child,
    builder: (context, state, capabilities) =>
        _DuoFoldScope(state: state, capabilities: capabilities, child: child),
    unsupportedBuilder: (_, capabilities) => _DuoFoldScope(
      state: DuoFoldState(
        posture: DuoFoldPosture.unknown,
        hingeAngle: null,
        timestamp: DateTime.now(),
      ),
      capabilities: capabilities,
      child: child,
    ),
    errorBuilder: (_, _, state, capabilities) =>
        _DuoFoldScope(state: state, capabilities: capabilities, child: child),
  );
}

class _DuoFoldScope extends InheritedModel<DuoMediaAspect> {
  const _DuoFoldScope({
    required this.state,
    required this.capabilities,
    required super.child,
  });

  final DuoFoldState state;
  final DuoCapabilities capabilities;

  @override
  bool updateShouldNotify(_DuoFoldScope oldWidget) =>
      state != oldWidget.state || capabilities != oldWidget.capabilities;

  @override
  bool updateShouldNotifyDependent(
    _DuoFoldScope oldWidget,
    Set<DuoMediaAspect> aspects,
  ) {
    return (aspects.contains(DuoMediaAspect.posture) &&
            state.posture != oldWidget.state.posture) ||
        (aspects.contains(DuoMediaAspect.hingeAngle) &&
            state.hingeAngle != oldWidget.state.hingeAngle) ||
        (aspects.contains(DuoMediaAspect.capabilities) &&
            capabilities != oldWidget.capabilities);
  }
}

/// Reads only the requested fold-data facet and rebuilds when it changes.
class DuoMediaQuery {
  DuoMediaQuery._();

  static DuoFoldState of(BuildContext context) =>
      InheritedModel.inheritFrom<_DuoFoldScope>(context)!.state;

  static DuoFoldState? maybeOf(BuildContext context) =>
      InheritedModel.inheritFrom<_DuoFoldScope>(context)?.state;

  static DuoFoldPosture postureOf(BuildContext context) =>
      InheritedModel.inheritFrom<_DuoFoldScope>(
        context,
        aspect: DuoMediaAspect.posture,
      )!.state.posture;

  static double? hingeAngleOf(BuildContext context) =>
      InheritedModel.inheritFrom<_DuoFoldScope>(
        context,
        aspect: DuoMediaAspect.hingeAngle,
      )!.state.hingeAngle;

  static DuoCapabilities capabilitiesOf(BuildContext context) =>
      InheritedModel.inheritFrom<_DuoFoldScope>(
        context,
        aspect: DuoMediaAspect.capabilities,
      )!.capabilities;
}
