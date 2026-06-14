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

    setUp(() {
      originalMac = platform.isMacOS;
      originalIos = platform.isIOS;
    });
    tearDown(() {
      platform.isMacOS = originalMac;
      platform.isIOS = originalIos;
    });

    test('falls back to the unavailable engine off the Apple platforms', () {
      platform.isMacOS = false;
      platform.isIOS = false;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsEngineProvider), isA<UnavailableTtsEngine>());
    });

    test('provides the Supertonic engine on the Apple platforms', () {
      platform.isMacOS = true;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(ttsEngineProvider), isA<SupertonicOnnxEngine>());
    });
  });
}
