import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/engine/supertonic_onnx_engine.dart';
import 'package:lotti/features/tts/engine/supertonic_tts_session.dart';
import 'package:lotti/features/tts/engine/voice_style_loader.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

VoiceStyle _voiceStyle() => VoiceStyle(
  MockOrtValue(),
  MockOrtValue(),
  const [1, 50, 256],
  const [
    1,
    1,
    256,
  ],
);

void main() {
  setUpAll(() => registerFallbackValue(_voiceStyle()));

  late MockSupertonicTtsSession session;
  late List<String> sessionLoads;
  late List<List<String>> voiceLoads;
  late VoiceStyle voiceStyle;
  late Directory tempDir;

  setUp(() {
    session = MockSupertonicTtsSession();
    when(() => session.sampleRate).thenReturn(44100);
    when(() => session.dispose()).thenAnswer((_) async {});
    when(
      () => session.synthesize(
        text: any(named: 'text'),
        language: any(named: 'language'),
        style: any(named: 'style'),
        totalStep: any(named: 'totalStep'),
      ),
    ).thenAnswer((_) async => const SynthesisResult([0, 0.25, -0.25], 0.5));

    sessionLoads = [];
    voiceLoads = [];
    voiceStyle = _voiceStyle();
    when(() => voiceStyle.ttl.dispose()).thenAnswer((_) async {});
    when(() => voiceStyle.dp.dispose()).thenAnswer((_) async {});
    tempDir = Directory.systemTemp.createTempSync('tts_engine_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SupertonicOnnxEngine buildEngine() => SupertonicOnnxEngine(
    sessionLoader: (dir) async {
      sessionLoads.add(dir);
      return session;
    },
    voiceLoader: (paths) async {
      voiceLoads.add(paths);
      return voiceStyle;
    },
    tempDirProvider: () async => tempDir,
  );

  group('isSupported', () {
    late bool originalMac;
    late bool originalIos;
    late bool originalLinux;
    late bool originalAndroid;

    setUp(() {
      originalMac = platform.isMacOS;
      originalIos = platform.isIOS;
      originalLinux = platform.isLinux;
      originalAndroid = platform.isAndroid;
      // Clean baseline so the host platform doesn't leak into assertions.
      platform.isMacOS = false;
      platform.isIOS = false;
      platform.isLinux = false;
      platform.isAndroid = false;
    });
    tearDown(() {
      platform.isMacOS = originalMac;
      platform.isIOS = originalIos;
      platform.isLinux = originalLinux;
      platform.isAndroid = originalAndroid;
    });

    test('is false when no supported platform flag is set', () {
      expect(SupertonicOnnxEngine.isPlatformSupported, isFalse);
      expect(buildEngine().isSupported, isFalse);
    });

    for (final entry in <String, void Function()>{
      'macOS': () => platform.isMacOS = true,
      'iOS': () => platform.isIOS = true,
      'Linux': () => platform.isLinux = true,
      'Android': () => platform.isAndroid = true,
    }.entries) {
      test('is true on ${entry.key}', () {
        entry.value();
        expect(SupertonicOnnxEngine.isPlatformSupported, isTrue);
        expect(buildEngine().isSupported, isTrue);
      });
    }
  });

  group('synthesizeToFile', () {
    test(
      'loads the session + voice, synthesizes, and writes a WAV file',
      () async {
        final engine = buildEngine();

        final file = await engine.synthesizeToFile(
          text: 'hello',
          voiceId: 'F1',
          modelDirectory: '/models/supertonic',
          language: 'en',
        );

        expect(sessionLoads, ['/models/supertonic']);
        expect(voiceLoads, [
          ['assets/tts/voice_styles/F1.json'],
        ]);
        verify(
          () => session.synthesize(
            text: 'hello',
            language: 'en',
            style: voiceStyle,
            totalStep: any(named: 'totalStep'),
          ),
        ).called(1);
        // A real WAV was written (RIFF header) at 44.1kHz from the samples.
        expect(file.existsSync(), isTrue);
        expect(file.readAsBytesSync().sublist(0, 4), 'RIFF'.codeUnits);
      },
    );

    test('reuses the cached session for the same model directory', () async {
      final engine = buildEngine();
      await engine.synthesizeToFile(
        text: 'a',
        voiceId: 'F1',
        modelDirectory: '/m',
        language: 'en',
      );
      await engine.synthesizeToFile(
        text: 'b',
        voiceId: 'F1',
        modelDirectory: '/m',
        language: 'en',
      );

      expect(sessionLoads, ['/m']); // loaded once
      expect(voiceLoads.length, 1); // voice cached too
    });

    test(
      'disposes the old session and reloads when the model dir changes',
      () async {
        final engine = buildEngine();
        await engine.synthesizeToFile(
          text: 'a',
          voiceId: 'F1',
          modelDirectory: '/m1',
          language: 'en',
        );
        await engine.synthesizeToFile(
          text: 'b',
          voiceId: 'F1',
          modelDirectory: '/m2',
          language: 'en',
        );

        expect(sessionLoads, ['/m1', '/m2']);
        verify(() => session.dispose()).called(1); // old session freed
      },
    );
  });

  group('dispose', () {
    test('disposes the session and every cached voice-style tensor', () async {
      final engine = buildEngine();
      await engine.synthesizeToFile(
        text: 'a',
        voiceId: 'F1',
        modelDirectory: '/m',
        language: 'en',
      );

      await engine.dispose();

      verify(() => session.dispose()).called(1);
      verify(() => voiceStyle.ttl.dispose()).called(1);
      verify(() => voiceStyle.dp.dispose()).called(1);

      // Cache cleared: a subsequent voice resolution reloads.
      await engine.synthesizeToFile(
        text: 'b',
        voiceId: 'F1',
        modelDirectory: '/m',
        language: 'en',
      );
      expect(voiceLoads.length, 2);
    });
  });
}
