import 'package:flutter/widgets.dart';

import '../models/duo_screen_layout_info.dart';

/// Builds from local Flutter viewport dimensions and the nearest [MediaQuery].
///
/// Width and height are constrained local logical pixels. This widget works on
/// every Flutter platform and does not subscribe to native display streams.
/// [DuoScreenLayoutInfo.viewPadding], [DuoScreenLayoutInfo.padding], and
/// [DuoScreenLayoutInfo.viewInsets] remain separate; keyboard insets are not
/// reported as safe-area padding. None of these values describes a fold hinge.
class DuoScreenBuilder extends StatelessWidget {
  /// Creates a local viewport builder.
  const DuoScreenBuilder({super.key, required this.builder});

  /// Builds using current local viewport information.
  final Widget Function(BuildContext context, DuoScreenLayoutInfo screen)
  builder;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _finiteExtent(
          constraints.maxWidth,
          constraints.minWidth,
          media.size.width,
        );
        final height = _finiteExtent(
          constraints.maxHeight,
          constraints.minHeight,
          media.size.height,
        );
        return builder(
          context,
          DuoScreenLayoutInfo(
            width: width,
            height: height,
            devicePixelRatio: media.devicePixelRatio,
            orientation: media.orientation,
            viewPadding: media.viewPadding,
            padding: media.padding,
            viewInsets: media.viewInsets,
          ),
        );
      },
    );
  }

  static double _finiteExtent(
    double maximum,
    double minimum,
    double viewportFallback,
  ) => maximum.isFinite
      ? maximum
      : (minimum.isFinite && minimum > 0 ? minimum : viewportFallback);
}
