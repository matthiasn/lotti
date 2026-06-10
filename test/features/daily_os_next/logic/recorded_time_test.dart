import 'package:glados/glados.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os_next/logic/recorded_time.dart';

final _day = DateTime(2026, 6, 8);

JournalEntry _entry({
  required String id,
  required int startHour,
  int durationMinutes = 60,
  String? categoryId,
  bool deleted = false,
}) {
  final start = _day.add(Duration(hours: startHour));
  return JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          createdAt: _day,
          updatedAt: _day,
          dateFrom: start,
          dateTo: start.add(Duration(minutes: durationMinutes)),
          categoryId: categoryId,
          deletedAt: deleted ? _day : null,
        ),
        entryText: const EntryText(plainText: 'recorded work'),
      )
      as JournalEntry;
}

Task _task({
  required String id,
  String? categoryId,
  bool deleted = false,
}) {
  return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: _day,
          updatedAt: _day,
          dateFrom: _day,
          dateTo: _day,
          categoryId: categoryId,
          deletedAt: deleted ? _day : null,
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: '$id-status',
            createdAt: _day,
            utcOffset: 0,
          ),
          dateFrom: _day,
          dateTo: _day,
          statusHistory: const [],
          title: 'Task $id',
        ),
      )
      as Task;
}

JournalEntity _note({required String id, String? categoryId}) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: _day,
      updatedAt: _day,
      dateFrom: _day,
      dateTo: _day,
      categoryId: categoryId,
    ),
    entryText: const EntryText(plainText: 'a linked note'),
  );
}

JournalEntity _rating({required String id}) {
  return JournalEntity.rating(
    meta: Metadata(
      id: id,
      createdAt: _day,
      updatedAt: _day,
      dateFrom: _day,
      dateTo: _day,
    ),
    data: const RatingData(targetId: 'entry', dimensions: []),
  );
}

EntryLink _link({
  required String fromId,
  required String toId,
  bool deleted = false,
}) {
  return EntryLink.basic(
    id: 'link-$fromId-$toId',
    fromId: fromId,
    toId: toId,
    createdAt: _day,
    updatedAt: _day,
    vectorClock: null,
    deletedAt: deleted ? _day : null,
  );
}

/// One generated entry: its duration, tombstone flag, own category, and the
/// kind of linked-from entity its link points at.
class _GeneratedRecordedEntry {
  const _GeneratedRecordedEntry({
    required this.durationMinutes,
    required this.entryDeleted,
    required this.hasOwnCategory,
    required this.linkKind,
    required this.linkDeleted,
  });

  final int durationMinutes;
  final bool entryDeleted;
  final bool hasOwnCategory;
  final String linkKind;
  final bool linkDeleted;

  @override
  String toString() =>
      '_GeneratedRecordedEntry(minutes: $durationMinutes, '
      'entryDeleted: $entryDeleted, ownCategory: $hasOwnCategory, '
      'link: $linkKind, linkDeleted: $linkDeleted)';
}

extension _AnyRecordedEntry on Any {
  Generator<_GeneratedRecordedEntry> get recordedEntry => combine5(
    intInRange(0, 200),
    this.bool,
    this.bool,
    choose(const ['none', 'task', 'categorylessTask', 'rating', 'note']),
    this.bool,
    (
      int durationMinutes,
      bool entryDeleted,
      bool hasOwnCategory,
      String linkKind,
      bool linkDeleted,
    ) => _GeneratedRecordedEntry(
      durationMinutes: durationMinutes,
      entryDeleted: entryDeleted,
      hasOwnCategory: hasOwnCategory,
      linkKind: linkKind,
      linkDeleted: linkDeleted,
    ),
  );
}

void main() {
  group('resolveTimeEntries', () {
    test('pairs an entry with its linked task and derives projections', () {
      final task = _task(id: 'task-1', categoryId: 'cat-work');
      final entry = _entry(id: 'e1', startHour: 9, durationMinutes: 90);

      final resolved = resolveTimeEntries(
        entries: [entry],
        links: [_link(fromId: 'task-1', toId: 'e1')],
        linkedFromById: {'task-1': task},
      );

      final pair = resolved.single;
      expect(pair.entry.meta.id, 'e1');
      expect(pair.linkedFrom?.meta.id, 'task-1');
      expect(pair.duration, const Duration(minutes: 90));
      expect(pair.categoryId, 'cat-work');
      expect(pair.taskId, 'task-1');
      expect(pair.start, _day.add(const Duration(hours: 9)));
    });

    test('falls back to the entry category when the link has none', () {
      final task = _task(id: 'task-1');
      final entry = _entry(id: 'e1', startHour: 9, categoryId: 'cat-own');

      final pair = resolveTimeEntries(
        entries: [entry],
        links: [_link(fromId: 'task-1', toId: 'e1')],
        linkedFromById: {'task-1': task},
      ).single;

      expect(pair.categoryId, 'cat-own');
      expect(pair.taskId, 'task-1');
    });

    test('skips deleted entries, zero durations, and deleted links', () {
      final task = _task(id: 'task-1', categoryId: 'cat-work');
      final deleted = _entry(id: 'e-del', startHour: 8, deleted: true);
      final zero = _entry(id: 'e-zero', startHour: 9, durationMinutes: 0);
      final linkedViaDeletedLink = _entry(id: 'e-live', startHour: 10);

      final resolved = resolveTimeEntries(
        entries: [deleted, zero, linkedViaDeletedLink],
        links: [_link(fromId: 'task-1', toId: 'e-live', deleted: true)],
        linkedFromById: {'task-1': task},
      );

      // Only the live entry survives, and its tombstoned link contributes no
      // linked-from resolution.
      final pair = resolved.single;
      expect(pair.entry.meta.id, 'e-live');
      expect(pair.linkedFrom, isNull);
      expect(pair.taskId, isNull);
      expect(pair.categoryId, isNull);
    });

    test('a non-task linked-from yields its category but no taskId', () {
      final note = _note(id: 'note-1', categoryId: 'cat-note');
      final entry = _entry(id: 'e1', startHour: 9);

      final pair = resolveTimeEntries(
        entries: [entry],
        links: [_link(fromId: 'note-1', toId: 'e1')],
        linkedFromById: {'note-1': note},
      ).single;

      expect(pair.linkedFrom?.meta.id, 'note-1');
      expect(pair.categoryId, 'cat-note');
      expect(pair.taskId, isNull);
    });

    Glados<List<_GeneratedRecordedEntry>>(
      any.list(any.recordedEntry),
      ExploreConfig(numRuns: 140),
    ).test(
      'matches the declarative oracle for any entry/link population',
      (
        specs,
      ) {
        final entries = <JournalEntity>[];
        final links = <EntryLink>[];
        final linkedFromById = <String, JournalEntity>{};

        for (var i = 0; i < specs.length; i++) {
          final spec = specs[i];
          final entryId = 'e$i';
          entries.add(
            _entry(
              id: entryId,
              startHour: 0,
              durationMinutes: spec.durationMinutes,
              deleted: spec.entryDeleted,
              categoryId: spec.hasOwnCategory ? 'own-$i' : null,
            ),
          );
          if (spec.linkKind == 'none') continue;
          final linkedId = '${spec.linkKind}-$i';
          links.add(
            _link(fromId: linkedId, toId: entryId, deleted: spec.linkDeleted),
          );
          linkedFromById[linkedId] = switch (spec.linkKind) {
            'task' => _task(id: linkedId, categoryId: 'linked-$i'),
            'categorylessTask' => _task(id: linkedId),
            'rating' => _rating(id: linkedId),
            _ => _note(id: linkedId, categoryId: 'linked-$i'),
          };
        }

        final resolved = resolveTimeEntries(
          entries: entries,
          links: links,
          linkedFromById: linkedFromById,
        );

        // Oracle: live entries with positive duration survive, in input order.
        final surviving = <int>[
          for (var i = 0; i < specs.length; i++)
            if (!specs[i].entryDeleted && specs[i].durationMinutes > 0) i,
        ];
        expect(
          resolved.map((p) => p.entry.meta.id),
          surviving.map((i) => 'e$i'),
          reason: 'specs=$specs',
        );

        for (final pair in resolved) {
          final i = int.parse(pair.entry.meta.id.substring(1));
          final spec = specs[i];
          final reason = 'spec[$i]=$spec';
          // A live link resolves to its entity unless it is a rating.
          final effectiveKind = (spec.linkDeleted || spec.linkKind == 'rating')
              ? 'none'
              : spec.linkKind;
          switch (effectiveKind) {
            case 'none':
              expect(pair.linkedFrom, isNull, reason: reason);
              expect(pair.taskId, isNull, reason: reason);
              expect(
                pair.categoryId,
                spec.hasOwnCategory ? 'own-$i' : null,
                reason: reason,
              );
            case 'task':
              expect(pair.taskId, 'task-$i', reason: reason);
              expect(pair.categoryId, 'linked-$i', reason: reason);
            case 'categorylessTask':
              expect(pair.taskId, 'categorylessTask-$i', reason: reason);
              // Linked task carries no category → entry's own category wins.
              expect(
                pair.categoryId,
                spec.hasOwnCategory ? 'own-$i' : null,
                reason: reason,
              );
            case 'note':
              expect(pair.taskId, isNull, reason: reason);
              expect(pair.categoryId, 'linked-$i', reason: reason);
          }
          expect(
            pair.duration,
            Duration(minutes: spec.durationMinutes),
            reason: reason,
          );
        }
      },
      tags: 'glados',
    );
  });

  group('resolveLinkedFrom', () {
    test('returns null for null candidate ids', () {
      expect(
        resolveLinkedFrom(linkedFromIds: null, linkedFromById: const {}),
        isNull,
      );
    });

    Glados<List<String>>(
      any.list(
        any.choose(const [
          'task-a',
          'task-b',
          'note-a',
          'note-b',
          'rating',
          'deleted-task',
          'missing',
        ]),
      ),
      ExploreConfig(numRuns: 140),
    ).test(
      'prefers tasks, never surfaces ratings or tombstones, falls back to '
      'the first surviving non-task',
      (kinds) {
        // Two live tasks and two live notes make the FIRST-survivor
        // semantics observable: "any task" or "last non-rating" would
        // diverge from the oracle for multi-candidate inputs.
        final pool = <String, JournalEntity>{
          'task-a': _task(id: 'task-a'),
          'task-b': _task(id: 'task-b'),
          'note-a': _note(id: 'note-a'),
          'note-b': _note(id: 'note-b'),
          'rating': _rating(id: 'rating'),
          'deleted-task': _task(id: 'deleted-task', deleted: true),
        };
        final ids = <String>{...kinds};

        final result = resolveLinkedFrom(
          linkedFromIds: ids,
          linkedFromById: pool,
        );

        // Oracle: first surviving Task wins; else first non-rating survivor.
        JournalEntity? expected;
        for (final id in ids) {
          final entity = pool[id];
          if (entity == null || entity.meta.deletedAt != null) continue;
          if (entity is Task) {
            expected = entity;
            break;
          }
          if (entity is RatingEntry) continue;
          expected ??= entity;
        }

        expect(result?.meta.id, expected?.meta.id, reason: 'kinds=$kinds');
        expect(result is RatingEntry, isFalse, reason: 'kinds=$kinds');
        expect(result?.meta.deletedAt, isNull, reason: 'kinds=$kinds');
      },
      tags: 'glados',
    );
  });
}
