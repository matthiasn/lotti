import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show Glados, Glados2, StringAnys, any;
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'conflict_test_entities.dart';

FieldDiff _fieldFor(EntryDiff diff, EntryField field) =>
    diff.fields.firstWhere((f) => f.field == field);

void main() {
  group('computeEntryDiff — shape', () {
    test(
      'identical content is identical despite differing clock/updatedAt',
      () {
        final diff = computeEntryDiff(
          entryOf(
            vectorClock: const VectorClock({'a': 1}),
            updatedAt: DateTime(2024, 3, 15, 10),
          ),
          entryOf(
            vectorClock: const VectorClock({'b': 2}),
            updatedAt: DateTime(2024, 3, 15, 12),
          ),
        );

        expect(diff.shape, ConflictShape.identical);
        expect(diff.fields, isEmpty);
        // body + dateFrom + dateTo present and equal on both sides.
        expect(diff.identicalFieldCount, 3);
      },
    );

    test('different entity types are reported as typeChanged', () {
      final diff = computeEntryDiff(entryOf(), taskOf());
      expect(diff.shape, ConflictShape.typeChanged);
      expect(diff.fields, isEmpty);
      expect(diff.identicalFieldCount, 0);
    });

    test('soft-delete on the remote side is classified, not diffed', () {
      final diff = computeEntryDiff(
        entryOf(text: 'hello'),
        entryOf(text: 'hello', deletedAt: DateTime(2024, 3, 15, 13)),
      );
      expect(diff.shape, ConflictShape.deletedOnRemote);
      expect(diff.fields, isEmpty);
    });

    test("a purge's tombstone against an edit of another type is a "
        'deletion, not a type change (ADR 0095)', () {
      final deletedAt = DateTime(2024, 3, 15, 13);
      final tombstone = taskOf()
          .copyWith(meta: taskOf().meta.copyWith(deletedAt: deletedAt))
          .toPurgedTombstone(DateTime(2024, 3, 16));

      final local = computeEntryDiff(tombstone, taskOf());
      final remote = computeEntryDiff(taskOf(), tombstone);

      expect(tombstone, isA<JournalEntry>());
      expect(local.shape, ConflictShape.deletedOnLocal);
      expect(local.fields, isEmpty);
      expect(remote.shape, ConflictShape.deletedOnRemote);
      expect(remote.fields, isEmpty);
    });

    test('two tombstones of one entry are not a type change either', () {
      final tombstone = entryOf(
        deletedAt: DateTime(2024, 3, 15, 13),
      ).toPurgedTombstone(DateTime(2024, 3, 16));

      final diff = computeEntryDiff(tombstone, tombstone);

      expect(diff.shape, ConflictShape.identical);
    });

    test('soft-delete on the local side is classified, not diffed', () {
      final diff = computeEntryDiff(
        entryOf(text: 'hello', deletedAt: DateTime(2024, 3, 15, 13)),
        entryOf(text: 'hello'),
      );
      expect(diff.shape, ConflictShape.deletedOnLocal);
      expect(diff.fields, isEmpty);
    });
  });

  group('computeEntryDiff — text fields', () {
    test('body change yields a changed field with a word diff', () {
      final diff = computeEntryDiff(
        entryOf(text: 'hello world'),
        entryOf(text: 'hello brave world'),
      );

      expect(diff.shape, ConflictShape.edited);
      expect(diff.fields.map((f) => f.field), [EntryField.body]);
      final body = _fieldFor(diff, EntryField.body);
      expect(body.kind, FieldDiffKind.changed);
      expect(body.localValue, 'hello world');
      expect(body.remoteValue, 'hello brave world');
      expect(body.wordDiff, isNotNull);
      // dateFrom + dateTo match.
      expect(diff.identicalFieldCount, 2);
    });

    test('body present on one side only is onlyLocal with no word diff', () {
      final diff = computeEntryDiff(entryOf(text: 'hello'), entryOf(text: ''));
      final body = _fieldFor(diff, EntryField.body);
      expect(body.kind, FieldDiffKind.onlyLocal);
      expect(body.localValue, 'hello');
      expect(body.remoteValue, isNull);
      expect(body.wordDiff, isNull);
    });

    test('task title is diffed from structured data, not the body', () {
      final diff = computeEntryDiff(
        taskOf(title: 'My task'),
        taskOf(title: 'My new task'),
      );
      expect(diff.fields.map((f) => f.field), [EntryField.title]);
      final title = _fieldFor(diff, EntryField.title);
      expect(title.kind, FieldDiffKind.changed);
      expect(title.localValue, 'My task');
      expect(title.remoteValue, 'My new task');
      expect(title.wordDiff, isNotNull);
    });
  });

  group('computeEntryDiff — scalar fields', () {
    test('category added on the remote side', () {
      final diff = computeEntryDiff(entryOf(), entryOf(categoryId: 'cat-1'));
      final field = _fieldFor(diff, EntryField.category);
      expect(field.kind, FieldDiffKind.onlyRemote);
      expect(field.localValue, isNull);
      expect(field.remoteValue, 'cat-1');
    });

    test('null vs empty string is not reported as a change', () {
      final diff = computeEntryDiff(entryOf(), entryOf(categoryId: ''));
      expect(
        diff.fields.where((f) => f.field == EntryField.category),
        isEmpty,
      );
    });

    test('category changed between two values', () {
      final diff = computeEntryDiff(
        entryOf(categoryId: 'cat-a'),
        entryOf(categoryId: 'cat-b'),
      );
      final field = _fieldFor(diff, EntryField.category);
      expect(field.kind, FieldDiffKind.changed);
      expect(field.localValue, 'cat-a');
      expect(field.remoteValue, 'cat-b');
    });

    test('starred toggled', () {
      final diff = computeEntryDiff(
        entryOf(starred: true),
        entryOf(starred: false),
      );
      final field = _fieldFor(diff, EntryField.starred);
      expect(field.localValue, 'true');
      expect(field.remoteValue, 'false');
    });

    test('private toggled', () {
      final diff = computeEntryDiff(
        entryOf(private: false),
        entryOf(private: true),
      );
      final field = _fieldFor(diff, EntryField.private);
      expect(field.localValue, 'false');
      expect(field.remoteValue, 'true');
    });

    test('flag changed', () {
      final diff = computeEntryDiff(
        entryOf(flag: EntryFlag.none),
        entryOf(flag: EntryFlag.followUpNeeded),
      );
      final field = _fieldFor(diff, EntryField.flag);
      expect(field.localValue, 'none');
      expect(field.remoteValue, 'followUpNeeded');
    });

    test('dateFrom changed', () {
      final diff = computeEntryDiff(
        entryOf(dateFrom: DateTime(2024, 3, 15, 9)),
        entryOf(dateFrom: DateTime(2024, 3, 16, 9)),
      );
      final field = _fieldFor(diff, EntryField.dateFrom);
      expect(field.kind, FieldDiffKind.changed);
      expect(field.localValue, isNot(field.remoteValue));
    });

    test('dateTo changed', () {
      final diff = computeEntryDiff(
        entryOf(dateTo: DateTime(2024, 3, 15, 11)),
        entryOf(dateTo: DateTime(2024, 3, 15, 18)),
      );
      expect(_fieldFor(diff, EntryField.dateTo).kind, FieldDiffKind.changed);
    });

    test('audio duration changed is formatted for display', () {
      final diff = computeEntryDiff(
        audioOf(duration: const Duration(seconds: 60)),
        audioOf(duration: const Duration(seconds: 90)),
      );
      final field = _fieldFor(diff, EntryField.audioDuration);
      expect(field.localValue, '1:00');
      expect(field.remoteValue, '1:30');
    });
  });

  group('computeEntryDiff — completeness guard', () {
    test('an unmodelled field change surfaces as EntryField.other', () {
      final diff = computeEntryDiff(
        taskOf(languageCode: 'de'),
        taskOf(languageCode: 'fr'),
      );
      expect(diff.shape, ConflictShape.edited);
      expect(diff.fields.map((f) => f.field), [EntryField.other]);
    });

    test('other is appended after modelled fields', () {
      final diff = computeEntryDiff(
        taskOf(title: 'My task', languageCode: 'de'),
        taskOf(title: 'Renamed', languageCode: 'fr'),
      );
      expect(
        diff.fields.map((f) => f.field),
        [EntryField.title, EntryField.other],
      );
    });
  });

  group("computeEntryDiff — a task's fields (ADR 0107)", () {
    TaskStatus blocked(String reason) => TaskStatus.blocked(
      id: 'st-b',
      createdAt: DateTime(2024, 3, 15, 10),
      utcOffset: 0,
      reason: reason,
    );

    test('status, priority, estimate and due date are each shown, with '
        'their raw values, and nothing is left to other', () {
      final diff = computeEntryDiff(
        taskOf(
          estimate: const Duration(minutes: 30),
          priority: TaskPriority.p1High,
          due: DateTime(2024, 4),
        ),
        taskOf(
          status: TaskStatus.done(
            id: 'st-d',
            createdAt: DateTime(2024, 3, 15, 10),
            utcOffset: 0,
          ),
          estimate: const Duration(hours: 2),
          priority: TaskPriority.p3Low,
          due: DateTime(2024, 5),
        ),
      );

      expect(diff.shape, ConflictShape.edited);
      expect(
        {for (final f in diff.fields) f.field: (f.localValue, f.remoteValue)},
        {
          EntryField.status: ('OPEN', 'DONE'),
          EntryField.priority: ('P1', 'P3'),
          EntryField.estimate: ('30', '120'),
          EntryField.dueDate: (
            DateTime(2024, 4).toIso8601String(),
            DateTime(2024, 5).toIso8601String(),
          ),
        },
      );
    });

    test('two reasons behind the same status are a difference to show', () {
      final diff = computeEntryDiff(
        taskOf(status: blocked('waiting on design')),
        taskOf(status: blocked('waiting on review')),
      );

      expect(diff.fields.single.field, EntryField.status);
      expect(diff.fields.single.localValue, 'BLOCKED: waiting on design');
      expect(diff.fields.single.remoteValue, 'BLOCKED: waiting on review');
    });

    test('a due date set on one side only is onlyLocal / onlyRemote', () {
      final diff = computeEntryDiff(
        taskOf(due: DateTime(2024, 4)),
        taskOf(),
      );

      expect(diff.fields.single.field, EntryField.dueDate);
      expect(diff.fields.single.kind, FieldDiffKind.onlyLocal);
    });

    test('a difference only in what the resolution joins — the status '
        'history, the applied changes — is not reported at all', () {
      final open = TaskStatus.open(
        id: 'st-1',
        createdAt: DateTime(2024, 3, 15, 9),
        utcOffset: 0,
      );
      final diff = computeEntryDiff(
        taskOf(
          status: open,
          statusHistory: [open],
          appliedChangeEffects: {'a'},
        ),
        taskOf(status: open, appliedChangeEffects: {'b'}),
      );

      expect(diff.shape, ConflictShape.identical);
      expect(diff.fields, isEmpty);
    });

    test("an event's status is not a task field: it stays in other", () {
      JournalEntity event(EventStatus status) => JournalEvent(
        meta: metaOf(id: 'ev'),
        data: EventData(title: 'Launch', stars: 0.5, status: status),
      );

      final diff = computeEntryDiff(
        event(EventStatus.planned),
        event(EventStatus.completed),
      );

      expect(diff.fields.map((f) => f.field), [EntryField.other]);
    });
  });

  group('value equality', () {
    test('equal diffs are equal including word diffs', () {
      final a = computeEntryDiff(
        entryOf(text: 'hello world'),
        entryOf(text: 'hello brave world'),
      );
      final b = computeEntryDiff(
        entryOf(text: 'hello world'),
        entryOf(text: 'hello brave world'),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('diffs over different content are unequal', () {
      final a = computeEntryDiff(entryOf(text: 'a'), entryOf(text: 'b'));
      final b = computeEntryDiff(entryOf(text: 'a'), entryOf(text: 'c'));
      expect(a == b, isFalse);
    });

    test('FieldDiff.toString surfaces field, kind and both values', () {
      final field = _fieldFor(
        computeEntryDiff(entryOf(categoryId: 'cat-a'), entryOf()),
        EntryField.category,
      );
      expect(
        field.toString(),
        'FieldDiff(category, onlyLocal, local: cat-a, remote: null)',
      );
    });
  });

  group('properties', () {
    Glados<String>(any.letterOrDigits).test(
      'identical content always resolves to an identical diff',
      (text) {
        final diff = computeEntryDiff(
          entryOf(text: text, vectorClock: const VectorClock({'a': 1})),
          entryOf(text: text, vectorClock: const VectorClock({'b': 9})),
        );
        expect(diff.shape, ConflictShape.identical);
        expect(diff.fields, isEmpty);
      },
      tags: 'glados',
    );

    Glados2<String, String>(any.letterOrDigits, any.letterOrDigits).test(
      'the diff is symmetric under swapping the two sides',
      (t1, t2) {
        final ab = computeEntryDiff(entryOf(text: t1), entryOf(text: t2));
        final ba = computeEntryDiff(entryOf(text: t2), entryOf(text: t1));

        expect(
          ab.fields.map((f) => f.field).toSet(),
          ba.fields.map((f) => f.field).toSet(),
        );

        if (ab.fields.any((f) => f.field == EntryField.body)) {
          final f1 = _fieldFor(ab, EntryField.body);
          final f2 = _fieldFor(ba, EntryField.body);
          expect(f1.localValue, f2.remoteValue);
          expect(f1.remoteValue, f2.localValue);
        }
      },
      tags: 'glados',
    );
  });
}
