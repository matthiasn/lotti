import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/plaza_task.dart';

/// A reproducible synthetic project for the plaza tests: bursty creation
/// over many weeks (so the street folds), a spread of states and
/// priorities, links to a few hubs, and attention signals planted at the
/// frontier (overdue, due soon, stale, blocked).
///
/// Test-only: the harness shows the penguin demo world and nothing else.
List<PlazaTask> syntheticPlazaTasks({int count = 120, int seed = 42}) {
  assert(count >= 0, 'count must not be negative');
  if (count == 0) return const [];
  final rng = math.Random(seed);
  final start = DateTime.utc(2026, 3, 2, 9);
  final hubs = <int>{};
  while (hubs.length < math.max(1, count ~/ 25)) {
    hubs.add(rng.nextInt(count));
  }
  final tasks = <PlazaTask>[];
  var cursor = start;
  for (var i = 0; i < count; i++) {
    cursor = cursor.add(
      rng.nextDouble() < 0.6
          ? Duration(minutes: 20 + rng.nextInt(400))
          : Duration(days: 1 + rng.nextInt(9), hours: rng.nextInt(8)),
    );
    final roll = rng.nextDouble();
    final state = roll < 0.32
        ? PlazaTaskState.open
        : roll < 0.52
        ? PlazaTaskState.inProgress
        : roll < 0.6
        ? PlazaTaskState.blocked
        : roll < 0.94
        ? PlazaTaskState.done
        : PlazaTaskState.cancelled;
    final items = rng.nextDouble() < 0.45 ? 2 + rng.nextInt(9) : 0;
    final progress = items == 0
        ? 0.0
        : state == PlazaTaskState.done
        ? 1.0
        : rng.nextInt(items + 1) / items;
    final open = items - (progress * items).round();
    final links = <String>[
      if (rng.nextDouble() < 0.25 && i > 0)
        'synthetic-$seed-${rng.nextDouble() < 0.7 ? hubs.elementAt(rng.nextInt(hubs.length)) : rng.nextInt(i)}',
    ]..removeWhere((l) => l == 'synthetic-$seed-$i');
    final priorityRoll = rng.nextDouble();
    tasks.add(
      PlazaTask(
        id: 'synthetic-$seed-$i',
        createdAt: cursor,
        title: 'Task $i of $count',
        state: state,
        due: rng.nextDouble() < 0.3
            ? cursor.add(Duration(days: 2 + rng.nextInt(30)))
            : null,
        progress: progress,
        checklistItems: items,
        openChecklistItems: [for (var n = 0; n < open; n++) 'Step ${n + 1}'],
        linkedTaskIds: links,
        categoryColor: const [
          0xFF5C9DFF,
          0xFFB588F2,
          0xFF63C99A,
          0xFFE8B44F,
        ][rng.nextInt(4)],
        deleted: rng.nextDouble() < 0.03,
        priority: priorityRoll < 0.08
            ? 0
            : priorityRoll < 0.3
            ? 1
            : priorityRoll < 0.85
            ? 2
            : 3,
        coverImageUrl: rng.nextDouble() < 0.3
            ? 'https://demo.invalid/cover-$i.webp'
            : null,
      ),
    );
  }
  return _plantFrontierSignals(tasks);
}

/// The clock the synthetic project is scored against: the day after its
/// newest task.
DateTime syntheticNow(List<PlazaTask> tasks) => tasks
    .map((t) => t.createdAt)
    .reduce((a, b) => a.isAfter(b) ? a : b)
    .add(const Duration(days: 1));

List<PlazaTask> _plantFrontierSignals(List<PlazaTask> tasks) {
  final now = syntheticNow(tasks);
  final out = [...tasks];
  final recent = <int>[];
  for (var i = out.length - 1; i >= 0 && recent.length < 6; i--) {
    if (out[i].state == PlazaTaskState.open ||
        out[i].state == PlazaTaskState.inProgress) {
      recent.add(i);
    }
  }
  for (final (n, i) in recent.indexed) {
    final t = out[i];
    out[i] = PlazaTask(
      id: t.id,
      createdAt: t.createdAt,
      title: t.title,
      state: n == 5 ? PlazaTaskState.blocked : t.state,
      due: n < 2
          ? now.subtract(Duration(days: 3 + n * 9))
          : n < 5
          ? now.add(Duration(days: n - 2))
          : t.due,
      progress: t.progress,
      checklistItems: t.checklistItems,
      openChecklistItems: t.openChecklistItems,
      linkedTaskIds: t.linkedTaskIds,
      categoryColor: t.categoryColor,
      deleted: t.deleted,
      priority: t.priority,
      lastActivityAt: n == 4 ? now.subtract(const Duration(days: 21)) : null,
      coverImageUrl: t.coverImageUrl,
    );
  }
  return out;
}
