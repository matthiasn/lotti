import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_merge.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'conflict_test_entities.dart';

void main() {
  // Distinct, concurrent clocks so the merge is observable: neither dominates.
  const localClock = VectorClock({'a': 2, 'b': 1});
  const remoteClock = VectorClock({'a': 1, 'b': 3});
  const mergedClock = VectorClock({'a': 2, 'b': 3});

  String? bodyOf(JournalEntity e) => e.entryText?.plainText;

  group('resolveToSide', () {
    test('keeps the local side, stamped with the merged clock', () {
      final result = resolveToSide(
        local: entryOf(
          text: 'local',
          categoryId: 'cat-l',
          vectorClock: localClock,
        ),
        remote: entryOf(
          text: 'remote',
          categoryId: 'cat-r',
          vectorClock: remoteClock,
        ),
        side: ConflictSide.local,
      );

      expect(bodyOf(result), 'local');
      expect(result.meta.categoryId, 'cat-l');
      expect(result.meta.vectorClock, mergedClock);
    });

    test('keeps the remote side, stamped with the merged clock', () {
      final result = resolveToSide(
        local: entryOf(text: 'local', vectorClock: localClock),
        remote: entryOf(text: 'remote', vectorClock: remoteClock),
        side: ConflictSide.remote,
      );

      expect(bodyOf(result), 'remote');
      expect(result.meta.vectorClock, mergedClock);
    });

    test('the merged clock causally dominates both sides', () {
      final result = resolveToSide(
        local: entryOf(vectorClock: localClock),
        remote: entryOf(vectorClock: remoteClock),
        side: ConflictSide.local,
      );
      final clock = result.meta.vectorClock!;

      expect(VectorClock.compare(clock, localClock), VclockStatus.a_gt_b);
      expect(VectorClock.compare(clock, remoteClock), VclockStatus.a_gt_b);
    });

    test('leaves the clock null when neither side has one', () {
      final noClock = JournalEntry(meta: metaNoClock(text: 'x'));
      final result = resolveToSide(
        local: noClock,
        remote: JournalEntry(meta: metaNoClock(text: 'y')),
        side: ConflictSide.local,
      );
      expect(result.meta.vectorClock, isNull);
    });
  });

  group('buildMergedEntity', () {
    test('overrides the body from the non-base side', () {
      final result = buildMergedEntity(
        local: entryOf(text: 'local body', categoryId: 'cat-l'),
        remote: entryOf(text: 'remote body', categoryId: 'cat-r'),
        baseSide: ConflictSide.local,
        choices: {EntryField.body: ConflictSide.remote},
      );

      expect(bodyOf(result), 'remote body');
      // Category stays the base (local) value — it was not chosen.
      expect(result.meta.categoryId, 'cat-l');
    });

    test('overrides a metadata field from the non-base side', () {
      final result = buildMergedEntity(
        local: entryOf(text: 'local body', categoryId: 'cat-l'),
        remote: entryOf(text: 'remote body', categoryId: 'cat-r'),
        baseSide: ConflictSide.local,
        choices: {EntryField.category: ConflictSide.remote},
      );

      expect(result.meta.categoryId, 'cat-r');
      expect(bodyOf(result), 'local body');
    });

    test('combines fields from both sides onto the base', () {
      final result = buildMergedEntity(
        local: entryOf(text: 'local body', categoryId: 'cat-l', starred: false),
        remote: entryOf(
          text: 'remote body',
          categoryId: 'cat-r',
          starred: true,
        ),
        baseSide: ConflictSide.local,
        choices: {
          EntryField.body: ConflictSide.remote,
          EntryField.starred: ConflictSide.remote,
          // category not chosen -> stays base (local).
        },
      );

      expect(bodyOf(result), 'remote body');
      expect(result.meta.starred, true);
      expect(result.meta.categoryId, 'cat-l');
    });

    test('a choice equal to the base side is a no-op', () {
      final result = buildMergedEntity(
        local: entryOf(text: 'local body'),
        remote: entryOf(text: 'remote body'),
        baseSide: ConflictSide.local,
        choices: {EntryField.body: ConflictSide.local},
      );
      expect(bodyOf(result), 'local body');
    });

    test(
      'base=remote keeps the remote payload while pulling a field local',
      () {
        final result = buildMergedEntity(
          local: entryOf(text: 'local body', starred: true),
          remote: entryOf(text: 'remote body', starred: false),
          baseSide: ConflictSide.remote,
          choices: {EntryField.starred: ConflictSide.local},
        );

        expect(bodyOf(result), 'remote body');
        expect(result.meta.starred, true);
      },
    );

    test('overrides a structured task title without touching other data', () {
      final result = buildMergedEntity(
        local: taskOf(title: 'Local title', estimate: const Duration(hours: 4)),
        remote: taskOf(
          title: 'Remote title',
          estimate: const Duration(hours: 5),
        ),
        baseSide: ConflictSide.local,
        choices: {EntryField.title: ConflictSide.remote},
      );

      final task = result as Task;
      expect(task.data.title, 'Remote title');
      // The rest of the structured payload follows the base (local) side.
      expect(task.data.estimate, const Duration(hours: 4));
    });

    test('stamps the merged clock on the combined result', () {
      final result = buildMergedEntity(
        local: entryOf(text: 'local', vectorClock: localClock),
        remote: entryOf(text: 'remote', vectorClock: remoteClock),
        baseSide: ConflictSide.local,
        choices: {EntryField.body: ConflictSide.remote},
      );
      expect(result.meta.vectorClock, mergedClock);
    });

    test(
      'overrides private, flag, dateFrom and dateTo from the chosen side',
      () {
        final result = buildMergedEntity(
          local: entryOf(
            flag: EntryFlag.none,
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15, 10),
          ),
          remote: entryOf(
            private: true,
            flag: EntryFlag.followUpNeeded,
            dateFrom: DateTime(2024, 3, 16),
            dateTo: DateTime(2024, 3, 16, 10),
          ),
          baseSide: ConflictSide.local,
          choices: const {
            EntryField.private: ConflictSide.remote,
            EntryField.flag: ConflictSide.remote,
            EntryField.dateFrom: ConflictSide.remote,
            EntryField.dateTo: ConflictSide.remote,
          },
        );
        expect(result.meta.private, true);
        expect(result.meta.flag, EntryFlag.followUpNeeded);
        expect(result.meta.dateFrom, DateTime(2024, 3, 16));
        expect(result.meta.dateTo, DateTime(2024, 3, 16, 10));
      },
    );
  });

  group('buildMergedEntity · structured title across entity types', () {
    final builders = <String, JournalEntity Function(String)>{
      'event': (t) => JournalEvent(
        meta: metaOf(id: 'ev'),
        data: EventData(title: t, stars: 0.5, status: EventStatus.planned),
      ),
      'project': (t) => ProjectEntry(
        meta: metaOf(id: 'pr'),
        data: ProjectData(
          title: t,
          status: ProjectStatus.open(
            id: 's',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      ),
      'checklist': (t) => Checklist(
        meta: metaOf(id: 'cl'),
        data: ChecklistData(
          title: t,
          linkedChecklistItems: const [],
          linkedTasks: const [],
        ),
      ),
      'checklist item': (t) => ChecklistItem(
        meta: metaOf(id: 'ci'),
        data: ChecklistItemData(
          title: t,
          isChecked: false,
          linkedChecklists: const [],
        ),
      ),
    };

    for (final entry in builders.entries) {
      final name = entry.key;
      final build = entry.value;
      test('combines the $name title from the chosen side', () {
        final result = buildMergedEntity(
          local: build('Local title'),
          remote: build('Remote title'),
          baseSide: ConflictSide.local,
          choices: const {EntryField.title: ConflictSide.remote},
        );
        expect(_titleOf(result), 'Remote title');
      });
    }
  });
}

String? _titleOf(JournalEntity e) => switch (e) {
  Task(:final data) => data.title,
  JournalEvent(:final data) => data.title,
  ProjectEntry(:final data) => data.title,
  Checklist(:final data) => data.title,
  ChecklistItem(:final data) => data.title,
  _ => null,
};

/// A metadata block with no vector clock, for the null-clock path.
Metadata metaNoClock({required String text}) => Metadata(
  id: text,
  createdAt: DateTime(2024, 3, 15, 8),
  updatedAt: DateTime(2024, 3, 15, 10),
  dateFrom: DateTime(2024, 3, 15, 9),
  dateTo: DateTime(2024, 3, 15, 11),
);
