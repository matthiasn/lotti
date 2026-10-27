import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/tts/cloud/voxtral_tts_service.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart' show MockSettingsDb;
import '../../agents/test_data/ai_config_factories.dart';

class _MockService extends Mock implements VoxtralTtsService {}

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);
  final provider = testInferenceProvider(
    id: 'mistral',
    apiKey: 'key',
    inferenceProviderType: InferenceProviderType.mistral,
  );
  const key = '${voxtralVoiceCatalogKeyPrefix}mistral';
  const heidi = VoxtralVoice(id: 'v-de', name: 'Heidi', languages: ['de']);
  const emma = VoxtralVoice(id: 'v-en', name: 'Emma', languages: ['en']);

  late MockSettingsDb db;
  late _MockService service;
  late VoxtralVoiceCatalogRepository repository;

  String encoded(VoxtralVoiceCatalog catalog) => jsonEncode(catalog.toJson());

  setUp(() {
    db = MockSettingsDb();
    service = _MockService();
    repository = VoxtralVoiceCatalogRepository(
      settingsDb: db,
      service: service,
    );
    when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);
  });

  Future<VoxtralVoiceCatalog> catalog({bool refresh = false}) => withClock(
    Clock.fixed(now),
    () => repository.catalogFor(provider, refresh: refresh),
  );

  test('a fresh cached catalog answers without a request', () async {
    final cached = VoxtralVoiceCatalog(
      voices: const [heidi],
      fetchedAt: now.subtract(const Duration(hours: 2)),
    );
    when(() => db.itemByKey(key)).thenAnswer((_) async => encoded(cached));

    expect(await catalog(), cached);
    verifyNever(
      () => service.fetchVoices(
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
      ),
    );
  });

  test('a stale or missing cache is fetched with the provider credentials '
      'and stored', () async {
    final fetched = VoxtralVoiceCatalog(voices: const [emma], fetchedAt: now);
    when(() => db.itemByKey(key)).thenAnswer((_) async => null);
    when(
      () => service.fetchVoices(baseUrl: provider.baseUrl, apiKey: 'key'),
    ).thenAnswer((_) async => fetched);

    expect(await catalog(), fetched);
    verify(() => db.saveSettingsItem(key, encoded(fetched))).called(1);
  });

  test('refresh fetches even when the cache is fresh', () async {
    final cached = VoxtralVoiceCatalog(voices: const [heidi], fetchedAt: now);
    final fetched = VoxtralVoiceCatalog(voices: const [emma], fetchedAt: now);
    when(() => db.itemByKey(key)).thenAnswer((_) async => encoded(cached));
    when(
      () => service.fetchVoices(
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
      ),
    ).thenAnswer((_) async => fetched);

    expect(await catalog(refresh: true), fetched);
  });

  test('offline, a stale cache still answers', () async {
    final stale = VoxtralVoiceCatalog(
      voices: const [heidi],
      fetchedAt: now.subtract(const Duration(days: 3)),
    );
    when(() => db.itemByKey(key)).thenAnswer((_) async => encoded(stale));
    when(
      () => service.fetchVoices(
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
      ),
    ).thenThrow(
      const VoxtralTtsException(VoxtralTtsFailure.network, 'offline'),
    );

    expect(await catalog(), stale);
    verifyNever(() => db.saveSettingsItem(any(), any()));
  });

  for (final stored in [null, 'not json', '{"voices": []}']) {
    test('without a usable cache ($stored) a failed fetch surfaces', () async {
      when(() => db.itemByKey(key)).thenAnswer((_) async => stored);
      when(
        () => service.fetchVoices(
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
        ),
      ).thenThrow(
        const VoxtralTtsException(VoxtralTtsFailure.unauthorized, 'no'),
      );

      await expectLater(
        catalog(),
        throwsA(
          isA<VoxtralTtsException>().having(
            (e) => e.failure,
            'failure',
            VoxtralTtsFailure.unauthorized,
          ),
        ),
      );
    });
  }
}
