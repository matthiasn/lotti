import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';

void main() {
  const full = EmbeddingRegister(
    entityId: 'report-1',
    modelId: 'embeddinggemma-300m-q4',
    entityType: 'agent_report',
    contentHash: 'abc',
    vectorClock: VectorClock({'a': 3, 'b': 1}),
    sourceVectorClock: VectorClock({'a': 2}),
    taskId: 'task-1',
    subtype: 'current',
    originatingHostId: 'a',
  );

  test('is keyed by entity and model', () {
    expect(full.id, 'report-1|embeddinggemma-300m-q4');
    expect(embeddingRegisterId('e', 'm'), 'e|m');
  });

  test('a version without a clock was never shared', () {
    expect(full.isShared, isTrue);
    expect(
      const EmbeddingRegister(
        entityId: 'e',
        modelId: 'm',
        entityType: 'task',
        contentHash: 'h',
      ).isShared,
      isFalse,
    );
  });

  test('round-trips through JSON, a tombstone included', () {
    const tombstone = EmbeddingRegister(
      entityId: 'e',
      modelId: 'm',
      entityType: '',
      contentHash: '',
      vectorClock: VectorClock({'a': 9}),
      deleted: true,
    );

    expect(EmbeddingRegister.fromJson(full.toJson()), full);
    expect(EmbeddingRegister.fromJson(tombstone.toJson()), tombstone);
  });

  test('copyWith versions a register and keeps everything else', () {
    final versioned = full.copyWith(
      vectorClock: const VectorClock({'c': 1}),
      originatingHostId: 'c',
    );

    expect(versioned.vectorClock, const VectorClock({'c': 1}));
    expect(versioned.originatingHostId, 'c');
    expect(versioned.contentHash, full.contentHash);
    expect(versioned.sourceVectorClock, full.sourceVectorClock);
    expect(versioned.taskId, full.taskId);
    expect(versioned, isNot(full));
  });

  test('equal versions hash alike and print their register and clock', () {
    const same = EmbeddingRegister(
      entityId: 'report-1',
      modelId: 'embeddinggemma-300m-q4',
      entityType: 'agent_report',
      contentHash: 'abc',
      vectorClock: VectorClock({'a': 3, 'b': 1}),
      sourceVectorClock: VectorClock({'a': 2}),
      taskId: 'task-1',
      subtype: 'current',
      originatingHostId: 'a',
    );

    expect(same.hashCode, full.hashCode);
    expect(<EmbeddingRegister>{full}..add(same), hasLength(1));
    expect(full.copyWith(originatingHostId: 'b').vectorClock, full.vectorClock);
    expect(
      full.toString(),
      contains('report-1|embeddinggemma-300m-q4'),
    );
    expect(full.toString(), contains('deleted: false'));
  });
}
