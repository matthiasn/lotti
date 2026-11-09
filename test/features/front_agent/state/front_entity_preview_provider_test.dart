import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
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
    ),
  );

  late Map<String, TaskPreview?> previews;
  late List<String> taskReads;
  late MockJournalDb journalDb;
  late StreamController<Set<String>> updates;
  late ProviderContainer container;

  setUp(() {
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
