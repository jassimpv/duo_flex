import 'package:flutter/widgets.dart';

import '../models/display_info.dart';

/// Provides a layout callback with the regions reported by the platform.
class DuoFlexAdaptiveLayout extends StatelessWidget {
  const DuoFlexAdaptiveLayout({
    required this.displayInfo,
    required this.builder,
    super.key,
  });

  final DisplayInfo displayInfo;
  final Widget Function(BuildContext context, DisplayInfo displayInfo) builder;

  @override
  Widget build(BuildContext context) => builder(context, displayInfo);
}
