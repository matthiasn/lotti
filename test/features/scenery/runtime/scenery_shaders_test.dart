import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';

void main() {
  tearDown(SceneryShaderProgramCache.reset);

  group('scenery shader assets', () {
    test('are registered in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains(SceneryShaderAssets.sky));
      expect(pubspec, contains(SceneryShaderAssets.ocean));
      expect(pubspec, contains('shaders:'));
    });

    testWidgets('compile as Flutter runtime-effect shaders', (tester) async {
      final sky = await ui.FragmentProgram.fromAsset(SceneryShaderAssets.sky);
      final ocean = await ui.FragmentProgram.fromAsset(
        SceneryShaderAssets.ocean,
      );
      expect(sky, isA<ui.FragmentProgram>());
      expect(ocean, isA<ui.FragmentProgram>());
    });

    testWidgets('cache returns the identical program across many calls', (
      tester,
    ) async {
      for (var n = 2; n <= 6; n++) {
        SceneryShaderProgramCache.reset();
        final sky = [
          for (var i = 0; i < n; i++) await SceneryShaderProgramCache.loadSky(),
        ];
        for (final program in sky.skip(1)) {
          expect(identical(program, sky.first), isTrue, reason: 'n=$n');
        }
      }
    });
  });

  group('uniform layout contract', () {
    // setSceneryColor / buildSkyUniforms write floats by index; these tests pin
    // the exact uniform count each .frag declares so the Dart wiring and the
    // GLSL cannot silently drift apart.
    testWidgets('sky shader declares exactly 49 float uniforms (0..48)', (
      tester,
    ) async {
      final program = await ui.FragmentProgram.fromAsset(
        SceneryShaderAssets.sky,
      );
      final shader = program.fragmentShader();
      expect(
        () {
          for (var i = 0; i <= 12; i++) {
            shader.setFloat(i, 0);
          }
          setSceneryColor(shader, 45, const ui.Color(0xFFFFFFFF));
        },
        returnsNormally,
      );
      expect(() => shader.setFloat(49, 0), throwsA(isA<Error>()));
    });

    testWidgets('ocean shader declares exactly 31 float uniforms (0..30)', (
      tester,
    ) async {
      final program = await ui.FragmentProgram.fromAsset(
        SceneryShaderAssets.ocean,
      );
      final shader = program.fragmentShader();
      expect(
        () => setSceneryColor(shader, 27, const ui.Color(0xFFFFFFFF)),
        returnsNormally,
      );
      expect(() => shader.setFloat(31, 0), throwsA(isA<Error>()));
    });
  });
}
