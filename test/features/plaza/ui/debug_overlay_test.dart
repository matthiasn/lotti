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
  late PlazaFrameRate frameRate;

  setUp(() {
    stats = PlazaHarnessStats()
      ..fps = 60
      ..avgFrameMs = 16.6
      ..worstFrameMs = 20
      ..buildings = 28
      ..live = 1
      ..sign = 13
      ..far = 14
      ..captures = 42
      ..surfaceCaptures = 7
      ..lastCaptureMs = 1.5
      ..promotions = 3;
    config = FacadeLodConfig();
    knobs = PlazaLayoutKnobs();
    configChanges = 0;
    knobsApplied = 0;
    frameRate = PlazaFrameRate.sixty;
  });

  Widget host() {
    return makeTestableWidget2(
      Scaffold(
        body: SingleChildScrollView(
          child: PlazaDebugOverlay(
            stats: stats,
            config: config,
            knobs: knobs,
            datasetLabel: 'demo',
            onConfigChanged: () => configChanges++,
            onKnobsApplied: () => knobsApplied++,
            frameRate: frameRate,
            onFrameRateChanged: (rate) => frameRate = rate,
          ),
        ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(600, 1200)),
    );
  }

  testWidgets('renders the frame and tier instrumentation', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('60 fps'), findsOneWidget);
    expect(find.text('buildings 28   data demo'), findsOneWidget);
    expect(find.text('live 1   sign 13   far 14'), findsOneWidget);
    expect(
      find.text('captures 42+7   last 1.5 ms   promos 3'),
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

  testWidgets('budget sliders mutate the LOD config', (tester) async {
    await tester.pumpWidget(host());
    final sliders = find.byType(Slider);
    await tester.drag(sliders.at(0), const Offset(80, 0));
    await tester.pump();
    expect(config.liveCap, isNot(4));
    expect(configChanges, greaterThan(0));
    await tester.drag(sliders.at(1), const Offset(80, 0));
    await tester.pump();
    expect(config.signCap, isNot(80));
    await tester.drag(sliders.at(2), const Offset(80, 0));
    await tester.pump();
    expect(config.liveDistance, isNot(26));
    await tester.drag(sliders.at(3), const Offset(80, 0));
    await tester.pump();
    expect(config.signDistance, isNot(140));
    expect(knobsApplied, 0);
  });

  testWidgets('layout knob sliders apply on release', (tester) async {
    await tester.pumpWidget(host());
    final sliders = find.byType(Slider);
    await tester.drag(sliders.at(4), const Offset(60, 0)); // px/m
    await tester.pump();
    expect(knobs.pxPerMeter, isNot(90));
    expect(knobsApplied, greaterThan(0));

    final appliedSoFar = knobsApplied;
    await tester.drag(sliders.at(5), const Offset(60, 0)); // road width
    await tester.pump();
    expect(knobs.roadWidth, isNot(25));
    expect(knobsApplied, greaterThan(appliedSoFar));

    await tester.drag(sliders.at(6), const Offset(60, 0)); // max height
    await tester.pump();
    expect(knobs.maxHeight, isNot(14));
  });

  testWidgets('stress switch flips forceAllLive', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(config.forceAllLive, isTrue);
    expect(configChanges, 1);
  });

  testWidgets('frame rate chips pick a cap', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('60'), findsOneWidget);
    await tester.tap(find.text('30'));
    await tester.pump();
    expect(frameRate, PlazaFrameRate.thirty);
    await tester.tap(find.text('auto'));
    await tester.pump();
    expect(frameRate, PlazaFrameRate.auto);
  });

  test('a cap for every setting: auto lets movement run at the display', () {
    expect(PlazaFrameRate.sixty.capFor(moving: true), 60);
    expect(PlazaFrameRate.sixty.capFor(moving: false), 60);
    expect(PlazaFrameRate.thirty.capFor(moving: true), 30);
    expect(PlazaFrameRate.auto.capFor(moving: true), isNull);
    expect(PlazaFrameRate.auto.capFor(moving: false), 30);
    expect(PlazaFrameRate.values.map((r) => r.label), ['auto', '60', '30']);
  });
}
