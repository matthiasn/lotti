import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart' show MockCloudTtsClient, MockSettingsDb;
import '../../agents/test_data/ai_config_factories.dart';

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);
  final provider = testInferenceProvider(
    id: 'mistral',
    apiKey: 'key',
    inferenceProviderType: InferenceProviderType.mistral,
  );
  final model = testAiModel(id: 'tts', providerModelId: 'voxtral-mini-tts');
  const key = '${voxtralVoiceCatalogKeyPrefix}mistral';
  const heidi = CloudVoice(id: 'v-de', name: 'Heidi', languages: ['de']);
  const emma = CloudVoice(id: 'v-en', name: 'Emma', languages: ['en']);

  late MockSettingsDb db;
  late MockCloudTtsClient service;
  late MockCloudTtsClient elevenLabs;
  late CloudVoiceCatalogRepository repository;

  /// [catalog] as stored for [from]'s account (the Mistral provider's by
  /// default); `account: false` stores it as builds before the account
  /// fingerprint did.
  String encoded(
    CloudVoiceCatalog catalog, {
    AiConfigInferenceProvider? from,
    bool account = true,
  }) => jsonEncode({
    ...catalog.toJson(),
    if (account)
      'account': CloudVoiceCatalogRepository.accountFingerprint(
        from ?? provider,
      ),
  });

  void stubFetch(Future<CloudVoiceCatalog> Function() answer) => when(
    () => service.fetchVoices(
      baseUrl: any(named: 'baseUrl'),
      apiKey: any(named: 'apiKey'),
      model: any(named: 'model'),
    ),
  ).thenAnswer((_) => answer());

  setUp(() {
    db = MockSettingsDb();
    service = MockCloudTtsClient();
    elevenLabs = MockCloudTtsClient();
    repository = CloudVoiceCatalogRepository(
      settingsDb: db,
      clients: {
        InferenceProviderType.mistral: service,
        InferenceProviderType.elevenLabs: elevenLabs,
      },
    );
    when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);
  });

  Future<CloudVoiceCatalog> catalog({
    bool refresh = false,
    AiConfigInferenceProvider? from,
    AiConfigModel? forModel,
  }) => withClock(
    Clock.fixed(now),
    () => repository.catalogFor(
      from ?? provider,
      forModel ?? model,
      refresh: refresh,
    ),
  );

  test('a fresh cached catalog answers without a request', () async {
    final cached = CloudVoiceCatalog(
      voices: const [heidi],
      fetchedAt: now.subtract(const Duration(hours: 2)),
    );
    when(() => db.itemByKey(key)).thenAnswer((_) async => encoded(cached));

    expect(await catalog(), cached);
    verifyNever(
      () => service.fetchVoices(
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        model: any(named: 'model'),
      ),
    );
  });

  test('a stale or missing cache is fetched with the provider credentials '
      'and the model, and stored', () async {
    final fetched = CloudVoiceCatalog(voices: const [emma], fetchedAt: now);
    when(() => db.itemByKey(key)).thenAnswer((_) async => null);
    when(
      () => service.fetchVoices(
        baseUrl: provider.baseUrl,
        apiKey: 'key',
        model: 'voxtral-mini-tts',
      ),
    ).thenAnswer((_) async => fetched);

    expect(await catalog(), fetched);
    verify(() => db.saveSettingsItem(key, encoded(fetched))).called(1);
  });

  test('refresh fetches even when the cache is fresh', () async {
    final cached = CloudVoiceCatalog(voices: const [heidi], fetchedAt: now);
    final fetched = CloudVoiceCatalog(voices: const [emma], fetchedAt: now);
    when(() => db.itemByKey(key)).thenAnswer((_) async => encoded(cached));
    stubFetch(() async => fetched);

    expect(await catalog(refresh: true), fetched);
  });

  test('offline, a stale cache still answers', () async {
    final stale = CloudVoiceCatalog(
      voices: const [heidi],
      fetchedAt: now.subtract(const Duration(days: 3)),
    );
    when(() => db.itemByKey(key)).thenAnswer((_) async => encoded(stale));
    stubFetch(
      () async =>
          throw const CloudTtsException(CloudTtsFailure.network, 'offline'),
    );

    expect(await catalog(), stale);
    verifyNever(() => db.saveSettingsItem(any(), any()));
  });

  for (final stored in [null, 'not json', '{"voices": []}']) {
    test('without a usable cache ($stored) a failed fetch surfaces', () async {
      when(() => db.itemByKey(key)).thenAnswer((_) async => stored);
      stubFetch(
        () async =>
            throw const CloudTtsException(CloudTtsFailure.unauthorized, 'no'),
      );

      await expectLater(
        catalog(),
        throwsA(
          isA<CloudTtsException>().having(
            (e) => e.failure,
            'failure',
            CloudTtsFailure.unauthorized,
          ),
        ),
      );
    });
  }

  group('ElevenLabs', () {
    final eleven = testInferenceProvider(
      id: 'eleven',
      apiKey: 'xi',
      inferenceProviderType: InferenceProviderType.elevenLabs,
    );
    final flash = testAiModel(id: 'flash', providerModelId: 'eleven_flash');

    test('is fetched through its own client and cached per model, since the '
        "model decides the voices' languages", () async {
      final fetched = CloudVoiceCatalog(voices: const [emma], fetchedAt: now);
      when(() => db.itemByKey(any())).thenAnswer((_) async => null);
      when(
        () => elevenLabs.fetchVoices(
          baseUrl: eleven.baseUrl,
          apiKey: 'xi',
          model: 'eleven_flash',
        ),
      ).thenAnswer((_) async => fetched);

      expect(await catalog(from: eleven, forModel: flash), fetched);
      verify(
        () => db.saveSettingsItem(
          '${elevenLabsVoiceCatalogKeyPrefix}eleven/eleven_flash',
          encoded(fetched, from: eleven),
        ),
      ).called(1);
      verifyNever(
        () => service.fetchVoices(
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
        ),
      );
    });
  });

  group('the account it was fetched for', () {
    test('a catalog of another account is never used, even when fresh or '
        'offline', () async {
      final otherAccount = CloudVoiceCatalog(
        voices: const [heidi],
        fetchedAt: now,
      );
      when(() => db.itemByKey(key)).thenAnswer(
        (_) async => encoded(
          otherAccount,
          from: provider.copyWith(apiKey: 'old-key'),
        ),
      );
      final fetched = CloudVoiceCatalog(voices: const [emma], fetchedAt: now);
      stubFetch(() async => fetched);

      expect(await catalog(), fetched);

      stubFetch(
        () async =>
            throw const CloudTtsException(CloudTtsFailure.network, 'offline'),
      );
      await expectLater(catalog(), throwsA(isA<CloudTtsException>()));
    });

    test('a base URL change is another account too', () {
      expect(
        CloudVoiceCatalogRepository.accountFingerprint(provider),
        isNot(
          CloudVoiceCatalogRepository.accountFingerprint(
            provider.copyWith(baseUrl: 'https://eu.example.test/v1'),
          ),
        ),
      );
      expect(
        CloudVoiceCatalogRepository.accountFingerprint(provider),
        CloudVoiceCatalogRepository.accountFingerprint(provider),
      );
    });

    test('the fingerprint holds neither the key nor the URL', () {
      final fingerprint = CloudVoiceCatalogRepository.accountFingerprint(
        provider,
      );
      expect(fingerprint, hasLength(16));
      expect(fingerprint, isNot(contains('key')));
      expect(fingerprint, isNot(contains('http')));
    });

    test('a catalog stored before accounts were recorded is refreshed even '
        'when fresh, and still answers offline', () async {
      final unrecorded = CloudVoiceCatalog(
        voices: const [heidi],
        fetchedAt: now,
      );
      when(
        () => db.itemByKey(key),
      ).thenAnswer((_) async => encoded(unrecorded, account: false));
      final fetched = CloudVoiceCatalog(voices: const [emma], fetchedAt: now);
      stubFetch(() async => fetched);

      expect(await catalog(), fetched);
      verify(() => db.saveSettingsItem(key, encoded(fetched))).called(1);

      stubFetch(
        () async =>
            throw const CloudTtsException(CloudTtsFailure.network, 'offline'),
      );
      expect(await catalog(), unrecorded);
    });
  });

  test('the cache key is per provider for Mistral and per provider and '
      'model for ElevenLabs', () {
    expect(CloudVoiceCatalogRepository.cacheKey(provider, model), key);
    expect(
      CloudVoiceCatalogRepository.cacheKey(
        testInferenceProvider(
          id: 'p',
          inferenceProviderType: InferenceProviderType.elevenLabs,
        ),
        testAiModel(id: 'm', providerModelId: 'eleven_v3'),
      ),
      'TTS_ELEVENLABS_VOICES_p/eleven_v3',
    );
  });

  test('a provider type without a speech client is refused before the cache '
      'is read', () async {
    await expectLater(
      catalog(
        from: testInferenceProvider(
          id: 'openai',
          inferenceProviderType: InferenceProviderType.openAi,
        ),
      ),
      throwsArgumentError,
    );
    verifyNever(() => db.itemByKey(any()));
  });
}
