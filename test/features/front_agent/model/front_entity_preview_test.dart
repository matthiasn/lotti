import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';

import '../../../test_data/test_data.dart';
import '../../projects/test_utils.dart';

void main() {
  final at = DateTime(2026, 11, 9, 10);
  TaskStatus open() => TaskStatus.open(id: 's', createdAt: at, utcOffset: 0);

  group('FrontEntityReference', () {
    const reference = FrontEntityReference(
      kind: FrontEntityKind.task,
      id: 't-1',
      title: 'Check the ice-pad weather window',
    );

    test('round-trips through JSON; a shape this build does not know reads '
        'as nothing, and a list skips it', () {
      expect(FrontEntityReference.fromJson(reference.toJson()), reference);
      for (final bad in <Object?>[
        null,
        'task:t-1',
        {'kind': 'hologram', 'id': 't-1', 'title': 'x'},
        {'kind': 'task', 'id': '', 'title': 'x'},
        {'kind': 'task', 'id': 't-1'},
      ]) {
        expect(FrontEntityReference.fromJson(bad), isNull, reason: '$bad');
      }
      expect(
        FrontEntityReference.listFromJson([
          reference.toJson(),
          {'kind': 'hologram'},
        ]),
        [reference],
      );
      expect(FrontEntityReference.listFromJson('nope'), isEmpty);
    });

    test('carries a note through JSON, trimmed; a blank one is none, and '
        'it tells two references apart', () {
      const noted = FrontEntityReference(
        kind: FrontEntityKind.task,
        id: 't-1',
        title: 'Check the ice-pad weather window',
        note: '2h 10m',
      );

      expect(FrontEntityReference.fromJson(noted.toJson()), noted);
      expect(noted, isNot(reference));
      expect(reference.toJson().containsKey('note'), isFalse);
      expect(
        FrontEntityReference.fromJson({
          ...noted.toJson(),
          'note': ' 45m ',
        })!.note,
        '45m',
      );
      for (final blank in <Object?>['   ', 7]) {
        expect(
          FrontEntityReference.fromJson({...noted.toJson(), 'note': blank}),
          reference,
          reason: '$blank',
        );
      }
    });

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
      TaskPriority priority = TaskPriority.p1High,
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
      priority: priority,
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
      expect(bare.priority, TaskPriority.p2Medium);
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
      ('priority', () => preview(priority: TaskPriority.p3Low)),
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
          priority: TaskPriority.p1High,
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
          priority: TaskPriority.p1High,
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

  test('a day plan is referred to by its date, whatever its time of day', () {
    expect(frontDayPlanId(DateTime(2026, 11, 9)), '2026-11-09');
    expect(frontDayPlanId(DateTime(2026, 11, 9, 23, 59)), '2026-11-09');
  });

  group('FrontDayPlanPreview', () {
    FrontPlanBlock block(
      String title, {
      int hour = 9,
      TimeBlockState state = TimeBlockState.committed,
      String? taskId,
    }) => FrontPlanBlock(
      title: title,
      start: DateTime(2026, 11, 9, hour),
      end: DateTime(2026, 11, 9, hour + 1),
      state: state,
      taskId: taskId,
    );

    test('is a day plan preview named by its date', () {
      final preview = FrontDayPlanPreview(
        day: DateTime(2026, 11, 9),
        blocks: [block('Audit')],
      );

      expect(preview.entityKind, FrontEntityKind.dayPlan);
      expect(preview.entityId, '2026-11-09');
      expect(preview.toString(), 'FrontDayPlanPreview(2026-11-09, 1)');
    });

    test('a block differs by each of its fields', () {
      final base = block('Audit', taskId: 't');
      expect(block('Audit', taskId: 't'), base);
      expect(block('Audit', taskId: 't').hashCode, base.hashCode);
      for (final other in [
        block('Weather', taskId: 't'),
        block('Audit', hour: 10, taskId: 't'),
        FrontPlanBlock(
          title: 'Audit',
          start: DateTime(2026, 11, 9, 9),
          end: DateTime(2026, 11, 9, 11),
          state: TimeBlockState.committed,
          taskId: 't',
        ),
        block('Audit', state: TimeBlockState.completed, taskId: 't'),
        block('Audit'),
      ]) {
        expect(other, isNot(base));
      }
    });

    test('is equal, and hashes alike, exactly when its day and blocks are', () {
      FrontDayPlanPreview plan(List<FrontPlanBlock> blocks, {int day = 9}) =>
          FrontDayPlanPreview(day: DateTime(2026, 11, day), blocks: blocks);

      expect(plan([block('Audit')]), plan([block('Audit')]));
      expect(plan([block('Audit')]).hashCode, plan([block('Audit')]).hashCode);
      expect(plan([block('Audit')]), isNot(plan([block('Weather')])));
      expect(plan([block('Audit')]), isNot(plan([block('Audit')], day: 10)));
      expect(
        plan([block('Audit')]),
        isNot(plan([block('Audit'), block('Weather', hour: 11)])),
      );
    });
  });

  group('FrontProjectPreview', () {
    final census = makeTestProject(id: 'census', title: 'Colony census');

    test('is a project preview of the project it carries, with its counts', () {
      final preview = FrontProjectPreview(
        project: census,
        totalTaskCount: 8,
        completedTaskCount: 3,
      );

      expect(preview.entityKind, FrontEntityKind.project);
      expect(preview.entityId, 'census');
      expect(preview.toString(), 'FrontProjectPreview(census, 3/8)');
    });

    test('is equal, and hashes alike, exactly when project and counts are', () {
      FrontProjectPreview preview({
        ProjectEntry? project,
        int total = 8,
        int done = 3,
      }) => FrontProjectPreview(
        project: project ?? census,
        totalTaskCount: total,
        completedTaskCount: done,
      );

      expect(preview(), preview());
      expect(preview().hashCode, preview().hashCode);
      expect(
        preview(
          project: makeTestProject(id: 'census', title: 'Renamed'),
        ),
        isNot(preview()),
      );
      expect(preview(total: 9), isNot(preview()));
      expect(preview(done: 4), isNot(preview()));
    });
  });

  group('FrontPersonPreview', () {
    final call =
        JournalEntity.checkIn(
              meta: testRelationship.meta.copyWith(id: 'check-in'),
              data: CheckInData(
                relationshipId: testRelationship.meta.id,
                interactionType: CheckInInteractionType.call,
              ),
            )
            as CheckInEntry;

    test('is a person preview of the person it carries', () {
      final preview = FrontPersonPreview(person: testRelationship);

      expect(preview.entityKind, FrontEntityKind.person);
      expect(preview.entityId, testRelationship.meta.id);
      expect(preview.lastCheckIn, isNull);
      expect(
        preview.toString(),
        'FrontPersonPreview(${testRelationship.meta.id}, Anna)',
      );
    });

    test('is equal, and hashes alike, exactly when person and last check-in '
        'are', () {
      expect(
        FrontPersonPreview(person: testRelationship, lastCheckIn: call),
        FrontPersonPreview(person: testRelationship, lastCheckIn: call),
      );
      expect(
        FrontPersonPreview(
          person: testRelationship,
          lastCheckIn: call,
        ).hashCode,
        FrontPersonPreview(
          person: testRelationship,
          lastCheckIn: call,
        ).hashCode,
      );
      expect(
        FrontPersonPreview(person: testRelationship),
        isNot(FrontPersonPreview(person: testRelationship, lastCheckIn: call)),
      );
      expect(
        FrontPersonPreview(
          person: testRelationship.copyWith(
            data: testRelationship.data.copyWith(title: 'Annie'),
          ),
        ),
        isNot(FrontPersonPreview(person: testRelationship)),
      );
    });
  });
}
