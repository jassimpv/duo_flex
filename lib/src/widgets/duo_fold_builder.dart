import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/duo_capabilities.dart';
import '../models/duo_display_info.dart';
import '../models/duo_fold_data_status.dart';
import '../models/duo_fold_posture.dart';
import '../models/duo_fold_state.dart';
import '../services/duo_flex_service.dart';

/// Builds from capability-checked native fold data.
///
/// The widget refreshes capabilities when display geometry changes and
/// subscribes only to supported event streams. An absent angle remains `null` and an absent
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
  Object? _hingeError;
  Object? _postureError;
  bool _refreshing = false;
  bool _refreshPending = false;
  int _hingeRevision = 0;
  int _postureRevision = 0;
  StreamSubscription<DuoDisplayInfo>? _displaySubscription;
  StreamSubscription<double?>? _hingeSubscription;
  StreamSubscription<DuoFoldPosture>? _postureSubscription;

  @override
  void initState() {
    super.initState();
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    if (_refreshing) {
      _refreshPending = true;
      return;
    }
    _refreshing = true;
    try {
      final capabilities = await _service.getCapabilities();
      if (!mounted) return;
      if (capabilities.supportsDisplayChanges && _displaySubscription == null) {
        _displaySubscription = _service.displayChangesStream.listen(
          (_) => _loadCapabilities(),
          // Geometry observation is optional; fold streams remain usable.
          onError: (Object _) {},
        );
      }
      final changed = capabilities != _capabilities;
      _capabilities = capabilities;
      final supportsHinge = capabilities.supportsHingeAngle;
      final supportsPosture = capabilities.supportsFoldPosture;
      if (!supportsHinge) {
        await _hingeSubscription?.cancel();
        _hingeSubscription = null;
        _hingeError = null;
        _hingeRevision++;
      }
      if (!supportsPosture) {
        await _postureSubscription?.cancel();
        _postureSubscription = null;
        _postureError = null;
        _postureRevision++;
      }
      if (!mounted) return;
      setState(() {
        _foldState = DuoFoldState(
          posture: supportsPosture
              ? _foldState.posture
              : DuoFoldPosture.unknown,
          hingeAngle: supportsHinge ? _foldState.hingeAngle : null,
          timestamp: DateTime.now(),
        );
        _updateStatus();
      });
      if (supportsHinge && _hingeSubscription == null) {
        _hingeSubscription = _service.hingeAngleStream.listen(
          _onHingeAngle,
          onError: (Object error) => _onStreamError(error, hinge: true),
        );
      }
      if (supportsPosture && _postureSubscription == null) {
        _postureSubscription = _service.foldPostureStream.listen(
          _onPosture,
          onError: (Object error) => _onStreamError(error, hinge: false),
        );
      }
      if (changed || _status == DuoFoldDataStatus.loading) {
        // Broadcast streams need not replay to a listener joining later.
        if (supportsHinge) unawaited(_readHingeSnapshot());
        if (supportsPosture) unawaited(_readPostureSnapshot());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = DuoFoldDataStatus.error;
        _error = error;
      });
    } finally {
      _refreshing = false;
      if (mounted && _refreshPending) {
        _refreshPending = false;
        unawaited(_loadCapabilities());
      }
    }
  }

  Future<void> _readHingeSnapshot() async {
    final revision = _hingeRevision;
    try {
      final angle = await _service.getHingeAngle();
      if (mounted && revision == _hingeRevision) _onHingeAngle(angle);
    } catch (error) {
      if (mounted && revision == _hingeRevision) {
        _onStreamError(error, hinge: true);
      }
    }
  }

  Future<void> _readPostureSnapshot() async {
    final revision = _postureRevision;
    try {
      final posture = await _service.getFoldPosture();
      if (mounted && revision == _postureRevision) _onPosture(posture);
    } catch (error) {
      if (mounted && revision == _postureRevision) {
        _onStreamError(error, hinge: false);
      }
    }
  }

  void _updateStatus() {
    _error = _hingeError ?? _postureError;
    _status = _error != null
        ? DuoFoldDataStatus.error
        : !_capabilities.supportsHingeAngle &&
              !_capabilities.supportsFoldPosture
        ? DuoFoldDataStatus.unsupported
        : DuoFoldDataStatus.available;
  }

  void _onHingeAngle(double? angle) {
    if (!mounted) return;
    setState(() {
      _hingeRevision++;
      _hingeError = null;
      _updateStatus();
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
      _postureRevision++;
      _postureError = null;
      _updateStatus();
      _foldState = DuoFoldState(
        posture: posture,
        hingeAngle: _foldState.hingeAngle,
        timestamp: DateTime.now(),
      );
    });
  }

  void _onStreamError(Object error, {required bool hinge}) {
    if (!mounted) return;
    setState(() {
      if (hinge) {
        _hingeRevision++;
        _hingeError = error;
      } else {
        _postureRevision++;
        _postureError = error;
      }
      _updateStatus();
    });
  }

  @override
  void dispose() {
    _displaySubscription?.cancel();
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
