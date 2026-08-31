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

/// Generates a reproducible task list for [preset] from [seed].
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

    final links = <String>[];
    if (rng.nextDouble() < 0.25 && i > 0) {
      // Mostly link to a hub, occasionally to a random earlier task.
      final target = rng.nextDouble() < 0.7
          ? hubs.elementAt(rng.nextInt(hubs.length))
          : rng.nextInt(i);
      if (target != i) links.add('plaza-$seed-$target');
    }

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
        linkedTaskIds: links,
        categoryColor: _categoryColors[rng.nextInt(_categoryColors.length)],
        deleted: rng.nextDouble() < 0.03,
      ),
    );
  }
  return tasks;
}

String _title(math.Random rng) {
  final verb = _verbs[rng.nextInt(_verbs.length)];
  final object = _objects[rng.nextInt(_objects.length)];
  final tail = _tails[rng.nextInt(_tails.length)];
  return tail.isEmpty ? '$verb the $object' : '$verb the $object $tail';
}
