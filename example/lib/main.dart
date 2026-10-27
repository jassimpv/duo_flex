import 'dart:async';
import 'dart:math' as math;

import 'package:duo_flex/duo_flex.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DuoFlexExampleApp());

class DuoFlexExampleApp extends StatefulWidget {
  const DuoFlexExampleApp({super.key});

  @override
  State<DuoFlexExampleApp> createState() => _DuoFlexExampleAppState();
}

typedef MyApp = DuoFlexExampleApp;

class _DuoFlexExampleAppState extends State<DuoFlexExampleApp> {
  DuoDeviceInfo? _device;
  DuoScreenInfo? _screen;
  DuoDisplayInfo? _display;
  DuoCapabilities? _capabilities;
  Object? _error;
  StreamSubscription<DuoScreenInfo>? _screenSubscription;
  StreamSubscription<DuoDisplayInfo>? _displaySubscription;
  StreamSubscription<double?>? _hingeSubscription;
  StreamSubscription<DuoFoldPosture>? _postureSubscription;
  double? _hingeAngleRadians;
  DuoFoldPosture _posture = DuoFoldPosture.unknown;
  int _hingeEventRevision = 0;
  int _postureEventRevision = 0;
  String? _foldStreamError;
  final List<String> _eventHistory = <String>[];

  @override
  void initState() {
    super.initState();
    _load();
    _screenSubscription = DuoFlex.screenInfoStream.listen(
      (value) {
        if (!mounted) return;
        setState(() {
          _screen = value;
          _appendEvent('Screen snapshot ${value.width} × ${value.height}');
        });
      },
      onError: (Object error) {
        _recordEvent('Screen stream error: $error');
      },
    );
    _displaySubscription = DuoFlex.displayChangesStream.listen(
      (value) {
        if (!mounted) return;
        setState(() {
          _display = value;
          _appendEvent('Display snapshot ${value.width} × ${value.height}');
        });
      },
      onError: (Object error) {
        _recordEvent('Display stream error: $error');
      },
    );
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>([
        DuoFlex.getDeviceInfo(),
        DuoFlex.getCapabilities(),
      ]);
      if (!mounted) return;
      setState(() {
        _device = values[0] as DuoDeviceInfo;
        _capabilities = values[1] as DuoCapabilities;
        _appendEvent('Initial device capabilities loaded');
      });
      unawaited(_loadScreenSnapshot());
      unawaited(_loadDisplaySnapshot());
      final capabilities = values[1] as DuoCapabilities;
      if (capabilities.supportsHingeAngle || capabilities.supportsFoldPosture) {
        _listenToFoldUpdates(capabilities);
        await _loadNativeFoldSnapshot(capabilities);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _loadScreenSnapshot() async {
    try {
      final screen = await DuoFlex.getScreenInfo();
      if (!mounted || screen == null) return;
      setState(() => _screen ??= screen);
    } catch (error) {
      _recordEvent('Initial screen snapshot unavailable: $error');
    }
  }

  Future<void> _loadDisplaySnapshot() async {
    try {
      final display = await DuoFlex.getDisplayInfo();
      if (!mounted || display == null) return;
      setState(() => _display ??= display);
    } catch (error) {
      _recordEvent('Initial display snapshot unavailable: $error');
    }
  }

  Future<void> _loadNativeFoldSnapshot(DuoCapabilities capabilities) async {
    final hingeRevision = _hingeEventRevision;
    final postureRevision = _postureEventRevision;
    try {
      final readings = await Future.wait<Object?>([
        capabilities.supportsHingeAngle
            ? DuoFlex.getHingeAngle()
            : Future<double?>.value(null),
        capabilities.supportsFoldPosture
            ? DuoFlex.getFoldPosture()
            : Future<DuoFoldPosture>.value(DuoFoldPosture.unknown),
      ]);
      if (!mounted) return;
      setState(() {
        // Preserve a newer live event if it arrived while the snapshot calls
        // were in flight.
        if (_hingeEventRevision == hingeRevision &&
            capabilities.supportsHingeAngle) {
          _hingeAngleRadians = readings[0] as double?;
        }
        if (_postureEventRevision == postureRevision &&
            capabilities.supportsFoldPosture) {
          _posture = readings[1] as DuoFoldPosture;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _foldStreamError = error.toString());
    }
  }

  @override
  void dispose() {
    _screenSubscription?.cancel();
    _displaySubscription?.cancel();
    _hingeSubscription?.cancel();
    _postureSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5546A5)),
      scaffoldBackgroundColor: const Color(0xFFFCF8FF),
    ),
    home: DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.phonelink_rounded),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DuoFlex'),
                  Text(
                    'Native display monitor',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          centerTitle: false,
          toolbarHeight: 60,
          bottom: const TabBar(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: EdgeInsets.symmetric(horizontal: 28),
            tabs: [
              Tab(
                icon: Icon(Icons.phone_iphone_rounded, size: 20),
                text: 'Device',
              ),
              Tab(
                icon: Icon(Icons.dashboard_customize_rounded, size: 20),
                text: 'Adaptive UI',
              ),
            ],
          ),
        ),
        body: TabBarView(children: [_deviceDashboard(), _adaptiveDashboard()]),
      ),
    ),
  );

  Widget _deviceDashboard() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
    children: [
      if (_error != null) _errorCard(_error.toString()),
      _deviceSummaryCard(),
      _hingeAngleCard(),
      _foldShapeCard(),
      _sectionHeading('Live viewport'),
      _metricGrid([
        _MetricData(
          label: 'Window size',
          value: _screen == null
              ? 'Unavailable'
              : '${_screen!.width.toStringAsFixed(0)} × ${_screen!.height.toStringAsFixed(0)}',
          detail: 'logical pixels',
          icon: Icons.aspect_ratio_rounded,
        ),
        _MetricData(
          label: 'Pixel ratio',
          value: _screen?.devicePixelRatio.toStringAsFixed(2) ?? '—',
          detail: 'device scale',
          icon: Icons.zoom_in_rounded,
        ),
        _MetricData(
          label: 'Orientation',
          value: _screen?.orientation ?? 'Unavailable',
          detail: 'active Flutter view',
          icon: Icons.screen_rotation_rounded,
        ),
        _MetricData(
          label: 'Safe area',
          value: _screen == null
              ? 'Unavailable'
              : 'T ${_screen!.safeArea.top.toStringAsFixed(0)}  '
                    'B ${_screen!.safeArea.bottom.toStringAsFixed(0)}',
          detail: 'top and bottom insets',
          icon: Icons.space_bar_rounded,
        ),
      ]),
      _safeAreaCard(),
      const SizedBox(height: 8),
      _displayCard(),
      _capabilitiesCard(),
      _eventHistoryPanel(),
    ],
  );

  Widget _adaptiveDashboard() => LayoutBuilder(
    builder: (context, constraints) {
      final viewInsets = MediaQuery.viewInsetsOf(context);
      final horizontalPadding = constraints.maxWidth >= 840 ? 48.0 : 16.0;
      return ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          14,
          horizontalPadding,
          24,
        ),
        children: [
          _ViewportSummary(
            constraints: constraints,
            safeArea: MediaQuery.paddingOf(context),
            viewInsets: viewInsets,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: constraints.maxWidth - horizontalPadding * 2,
            child: DuoAdaptiveLayout.builder(
              builder: (context, layout) =>
                  _ResponsiveLayoutCard(layout: layout),
            ),
          ),
          const SizedBox(height: 12),
          DuoFoldBuilder(
            builder: (context, state, capabilities) => _NativeFoldStatusCard(
              posture: capabilities.supportsFoldPosture
                  ? state.posture.name
                  : 'Unsupported',
              angle: capabilities.supportsHingeAngle && state.hingeAngle != null
                  ? '${(state.hingeAngle! * 180 / math.pi).toStringAsFixed(1)}°'
                  : 'Unavailable',
            ),
            errorBuilder: (context, error, state, capabilities) =>
                _NativeFoldStatusCard(
                  posture: capabilities.supportsFoldPosture
                      ? state.posture.name
                      : 'Unsupported',
                  angle: 'Unavailable',
                  error: error.toString(),
                ),
          ),
          const SizedBox(height: 8),
          DuoFoldAwareLayout(
            defaultLayout: const _FoldAwareSample(
              icon: Icons.dashboard_outlined,
              title: 'Default responsive content',
              detail: 'Used when physical posture is unknown or unsupported.',
            ),
            tabletopLayout: const _FoldAwareSample(
              icon: Icons.table_restaurant_outlined,
              title: 'Tabletop content',
              detail: 'Shown when native posture reports tabletop.',
            ),
            fullyOpenLayout: const _FoldAwareSample(
              icon: Icons.open_in_full_rounded,
              title: 'Fully open content',
              detail: 'Shown when native posture reports fully open.',
            ),
          ),
        ],
      );
    },
  );

  Widget _sectionHeading(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _deviceSummaryCard() {
    final foldability = _device?.isFoldable == true
        ? 'Foldable reported'
        : _device?.isFoldable == false
        ? 'No hinge reported'
        : 'Foldability unknown';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              child: Icon(
                _device?.isFoldable == true
                    ? Icons.phone_android_rounded
                    : Icons.phone_iphone_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _device?.model ?? 'Reading device…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_device?.systemName ?? 'iOS'} ${_device?.systemVersion ?? ''} · $foldability',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _StatusPill(
              label: _capabilities == null ? 'Loading' : 'Connected',
              active: _capabilities != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricGrid(List<_MetricData> metrics) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 620 ? 4 : 2;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: columns == 4 ? 1.45 : 1.55,
        children: [for (final metric in metrics) _metricCard(metric)],
      );
    },
  );

  Widget _metricCard(_MetricData metric) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            metric.icon,
            size: 19,
            color: Theme.of(context).colorScheme.primary,
          ),
          Text(metric.label, style: Theme.of(context).textTheme.labelSmall),
          Text(metric.value, style: Theme.of(context).textTheme.titleSmall),
          Text(metric.detail, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    ),
  );

  Widget _safeAreaCard() {
    final safeArea = _screen?.safeArea;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safe area insets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InsetValue('Top', safeArea?.top),
                _InsetValue('Bottom', safeArea?.bottom),
                _InsetValue('Left', safeArea?.left),
                _InsetValue('Right', safeArea?.right),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'UIKit window insets in logical points. Use MediaQuery for Flutter layout padding.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String error) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text('Native read failed: $error')),
        ],
      ),
    ),
  );

  Widget _displayCard() => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.display_settings_rounded),
              const SizedBox(width: 8),
              Text(
                'Display and regions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              _StatusPill(
                label: _display == null
                    ? 'Waiting'
                    : _display!.isActive
                    ? 'Active'
                    : 'Inactive',
                active: _display?.isActive ?? false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _display == null
                ? 'Display snapshot unavailable'
                : '${_display!.width.toStringAsFixed(0)} × ${_display!.height.toStringAsFixed(0)} pt  ·  ${_display!.scale.toStringAsFixed(1)}×',
          ),
          const SizedBox(height: 10),
          if (_display == null || _display!.regions.isEmpty)
            Text(
              'No native regions reported',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final region in _display!.regions)
                  Chip(
                    avatar: Icon(
                      region.type == DuoDisplayRegionType.reservedDivision
                          ? Icons.compare_arrows_rounded
                          : Icons.crop_free_rounded,
                      size: 16,
                    ),
                    label: Text(
                      '${region.type.name} · ${region.width.toStringAsFixed(0)} × ${region.height.toStringAsFixed(0)}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _capabilitiesCard() {
    final capabilities = _capabilities;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plugin capabilities',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CapabilityChip(
                  'Hinge angle',
                  capabilities?.supportsHingeAngle,
                ),
                _CapabilityChip(
                  'Fold posture',
                  capabilities?.supportsFoldPosture,
                ),
                _CapabilityChip(
                  'Reserved regions',
                  capabilities?.supportsDisplayRegions,
                ),
                _CapabilityChip(
                  'Live screen',
                  capabilities?.supportsDisplayChanges,
                ),
              ],
            ),
            if (_foldStreamError != null) ...[
              const SizedBox(height: 10),
              Text(
                _foldStreamError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hingeAngleCard() {
    final radians = _capabilities?.supportsHingeAngle == true
        ? _hingeAngleRadians
        : null;
    final degrees = radians == null ? null : radians * 180 / math.pi;
    final progress = radians == null
        ? null
        : (radians / math.pi).clamp(0.0, 1.0).toDouble();
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hinge angle', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  degrees == null
                      ? 'Unavailable'
                      : '${degrees.toStringAsFixed(1)}°',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: progress == null
                      ? Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.outline,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      : LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: colors.outline,
                          color: colors.primary,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '0° closed, 180° flat',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _foldShapeCard() {
    final supported = _capabilities?.supportsHingeAngle == true;
    final radians = supported ? _hingeAngleRadians : null;
    final degrees = radians == null ? null : radians * 180 / math.pi;
    final posture = _capabilities?.supportsFoldPosture == true
        ? _posture.name
        : 'unavailable';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Native fold · $posture',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: degrees == null
                  ? Center(
                      child: Text(
                        'Fold shape unavailable',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : CustomPaint(
                      painter: _NativeFoldShapePainter(
                        angleDegrees: degrees,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _listenToFoldUpdates(DuoCapabilities capabilities) {
    if (capabilities.supportsHingeAngle && _hingeSubscription == null) {
      _hingeSubscription = DuoFlex.hingeAngleStream.listen(
        (value) {
          if (!mounted) return;
          setState(() {
            _hingeEventRevision++;
            _hingeAngleRadians = value;
            _appendEvent('Native hinge update: ${value ?? 'unavailable'} rad');
          });
        },
        onError: (Object error) {
          if (mounted) {
            setState(() {
              _foldStreamError = error.toString();
              _appendEvent('Hinge stream error: $error');
            });
          }
        },
      );
    }
    if (capabilities.supportsFoldPosture && _postureSubscription == null) {
      _postureSubscription = DuoFlex.foldPostureStream.listen(
        (value) {
          if (!mounted) return;
          setState(() {
            _postureEventRevision++;
            _posture = value;
            _appendEvent('Native posture update: ${value.name}');
          });
        },
        onError: (Object error) {
          if (mounted) {
            setState(() {
              _foldStreamError = error.toString();
              _appendEvent('Posture stream error: $error');
            });
          }
        },
      );
    }
  }

  void _appendEvent(String message) {
    _eventHistory.insert(
      0,
      '${DateTime.now().toLocal().toIso8601String()}  $message',
    );
    if (_eventHistory.length > 20) {
      _eventHistory.removeRange(20, _eventHistory.length);
    }
  }

  void _recordEvent(String message) {
    if (!mounted) return;
    setState(() => _appendEvent(message));
  }

  Widget _eventHistoryPanel() => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Latest events', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_eventHistory.isEmpty) const Text('Waiting for native events.'),
          for (final event in _eventHistory)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(event),
            ),
        ],
      ),
    ),
  );
}

class _ViewportSummary extends StatelessWidget {
  const _ViewportSummary({
    required this.constraints,
    required this.safeArea,
    required this.viewInsets,
  });

  final BoxConstraints constraints;
  final EdgeInsets safeArea;
  final EdgeInsets viewInsets;

  String _extent(double value) =>
      value.isFinite ? value.toStringAsFixed(1) : 'unbounded';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Flutter viewport: ${_extent(constraints.maxWidth)} × ${_extent(constraints.maxHeight)} logical pixels',
      ),
      const SizedBox(height: 3),
      Text(
        'Orientation: ${constraints.maxWidth > constraints.maxHeight ? 'landscape' : 'portrait'}',
      ),
      const SizedBox(height: 3),
      Text(
        'Pixel ratio: ${MediaQuery.devicePixelRatioOf(context).toStringAsFixed(1)}',
      ),
      const SizedBox(height: 3),
      Text(
        'Safe padding T/B/L/R: ${safeArea.top.toStringAsFixed(1)}/${safeArea.bottom.toStringAsFixed(1)}/${safeArea.left.toStringAsFixed(1)}/${safeArea.right.toStringAsFixed(1)}',
      ),
      const SizedBox(height: 3),
      Text(
        'Keyboard/view insets T/B/L/R: ${viewInsets.top.toStringAsFixed(1)}/${viewInsets.bottom.toStringAsFixed(1)}/${viewInsets.left.toStringAsFixed(1)}/${viewInsets.right.toStringAsFixed(1)}',
      ),
    ],
  );
}

class _ResponsiveLayoutCard extends StatelessWidget {
  const _ResponsiveLayoutCard({required this.layout});

  final DuoLayoutInfo layout;

  @override
  Widget build(BuildContext context) {
    final title = switch (layout.size) {
      DuoLayoutSize.compact => 'Compact · stacked content',
      DuoLayoutSize.medium => 'Medium · two-column content',
      DuoLayoutSize.expanded => 'Expanded · master and detail',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current responsive size: ${layout.size.name}'),
        const SizedBox(height: 8),
        Text(title),
        const SizedBox(height: 10),
        _AdaptiveLayoutContent(layout: layout),
      ],
    );
  }
}

class _NativeFoldStatusCard extends StatelessWidget {
  const _NativeFoldStatusCard({
    required this.posture,
    required this.angle,
    this.error,
  });

  final String posture;
  final String angle;
  final String? error;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Physical fold state: $posture'),
          const SizedBox(height: 4),
          Text('Native hinge angle: $angle'),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
  );
}

class _FoldAwareSample extends StatelessWidget {
  const _FoldAwareSample({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(detail),
    ),
  );
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? colors.tertiaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: active
                ? colors.onTertiaryContainer
                : colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip(this.label, this.supported);

  final String label;
  final bool? supported;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (supported) {
      true => Icons.check_circle_rounded,
      false => Icons.remove_circle_outline_rounded,
      null => Icons.hourglass_empty_rounded,
    };
    final state = switch (supported) {
      true => 'Available',
      false => 'Unsupported',
      null => 'Checking',
    };
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text('$label · $state'),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: colors.outline),
    );
  }
}

class _InsetValue extends StatelessWidget {
  const _InsetValue(this.side, this.value);

  final String side;
  final Object? value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text('$side  ${value?.toString() ?? '—'}'),
  );
}

class _AdaptiveLayoutContent extends StatelessWidget {
  const _AdaptiveLayoutContent({required this.layout});

  final DuoLayoutInfo layout;

  @override
  Widget build(BuildContext context) {
    if (layout.isCompact) {
      return const Column(
        children: [
          _AdaptivePanelCard(
            title: 'Navigation',
            color: Color(0xFFE8EAF6),
            height: 68,
          ),
          SizedBox(height: 8),
          _AdaptivePanelCard(
            title: 'Primary content',
            color: Color(0xFFE3F2FD),
            height: 88,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (layout.isExpanded)
              const SizedBox(
                width: 120,
                child: _AdaptivePanelCard(
                  title: 'Persistent navigation',
                  color: Color(0xFFE8EAF6),
                  height: 92,
                ),
              ),
            if (layout.isMedium)
              const SizedBox(
                width: 76,
                child: _AdaptivePanelCard(
                  title: 'Rail',
                  color: Color(0xFFE8EAF6),
                  height: 92,
                ),
              ),
            const SizedBox(width: 8),
            const Expanded(
              child: _AdaptivePanelCard(
                title: 'Master list',
                color: Color(0xFFE3F2FD),
                height: 92,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: _AdaptivePanelCard(
                title: 'Detail content',
                color: Color(0xFFE0F2F1),
                height: 92,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdaptivePanelCard extends StatelessWidget {
  const _AdaptivePanelCard({
    required this.title,
    required this.color,
    required this.height,
  });

  final String title;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(child: Text(title, textAlign: TextAlign.center)),
      ),
    ),
  );
}

class _NativeFoldShapePainter extends CustomPainter {
  const _NativeFoldShapePainter({
    required this.angleDegrees,
    required this.color,
  });

  final double angleDegrees;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = angleDegrees.clamp(0.0, 180.0);
    final halfRadians = (180 - angle) * math.pi / 360;
    final center = Offset(size.width / 2, size.height * 0.78);
    final armLength = size.width * 0.16;
    final rise = armLength * math.sin(halfRadians);
    final run = armLength * math.cos(halfRadians);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, Offset(center.dx - run, center.dy - rise), stroke);
    canvas.drawLine(center, Offset(center.dx + run, center.dy - rise), stroke);
    canvas.drawCircle(center, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_NativeFoldShapePainter oldDelegate) =>
      oldDelegate.angleDegrees != angleDegrees || oldDelegate.color != color;
}
