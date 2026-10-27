import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/duo_capabilities.dart';
import '../models/duo_fold_data_status.dart';
import '../models/duo_fold_posture.dart';
import '../models/duo_fold_state.dart';
import '../services/duo_flex_service.dart';

/// Builds from capability-checked native fold data.
///
/// The widget queries capabilities once when inserted, then subscribes only to
/// supported event streams. An absent angle remains `null` and an absent
/// posture remains `unknown`; neither is inferred from layout dimensions.
class DuoFoldBuilder extends StatefulWidget {
  /// Creates a fold-state builder.
  const DuoFoldBuilder({
    super.key,
    required this.builder,
    this.loadingBuilder,
    this.unsupportedBuilder,
    this.errorBuilder,
  });

  /// Builds after capabilities are loaded and at least one feature is available.
  final Widget Function(
    BuildContext context,
    DuoFoldState foldState,
    DuoCapabilities capabilities,
  )
  builder;

  /// Optional loading UI. Defaults to a small descriptive label.
  final WidgetBuilder? loadingBuilder;

  /// Optional unsupported UI. Otherwise [builder] receives false capabilities.
  final Widget Function(BuildContext context, DuoCapabilities capabilities)?
  unsupportedBuilder;

  /// Optional operational-error UI.
  ///
  /// The most recent state and capabilities are passed through so a UI can
  /// continue to show data from a stream that remains available after another
  /// stream reports an error.
  final Widget Function(
    BuildContext context,
    Object error,
    DuoFoldState foldState,
    DuoCapabilities capabilities,
  )?
  errorBuilder;

  @override
  State<DuoFoldBuilder> createState() => _DuoFoldBuilderState();
}

class _DuoFoldBuilderState extends State<DuoFoldBuilder> {
  final DuoFlexService _service = DuoFlexService();
  DuoFoldDataStatus _status = DuoFoldDataStatus.loading;
  DuoCapabilities _capabilities = const DuoCapabilities.unsupported();
  DuoFoldState _foldState = DuoFoldState(
    posture: DuoFoldPosture.unknown,
    hingeAngle: null,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );
  Object? _error;
  StreamSubscription<double?>? _hingeSubscription;
  StreamSubscription<DuoFoldPosture>? _postureSubscription;

  @override
  void initState() {
    super.initState();
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    try {
      final capabilities = await _service.getCapabilities();
      if (!mounted) return;
      _capabilities = capabilities;
      final supportsHinge = capabilities.supportsHingeAngle;
      final supportsPosture = capabilities.supportsFoldPosture;
      if (!supportsHinge && !supportsPosture) {
        setState(() => _status = DuoFoldDataStatus.unsupported);
        return;
      }

      setState(() {
        _status = DuoFoldDataStatus.available;
        _foldState = DuoFoldState(
          posture: DuoFoldPosture.unknown,
          hingeAngle: null,
          timestamp: DateTime.now(),
        );
      });
      if (supportsHinge) {
        _hingeSubscription = _service.hingeAngleStream.listen(
          _onHingeAngle,
          onError: (Object error) => _onStreamError(error),
        );
      }
      if (supportsPosture) {
        _postureSubscription = _service.foldPostureStream.listen(
          _onPosture,
          onError: (Object error) => _onStreamError(error),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = DuoFoldDataStatus.error;
        _error = error;
      });
    }
  }

  void _onHingeAngle(double? angle) {
    if (!mounted) return;
    setState(() {
      _foldState = DuoFoldState(
        posture: _foldState.posture,
        hingeAngle: angle,
        timestamp: DateTime.now(),
      );
    });
  }

  void _onPosture(DuoFoldPosture posture) {
    if (!mounted) return;
    setState(() {
      _foldState = DuoFoldState(
        posture: posture,
        hingeAngle: _foldState.hingeAngle,
        timestamp: DateTime.now(),
      );
    });
  }

  void _onStreamError(Object error) {
    if (!mounted) return;
    setState(() {
      _status = DuoFoldDataStatus.error;
      _error = error;
    });
  }

  @override
  void dispose() {
    _hingeSubscription?.cancel();
    _postureSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      DuoFoldDataStatus.loading =>
        widget.loadingBuilder?.call(context) ??
            const Center(child: Text('Loading fold capabilities…')),
      DuoFoldDataStatus.unsupported =>
        widget.unsupportedBuilder?.call(context, _capabilities) ??
            widget.builder(context, _foldState, _capabilities),
      DuoFoldDataStatus.error =>
        widget.errorBuilder?.call(
              context,
              _error!,
              _foldState,
              _capabilities,
            ) ??
            Center(child: Text('Fold information unavailable: $_error')),
      DuoFoldDataStatus.available => widget.builder(
        context,
        _foldState,
        _capabilities,
      ),
    };
  }
}
