import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_merge.dart';
import 'package:lotti/classes/vector_clock.dart';

import 'task_document_fixtures.dart';

void main() {
  test(
    "a version's ref carries its id, number and creation time, what the "
    'merge orders by',
    () {
      final version = taskDocumentVersionEntry(number: 3, id: 'v3');

      expect(version.ref, taskDocumentRef(3, id: 'v3'));
    },
  );

  group('compareTaskDocumentVersionRefs -', () {
    test('no version is older than any version', () {
      expect(compareTaskDocumentVersionRefs(null, taskDocumentRef(1)), -1);
      expect(compareTaskDocumentVersionRefs(taskDocumentRef(1), null), 1);
      expect(compareTaskDocumentVersionRefs(null, null), 0);
    });

    test(
      'a higher number is newer even when it was written earlier, so a '
      'device with a skewed clock cannot roll the document back',
      () {
        expect(
          compareTaskDocumentVersionRefs(
            taskDocumentRef(4),
            taskDocumentRef(3, second: 60),
          ),
          greaterThan(0),
        );
      },
    );

    test(
      'two versions with one number, written over the same base on two '
      'devices, are ordered by when they were written, then by id',
      () {
        expect(
          compareTaskDocumentVersionRefs(
            taskDocumentRef(4, second: 2, id: 'a'),
            taskDocumentRef(4, second: 1, id: 'z'),
          ),
          greaterThan(0),
        );
        expect(
          compareTaskDocumentVersionRefs(
            taskDocumentRef(4, id: 'z'),
            taskDocumentRef(4, id: 'a'),
          ),
          greaterThan(0),
        );
      },
    );
  });

  group('mergeConcurrentTaskDocumentVersions -', () {
    test(
      'a rename on one device and a confirmed version on another both '
      'survive, in either order',
      () {
        final renamed = taskDocumentEntry(
          clock: {'a': 2},
          title: 'One-pager for the client',
          current: taskDocumentRef(3),
          editedSecond: 20,
        );
        final confirmed = taskDocumentEntry(
          clock: {'a': 1, 'b': 1},
          current: taskDocumentRef(4, second: 10),
          editedSecond: 10,
        );

        final ab = mergeConcurrentTaskDocumentVersions(renamed, confirmed);
        final ba = mergeConcurrentTaskDocumentVersions(confirmed, renamed);

        expect(ab, ba);
        expect(ab.data.title, 'One-pager for the client');
        expect(ab.data.current, taskDocumentRef(4, second: 10));
        expect(ab.meta.vectorClock, const VectorClock({'a': 2, 'b': 1}));
      },
    );

    test(
      'two versions confirmed over the same base pick the same one on every '
      'device',
      () {
        final onA = taskDocumentEntry(
          clock: {'a': 2},
          current: taskDocumentRef(4, second: 5, id: 'from-a'),
          editedSecond: 5,
        );
        final onB = taskDocumentEntry(
          clock: {'a': 1, 'b': 1},
          current: taskDocumentRef(4, second: 9, id: 'from-b'),
          editedSecond: 9,
        );

        expect(
          mergeConcurrentTaskDocumentVersions(onA, onB).data.current?.id,
          'from-b',
        );
        expect(
          mergeConcurrentTaskDocumentVersions(onB, onA).data.current?.id,
          'from-b',
        );
      },
    );

    test('a deletion on either side survives, in either order', () {
      final deleted = taskDocumentEntry(
        clock: {'a': 2},
        current: taskDocumentRef(3),
        deleted: true,
      );
      final edited = taskDocumentEntry(
        clock: {'a': 1, 'b': 1},
        current: taskDocumentRef(4),
        editedSecond: 30,
      );

      final ab = mergeConcurrentTaskDocumentVersions(deleted, edited);
      final ba = mergeConcurrentTaskDocumentVersions(edited, deleted);

      expect(ab, ba);
      expect(ab.isDeleted, isTrue);
      // The later edit still decides the rest of the row.
      expect(ab.data.current, taskDocumentRef(4));
    });

    test(
      'two edits at the same instant are broken by the clock, not by which '
      'side the device held',
      () {
        final onA = taskDocumentEntry(clock: {'a': 2}, title: 'From A');
        final onB = taskDocumentEntry(clock: {'a': 1, 'b': 1}, title: 'From B');

        final ab = mergeConcurrentTaskDocumentVersions(onA, onB);
        final ba = mergeConcurrentTaskDocumentVersions(onB, onA);

        expect(ab, ba);
        // Node `a` decides the canonical order: 2 > 1.
        expect(ab.data.title, 'From A');
      },
    );

    glados.Glados2<int, int>(
      glados.any.intInRange(0, 64),
      glados.any.intInRange(0, 64),
    ).test(
      'every device computes the same row, whichever version it held first',
      (left, right) {
        TaskDocumentEntry version(int seed, String host) => taskDocumentEntry(
          clock: {host: 1 + seed % 3},
          title: 'Title ${seed % 4}',
          current: seed % 5 == 0
              ? null
              : taskDocumentRef(
                  1 + seed % 3,
                  second: seed % 4,
                  id: 'v${seed % 6}',
                ),
          editedSecond: seed % 3,
          deleted: seed % 7 == 0,
        );
        final a = version(left, 'a');
        final b = version(right, 'b');

        final ab = mergeConcurrentTaskDocumentVersions(a, b);
        final ba = mergeConcurrentTaskDocumentVersions(b, a);

        expect(ab, ba);
        // The document never goes back to an older version.
        expect(
          compareTaskDocumentVersionRefs(ab.data.current, a.data.current),
          greaterThanOrEqualTo(0),
        );
        expect(
          compareTaskDocumentVersionRefs(ab.data.current, b.data.current),
          greaterThanOrEqualTo(0),
        );
        // A deletion on either side survives.
        expect(ab.isDeleted, a.isDeleted || b.isDeleted);
        // The clock includes both.
        expect(
          ab.meta.vectorClock,
          VectorClock.merge(a.meta.vectorClock, b.meta.vectorClock),
        );
      },
      tags: 'glados',
    );
  });

  group('mergeConcurrentTaskDocumentVersionRows -', () {
    // One confirmed proposal applied on two devices before either synced:
    // the same derived id and text, written at different times.
    final early = taskDocumentVersionEntry(
      number: 4,
      clock: {'a': 1},
      writtenSecond: 10,
    );
    final late = taskDocumentVersionEntry(
      number: 4,
      clock: {'b': 1},
      writtenSecond: 20,
    );
    const joined = VectorClock({'a': 1, 'b': 1});

    test('keeps the later write, under the join of both clocks, in either '
        'order', () {
      final merged = mergeConcurrentTaskDocumentVersionRows(early, late);

      expect(mergeConcurrentTaskDocumentVersionRows(late, early), merged);
      expect(merged.meta.updatedAt, late.meta.updatedAt);
      expect(merged.data, late.data);
      expect(merged.meta.vectorClock, joined);
    });

    test('keeps a live copy over one its device took back, even when the '
        'deletion is the later write, in either order', () {
      final takenBack = taskDocumentVersionEntry(
        number: 4,
        clock: {'b': 1},
        writtenSecond: 30,
        deleted: true,
      );

      final merged = mergeConcurrentTaskDocumentVersionRows(early, takenBack);

      expect(mergeConcurrentTaskDocumentVersionRows(takenBack, early), merged);
      expect(merged.meta.deletedAt, isNull);
      expect(merged.meta.updatedAt, early.meta.updatedAt);
      expect(merged.meta.vectorClock, joined);
    });

    test('of two writes at the same instant, picks one by clock in either '
        'order', () {
      final twin = taskDocumentVersionEntry(
        number: 4,
        clock: {'b': 1},
        writtenSecond: 10,
      );

      expect(
        mergeConcurrentTaskDocumentVersionRows(early, twin),
        mergeConcurrentTaskDocumentVersionRows(twin, early),
      );
    });
  });
}
