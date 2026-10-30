import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/cloud/voxtral_tts_service.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';

void main() {
  final provider = testInferenceProvider(
    id: 'mistral',
    apiKey: 'key',
    inferenceProviderType: InferenceProviderType.mistral,
  );
  final route = TtsCloudRoute(
    provider: provider,
    model: testAiModel(
      id: 'voice-row',
      providerModelId: 'voxtral-mini-tts-2603',
    ),
    languageCode: 'de',
  );
  final catalog = VoxtralVoiceCatalog(
    fetchedAt: DateTime.utc(2026, 10, 27),
    voices: const [
      VoxtralVoice(
        id: 'v-de-f',
        name: 'Heidi',
        gender: 'female',
        languages: ['de'],
        type: VoxtralVoiceType.preset,
      ),
      VoxtralVoice(id: 'v-de-m', name: 'Klaus', languages: ['de']),
    ],
  );
  final audio = Uint8List.fromList([82, 73, 70, 70]);
  Future<bool> allow() async => true;

  late MockVoxtralTtsService service;
  late MockVoxtralVoiceCatalogRepository catalogs;
  late Directory temp;
  late CloudSpeechSynthesizer synthesizer;

  setUp(() {
    service = MockVoxtralTtsService();
    catalogs = MockVoxtralVoiceCatalogRepository();
    temp = Directory.systemTemp.createTempSync('cloud_speech_test');
    addTearDown(() => temp.deleteSync(recursive: true));
    synthesizer = CloudSpeechSynthesizer(
      service: service,
      catalogs: catalogs,
      tempDirectory: () async => temp,
    );
    when(() => catalogs.catalogFor(provider)).thenAnswer((_) async => catalog);
    when(
      () => service.synthesize(
        text: any(named: 'text'),
        voiceId: any(named: 'voiceId'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        model: any(named: 'model'),
      ),
    ).thenAnswer((_) async => audio);
  });

  test("speaks with the language's default voice and the route's model, "
      'into a temporary WAV', () async {
    final file = await synthesizer.synthesizeToFile(
      route: route,
      text: 'Grüß dich',
      voiceByLanguage: const {},
      canSend: allow,
    );

    expect(file!.parent.path, temp.path);
    expect(file.path, endsWith('.wav'));
    expect(file.readAsBytesSync(), audio);
    verify(
      () => service.synthesize(
        text: 'Grüß dich',
        voiceId: 'v-de-f',
        baseUrl: provider.baseUrl,
        apiKey: 'key',
        model: 'voxtral-mini-tts-2603',
      ),
    ).called(1);
  });

  test("the user's voice for the language wins", () async {
    final first = await synthesizer.synthesizeToFile(
      route: route,
      text: 'Hallo',
      voiceByLanguage: const {'de': 'v-de-m', 'en': 'v-en'},
      canSend: allow,
    );
    final second = await synthesizer.synthesizeToFile(
      route: route,
      text: 'Hallo',
      voiceByLanguage: const {'de': 'v-de-m'},
      canSend: allow,
    );

    expect(first!.path, isNot(second!.path));
    verify(
      () => service.synthesize(
        text: 'Hallo',
        voiceId: 'v-de-m',
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        model: any(named: 'model'),
      ),
    ).called(2);
  });

  test("a preview route's own voice wins over the user's choice", () async {
    await synthesizer.synthesizeToFile(
      route: TtsCloudRoute(
        provider: route.provider,
        model: route.model,
        languageCode: 'de',
        voiceId: 'v-de-m',
      ),
      text: 'Hallo',
      voiceByLanguage: const {'de': 'v-de-f'},
      canSend: allow,
    );

    verify(
      () => service.synthesize(
        text: 'Hallo',
        voiceId: 'v-de-m',
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        model: any(named: 'model'),
      ),
    ).called(1);
  });

  test('withdrawn permission after the catalog loads sends nothing', () async {
    final loaded = <String>[];
    final file = await synthesizer.synthesizeToFile(
      route: route,
      text: 'Privat',
      voiceByLanguage: const {},
      canSend: () async {
        // Asked only once the catalog — the slow, networked step — is in.
        verify(() => catalogs.catalogFor(provider)).called(1);
        loaded.add('checked');
        return false;
      },
    );

    expect(file, isNull);
    expect(loaded, ['checked']);
    verifyNever(
      () => service.synthesize(
        text: any(named: 'text'),
        voiceId: any(named: 'voiceId'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        model: any(named: 'model'),
      ),
    );
    expect(temp.listSync(), isEmpty);
  });

  test('a language without a voice fails before any text is sent', () async {
    await expectLater(
      synthesizer.synthesizeToFile(
        route: TtsCloudRoute(
          provider: provider,
          model: route.model,
          languageCode: 'fr',
        ),
        text: 'Bonjour',
        voiceByLanguage: const {},
        canSend: allow,
      ),
      throwsA(
        isA<VoxtralTtsException>()
            .having((e) => e.failure, 'failure', VoxtralTtsFailure.noVoice)
            .having((e) => e.isRetryable, 'retryable', isFalse),
      ),
    );
    verifyNever(
      () => service.synthesize(
        text: any(named: 'text'),
        voiceId: any(named: 'voiceId'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        model: any(named: 'model'),
      ),
    );
  });

  group('providers', () {
    setUp(() async {
      await setUpTestGetIt();
    });
    tearDown(tearDownTestGetIt);

    test('the synthesizer and the catalog cache share one Voxtral client', () {
      final container = ProviderContainer(overrides: getItServiceOverrides());
      addTearDown(container.dispose);

      final service = container.read(voxtralTtsServiceProvider);
      expect(container.read(cloudSpeechSynthesizerProvider), isNotNull);
      expect(container.read(voxtralVoiceCatalogRepositoryProvider), isNotNull);
      // Reading again yields the same client: no second HTTP pool.
      expect(container.read(voxtralTtsServiceProvider), same(service));
    });
  });
}
