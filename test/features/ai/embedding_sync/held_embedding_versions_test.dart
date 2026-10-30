import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/embedding_sync/held_embedding_versions.dart';
import 'package:path/path.dart' as p;

HeldEmbeddingVersion _held(String entityId, int counter) =>
    HeldEmbeddingVersion(
      register: EmbeddingRegister(
        entityId: entityId,
        modelId: 'm',
        entityType: 'task',
        contentHash: 'hash-$counter',
        vectorClock: VectorClock({'a': counter}),
        sourceVectorClock: const VectorClock({'a': 1}),
        taskId: 'task',
        originatingHostId: 'a',
      ),
      payload: '{"dims":768}',
      labelIds: const ['l1', 'l2'],
    );

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('held_versions_');
    path = p.join(dir.path, 'nested', 'holds.json');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('a missing file is an empty table', () async {
    final held = await HeldEmbeddingVersions.open(path);

    expect(held.all, isEmpty);
    expect(held['e1|m'], isNull);
  });

  test('what is held survives reopening, field for field', () async {
    final held = await HeldEmbeddingVersions.open(path);
    await held.put(_held('e1', 1));
    await held.put(_held('e2', 4));

    final reopened = await HeldEmbeddingVersions.open(path);

    expect(reopened.all.map((h) => h.register.id), ['e1|m', 'e2|m']);
    final e2 = reopened['e2|m']!;
    expect(e2.register, _held('e2', 4).register);
    expect(e2.payload, '{"dims":768}');
    expect(e2.labelIds, ['l1', 'l2']);
  });

  test('put replaces what is held of the register, remove drops it', () async {
    final held = await HeldEmbeddingVersions.open(path);
    await held.put(_held('e1', 1));
    await held.put(_held('e1', 2));
    await held.remove('absent|m');

    expect(held.all, hasLength(1));
    expect(held['e1|m']!.register.vectorClock, const VectorClock({'a': 2}));

    await held.remove('e1|m');
    final reopened = await HeldEmbeddingVersions.open(path);
    expect(reopened.all, isEmpty);
  });

  test(
    'an unreadable file is an empty table, overwritten by the next put',
    () async {
      await File(path).create(recursive: true);
      await File(path).writeAsString('{not json');

      final held = await HeldEmbeddingVersions.open(path);
      expect(held.all, isEmpty);

      await held.put(_held('e1', 1));
      expect((await HeldEmbeddingVersions.open(path)).all, hasLength(1));
    },
  );

  test('writes asked for at once all land, the newest last', () async {
    final held = await HeldEmbeddingVersions.open(path);

    await Future.wait([
      held.put(_held('e1', 1)),
      held.put(_held('e2', 1)),
      held.put(_held('e1', 2)),
      held.remove('e2|m'),
    ]);

    final reopened = await HeldEmbeddingVersions.open(path);
    expect(reopened.all.map((h) => h.register.id), ['e1|m']);
    expect(
      reopened['e1|m']!.register.vectorClock,
      const VectorClock({'a': 2}),
    );
  });
}
