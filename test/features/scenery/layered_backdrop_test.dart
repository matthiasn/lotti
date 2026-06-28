import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layered_backdrop.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
import 'package:lotti/features/scenery/model/scenery_assets.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';

Future<ui.FragmentProgram> _failingLoader() =>
    Future<ui.FragmentProgram>.error(StateError('shader unavailable'));

Future<ui.Image> _solid(Color color, int w, int h) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(w, h);
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox.expand(child: child)),
);

void main() {
  tearDown(SceneryShaderProgramCache.reset);

  testWidgets('renders the shader CPU fallback without error before load', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.proceduralBlueHour(),
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
    // A wrong float count would throw a RangeError in paint.
    final sky = await ui.FragmentProgram.fromAsset(SceneryShaderAssets.sky);

    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.proceduralBlueHour(),
          timeOverride: 2,
          skyProgramLoader: () async => sky,
          oceanProgramLoader: _failingLoader,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('decodes the painted scene assets via the injected loader', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final requested = <String>[];
      // A fresh image per asset — the widget owns and disposes each one.
      Future<ui.Image> loader(String path) async {
        requested.add(path);
        return _solid(const Color(0xFF112233), 4, 4);
      }

      await tester.pumpWidget(
        _host(
          LayeredBackdrop(
            scene: BackdropScene.blueHourWaterfront(),
            timeOverride: 0,
            skyProgramLoader: _failingLoader,
            oceanProgramLoader: _failingLoader,
            imageLoader: loader,
          ),
        ),
      );
      await tester.pump();

      expect(requested, contains(SceneryAssets.masterPlate));
      expect(tester.takeException(), isNull);
      // The widget owns and disposes the decoded image on teardown.
    });
  });

  testWidgets('self-drives a clock when no time is injected', (tester) async {
    await tester.pumpWidget(
      _host(
        LayeredBackdrop(
          scene: BackdropScene.proceduralBlueHour(),
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
                scene: BackdropScene.proceduralBlueHour(),
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
