import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/engine/supertonic_onnx_engine.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/utils/platform.dart' as platform;

void main() {
  group('UnavailableTtsEngine', () {
    const engine = UnavailableTtsEngine();

    test('reports it is not supported', () {
      expect(engine.isSupported, isFalse);
    });

    test('throws when asked to synthesize', () {
      expect(
        () => engine.synthesizeToFile(
          text: 'hi',
          voiceId: 'F1',
          modelDirectory: '/m',
          language: 'en',
        ),
        throwsUnsupportedError,
      );
    });

    test('dispose is a safe no-op', () {
      expect(engine.dispose(), completes);
    });
  });

  group('ttsEngine provider', () {
    late bool originalMac;
    late bool originalIos;
    late bool originalLinux;

    setUp(() {
      originalMac = platform.isMacOS;
      originalIos = platform.isIOS;
      originalLinux = platform.isLinux;
      // Clean baseline so the host platform doesn't leak into assertions.
      platform.isMacOS = false;
      platform.isIOS = false;
      platform.isLinux = false;
    });
    tearDown(() {
      platform.isMacOS = originalMac;
      platform.isIOS = originalIos;
      platform.isLinux = originalLinux;
    });

    test('falls back to the unavailable engine on unsupported platforms', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsEngineProvider), isA<UnavailableTtsEngine>());
    });

    for (final entry in <String, void Function()>{
      'macOS': () => platform.isMacOS = true,
      'iOS': () => platform.isIOS = true,
      'Linux': () => platform.isLinux = true,
    }.entries) {
      test('provides the Supertonic engine on ${entry.key}', () {
        entry.value();
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(ttsEngineProvider), isA<SupertonicOnnxEngine>());
      });
    }
  });
}
