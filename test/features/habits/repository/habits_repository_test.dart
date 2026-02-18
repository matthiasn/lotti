import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late HabitsRepositoryImpl repository;
  late StreamController<Set<String>> updateStreamController;

  final testHabit = HabitDefinition(
    id: 'habit-1',
    name: 'Test Habit',
    description: 'Test description',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  );

  final testDashboard = DashboardDefinition(
    id: 'dashboard-1',
    name: 'Test Dashboard',
    description: 'Test dashboard',
    version: '1.0',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    reviewAt: DateTime(2025),
    lastReviewed: DateTime(2025),
    items: [],
  );

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    repository = HabitsRepositoryImpl(
      journalDb: mockJournalDb,
      updateNotifications: mockUpdateNotifications,
    );
  });

  tearDown(() async {
    await updateStreamController.close();
  });

  group('HabitsRepositoryImpl', () {
    group('watchHabitDefinitions', () {
      test('emits habits from initial fetch', () async {
        when(mockJournalDb.getAllHabitDefinitions)
            .thenAnswer((_) async => [testHabit]);

        final result = await repository.watchHabitDefinitions().first;

        expect(result, hasLength(1));
        expect(result.first.id, 'habit-1');
        expect(result.first.name, 'Test Habit');

        verify(mockJournalDb.getAllHabitDefinitions).called(1);
      });

      test('emits updated habits on notification', () {
        fakeAsync((async) {
          var callCount = 0;
          final updatedHabit = testHabit.copyWith(name: 'Updated Habit');
          when(mockJournalDb.getAllHabitDefinitions).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return [testHabit];
            return [testHabit, updatedHabit];
          });

          final results = <List<HabitDefinition>>[];
          final subscription =
              repository.watchHabitDefinitions().listen(results.add);

          async.flushMicrotasks();
          expect(results, hasLength(1));
          expect(results[0], hasLength(1));

          updateStreamController.add({habitsNotification});
          async
            ..elapse(const Duration(milliseconds: 50))
            ..flushMicrotasks();

          expect(results, hasLength(2));
          expect(results[1], hasLength(2));

          subscription.cancel();
        });
      });
    });

    group('watchHabitById', () {
      test('emits specific habit from initial fetch', () async {
        when(() => mockJournalDb.getHabitById('habit-1'))
            .thenAnswer((_) async => testHabit);

        final result = await repository.watchHabitById('habit-1').first;

        expect(result, isNotNull);
        expect(result!.id, 'habit-1');

        verify(() => mockJournalDb.getHabitById('habit-1')).called(1);
      });

      test('returns null for non-existent habit', () async {
        when(() => mockJournalDb.getHabitById('non-existent'))
            .thenAnswer((_) async => null);

        final result = await repository.watchHabitById('non-existent').first;

        expect(result, isNull);
      });
    });

    group('getHabitCompletionsInRange', () {
      test('returns completions from JournalDb', () async {
        final rangeStart = DateTime(2025);
        final testCompletion = HabitCompletionEntry(
          meta: Metadata(
            id: 'completion-1',
            createdAt: DateTime(2025, 1, 15),
            updatedAt: DateTime(2025, 1, 15),
            dateFrom: DateTime(2025, 1, 15),
            dateTo: DateTime(2025, 1, 15),
          ),
          data: HabitCompletionData(
            habitId: 'habit-1',
            dateFrom: DateTime(2025, 1, 15),
            dateTo: DateTime(2025, 1, 15),
            completionType: HabitCompletionType.success,
          ),
        );

        when(
          () => mockJournalDb.getHabitCompletionsInRange(
            rangeStart: rangeStart,
          ),
        ).thenAnswer((_) async => [testCompletion]);

        final result = await repository.getHabitCompletionsInRange(
          rangeStart: rangeStart,
        );

        expect(result, hasLength(1));
        expect(result.first, isA<HabitCompletionEntry>());
        verify(
          () => mockJournalDb.getHabitCompletionsInRange(
            rangeStart: rangeStart,
          ),
        ).called(1);
      });

      test('returns empty list when no completions', () async {
        final rangeStart = DateTime(2025);

        when(
          () => mockJournalDb.getHabitCompletionsInRange(
            rangeStart: rangeStart,
          ),
        ).thenAnswer((_) async => []);

        final result = await repository.getHabitCompletionsInRange(
          rangeStart: rangeStart,
        );

        expect(result, isEmpty);
      });
    });

    group('getHabitCompletionsByHabitId', () {
      test('returns completions for specific habit', () async {
        final rangeStart = DateTime(2025);
        final rangeEnd = DateTime(2025, 1, 31);
        final testCompletion = HabitCompletionEntry(
          meta: Metadata(
            id: 'completion-1',
            createdAt: DateTime(2025, 1, 15),
            updatedAt: DateTime(2025, 1, 15),
            dateFrom: DateTime(2025, 1, 15),
            dateTo: DateTime(2025, 1, 15),
          ),
          data: HabitCompletionData(
            habitId: 'habit-1',
            dateFrom: DateTime(2025, 1, 15),
            dateTo: DateTime(2025, 1, 15),
            completionType: HabitCompletionType.success,
          ),
        );

        when(
          () => mockJournalDb.getHabitCompletionsByHabitId(
            habitId: 'habit-1',
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
        ).thenAnswer((_) async => [testCompletion]);

        final result = await repository.getHabitCompletionsByHabitId(
          habitId: 'habit-1',
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(result, hasLength(1));
        verify(
          () => mockJournalDb.getHabitCompletionsByHabitId(
            habitId: 'habit-1',
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
        ).called(1);
      });
    });

    group('upsertHabitDefinition', () {
      test('delegates to JournalDb', () async {
        when(() => mockJournalDb.upsertHabitDefinition(testHabit))
            .thenAnswer((_) async => 1);

        final result = await repository.upsertHabitDefinition(testHabit);

        expect(result, 1);
        verify(() => mockJournalDb.upsertHabitDefinition(testHabit)).called(1);
      });
    });

    group('watchDashboards', () {
      test('emits dashboards from initial fetch', () async {
        when(mockJournalDb.getAllDashboards)
            .thenAnswer((_) async => [testDashboard]);

        final result = await repository.watchDashboards().first;

        expect(result, hasLength(1));
        expect(result.first.id, 'dashboard-1');

        verify(mockJournalDb.getAllDashboards).called(1);
      });
    });

    group('updateStream', () {
      test('returns stream from UpdateNotifications', () {
        fakeAsync((async) {
          final notifications = <Set<String>>[];
          final subscription =
              repository.updateStream.listen(notifications.add);

          updateStreamController.add({'habit-1'});
          async.flushMicrotasks();

          updateStreamController.add({habitCompletionNotification});
          async.flushMicrotasks();

          expect(notifications, hasLength(2));
          expect(notifications[0], contains('habit-1'));
          expect(notifications[1], contains(habitCompletionNotification));

          subscription.cancel();
        });
      });
    });
  });

  group('habitsRepositoryProvider', () {
    setUp(() {
      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('provides HabitsRepositoryImpl instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repository = container.read(habitsRepositoryProvider);

      expect(repository, isA<HabitsRepositoryImpl>());
    });

    test('is keepAlive (persists across reads)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repository1 = container.read(habitsRepositoryProvider);
      final repository2 = container.read(habitsRepositoryProvider);

      expect(identical(repository1, repository2), isTrue);
    });

    test('can be overridden in tests', () async {
      final mockRepository = MockHabitsRepository();
      final controller = StreamController<List<HabitDefinition>>.broadcast();
      when(mockRepository.watchHabitDefinitions)
          .thenAnswer((_) => controller.stream);

      final container = ProviderContainer(
        overrides: [
          habitsRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(habitsRepositoryProvider);
      expect(repository, same(mockRepository));

      // Verify the mock is working
      final stream = repository.watchHabitDefinitions();
      final future = stream.first;
      controller.add([testHabit]);
      final result = await future;

      expect(result, hasLength(1));
      await controller.close();
    });
  });
}
