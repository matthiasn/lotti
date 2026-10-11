import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/ai_api_key_storage.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/deep_backfill/ai_config_deep_backfill_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late AiConfigDb db;
  late AiConfigRepository repository;
  late MockOutboxService outbox;
  late AiConfigDeepBackfillStore store;

  const liveClock = VectorClock({'host-a': 2});
  const deletionClock = VectorClock({'host-b': 1});

  AiConfig profile(String id) => AiConfig.inferenceProfile(
    id: id,
    name: 'Profile $id',
    createdAt: DateTime(2026, 10, 11),
    thinkingModelId: 'model-1',
  );

  setUp(() async {
    db = AiConfigDb(
      inMemoryDatabase: true,
      apiKeyStorage: AiApiKeyStorage.inMemory(),
    );
    repository = AiConfigRepository(db);
    outbox = MockOutboxService();
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    store = AiConfigDeepBackfillStore(
      aiConfigRepository: repository,
      outboxService: outbox,
    );
    await db.saveConfig(profile('a-live'), vectorClock: liveClock);
    await db.applyConfigDeletion(
      'b-gone',
      stamp: 9,
      vectorClock: deletionClock,
    );
    await db.saveConfig(profile('c-legacy'));
  });

  tearDown(() => repository.close());

  test('lists live rows and hard deletions alike, with their clocks', () async {
    expect(store.payloadType, SyncSequencePayloadType.aiConfig);
    expect(await store.count(), 3);

    final page = await store.page(after: null, limit: 2);
    expect(
      [for (final row in page) (row.id, row.clock)],
      [
        ('a-live', liveClock),
        ('b-gone', deletionClock),
      ],
    );
    final rest = await store.page(after: 'b-gone', limit: 2);
    expect(
      [for (final row in rest) (row.id, row.clock)],
      [
        ('c-legacy', null),
      ],
    );

    expect(await store.range(start: 'b', end: null), {
      'b-gone': deletionClock,
      'c-legacy': null,
    });
  });

  test('a write is announced on the change stream', () async {
    final changed = expectLater(store.changes, emits(anything));
    await db.saveConfig(profile('d-new'));
    await changed;
  });

  test('resends the version each id holds now, a deletion as a hard '
      'deletion, and skips an id it holds nothing of', () async {
    final sent = await store.enqueueCurrent(
      {'a-live', 'b-gone', 'unknown'},
      withMedia: const {},
    );

    expect(sent, 2);
    final messages = verify(
      () => outbox.enqueueMessage(captureAny()),
    ).captured.cast<SyncMessage>();
    expect(
      messages,
      unorderedEquals(<Matcher>[
        isA<SyncAiConfig>()
            .having((m) => m.aiConfig.id, 'id', 'a-live')
            .having((m) => m.vectorClock, 'vectorClock', liveClock),
        isA<SyncAiConfigDelete>()
            .having((m) => m.id, 'id', 'b-gone')
            .having((m) => m.hardDelete, 'hardDelete', true)
            .having((m) => m.versionStamp, 'versionStamp', 9)
            .having((m) => m.vectorClock, 'vectorClock', deletionClock),
      ]),
    );
  });
}
