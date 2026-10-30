import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/sync/deep_backfill/embedding_vectors_deep_backfill_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

EmbeddingRegister _register(String entityId, int counter) => EmbeddingRegister(
  entityId: entityId,
  modelId: 'm',
  entityType: 'task',
  contentHash: 'h',
  vectorClock: VectorClock({'a': counter}),
  originatingHostId: 'a',
);

void main() {
  late MockEmbeddingVectorsSync vectors;
  late EmbeddingVectorsDeepBackfillStore store;

  setUp(() {
    vectors = MockEmbeddingVectorsSync();
    when(vectors.sharedRegisters).thenAnswer(
      (_) async => [_register('a', 1), _register('b', 2), _register('c', 3)],
    );
    store = EmbeddingVectorsDeepBackfillStore(vectors);
  });

  test('advertises the vectors register type', () {
    expect(store.payloadType, SyncSequencePayloadType.embeddingVectors);
  });

  test('takes part exactly while vectors are shared', () async {
    when(() => vectors.isSharing).thenAnswer((_) async => false);
    expect(await store.participates(), isFalse);
    when(() => vectors.isSharing).thenAnswer((_) async => true);
    expect(await store.participates(), isTrue);
  });

  test('counts and pages the shared registers in id order', () async {
    expect(await store.count(), 3);
    expect(
      (await store.page(after: null, limit: 2)).map((r) => (r.id, r.clock)),
      [
        ('a|m', const VectorClock({'a': 1})),
        ('b|m', const VectorClock({'a': 2})),
      ],
    );
    expect(
      (await store.page(after: 'b|m', limit: 5)).map((r) => r.id),
      ['c|m'],
    );
  });

  test('reads a half-open range, unbounded where a bound is null', () async {
    expect((await store.range(start: 'b|m', end: 'c|m')).keys, ['b|m']);
    expect((await store.range(start: null, end: 'b|m')).keys, ['a|m']);
    expect((await store.range(start: 'b|m', end: null)).keys, ['b|m', 'c|m']);
  });

  test('enqueues the current version of each id it still holds', () async {
    when(() => vectors.resend('a|m')).thenAnswer((_) async => true);
    when(() => vectors.resend('gone|m')).thenAnswer((_) async => false);

    final sent = await store.enqueueCurrent(
      {'a|m', 'gone|m'},
      withMedia: const {},
    );

    expect(sent, 1);
    verify(() => vectors.resend('a|m')).called(1);
  });

  test('reports no table changes: the count refreshes on its own schedule', () {
    expect(store.changes, emitsDone);
  });
}
