import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;
  late StreamController<Set<String>> updateStreamController;

  final testDate = DateTime(2026, 1, 15);
  final planId = dayPlanId(testDate);

  DayPlanEntry createTestPlan({
    DayPlanStatus status = const DayPlanStatus.draft(),
    List<TimeBudget> budgets = const [],
  }) {
    return DayPlanEntry(
      meta: Metadata(
        id: planId,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: testDate,
        status: status,
        budgets: budgets,
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(
      const AsyncValue<JournalEntity?>.loading(),
    );
    registerFallbackValue(createTestPlan());
    registerFallbackValue(
      Metadata(
        id: 'test',
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
        dateFrom: DateTime(2026, 1, 15),
        dateTo: DateTime(2026, 1, 16),
      ),
    );

    getIt.allowReassignment = true;
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockUpdateNotifications = MockUpdateNotifications();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    when(() => mockPersistenceLogic.createDbEntity(any()))
        .thenAnswer((_) async => true);

    when(() => mockPersistenceLogic.updateMetadata(any())).thenAnswer(
      (invocation) async {
        final meta = invocation.positionalArguments.first as Metadata;
        return meta.copyWith(updatedAt: DateTime.now());
      },
    );

    when(() => mockPersistenceLogic.updateDbEntity(any()))
        .thenAnswer((_) async => true);

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
    getIt.reset();
  });

  group('DayPlanController', () {
    test('creates new plan if none exists', () async {
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => null);

      final subscription = container.listen(
        dayPlanControllerProvider(date: testDate),
        (_, __) {},
      );

      await container.read(dayPlanControllerProvider(date: testDate).future);

      // Should have called persistence to save the new plan
      verify(() => mockPersistenceLogic.createDbEntity(any())).called(1);

      subscription.close();
    });

    test('returns existing plan if it exists', () async {
      final existingPlan = createTestPlan();
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      final result = await container
          .read(dayPlanControllerProvider(date: testDate).future);

      expect(result, isA<DayPlanEntry>());
      expect((result! as DayPlanEntry).data.isDraft, isTrue);
    });

    test('agreeToPlan updates status to agreed', () async {
      final existingPlan = createTestPlan();
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      // Load the initial state
      await container.read(dayPlanControllerProvider(date: testDate).future);

      // Agree to the plan
      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );
      await notifier.agreeToPlan();

      // Verify persistence was called with agreed status (updateDbEntity for existing plans)
      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      expect(captured.length, greaterThan(0));
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.isAgreed, isTrue);
    });

    test('addBudget adds a budget to the plan', () async {
      final existingPlan = createTestPlan();
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      const newBudget = TimeBudget(
        id: 'budget-1',
        categoryId: 'cat-work',
        plannedMinutes: 120,
      );
      await notifier.addBudget(newBudget);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.budgets.length, equals(1));
      expect(savedPlan.data.budgets.first.categoryId, equals('cat-work'));
    });

    test('removeBudget removes a budget and its pinned tasks', () async {
      final existingPlan = createTestPlan(
        budgets: const [
          TimeBudget(id: 'budget-1', categoryId: 'cat-1', plannedMinutes: 60),
          TimeBudget(id: 'budget-2', categoryId: 'cat-2', plannedMinutes: 90),
        ],
      );

      // We need to add pinned tasks as well - but the createTestPlan doesn't
      // have pinnedTasks parameter, so let's create a more complete plan
      final planWithTasks = existingPlan.copyWith(
        data: existingPlan.data.copyWith(
          pinnedTasks: const [
            PinnedTaskRef(taskId: 'task-1', budgetId: 'budget-1'),
            PinnedTaskRef(taskId: 'task-2', budgetId: 'budget-2'),
          ],
        ),
      );

      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => planWithTasks);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      await notifier.removeBudget('budget-1');

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.budgets.length, equals(1));
      expect(savedPlan.data.budgets.first.id, equals('budget-2'));
      // Pinned tasks for the removed budget should also be gone
      expect(savedPlan.data.pinnedTasks.length, equals(1));
      expect(savedPlan.data.pinnedTasks.first.budgetId, equals('budget-2'));
    });

    test('pinTask adds a pinned task', () async {
      final existingPlan = createTestPlan(
        budgets: const [
          TimeBudget(id: 'budget-1', categoryId: 'cat-1', plannedMinutes: 60),
        ],
      );

      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      const taskRef = PinnedTaskRef(
        taskId: 'task-123',
        budgetId: 'budget-1',
        sortOrder: 1,
      );
      await notifier.pinTask(taskRef);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.pinnedTasks.length, equals(1));
      expect(savedPlan.data.pinnedTasks.first.taskId, equals('task-123'));
    });

    test('unpinTask removes a pinned task', () async {
      final planWithTasks = createTestPlan().copyWith(
        data: DayPlanData(
          planDate: testDate,
          status: const DayPlanStatus.draft(),
          pinnedTasks: const [
            PinnedTaskRef(taskId: 'task-1', budgetId: 'budget-1'),
            PinnedTaskRef(taskId: 'task-2', budgetId: 'budget-1'),
          ],
        ),
      );

      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => planWithTasks);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      await notifier.unpinTask('task-1');

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.pinnedTasks.length, equals(1));
      expect(savedPlan.data.pinnedTasks.first.taskId, equals('task-2'));
    });

    test('setDayLabel updates the label', () async {
      final existingPlan = createTestPlan();
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      await notifier.setDayLabel('Deep Work Day');

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.dayLabel, equals('Deep Work Day'));
    });

    test('listens to update stream and refreshes', () async {
      final existingPlan = createTestPlan();
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      // Trigger an update notification
      updateStreamController.add({planId});

      // Allow microtasks to complete
      await Future<void>.delayed(Duration.zero);

      // Should have refetched the plan
      verify(() => mockDb.getDayPlanById(planId))
          .called(greaterThanOrEqualTo(2));
    });

    test('reorderBudgets updates sortOrder of budgets', () async {
      final existingPlan = createTestPlan(
        budgets: const [
          TimeBudget(
            id: 'budget-1',
            categoryId: 'cat-1',
            plannedMinutes: 60,
          ),
          TimeBudget(
            id: 'budget-2',
            categoryId: 'cat-2',
            plannedMinutes: 90,
            sortOrder: 1,
          ),
          TimeBudget(
            id: 'budget-3',
            categoryId: 'cat-3',
            plannedMinutes: 120,
            sortOrder: 2,
          ),
        ],
      );

      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      // Reorder: move budget-3 to the first position
      await notifier.reorderBudgets(['budget-3', 'budget-1', 'budget-2']);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.budgets.length, equals(3));

      // Verify the new order and sortOrder values
      expect(savedPlan.data.budgets[0].id, equals('budget-3'));
      expect(savedPlan.data.budgets[0].sortOrder, equals(0));
      expect(savedPlan.data.budgets[1].id, equals('budget-1'));
      expect(savedPlan.data.budgets[1].sortOrder, equals(1));
      expect(savedPlan.data.budgets[2].id, equals('budget-2'));
      expect(savedPlan.data.budgets[2].sortOrder, equals(2));
    });

    test('updateBudget updates budget plannedMinutes', () async {
      final existingPlan = createTestPlan(
        budgets: const [
          TimeBudget(
            id: 'budget-1',
            categoryId: 'cat-1',
            plannedMinutes: 60,
          ),
        ],
      );

      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      const updatedBudget = TimeBudget(
        id: 'budget-1',
        categoryId: 'cat-1',
        plannedMinutes: 120,
      );
      await notifier.updateBudget(updatedBudget);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.budgets.length, equals(1));
      expect(savedPlan.data.budgets.first.plannedMinutes, equals(120));
    });
  });
}
