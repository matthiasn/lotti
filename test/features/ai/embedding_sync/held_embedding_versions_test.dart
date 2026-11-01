import 'dart:async';
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

  test(
    'watchCount starts at the reopened count and follows every change, '
    'never a no-op removal',
    () async {
      await (await HeldEmbeddingVersions.open(path)).put(_held('e1', 1));
      final held = await HeldEmbeddingVersions.open(path);
      final counts = <int>[];
      final subscription = held.watchCount().listen(counts.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await held.put(_held('e2', 1));
      await held.put(_held('e2', 2));
      await held.remove('e1|m');
      await held.remove('e1|m');
      await pumpEventQueue();

      expect(counts, [1, 2, 2, 1]);
    },
  );

  test('two watchers each see the count from when they listen', () async {
    final held = await HeldEmbeddingVersions.open(path);
    final first = <int>[];
    final firstSubscription = held.watchCount().listen(first.add);
    addTearDown(firstSubscription.cancel);
    await held.put(_held('e1', 1));
    final second = <int>[];
    final secondSubscription = held.watchCount().listen(second.add);
    addTearDown(secondSubscription.cancel);
    await pumpEventQueue();

    await held.remove('e1|m');
    await pumpEventQueue();

    expect(first, [0, 1, 0]);
    expect(second, [1, 0]);
  });

  test(
    'a batch writes its changes once, at its end; a change from outside it '
    'is written at once',
    () async {
      final held = await HeldEmbeddingVersions.open(path);
      await held.put(_held('e1', 1));
      Future<List<String>> onDisk() async => (await HeldEmbeddingVersions.open(
        path,
      )).all.map((h) => h.register.id).toList();

      await held.batch(() async {
        await held.remove('e1|m');
        await held.put(_held('e2', 1));
        expect(await onDisk(), ['e1|m'], reason: 'deferred inside the batch');

        // The apply path, outside the batch's zone, writes at once — with
        // every change made so far.
        await Zone.root.run(() => held.put(_held('e3', 1)));
        expect(await onDisk(), ['e2|m', 'e3|m']);

        await held.remove('e3|m');
        expect(await onDisk(), ['e2|m', 'e3|m']);
      });

      expect(await onDisk(), ['e2|m']);
    },
  );

  test('a batch that throws still writes what it changed', () async {
    final held = await HeldEmbeddingVersions.open(path);
    await held.put(_held('e1', 1));

    await expectLater(
      held.batch(() async {
        await held.remove('e1|m');
        throw StateError('merge failed');
      }),
      throwsStateError,
    );

    expect((await HeldEmbeddingVersions.open(path)).all, isEmpty);
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
