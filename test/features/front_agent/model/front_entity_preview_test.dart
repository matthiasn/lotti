import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';

import '../../../test_data/test_data.dart';

void main() {
  final at = DateTime(2026, 11, 9, 10);
  TaskStatus open() => TaskStatus.open(id: 's', createdAt: at, utcOffset: 0);

  group('FrontEntityReference', () {
    const reference = FrontEntityReference(
      kind: FrontEntityKind.task,
      id: 't-1',
      title: 'Check the ice-pad weather window',
    );

    test('is equal, and hashes alike, only with the same kind, id and '
        'title', () {
      // Not const: a canonical constant would be the very same instance.
      // ignore: prefer_const_constructors
      final same = FrontEntityReference(
        kind: FrontEntityKind.task,
        id: 't-1',
        title: 'Check the ice-pad weather window',
      );

      expect(same, reference);
      expect(same.hashCode, reference.hashCode);
      expect({
        reference,
        same,
        const FrontEntityReference(
          kind: FrontEntityKind.event,
          id: 't-1',
          title: 'Check the ice-pad weather window',
        ),
        const FrontEntityReference(
          kind: FrontEntityKind.task,
          id: 't-2',
          title: 'Check the ice-pad weather window',
        ),
        const FrontEntityReference(
          kind: FrontEntityKind.task,
          id: 't-1',
          title: 'Another title',
        ),
      }, hasLength(4));
    });

    test('names its kind, its id and title', () {
      expect(
        reference.toString(),
        'FrontEntityReference(task, t-1, Check the ice-pad weather window)',
      );
    });
  });

  group('FrontTaskPreview', () {
    FrontTaskPreview preview({
      TaskStatus? status,
      String? oneLiner = 'Crosswind near the limit',
      DateTime? due,
      Duration? estimate = const Duration(minutes: 30),
      String? categoryId = 'launch',
      String? coverArtId = 'cover-1',
      double coverArtCropX = 0.3,
    }) => FrontTaskPreview(
      entityId: 't-1',
      title: 'Check the ice-pad weather window',
      status: status ?? open(),
      oneLiner: oneLiner,
      due: due ?? DateTime(2026, 11, 9, 17),
      estimate: estimate,
      categoryId: categoryId,
      coverArtId: coverArtId,
      coverArtCropX: coverArtCropX,
    );

    test('is a task preview, whatever else it carries', () {
      final task = preview();

      expect(task.entityKind, FrontEntityKind.task);
      expect(task.entityId, 't-1');
    });

    test('defaults to no optional field and a centred cover crop', () {
      final bare = FrontTaskPreview(
        entityId: 't-1',
        title: 'T',
        status: open(),
      );

      expect(bare.oneLiner, isNull);
      expect(bare.due, isNull);
      expect(bare.estimate, isNull);
      expect(bare.categoryId, isNull);
      expect(bare.coverArtId, isNull);
      expect(bare.coverArtCropX, 0.5);
    });

    for (final (name, status, settled) in [
      ('open', open(), false),
      (
        'in progress',
        TaskStatus.inProgress(id: 's', createdAt: at, utcOffset: 0),
        false,
      ),
      (
        'blocked',
        TaskStatus.blocked(id: 's', createdAt: at, utcOffset: 0, reason: 'r'),
        false,
      ),
      ('done', TaskStatus.done(id: 's', createdAt: at, utcOffset: 0), true),
      (
        'rejected',
        TaskStatus.rejected(id: 's', createdAt: at, utcOffset: 0),
        true,
      ),
    ]) {
      test('a $name task is ${settled ? '' : 'not '}settled', () {
        expect(preview(status: status).settled, settled);
      });
    }

    test('equal previews hash alike', () {
      expect(preview(), preview());
      expect(preview().hashCode, preview().hashCode);
    });

    // Each field on its own makes a different preview: a card that kept an
    // old one would show a stale field.
    for (final (field, changed) in <(String, FrontTaskPreview Function())>[
      (
        'status',
        () => preview(
          status: TaskStatus.done(id: 's', createdAt: at, utcOffset: 0),
        ),
      ),
      ('one-liner', () => preview(oneLiner: 'Calm all week')),
      ('due date', () => preview(due: DateTime(2026, 11, 10))),
      ('estimate', () => preview(estimate: const Duration(hours: 1))),
      ('category', () => preview(categoryId: 'colony')),
      ('cover', () => preview(coverArtId: 'cover-2')),
      ('cover crop', () => preview(coverArtCropX: 0.8)),
      (
        'title',
        () => FrontTaskPreview(
          entityId: 't-1',
          title: 'Renamed',
          status: open(),
          oneLiner: 'Crosswind near the limit',
          due: DateTime(2026, 11, 9, 17),
          estimate: const Duration(minutes: 30),
          categoryId: 'launch',
          coverArtId: 'cover-1',
          coverArtCropX: 0.3,
        ),
      ),
      (
        'id',
        () => FrontTaskPreview(
          entityId: 't-2',
          title: 'Check the ice-pad weather window',
          status: open(),
          oneLiner: 'Crosswind near the limit',
          due: DateTime(2026, 11, 9, 17),
          estimate: const Duration(minutes: 30),
          categoryId: 'launch',
          coverArtId: 'cover-1',
          coverArtCropX: 0.3,
        ),
      ),
    ]) {
      test('differs by its $field', () {
        expect(changed(), isNot(preview()));
      });
    }

    test('is not equal to something that is not a task preview', () {
      const Object reference = FrontEntityReference(
        kind: FrontEntityKind.task,
        id: 't-1',
        title: 'Check the ice-pad weather window',
      );

      expect(preview() == reference, isFalse);
    });

    test('names its id and title', () {
      expect(
        preview().toString(),
        'FrontTaskPreview(t-1, Check the ice-pad weather window)',
      );
    });
  });

  group('FrontEventPreview', () {
    test('is an event preview of the event it carries', () {
      final preview = FrontEventPreview(testRehearsalEvent);

      expect(preview.entityKind, FrontEntityKind.event);
      expect(preview.entityId, testRehearsalEvent.meta.id);
      expect(preview.event, testRehearsalEvent);
    });

    test('is equal, and hashes alike, exactly when its event is', () {
      final renamed = testRehearsalEvent.copyWith(
        data: testRehearsalEvent.data.copyWith(title: 'Rehearsal, moved'),
      );

      expect(
        FrontEventPreview(testRehearsalEvent),
        FrontEventPreview(testRehearsalEvent),
      );
      expect(
        FrontEventPreview(testRehearsalEvent).hashCode,
        FrontEventPreview(testRehearsalEvent).hashCode,
      );
      expect(
        FrontEventPreview(renamed),
        isNot(FrontEventPreview(testRehearsalEvent)),
      );
    });

    test('names its id and title', () {
      expect(
        FrontEventPreview(testRehearsalEvent).toString(),
        'FrontEventPreview(${testRehearsalEvent.meta.id}, '
        'Launch-day rehearsal at the ice pad)',
      );
    });
  });
}
