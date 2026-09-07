import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';

void main() {
  test('toggles per task and index, counting and notifying', () {
    final ticks = ChecklistTicks();
    addTearDown(ticks.dispose);
    var notified = 0;
    ticks.addListener(() => notified++);
    expect(ticks.isTicked('a', 0), isFalse);
    expect(ticks.tickedCount('a'), 0);

    ticks.toggle('a', 0);
    expect(ticks.isTicked('a', 0), isTrue);
    expect(ticks.isTicked('a', 1), isFalse);
    expect(ticks.isTicked('b', 0), isFalse);
    expect(ticks.tickedCount('a'), 1);

    ticks.toggle('a', 2);
    expect(ticks.tickedCount('a'), 2);
    ticks.toggle('a', 0);
    expect(ticks.isTicked('a', 0), isFalse);
    expect(ticks.tickedCount('a'), 1);
    expect(notified, 3);
  });
  PlazaTask taskWithIds(List<String> ids) => PlazaTask(
    id: 'task',
    createdAt: DateTime.utc(2026, 9, 7),
    title: 'Waddle',
    state: PlazaTaskState.open,
    progress: 0,
    checklistItems: ids.length,
    linkedTaskIds: const [],
    categoryColor: 0xFF123456,
    openChecklistItems: [for (final id in ids) 'Item $id'],
    openChecklistItemIds: ids,
  );

  testWidgets(
    'persists the captured item ID across preview reorder and coalesces taps',
    (tester) async {
      final pending = Completer<bool>();
      final writes = <(String, String, bool)>[];
      final ticks = ChecklistTicks(
        persist: (taskId, itemId, {required checked}) {
          writes.add((taskId, itemId, checked));
          return pending.future;
        },
      );
      addTearDown(ticks.dispose);
      ticks
        ..bindTasks([
          taskWithIds(['first', 'second']),
        ])
        ..toggle('task', 0)
        ..toggle('task', 0)
        ..bindTasks([
          taskWithIds(['second', 'first']),
        ]);
      expect(ticks.isTicked('task', 0), isFalse);
      expect(ticks.isTicked('task', 1), isTrue);
      pending.complete(true);
      await tester.pump();
      expect(writes, [('task', 'first', true)]);
      expect(ticks.tickedCount('task'), 1);
      ticks.bindTasks([
        taskWithIds(['second']),
      ]);
      expect(ticks.tickedCount('task'), 0);
    },
  );

  for (final throws in [false, true]) {
    testWidgets('failed write rolls back (throws: $throws)', (tester) async {
      var failures = 0;
      final ticks = ChecklistTicks(
        persist: (_, _, {required checked}) async {
          if (throws) throw StateError('write failed');
          return false;
        },
        onFailure: () => failures++,
      );
      addTearDown(ticks.dispose);
      ticks
        ..bindTasks([
          taskWithIds(['item']),
        ])
        ..toggle('task', 0);
      expect(ticks.isTicked('task', 0), isTrue);
      await tester.pump();
      expect(ticks.isTicked('task', 0), isFalse);
      expect(ticks.tickedCount('task'), 0);
      expect(failures, 1);
    });
  }

  testWidgets('unchecking rolls back if its write fails', (tester) async {
    var calls = 0;
    final ticks = ChecklistTicks(
      persist: (_, _, {required checked}) async => ++calls == 1,
    );
    addTearDown(ticks.dispose);
    ticks
      ..bindTasks([
        taskWithIds(['item']),
      ])
      ..toggle('task', 0);
    await tester.pump();
    ticks.toggle('task', 0);
    expect(ticks.isTicked('task', 0), isFalse);
    await tester.pump();
    expect(ticks.isTicked('task', 0), isTrue);
    expect(calls, 2);
  });

  testWidgets(
    'invalid or removed previews never write and disposal ignores late failure',
    (tester) async {
      final pending = Completer<bool>();
      var calls = 0;
      var failures = 0;
      final ticks =
          ChecklistTicks(
              persist: (_, _, {required checked}) {
                calls++;
                return pending.future;
              },
              onFailure: () => failures++,
            )
            ..toggle('task', 0)
            ..bindTasks([
              taskWithIds(['item']),
            ])
            ..toggle('task', -1)
            ..toggle('task', 1);
      expect(calls, 0);
      ticks
        ..toggle('task', 0)
        ..bindTasks([]);
      expect(ticks.tickedCount('task'), 0);
      ticks.toggle('task', 0);
      expect(calls, 1);
      ticks.dispose();
      pending.complete(false);
      await tester.pump();
      expect(failures, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
