import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_capture_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/state/front_entity_preview_provider.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  final at = DateTime(2026, 11, 9, 10);

  /// The penguin crew's weather check, with every field its card shows.
  final iceTask = testTask.copyWith(
    meta: testTask.meta.copyWith(id: 'ice-pad', categoryId: 'launch'),
    data: testTask.data.copyWith(
      title: 'Check the ice-pad weather window',
      status: TaskStatus.inProgress(id: 's', createdAt: at, utcOffset: 0),
      due: DateTime(2026, 11, 9, 17),
      estimate: const Duration(minutes: 30),
      coverArtId: 'cover-1',
      coverArtCropX: 0.2,
      priority: TaskPriority.p1High,
    ),
  );

  late Map<String, TaskPreview?> previews;
  late List<String> taskReads;
  late MockJournalDb journalDb;
  late StreamController<Set<String>> updates;
  late ProviderContainer container;
  late Map<DateTime, DraftPlan?> plans;
  late List<DateTime> planReads;

  setUp(() {
    plans = {};
    planReads = [];
    previews = {};
    taskReads = [];
    journalDb = MockJournalDb();
    when(
      () => journalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
    updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    final notifications = MockUpdateNotifications();
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    container = ProviderContainer(
      overrides: [
        taskPreviewProvider.overrideWith((ref, id) async {
          taskReads.add(id);
          return previews[id];
        }),
        journalDbProvider.overrideWithValue(journalDb),
        updateNotificationsProvider.overrideWithValue(notifications),
        currentDraftPlanProvider.overrideWith((ref, day) async {
          planReads.add(day);
          return plans[day];
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  void stubEntity(String id, JournalEntity? entity) => when(
    () => journalDb.journalEntityById(id),
  ).thenAnswer((_) async => entity);

  Future<FrontEntityPreview?> read(FrontEntityKind kind, String id) {
    final sub = container.listen(
      frontEntityPreviewProvider((kind, id)),
      (_, _) {},
    );
    addTearDown(sub.close);
    return container.read(frontEntityPreviewProvider((kind, id)).future);
  }

  group('frontTaskPreviewOf', () {
    test('keeps the glance-level fields of the task and its one-liner', () {
      final preview = frontTaskPreviewOf(
        TaskPreview(task: iceTask, oneLiner: 'Crosswind near the limit'),
      );

      expect(
        preview,
        FrontTaskPreview(
          entityId: 'ice-pad',
          title: 'Check the ice-pad weather window',
          status: iceTask.data.status,
          oneLiner: 'Crosswind near the limit',
          due: DateTime(2026, 11, 9, 17),
          estimate: const Duration(minutes: 30),
          categoryId: 'launch',
          coverArtId: 'cover-1',
          coverArtCropX: 0.2,
          priority: TaskPriority.p1High,
        ),
      );
    });

    test('leaves out what the task does not have', () {
      final preview = frontTaskPreviewOf(TaskPreview(task: testTask));

      expect(preview.oneLiner, isNull);
      expect(preview.due, isNull);
      expect(preview.categoryId, isNull);
      expect(preview.coverArtId, isNull);
      expect(preview.coverArtCropX, 0.5);
    });
  });

  group('frontEntityPreviewProvider', () {
    test("resolves a task to its card's preview", () async {
      previews['ice-pad'] = TaskPreview(task: iceTask, oneLiner: 'Windy');

      final preview = await read(FrontEntityKind.task, 'ice-pad');

      expect(
        preview,
        isA<FrontTaskPreview>()
            .having((p) => p.entityId, 'entityId', 'ice-pad')
            .having((p) => p.oneLiner, 'oneLiner', 'Windy'),
      );
    });

    test('is null for a task that is gone', () async {
      expect(await read(FrontEntityKind.task, 'deleted'), isNull);
      expect(taskReads, ['deleted']);
    });

    test('follows the task as it changes: a status set after the turn shows '
        'on the card', () async {
      previews['ice-pad'] = TaskPreview(task: iceTask);
      final first = await read(FrontEntityKind.task, 'ice-pad');
      expect((first! as FrontTaskPreview).settled, isFalse);

      previews['ice-pad'] = TaskPreview(
        task: iceTask.copyWith(
          data: iceTask.data.copyWith(
            status: TaskStatus.done(id: 's2', createdAt: at, utcOffset: 0),
          ),
        ),
      );
      container.invalidate(taskPreviewProvider('ice-pad'));
      final again = await container.read(
        frontEntityPreviewProvider((
          FrontEntityKind.task,
          'ice-pad',
        )).future,
      );

      expect((again! as FrontTaskPreview).settled, isTrue);
    });

    test('a task reference reads no event', () async {
      await read(FrontEntityKind.task, 'ice-pad');

      verifyNever(() => journalDb.journalEntityById(any()));
    });

    test(
      'a project has no preview of its own yet, and reads nothing',
      () async {
        expect(await read(FrontEntityKind.project, 'p-1'), isNull);
        expect(taskReads, isEmpty);
        expect(planReads, isEmpty);
        verifyNever(() => journalDb.journalEntityById(any()));
      },
    );

    group("a day's plan", () {
      final day = DateTime(2026, 11, 9);
      const launch = DayAgentCategory(
        id: 'launch',
        name: 'Launch Ops',
        colorHex: '3B82F6',
      );

      TimeBlock block(
        String title,
        int hour, {
        TimeBlockType type = TimeBlockType.ai,
        TimeBlockState state = TimeBlockState.committed,
        String? taskId,
      }) => TimeBlock(
        id: title,
        title: title,
        start: DateTime(2026, 11, 9, hour),
        end: DateTime(2026, 11, 9, hour + 1),
        type: type,
        state: state,
        category: launch,
        taskId: taskId,
      );

      DraftPlan plan(List<TimeBlock> blocks) => DraftPlan(
        dayDate: day,
        blocks: blocks,
        bands: const <EnergyBand>[],
        capacityMinutes: 480,
        scheduledMinutes: 0,
      );

      test('is its blocks in the order they run — not the buffers between, '
          'nor what was dropped — each with its task', () async {
        plans[day] = plan([
          block('Audit', 14, taskId: 'cold-chain'),
          block('Walk', 12, type: TimeBlockType.buffer),
          block('Weather check', 9, state: TimeBlockState.completed),
          block('Old idea', 16, state: TimeBlockState.dropped),
          block('Standup', 10, type: TimeBlockType.cal),
        ]);

        final preview =
            await read(FrontEntityKind.dayPlan, '2026-11-09')
                as FrontDayPlanPreview?;

        expect(planReads, [day]);
        expect(preview?.day, day);
        expect(preview?.blocks, [
          FrontPlanBlock(
            title: 'Weather check',
            start: DateTime(2026, 11, 9, 9),
            end: DateTime(2026, 11, 9, 10),
            state: TimeBlockState.completed,
          ),
          FrontPlanBlock(
            title: 'Standup',
            start: DateTime(2026, 11, 9, 10),
            end: DateTime(2026, 11, 9, 11),
            state: TimeBlockState.committed,
          ),
          FrontPlanBlock(
            title: 'Audit',
            start: DateTime(2026, 11, 9, 14),
            end: DateTime(2026, 11, 9, 15),
            state: TimeBlockState.committed,
            taskId: 'cold-chain',
          ),
        ]);
      });

      test('is null for a day with no plan, or none but buffers and dropped '
          'blocks, and for a date it cannot read', () async {
        expect(await read(FrontEntityKind.dayPlan, '2026-11-09'), isNull);

        plans[day] = plan([
          block('Walk', 12, type: TimeBlockType.buffer),
          block('Old idea', 16, state: TimeBlockState.dropped),
        ]);
        container.invalidate(currentDraftPlanProvider(day));
        expect(
          await container.read(
            frontEntityPreviewProvider((
              FrontEntityKind.dayPlan,
              '2026-11-09',
            )).future,
          ),
          isNull,
        );

        planReads.clear();
        expect(await read(FrontEntityKind.dayPlan, 'someday'), isNull);
        expect(planReads, isEmpty);
      });

      test('follows the plan as it changes', () async {
        plans[day] = plan([block('Audit', 14)]);
        final first =
            await read(FrontEntityKind.dayPlan, '2026-11-09')
                as FrontDayPlanPreview?;
        expect(first?.blocks.single.title, 'Audit');

        plans[day] = plan([block('Audit, moved', 15)]);
        container.invalidate(currentDraftPlanProvider(day));
        final again =
            await container.read(
                  frontEntityPreviewProvider((
                    FrontEntityKind.dayPlan,
                    '2026-11-09',
                  )).future,
                )
                as FrontDayPlanPreview?;

        expect(again?.blocks.single.title, 'Audit, moved');
      });
    });

    group('an event', () {
      final eventId = testRehearsalEvent.meta.id;

      test('resolves to the event as stored, and reads no task', () async {
        stubEntity(eventId, testRehearsalEvent);

        expect(
          await read(FrontEntityKind.event, eventId),
          FrontEventPreview(testRehearsalEvent),
        );
        expect(taskReads, isEmpty);
      });

      test('is null once gone, deleted, or not an event at all', () async {
        expect(await read(FrontEntityKind.event, 'gone'), isNull);

        stubEntity(
          'deleted',
          testRehearsalEvent.copyWith(
            meta: testRehearsalEvent.meta.copyWith(
              id: 'deleted',
              deletedAt: DateTime(2026, 11, 10),
            ),
          ),
        );
        expect(await read(FrontEntityKind.event, 'deleted'), isNull);

        stubEntity(testTask.meta.id, testTask);
        expect(await read(FrontEntityKind.event, testTask.meta.id), isNull);
      });

      test('follows the event as it changes: a notification naming it reads '
          'it again', () async {
        stubEntity(eventId, testRehearsalEvent);
        expect(
          await read(FrontEntityKind.event, eventId),
          FrontEventPreview(testRehearsalEvent),
        );

        final rated = testRehearsalEvent.copyWith(
          data: testRehearsalEvent.data.copyWith(stars: 4),
        );
        stubEntity(eventId, rated);
        updates.add({'another-entry'});
        await pumpEventQueue();
        expect(
          container
              .read(
                frontEntityPreviewProvider((FrontEntityKind.event, eventId)),
              )
              .value,
          FrontEventPreview(testRehearsalEvent),
        );

        updates.add({eventId});
        await pumpEventQueue();
        expect(
          await container.read(
            frontEntityPreviewProvider((FrontEntityKind.event, eventId)).future,
          ),
          FrontEventPreview(rated),
        );
      });
    });
  });
}
