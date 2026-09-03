import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/scene/facade_lod_manager.dart';
import 'package:lotti/features/plaza/ui/debug_overlay.dart';

import '../../../widget_test_utils.dart';

void main() {
  late PlazaHarnessStats stats;
  late FacadeLodConfig config;
  late PlazaLayoutKnobs knobs;
  late int configChanges;
  late int knobsApplied;
  late int presetCycles;
  late int overheadToggles;

  setUp(() {
    stats = PlazaHarnessStats()
      ..fps = 60
      ..avgFrameMs = 16.6
      ..worstFrameMs = 20
      ..buildings = 28
      ..near = 9
      ..mid = 13
      ..far = 6
      ..captures = 42
      ..lastCaptureMs = 1.5
      ..promotions = 3;
    config = FacadeLodConfig();
    knobs = PlazaLayoutKnobs();
    configChanges = 0;
    knobsApplied = 0;
    presetCycles = 0;
    overheadToggles = 0;
  });

  Widget host() {
    return makeTestableWidget2(
      Scaffold(
        body: SingleChildScrollView(
          child: PlazaDebugOverlay(
            stats: stats,
            config: config,
            knobs: knobs,
            presetLabel: 'waddle',
            onCyclePreset: () => presetCycles++,
            onConfigChanged: () => configChanges++,
            onKnobsApplied: () => knobsApplied++,
            onToggleOverhead: () => overheadToggles++,
          ),
        ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(600, 1200)),
    );
  }

  testWidgets('renders the frame and tier instrumentation', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('60 fps'), findsOneWidget);
    expect(find.text('buildings 28   preset waddle'), findsOneWidget);
    expect(find.text('live 9   static 13   far 6'), findsOneWidget);
    expect(
      find.text('captures 42   last 1.5 ms   promos 3'),
      findsOneWidget,
    );
  });

  testWidgets('stats.publish() live-updates the readout', (tester) async {
    await tester.pumpWidget(host());
    stats
      ..fps = 12
      ..publish();
    await tester.pump();
    expect(find.text('12 fps'), findsOneWidget);
    expect(find.text('60 fps'), findsNothing);
  });

  testWidgets('cap sliders mutate the LOD config', (tester) async {
    await tester.pumpWidget(host());
    final sliders = find.byType(Slider);
    await tester.drag(sliders.at(0), const Offset(80, 0));
    await tester.pump();
    expect(config.nearCap, isNot(12));
    expect(configChanges, greaterThan(0));

    await tester.drag(sliders.at(1), const Offset(80, 0));
    await tester.pump();
    expect(config.midCap, isNot(60));
  });

  testWidgets('layout knob sliders apply on release', (tester) async {
    await tester.pumpWidget(host());
    final sliders = find.byType(Slider);
    await tester.drag(sliders.at(2), const Offset(60, 0)); // px/m
    await tester.pump();
    expect(knobs.pxPerMeter, isNot(90));
    expect(knobsApplied, greaterThan(0));

    final appliedSoFar = knobsApplied;
    await tester.drag(sliders.at(3), const Offset(60, 0)); // road width
    await tester.pump();
    expect(knobs.roadWidth, isNot(25));
    expect(knobsApplied, greaterThan(appliedSoFar));

    await tester.drag(sliders.at(4), const Offset(60, 0)); // max height
    await tester.pump();
    expect(knobs.maxHeight, isNot(12));
  });

  testWidgets('stress switch and buttons fire their callbacks', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(config.forceAllLive, isTrue);

    await tester.tap(find.text('preset'));
    expect(presetCycles, 1);
    await tester.tap(find.text('overhead'));
    expect(overheadToggles, 1);
  });
}
