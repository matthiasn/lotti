import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late MockUpdateNotifications mockNotifications;
  late StreamController<Set<String>> updateStreamController;
  late ProviderContainer container;

  Metadata meta(String id) => Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
  );

  RelationshipEntry relationship(String id, {String title = 'Anna'}) =>
      RelationshipEntry(
        meta: meta(id),
        data: RelationshipData(
          title: title,
          status: RelationshipStatus.active(
            id: 'status-$id',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

  RelationshipListItem item(String id, {DateTime? lastCheckInAt}) => (
    relationship: relationship(id),
    lastCheckInAt: lastCheckInAt,
  );

  CheckInEntry checkIn(String id, String relationshipId) => CheckInEntry(
    meta: meta(id),
    data: CheckInData(
      relationshipId: relationshipId,
      interactionType: CheckInInteractionType.call,
    ),
  );

  Task task(String id) =>
      JournalEntity.task(
            meta: meta(id),
            data: TaskData(
              status: TaskStatus.open(
                id: 'ts-$id',
                createdAt: testDate,
                utcOffset: 0,
              ),
              dateFrom: testDate,
              dateTo: testDate,
              statusHistory: const [],
              title: 'Task $id',
            ),
          )
          as Task;

  setUp(() {
    mockRepository = MockRelationshipRepository();
    mockNotifications = MockUpdateNotifications();
    updateStreamController = StreamController<Set<String>>.broadcast();
    when(
      () => mockNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);
    getIt.registerSingleton<UpdateNotifications>(mockNotifications);
    container = ProviderContainer(
      overrides: [
        relationshipRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await updateStreamController.close();
    await getIt.unregister<UpdateNotifications>();
  });

  group('relationshipsListControllerProvider', () {
    test('loads relationships from the repository', () async {
      when(() => mockRepository.getRelationshipsByRecency()).thenAnswer(
        (_) async => [item('rel-1', lastCheckInAt: testDate), item('rel-2')],
      );

      final result = await container.read(
        relationshipsListControllerProvider.future,
      );

      expect(result.map((i) => i.relationship.id), ['rel-1', 'rel-2']);
      expect(result.first.lastCheckInAt, testDate);
      expect(result.last.lastCheckInAt, isNull);
    });

    test('refetches when a relationship notification arrives', () async {
      var calls = 0;
      when(() => mockRepository.getRelationshipsByRecency()).thenAnswer((
        _,
      ) async {
        calls++;
        return calls == 1 ? [item('rel-1')] : [item('rel-1'), item('rel-2')];
      });

      // Keep the provider alive across the invalidation.
      final subscription = container.listen(
        relationshipsListControllerProvider,
        (_, _) {},
      );

      expect(
        (await container.read(
          relationshipsListControllerProvider.future,
        )).length,
        1,
      );

      updateStreamController.add({relationshipNotification});
      await pumpEventQueue();

      expect(
        (await container.read(
          relationshipsListControllerProvider.future,
        )).length,
        2,
      );
      expect(calls, 2);
      subscription.close();
    });

    test('refetches when a check-in notification arrives', () async {
      var calls = 0;
      when(() => mockRepository.getRelationshipsByRecency()).thenAnswer((
        _,
      ) async {
        calls++;
        return [item('rel-1')];
      });

      final subscription = container.listen(
        relationshipsListControllerProvider,
        (_, _) {},
      );
      await container.read(relationshipsListControllerProvider.future);

      updateStreamController.add({checkInNotification});
      await pumpEventQueue();
      await container.read(relationshipsListControllerProvider.future);

      expect(calls, 2);
      subscription.close();
    });

    test('ignores unrelated notifications', () async {
      var calls = 0;
      when(() => mockRepository.getRelationshipsByRecency()).thenAnswer((
        _,
      ) async {
        calls++;
        return [item('rel-1')];
      });

      final subscription = container.listen(
        relationshipsListControllerProvider,
        (_, _) {},
      );
      await container.read(relationshipsListControllerProvider.future);

      updateStreamController.add({'TASK'});
      await pumpEventQueue();
      await container.read(relationshipsListControllerProvider.future);

      expect(calls, 1);
      subscription.close();
    });
  });

  group('relationshipDetailControllerProvider', () {
    test(
      'resolves the relationship with its check-ins and linked tasks',
      () async {
        when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
          (_) async => relationship('rel-1'),
        );
        when(
          () => mockRepository.getCheckInsForRelationship('rel-1'),
        ).thenAnswer(
          (_) async => [checkIn('check-1', 'rel-1')],
        );
        when(() => mockRepository.getLinkedTasks('rel-1')).thenAnswer(
          (_) async => [task('task-1')],
        );

        final detail = await container.read(
          relationshipDetailControllerProvider('rel-1').future,
        );

        expect(detail, isNotNull);
        expect(detail!.relationship.id, 'rel-1');
        expect(detail.checkIns.map((c) => c.id), ['check-1']);
        expect(detail.linkedTasks.map((t) => t.id), ['task-1']);
      },
    );

    test('resolves null when the relationship does not exist', () async {
      when(() => mockRepository.getRelationshipById('rel-404')).thenAnswer(
        (_) async => null,
      );

      final detail = await container.read(
        relationshipDetailControllerProvider('rel-404').future,
      );

      expect(detail, isNull);
      verifyNever(() => mockRepository.getCheckInsForRelationship(any()));
    });

    test('refetches when the relationship id appears in a notification — '
        'the denormalized check-in wake token', () async {
      var calls = 0;
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer((
        _,
      ) async {
        calls++;
        return relationship('rel-1');
      });
      when(() => mockRepository.getCheckInsForRelationship('rel-1')).thenAnswer(
        (_) async => [],
      );
      when(() => mockRepository.getLinkedTasks('rel-1')).thenAnswer(
        (_) async => [],
      );

      final subscription = container.listen(
        relationshipDetailControllerProvider('rel-1'),
        (_, _) {},
      );
      await container.read(
        relationshipDetailControllerProvider('rel-1').future,
      );

      // A saved check-in notifies its relationship id via affectedIds.
      updateStreamController.add({'rel-1', checkInNotification});
      await pumpEventQueue();
      await container.read(
        relationshipDetailControllerProvider('rel-1').future,
      );

      expect(calls, 2);
      subscription.close();
    });

    test('refetches when a currently linked task changes', () async {
      var calls = 0;
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer((
        _,
      ) async {
        calls++;
        return relationship('rel-1');
      });
      when(() => mockRepository.getCheckInsForRelationship('rel-1')).thenAnswer(
        (_) async => [],
      );
      when(() => mockRepository.getLinkedTasks('rel-1')).thenAnswer(
        (_) async => [task('task-9')],
      );

      final subscription = container.listen(
        relationshipDetailControllerProvider('rel-1'),
        (_, _) {},
      );
      await container.read(
        relationshipDetailControllerProvider('rel-1').future,
      );

      // A status edit on the task side notifies the task's own id.
      updateStreamController.add({'task-9'});
      await pumpEventQueue();
      await container.read(
        relationshipDetailControllerProvider('rel-1').future,
      );

      expect(calls, 2);
      subscription.close();
    });

    test(
      'refetches on a relationship edit, local or synced — every entity write '
      'emits its own id, so no feature-specific token is needed',
      () async {
        var calls = 0;
        when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer((
          _,
        ) async {
          calls++;
          return relationship('rel-1');
        });
        when(
          () => mockRepository.getCheckInsForRelationship('rel-1'),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepository.getLinkedTasks('rel-1'),
        ).thenAnswer((_) async => []);

        final subscription = container.listen(
          relationshipDetailControllerProvider('rel-1'),
          (_, _) {},
        );
        await container.read(
          relationshipDetailControllerProvider('rel-1').future,
        );

        // Exactly what updateDbEntity emits for a RelationshipEntry write.
        updateStreamController.add({'rel-1', relationshipNotification});
        await pumpEventQueue();
        await container.read(
          relationshipDetailControllerProvider('rel-1').future,
        );

        expect(calls, 2);

        // Another person's write must not reload this one.
        updateStreamController.add({'rel-2', relationshipNotification});
        await pumpEventQueue();
        await container.read(
          relationshipDetailControllerProvider('rel-1').future,
        );

        expect(calls, 2);
        subscription.close();
      },
    );
  });
}
