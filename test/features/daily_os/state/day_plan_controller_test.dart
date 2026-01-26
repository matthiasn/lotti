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
    List<PlannedBlock> plannedBlocks = const [],
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
        plannedBlocks: plannedBlocks,
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

    test('addPlannedBlock adds a block to the plan', () async {
      final existingPlan = createTestPlan();
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      final newBlock = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startTime: DateTime(2026, 1, 15, 9),
        endTime: DateTime(2026, 1, 15, 11),
      );
      await notifier.addPlannedBlock(newBlock);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.plannedBlocks.length, equals(1));
      expect(savedPlan.data.plannedBlocks.first.categoryId, equals('cat-work'));
    });

    test('removePlannedBlock removes a block', () async {
      final existingPlan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          ),
          PlannedBlock(
            id: 'block-2',
            categoryId: 'cat-2',
            startTime: DateTime(2026, 1, 15, 14),
            endTime: DateTime(2026, 1, 15, 15),
          ),
        ],
      );

      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      await notifier.removePlannedBlock('block-1');

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.plannedBlocks.length, equals(1));
      expect(savedPlan.data.plannedBlocks.first.id, equals('block-2'));
    });

    test('updatePlannedBlock updates an existing block', () async {
      final existingPlan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          ),
        ],
      );

      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => existingPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      final updatedBlock = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-1',
        startTime: DateTime(2026, 1, 15, 9),
        endTime: DateTime(2026, 1, 15, 12), // Extended end time
      );
      await notifier.updatePlannedBlock(updatedBlock);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.plannedBlocks.length, equals(1));
      expect(
        savedPlan.data.plannedBlocks.first.endTime,
        equals(DateTime(2026, 1, 15, 12)),
      );
    });

    test('pinTask adds a pinned task', () async {
      final existingPlan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          ),
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
        categoryId: 'cat-1',
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
            PinnedTaskRef(taskId: 'task-1', categoryId: 'cat-1'),
            PinnedTaskRef(taskId: 'task-2', categoryId: 'cat-1'),
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
  });

  group('Status transitions to needsReview', () {
    test('addPlannedBlock transitions agreed plan to needsReview', () async {
      final agreedPlan = createTestPlan(
        status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
      );
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => agreedPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      final newBlock = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startTime: DateTime(2026, 1, 15, 9),
        endTime: DateTime(2026, 1, 15, 11),
      );
      await notifier.addPlannedBlock(newBlock);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.needsReview, isTrue);
      expect(
        (savedPlan.data.status as DayPlanStatusNeedsReview).reason,
        equals(DayPlanReviewReason.blockModified),
      );
    });

    test('updatePlannedBlock transitions agreed plan to needsReview', () async {
      final agreedPlan = createTestPlan(
        status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => agreedPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      final updatedBlock = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-1',
        startTime: DateTime(2026, 1, 15, 9),
        endTime: DateTime(2026, 1, 15, 12),
      );
      await notifier.updatePlannedBlock(updatedBlock);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.needsReview, isTrue);
    });

    test('removePlannedBlock transitions agreed plan to needsReview', () async {
      final agreedPlan = createTestPlan(
        status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => agreedPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      await notifier.removePlannedBlock('block-1');

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.needsReview, isTrue);
    });

    test('pinTask transitions agreed plan to needsReview', () async {
      final agreedPlan = createTestPlan(
        status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => agreedPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      const taskRef = PinnedTaskRef(
        taskId: 'task-123',
        categoryId: 'cat-1',
      );
      await notifier.pinTask(taskRef);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.needsReview, isTrue);
      expect(
        (savedPlan.data.status as DayPlanStatusNeedsReview).reason,
        equals(DayPlanReviewReason.taskRescheduled),
      );
    });

    test('unpinTask transitions agreed plan to needsReview', () async {
      final agreedPlan = DayPlanEntry(
        meta: Metadata(
          id: planId,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(days: 1)),
        ),
        data: DayPlanData(
          planDate: testDate,
          status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
          pinnedTasks: const [
            PinnedTaskRef(taskId: 'task-1', categoryId: 'cat-1'),
          ],
        ),
      );
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => agreedPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      await notifier.unpinTask('task-1');

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.needsReview, isTrue);
    });

    test('edits on draft plan do not change status', () async {
      final draftPlan = createTestPlan();
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => draftPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      final newBlock = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startTime: DateTime(2026, 1, 15, 9),
        endTime: DateTime(2026, 1, 15, 11),
      );
      await notifier.addPlannedBlock(newBlock);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.isDraft, isTrue);
    });

    test('needsReview status preserves previouslyAgreedAt', () async {
      final agreedAt = DateTime(2026, 1, 15, 8);
      final agreedPlan = createTestPlan(
        status: DayPlanStatus.agreed(agreedAt: agreedAt),
      );
      when(() => mockDb.getDayPlanById(planId))
          .thenAnswer((_) async => agreedPlan);

      await container.read(dayPlanControllerProvider(date: testDate).future);

      final notifier = container.read(
        dayPlanControllerProvider(date: testDate).notifier,
      );

      final newBlock = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startTime: DateTime(2026, 1, 15, 9),
        endTime: DateTime(2026, 1, 15, 11),
      );
      await notifier.addPlannedBlock(newBlock);

      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      final savedPlan = captured.last as DayPlanEntry;
      final status = savedPlan.data.status as DayPlanStatusNeedsReview;
      expect(status.previouslyAgreedAt, equals(agreedAt));
    });
  });
}
