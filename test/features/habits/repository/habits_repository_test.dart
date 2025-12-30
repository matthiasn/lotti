import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

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
      test('returns stream from JournalDb', () async {
        final controller = StreamController<List<HabitDefinition>>.broadcast();
        when(mockJournalDb.watchHabitDefinitions)
            .thenAnswer((_) => controller.stream);

        final stream = repository.watchHabitDefinitions();
        final future = stream.first;

        controller.add([testHabit]);
        final result = await future;

        expect(result, hasLength(1));
        expect(result.first.id, 'habit-1');
        expect(result.first.name, 'Test Habit');

        await controller.close();
        verify(mockJournalDb.watchHabitDefinitions).called(1);
      });

      test('emits multiple updates', () async {
        final controller = StreamController<List<HabitDefinition>>.broadcast();
        when(mockJournalDb.watchHabitDefinitions)
            .thenAnswer((_) => controller.stream);

        final stream = repository.watchHabitDefinitions();
        final results = <List<HabitDefinition>>[];
        final subscription = stream.listen(results.add);

        controller.add([testHabit]);
        await Future<void>.delayed(Duration.zero);

        final updatedHabit = testHabit.copyWith(name: 'Updated Habit');
        controller.add([testHabit, updatedHabit]);
        await Future<void>.delayed(Duration.zero);

        expect(results, hasLength(2));
        expect(results[0], hasLength(1));
        expect(results[1], hasLength(2));

        await subscription.cancel();
        await controller.close();
      });
    });

    group('watchHabitById', () {
      test('returns stream for specific habit', () async {
        final controller = StreamController<HabitDefinition?>.broadcast();
        when(() => mockJournalDb.watchHabitById('habit-1'))
            .thenAnswer((_) => controller.stream);

        final stream = repository.watchHabitById('habit-1');
        final future = stream.first;

        controller.add(testHabit);
        final result = await future;

        expect(result, isNotNull);
        expect(result!.id, 'habit-1');

        await controller.close();
        verify(() => mockJournalDb.watchHabitById('habit-1')).called(1);
      });

      test('returns null for non-existent habit', () async {
        final controller = StreamController<HabitDefinition?>.broadcast();
        when(() => mockJournalDb.watchHabitById('non-existent'))
            .thenAnswer((_) => controller.stream);

        final stream = repository.watchHabitById('non-existent');
        final future = stream.first;

        controller.add(null);
        final result = await future;

        expect(result, isNull);

        await controller.close();
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
      test('returns stream from JournalDb', () async {
        final controller =
            StreamController<List<DashboardDefinition>>.broadcast();
        when(mockJournalDb.watchDashboards)
            .thenAnswer((_) => controller.stream);

        final stream = repository.watchDashboards();
        final future = stream.first;

        controller.add([testDashboard]);
        final result = await future;

        expect(result, hasLength(1));
        expect(result.first.id, 'dashboard-1');

        await controller.close();
        verify(mockJournalDb.watchDashboards).called(1);
      });
    });

    group('updateStream', () {
      test('returns stream from UpdateNotifications', () async {
        final notifications = <Set<String>>[];
        final subscription = repository.updateStream.listen(notifications.add);

        updateStreamController.add({'habit-1'});
        await Future<void>.delayed(Duration.zero);

        updateStreamController.add({habitCompletionNotification});
        await Future<void>.delayed(Duration.zero);

        expect(notifications, hasLength(2));
        expect(notifications[0], contains('habit-1'));
        expect(notifications[1], contains(habitCompletionNotification));

        await subscription.cancel();
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

class MockHabitsRepository extends Mock implements HabitsRepository {}
