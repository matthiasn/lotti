import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layered_backdrop.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';

Future<ui.FragmentProgram> _failingLoader() =>
    Future<ui.FragmentProgram>.error(StateError('shader unavailable'));

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox.expand(child: child)),
);

void main() {
  tearDown(SceneryShaderProgramCache.reset);

  testWidgets('renders the CPU fallback without error before programs load', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.blueHourWaterfront(),
          timeOverride: 1.5,
          skyProgramLoader: _failingLoader,
          oceanProgramLoader: _failingLoader,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drives the real sky shader without a uniform mismatch', (
    tester,
  ) async {
    // End-to-end check that SkyLayer's index-wise uniform wiring matches the
    // compiled shader: a wrong float count would throw a RangeError in paint.
    final sky = await ui.FragmentProgram.fromAsset(SceneryShaderAssets.sky);

    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.blueHourWaterfront(),
          timeOverride: 2,
          skyProgramLoader: () async => sky,
          oceanProgramLoader: _failingLoader,
        ),
      ),
    );
    await tester.pump(); // resolve loader + setState
    await tester.pump(); // paint with the real program

    expect(tester.takeException(), isNull);
  });

  testWidgets('self-drives a clock when no time is injected', (tester) async {
    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.blueHourWaterfront(),
          skyProgramLoader: _failingLoader,
          oceanProgramLoader: _failingLoader,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
  });

  testWidgets('holds a calm frame under reduce-motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox.expand(
              child: LayeredBackdrop(
                scene: BackdropScene.blueHourWaterfront(),
                skyProgramLoader: _failingLoader,
                oceanProgramLoader: _failingLoader,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
  });
}
