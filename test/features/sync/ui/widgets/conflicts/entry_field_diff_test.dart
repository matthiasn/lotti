import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show Glados, Glados2, StringAnys, any;
import 'package:lotti/classes/journal_entities.dart';
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
        expect(diff.isIdentical, isTrue);
        expect(diff.fields, isEmpty);
        expect(diff.hasOtherDifferences, isFalse);
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
      expect(diff.hasOtherDifferences, isFalse);
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
      expect(diff.hasOtherDifferences, isFalse);
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
      expect(diff.hasOtherDifferences, isFalse);
    });
  });

  group('computeEntryDiff — completeness guard', () {
    test('an unmodelled field change surfaces as EntryField.other', () {
      final diff = computeEntryDiff(
        taskOf(estimate: const Duration(hours: 4)),
        taskOf(estimate: const Duration(hours: 5)),
      );
      expect(diff.shape, ConflictShape.edited);
      expect(diff.fields.map((f) => f.field), [EntryField.other]);
      expect(diff.hasOtherDifferences, isTrue);
    });

    test('other is appended after modelled fields', () {
      final diff = computeEntryDiff(
        taskOf(title: 'My task', estimate: const Duration(hours: 4)),
        taskOf(title: 'Renamed', estimate: const Duration(hours: 5)),
      );
      expect(
        diff.fields.map((f) => f.field),
        [EntryField.title, EntryField.other],
      );
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
  });

  group('properties', () {
    Glados<String>(any.letterOrDigits).test(
      'identical content always resolves to an identical diff',
      (text) {
        final diff = computeEntryDiff(
          entryOf(text: text, vectorClock: const VectorClock({'a': 1})),
          entryOf(text: text, vectorClock: const VectorClock({'b': 9})),
        );
        expect(diff.isIdentical, isTrue);
        expect(diff.fields, isEmpty);
        expect(diff.hasOtherDifferences, isFalse);
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
