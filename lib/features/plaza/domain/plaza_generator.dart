/// Seeded synthetic task generator for the plaza prototype.
///
/// Pure Dart. Presets model a small project (20), a real one (80), and an
/// unreasonably large one (300). Output is fully reproducible from the seed.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/plaza_task.dart';

/// Dataset sizes the harness can switch between.
enum PlazaPreset {
  small(20),
  medium(80),
  large(300);

  const PlazaPreset(this.taskCount);

  final int taskCount;
}

const _verbs = [
  'Fix',
  'Ship',
  'Design',
  'Review',
  'Refactor',
  'Investigate',
  'Document',
  'Migrate',
  'Benchmark',
  'Localize',
  'Wire up',
  'Stabilize',
  'Prototype',
  'Deprecate',
  'Instrument',
  'Untangle',
  'Rebuild',
  'Audit',
  'Polish',
];

const _objects = [
  'sync conflict banner',
  'habit streak math',
  'audio recorder',
  'task header',
  'checklist drag handles',
  'calendar day view',
  'search index',
  'AI summary',
  'settings import',
  'onboarding flow',
  'theme tokens',
  'entry linking',
  'export pipeline',
  'notification wake',
  'attachment previews',
  'dashboards',
  'time tracking rollup',
  'category picker',
  'vector clock merge',
  'transcription queue',
];

const _tails = [
  '', '', '', '', // Most titles are short.
  'on Linux', 'for the mobile layout', 'before the release',
  'after the schema change', 'so the board stops lying',
  'without breaking offline sync, including the edge case where two devices edit the same entry inside one sync window',
];

const _categoryColors = [
  0xFF5C9DFF, // work — blue
  0xFFB588F2, // writing — purple
  0xFF63C99A, // health — green
  0xFFE8B44F, // learning — amber
  0xFFE87C6C, // home — coral
  0xFF6ECBD8, // admin — teal
];

/// The clock a synthetic preset is scored against: the day after the
/// newest task was created, so "overdue", "due soon" and "stale" mean
/// something without wall-clock time leaking into the harness.
DateTime plazaNowFor(List<PlazaTask> tasks) {
  if (tasks.isEmpty) return DateTime.utc(2026, 3, 2);
  final newest = tasks
      .map((t) => t.createdAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  return newest.add(const Duration(days: 1));
}

/// Generates a reproducible task list for [preset] from [seed].
///
/// Besides titles, states and checklists it plants the attention signals
/// the plaza is built to surface: a few blocked tasks, overdue and
/// due-soon dates around the frontier, stale in-progress work, and a
/// spread of priorities so heights vary.
List<PlazaTask> generatePlazaTasks({
  required PlazaPreset preset,
  int seed = 42,
}) {
  final rng = math.Random(seed);
  final count = preset.taskCount;
  final tasks = <PlazaTask>[];
  final start = DateTime(2026, 3, 2, 9);

  // A few hub tasks collect most links (plausible link-graph density).
  final hubCount = math.max(1, count ~/ 25);
  final hubs = <int>{};
  while (hubs.length < hubCount) {
    hubs.add(rng.nextInt(count));
  }

  var cursor = start;
  for (var i = 0; i < count; i++) {
    // Bursty creation: sometimes many in a day, sometimes a quiet week.
    cursor = cursor.add(
      rng.nextDouble() < 0.6
          ? Duration(minutes: 20 + rng.nextInt(400))
          : Duration(days: 1 + rng.nextInt(9), hours: rng.nextInt(8)),
    );

    final roll = rng.nextDouble();
    final PlazaTaskState state;
    if (roll < 0.32) {
      state = PlazaTaskState.open;
    } else if (roll < 0.52) {
      state = PlazaTaskState.inProgress;
    } else if (roll < 0.60) {
      state = PlazaTaskState.blocked;
    } else if (roll < 0.94) {
      state = PlazaTaskState.done;
    } else {
      state = PlazaTaskState.cancelled;
    }

    final checklistItems = rng.nextDouble() < 0.45 ? 2 + rng.nextInt(9) : 0;
    final double progress;
    if (checklistItems == 0) {
      progress = 0;
    } else if (state == PlazaTaskState.done) {
      progress = 1;
    } else {
      progress = rng.nextInt(checklistItems + 1) / checklistItems;
    }
    final openCount = checklistItems - (progress * checklistItems).round();
    final openItems = [
      for (var n = 0; n < openCount; n++)
        '${_verbs[rng.nextInt(_verbs.length)]} ${_objects[rng.nextInt(_objects.length)]}',
    ];

    final links = <String>[];
    if (rng.nextDouble() < 0.25 && i > 0) {
      // Mostly link to a hub, occasionally to a random earlier task.
      final target = rng.nextDouble() < 0.7
          ? hubs.elementAt(rng.nextInt(hubs.length))
          : rng.nextInt(i);
      if (target != i) links.add('plaza-$seed-$target');
    }

    final priorityRoll = rng.nextDouble();
    final priority = priorityRoll < 0.08
        ? 0
        : priorityRoll < 0.3
        ? 1
        : priorityRoll < 0.85
        ? 2
        : 3;

    // In-progress work is usually fresh; one in four is stale.
    final active = state == PlazaTaskState.inProgress;
    final lastActivityAt = active && rng.nextDouble() < 0.75
        ? null
        : cursor.add(Duration(hours: 6 + rng.nextInt(48)));

    tasks.add(
      PlazaTask(
        id: 'plaza-$seed-$i',
        createdAt: cursor,
        title: _title(rng),
        state: state,
        due: rng.nextDouble() < 0.3
            ? cursor.add(Duration(days: 2 + rng.nextInt(30)))
            : null,
        progress: progress,
        checklistItems: checklistItems,
        openChecklistItems: openItems,
        linkedTaskIds: links,
        categoryColor: _categoryColors[rng.nextInt(_categoryColors.length)],
        deleted: rng.nextDouble() < 0.03,
        priority: priority,
        lastActivityAt: lastActivityAt,
      ),
    );
  }
  return _plantFrontierSignals(tasks, rng);
}

/// Re-dates a handful of the newest open tasks so the frontier has
/// something to say: two overdue, three due within days, one stale. Only
/// dates change, never ids or creation times, so placement is untouched.
List<PlazaTask> _plantFrontierSignals(List<PlazaTask> tasks, math.Random rng) {
  final now = plazaNowFor(tasks);
  final out = [...tasks];
  final recentOpen = <int>[];
  for (var i = out.length - 1; i >= 0 && recentOpen.length < 6; i--) {
    if (out[i].state == PlazaTaskState.open ||
        out[i].state == PlazaTaskState.inProgress) {
      recentOpen.add(i);
    }
  }
  for (final (n, i) in recentOpen.indexed) {
    final t = out[i];
    final due = n < 2
        ? now.subtract(Duration(days: 3 + n * 9))
        : n < 5
        ? now.add(Duration(days: n - 2))
        : t.due;
    final stale = n == 5 && t.state == PlazaTaskState.inProgress;
    out[i] = PlazaTask(
      id: t.id,
      createdAt: t.createdAt,
      title: t.title,
      state: t.state,
      due: due,
      progress: t.progress,
      checklistItems: t.checklistItems,
      openChecklistItems: t.openChecklistItems,
      linkedTaskIds: t.linkedTaskIds,
      categoryColor: t.categoryColor,
      deleted: t.deleted,
      priority: t.priority,
      lastActivityAt: stale
          ? now.subtract(const Duration(days: 21))
          : t.lastActivityAt,
      coverImageUrl: t.coverImageUrl,
    );
  }
  return out;
}

String _title(math.Random rng) {
  final verb = _verbs[rng.nextInt(_verbs.length)];
  final object = _objects[rng.nextInt(_objects.length)];
  final tail = _tails[rng.nextInt(_tails.length)];
  return tail.isEmpty ? '$verb the $object' : '$verb the $object $tail';
}
