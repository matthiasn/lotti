import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_client.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog.dart';
import 'package:lotti/features/tts/cloud/elevenlabs_tts_service.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/cloud/voxtral_tts_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';

class _StreamingClient extends Mock implements StreamingCloudTtsClient {}

void main() {
  setUpAll(registerAllFallbackValues);

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
  final catalog = CloudVoiceCatalog(
    fetchedAt: DateTime.utc(2026, 10, 27),
    voices: const [
      CloudVoice(
        id: 'v-de-f',
        name: 'Heidi',
        gender: 'female',
        languages: ['de'],
        type: CloudVoiceType.preset,
      ),
      CloudVoice(id: 'v-de-m', name: 'Klaus', languages: ['de']),
    ],
  );
  final audio = Uint8List.fromList([82, 73, 70, 70]);
  Future<bool> allow() async => true;

  late MockCloudTtsClient service;
  late MockCloudTtsClient elevenLabs;
  late MockCloudVoiceCatalogRepository catalogs;
  late Directory temp;
  late CloudSpeechSynthesizer synthesizer;

  setUp(() {
    service = MockCloudTtsClient();
    elevenLabs = MockCloudTtsClient();
    catalogs = MockCloudVoiceCatalogRepository();
    temp = Directory.systemTemp.createTempSync('cloud_speech_test');
    addTearDown(() => temp.deleteSync(recursive: true));
    synthesizer = CloudSpeechSynthesizer(
      clients: {
        InferenceProviderType.mistral: service,
        InferenceProviderType.elevenLabs: elevenLabs,
      },
      catalogs: catalogs,
      tempDirectory: () async => temp,
    );
    when(
      () => catalogs.catalogFor(any(), any()),
    ).thenAnswer((_) async => catalog);
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
      chosenVoices: const {},
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

  group('a voice that sends its speech while it makes it', () {
    late _StreamingClient streaming;
    late CloudSpeechSynthesizer synth;

    setUp(() {
      streaming = _StreamingClient();
      synth = CloudSpeechSynthesizer(
        clients: {
          InferenceProviderType.mistral: streaming,
          InferenceProviderType.elevenLabs: elevenLabs,
        },
        catalogs: catalogs,
        tempDirectory: () async => temp,
      );
      when(
        () => streaming.synthesizeStream(
          text: any(named: 'text'),
          voiceId: any(named: 'voiceId'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          Uint8List(44),
          Uint8List.fromList([1, 2, 3, 4]),
        ]),
      );
    });

    test('is told apart from one that does not', () {
      expect(synth.canStream(route), isTrue);
      expect(synthesizer.canStream(route), isFalse);
    });

    test('writes the stream into a temporary WAV as it arrives, in the '
        "language's voice and the route's model, without its emoji", () async {
      final clip = await synth.synthesizeToGrowingFile(
        route: route,
        text: 'Grüß dich 😀',
        chosenVoices: const {},
        canSend: allow,
      );
      await clip!.done;

      expect(clip.file.parent.path, temp.path);
      expect(clip.file.path, endsWith('.wav'));
      expect(clip.isComplete, isTrue);
      expect(clip.file.readAsBytesSync().sublist(44), [1, 2, 3, 4]);
      verify(
        () => streaming.synthesizeStream(
          text: 'Grüß dich',
          voiceId: 'v-de-f',
          baseUrl: provider.baseUrl,
          apiKey: 'key',
          model: 'voxtral-mini-tts-2603',
        ),
      ).called(1);
    });

    test(
      'asks again as the request is made: a stop while its file was '
      'being prepared sends nothing, and leaves a clip without audio',
      () async {
        var asked = 0;
        // Yes while the voice is resolved, no once the clip starts reading.
        final clip = await synth.synthesizeToGrowingFile(
          route: route,
          text: 'Grüß dich',
          chosenVoices: const {},
          canSend: () async => ++asked == 1,
        );
        await clip!.done;

        expect(asked, 2);
        expect(clip.hasAudio, isFalse);
        verifyNever(
          () => streaming.synthesizeStream(
            text: any(named: 'text'),
            voiceId: any(named: 'voiceId'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: any(named: 'model'),
          ),
        );
      },
    );

    test('asks nothing of the voice when it may not be sent, or there is '
        'nothing to say', () async {
      expect(
        await synth.synthesizeToGrowingFile(
          route: route,
          text: 'Grüß dich',
          chosenVoices: const {},
          canSend: () async => false,
        ),
        isNull,
      );
      expect(
        await synth.synthesizeToGrowingFile(
          route: route,
          text: '😀',
          chosenVoices: const {},
          canSend: allow,
        ),
        isNull,
      );
      verifyNever(
        () => streaming.synthesizeStream(
          text: any(named: 'text'),
          voiceId: any(named: 'voiceId'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
        ),
      );
    });
  });

  test("the user's voice for the language wins", () async {
    final first = await synthesizer.synthesizeToFile(
      route: route,
      text: 'Hallo',
      chosenVoices: const {'de': 'v-de-m', 'en': 'v-en'},
      canSend: allow,
    );
    final second = await synthesizer.synthesizeToFile(
      route: route,
      text: 'Hallo',
      chosenVoices: const {'de': 'v-de-m'},
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
      chosenVoices: const {'de': 'v-de-f'},
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

  test('the voice gets the text without its emoji', () async {
    await synthesizer.synthesizeToFile(
      route: route,
      text: 'Gut gemacht 🎉! Weiter 🐧',
      chosenVoices: const {},
      canSend: allow,
    );

    verify(
      () => service.synthesize(
        text: 'Gut gemacht! Weiter',
        voiceId: 'v-de-f',
        baseUrl: provider.baseUrl,
        apiKey: 'key',
        model: 'voxtral-mini-tts-2603',
      ),
    ).called(1);
  });

  test('nothing but emoji sends nothing and makes no file', () async {
    var asked = false;
    final file = await synthesizer.synthesizeToFile(
      route: route,
      text: '🎉 👍🏽',
      chosenVoices: const {},
      canSend: () async => asked = true,
    );

    expect(file, isNull);
    expect(asked, isFalse);
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

  test('withdrawn permission after the catalog loads sends nothing', () async {
    final loaded = <String>[];
    final file = await synthesizer.synthesizeToFile(
      route: route,
      text: 'Privat',
      chosenVoices: const {},
      canSend: () async {
        // Asked only once the catalog — the slow, networked step — is in.
        verify(() => catalogs.catalogFor(provider, route.model)).called(1);
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
        chosenVoices: const {},
        canSend: allow,
      ),
      throwsA(
        isA<CloudTtsException>()
            .having((e) => e.failure, 'failure', CloudTtsFailure.noVoice)
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

  group('provider types', () {
    final elevenProvider = testInferenceProvider(
      id: 'eleven',
      apiKey: 'xi-key',
      inferenceProviderType: InferenceProviderType.elevenLabs,
    );
    final elevenRoute = TtsCloudRoute(
      provider: elevenProvider,
      model: testAiModel(
        id: 'eleven-row',
        providerModelId: 'eleven_multilingual_v2',
      ),
      languageCode: 'de',
    );

    setUp(() {
      when(
        () => elevenLabs.synthesize(
          text: any(named: 'text'),
          voiceId: any(named: 'voiceId'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) async => audio);
    });

    test("an ElevenLabs route speaks through ElevenLabs' client, with its "
        'own provider and model', () async {
      final file = await synthesizer.synthesizeToFile(
        route: elevenRoute,
        text: 'Hallo',
        chosenVoices: const {},
        canSend: allow,
      );

      expect(file!.readAsBytesSync(), audio);
      verify(
        () => catalogs.catalogFor(elevenProvider, elevenRoute.model),
      ).called(1);
      verify(
        () => elevenLabs.synthesize(
          text: 'Hallo',
          voiceId: 'v-de-f',
          baseUrl: elevenProvider.baseUrl,
          apiKey: 'xi-key',
          model: 'eleven_multilingual_v2',
        ),
      ).called(1);
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

    test("an ElevenLabs route follows its own pick and ignores Mistral's "
        'for the same language', () async {
      await synthesizer.synthesizeToFile(
        route: elevenRoute,
        text: 'Hallo',
        chosenVoices: const {'de': 'v-de-f', 'eleven/de': 'v-de-m'},
        canSend: allow,
      );
      await synthesizer.synthesizeToFile(
        route: route,
        text: 'Hallo',
        chosenVoices: const {'eleven/de': 'v-de-m'},
        canSend: allow,
      );

      verify(
        () => elevenLabs.synthesize(
          text: 'Hallo',
          voiceId: 'v-de-m',
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
        ),
      ).called(1);
      // The ElevenLabs pick is not Mistral's: its default voice speaks.
      verify(
        () => service.synthesize(
          text: 'Hallo',
          voiceId: 'v-de-f',
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
        ),
      ).called(1);
    });

    test('a provider without a speech client fails before the catalog is '
        'asked for', () async {
      await expectLater(
        synthesizer.synthesizeToFile(
          route: TtsCloudRoute(
            provider: testInferenceProvider(
              id: 'openai',
              inferenceProviderType: InferenceProviderType.openAi,
            ),
            model: route.model,
            languageCode: 'de',
          ),
          text: 'Hallo',
          chosenVoices: const {},
          canSend: allow,
        ),
        throwsArgumentError,
      );
      verifyNever(() => catalogs.catalogFor(any(), any()));
    });
  });

  group('providers', () {
    setUp(() async {
      await setUpTestGetIt();
    });
    tearDown(tearDownTestGetIt);

    test('every speaking provider type has its client, shared by the '
        'synthesizer and the catalog cache', () {
      final container = ProviderContainer(overrides: getItServiceOverrides());
      addTearDown(container.dispose);

      final clients = container.read(cloudTtsClientsProvider);
      expect(clients.keys.toSet(), cloudSpeechProviderTypes);
      expect(clients[InferenceProviderType.mistral], isA<VoxtralTtsService>());
      expect(
        clients[InferenceProviderType.elevenLabs],
        isA<ElevenLabsTtsService>(),
      );
      // Both voices are played while they are still being made.
      expect(clients.values, everyElement(isA<StreamingCloudTtsClient>()));
      expect(container.read(cloudSpeechSynthesizerProvider), isNotNull);
      expect(container.read(cloudVoiceCatalogRepositoryProvider), isNotNull);
      // Reading again yields the same clients: no second HTTP pool.
      expect(container.read(cloudTtsClientsProvider), same(clients));
    });
  });
}
