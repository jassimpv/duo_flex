import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

import '../models/duo_display_info.dart';
import '../models/duo_display_region.dart';
import '../models/duo_fold_posture.dart';
import '../services/duo_flex_service.dart';

/// Controls which native regions are added to [MediaQuery.displayFeatures].
enum DuoDisplayFeatureBridgeMode {
  /// Keep Flutter's display-feature list unchanged. This is the default.
  none,

  /// Add camera cutouts, while leaving hinge regions out of framework layout.
  cutoutsOnly,

  /// Add camera cutouts and hinge regions. Flutter may confine dialogs and
  /// other surfaces to one side of a reported fold.
  full,
}

/// Opt-in bridge from native display regions to Flutter's `MediaQuery`.
///
/// The default [DuoDisplayFeatureBridgeMode.none] avoids changing existing
/// Material layout behavior when adding DuoFlex to an app.
class DuoDisplayFeatureBridge extends StatefulWidget {
  const DuoDisplayFeatureBridge({
    super.key,
    required this.child,
    this.mode = DuoDisplayFeatureBridgeMode.none,
  });

  final Widget child;
  final DuoDisplayFeatureBridgeMode mode;

  @override
  State<DuoDisplayFeatureBridge> createState() =>
      _DuoDisplayFeatureBridgeState();
}

class _DuoDisplayFeatureBridgeState extends State<DuoDisplayFeatureBridge> {
  final DuoFlexService _service = DuoFlexService();
  DuoDisplayInfo? _display;
  StreamSubscription<DuoDisplayInfo>? _subscription;
  StreamSubscription<DuoFoldPosture>? _postureSubscription;
  DuoFoldPosture _posture = DuoFoldPosture.unknown;

  @override
  void initState() {
    super.initState();
    _configureStreams();
  }

  @override
  void didUpdateWidget(DuoDisplayFeatureBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _configureStreams();
  }

  void _configureStreams() {
    _subscription?.cancel();
    _postureSubscription?.cancel();
    _subscription = null;
    _postureSubscription = null;
    if (widget.mode == DuoDisplayFeatureBridgeMode.none) return;
    _service
        .getDisplayInfo()
        .then((value) {
          if (mounted) setState(() => _display = value);
        })
        .catchError((Object _) {});
    _subscription = _service.displayChangesStream.listen((value) {
      if (mounted) setState(() => _display = value);
    }, onError: (Object _) {});
    if (widget.mode == DuoDisplayFeatureBridgeMode.full) {
      _postureSubscription = _service.foldPostureStream.listen((value) {
        if (mounted) setState(() => _posture = value);
      }, onError: (Object _) {});
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _postureSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (widget.mode == DuoDisplayFeatureBridgeMode.none || _display == null) {
      return widget.child;
    }
    final features = <DisplayFeature>[...media.displayFeatures];
    for (final region in _display!.regions) {
      final type = _featureType(region);
      if (type == null) continue;
      if (region.width <= 0 || region.height <= 0) continue;
      if ((type == DisplayFeatureType.cutout && !region.isActive) ||
          (type == DisplayFeatureType.fold &&
              !const {
                DuoFoldPosture.partiallyOpen,
                DuoFoldPosture.halfOpen,
                DuoFoldPosture.tabletop,
                DuoFoldPosture.book,
                DuoFoldPosture.tent,
              }.contains(_posture))) {
        continue;
      }
      final feature = DisplayFeature(
        bounds: Rect.fromLTWH(region.x, region.y, region.width, region.height),
        type: type,
        state: _featureState(region),
      );
      if (!features.contains(feature)) features.add(feature);
    }
    return MediaQuery(
      data: media.copyWith(displayFeatures: features),
      child: widget.child,
    );
  }

  DisplayFeatureType? _featureType(DuoDisplayRegion region) {
    switch (region.type) {
      case DuoDisplayRegionType.cutout:
      case DuoDisplayRegionType.reservedOcclusion:
        return widget.mode == DuoDisplayFeatureBridgeMode.none
            ? null
            : DisplayFeatureType.cutout;
      case DuoDisplayRegionType.hingeExclusion:
      case DuoDisplayRegionType.reservedDivision:
        return widget.mode == DuoDisplayFeatureBridgeMode.full
            ? DisplayFeatureType.fold
            : null;
      default:
        return null;
    }
  }

  DisplayFeatureState _featureState(DuoDisplayRegion region) {
    if (region.type == DuoDisplayRegionType.cutout ||
        region.type == DuoDisplayRegionType.reservedOcclusion) {
      return DisplayFeatureState.unknown;
    }
    return switch (_posture) {
      DuoFoldPosture.partiallyOpen ||
      DuoFoldPosture.halfOpen ||
      DuoFoldPosture.tabletop ||
      DuoFoldPosture.book ||
      DuoFoldPosture.tent => DisplayFeatureState.postureHalfOpened,
      DuoFoldPosture.fullyOpen => DisplayFeatureState.postureFlat,
      _ => DisplayFeatureState.unknown,
    };
  }
}
