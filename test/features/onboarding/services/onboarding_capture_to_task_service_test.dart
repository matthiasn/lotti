import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_capture_to_task_service.dart';
import 'package:lotti/features/onboarding/services/onboarding_task_structuring_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockOnboardingTaskStructuringService structuring;
  late MockAutoChecklistService autoChecklist;
  late MockOnboardingMetricsRepository metrics;
  late MockPersistenceLogic persistence;
  late OnboardingCaptureToTaskService service;

  const categoryId = 'cat-1';
  final fixedNow = DateTime(2026, 6, 21, 9);

  setUpAll(registerAllFallbackValues);

  void stubMetrics() {
    when(
      () => metrics.recordEvent(
        any(),
        provider: any(named: 'provider'),
        reason: any(named: 'reason'),
        valueBucket: any(named: 'valueBucket'),
      ),
    ).thenAnswer((_) async {});
  }

  void stubStructureSuccess(OnboardingStructuredTask result) {
    when(
      () => structuring.structure(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => result);
  }

  void stubStructureFailure(OnboardingStructuringFailure failure) {
    when(
      () => structuring.structure(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenThrow(OnboardingStructuringException(failure));
  }

  void stubCreateTask(Task? task) {
    when(
      () => persistence.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => task);
  }

  void stubChecklist() {
    when(
      () => autoChecklist.autoCreateChecklist(
        taskId: any(named: 'taskId'),
        suggestions: any(named: 'suggestions'),
        title: any(named: 'title'),
        shouldAutoCreate: any(named: 'shouldAutoCreate'),
      ),
    ).thenAnswer(
      (_) async => (
        success: true,
        checklistId: 'cl-1',
        createdItems: null,
        error: null,
      ),
    );
  }

  TaskData capturedTaskData() =>
      verify(
            () => persistence.createTaskEntry(
              data: captureAny(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: any(named: 'categoryId'),
            ),
          ).captured.single
          as TaskData;

  setUp(() {
    structuring = MockOnboardingTaskStructuringService();
    autoChecklist = MockAutoChecklistService();
    metrics = MockOnboardingMetricsRepository();
    persistence = MockPersistenceLogic();
    service = OnboardingCaptureToTaskService(
      structuringService: structuring,
      autoChecklistService: autoChecklist,
      metricsRepository: metrics,
      persistenceLogic: persistence,
      clock: () => fixedNow,
    );
    stubMetrics();
  });

  group('real aha (structuring succeeds)', () {
    test('creates a task with a checklist and records realAha', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(
          title: 'Call the dentist',
          checklistItems: ['Find number', 'Book slot'],
        ),
      );
      stubCreateTask(TestTaskFactory.create(id: 'task-1'));
      stubChecklist();

      final result = await service.createTaskFromTranscript(
        transcript: 'call the dentist and book a slot',
        categoryId: categoryId,
        providerName: 'gemini',
      );

      expect(result.isRealAha, isTrue);
      expect(result.created, isTrue);
      expect(result.title, 'Call the dentist');
      expect(result.checklistItems, ['Find number', 'Book slot']);

      // The created task carries the structured title and lands already in
      // progress (the user spoke it into being and is dropped onto it).
      final data = capturedTaskData();
      expect(data.title, 'Call the dentist');
      expect(
        data.status.maybeMap(inProgress: (_) => true, orElse: () => false),
        isTrue,
      );

      // The checklist was attached with the structured items.
      final suggestions =
          verify(
                () => autoChecklist.autoCreateChecklist(
                  taskId: 'task-1',
                  suggestions: captureAny(named: 'suggestions'),
                  title: any(named: 'title'),
                  shouldAutoCreate: true,
                ),
              ).captured.single
              as List<ChecklistItemData>;
      expect(suggestions.map((s) => s.title), ['Find number', 'Book slot']);

      // Funnel: make-task tapped up front, then realAha (with provider).
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.makeTaskTapped,
          provider: 'gemini',
        ),
      ).called(1);
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.realAha,
          provider: 'gemini',
        ),
      ).called(1);
      verifyNever(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFloorUsed,
          provider: any(named: 'provider'),
        ),
      );
    });

    test('skips the checklist when there are no items', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(
          title: 'Water plants',
          checklistItems: [],
        ),
      );
      stubCreateTask(TestTaskFactory.create(id: 'task-1'));

      final result = await service.createTaskFromTranscript(
        transcript: 'water the plants',
        categoryId: categoryId,
      );

      expect(result.isRealAha, isTrue);
      verifyNever(
        () => autoChecklist.autoCreateChecklist(
          taskId: any(named: 'taskId'),
          suggestions: any(named: 'suggestions'),
          title: any(named: 'title'),
          shouldAutoCreate: any(named: 'shouldAutoCreate'),
        ),
      );
    });

    test('falls short of a real aha when the task fails to persist', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(title: 'X', checklistItems: ['a']),
      );
      stubCreateTask(null);

      final result = await service.createTaskFromTranscript(
        transcript: 'something',
        categoryId: categoryId,
      );

      expect(result.isRealAha, isFalse);
      expect(result.created, isFalse);
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFailed,
          reason: 'persist_failed',
          provider: any(named: 'provider'),
        ),
      ).called(1);
      verifyNever(
        () => metrics.recordEvent(
          OnboardingEventName.realAha,
          provider: any(named: 'provider'),
        ),
      );
    });
  });

  group('soft landing (structuring fails)', () {
    test('creates a title-only task from the first sentence', () async {
      stubStructureFailure(OnboardingStructuringFailure.parseError);
      stubCreateTask(TestTaskFactory.create(id: 'floor-1'));

      final result = await service.createTaskFromTranscript(
        transcript: 'Buy oat milk on the way home. Also water the plants.',
        categoryId: categoryId,
        providerName: 'mistral',
      );

      expect(result.isRealAha, isFalse);
      expect(result.created, isTrue);
      expect(result.failure, OnboardingStructuringFailure.parseError);
      // Floor title is the first sentence only.
      expect(result.title, 'Buy oat milk on the way home');
      expect(capturedTaskData().title, 'Buy oat milk on the way home');

      verify(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFailed,
          reason: 'parseError',
          provider: 'mistral',
        ),
      ).called(1);
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFloorUsed,
          provider: 'mistral',
        ),
      ).called(1);
    });

    test('collapses whitespace and caps a long transcript title', () async {
      stubStructureFailure(OnboardingStructuringFailure.requestFailed);
      stubCreateTask(TestTaskFactory.create(id: 'floor-1'));
      final longTranscript = 'word ${'really ' * 40}long';

      final result = await service.createTaskFromTranscript(
        transcript: longTranscript,
        categoryId: categoryId,
      );

      expect(result.title.length, 80);
      expect(result.title, isNot(contains('  ')));
    });

    test('never makes a blank task for an empty transcript', () async {
      stubStructureFailure(OnboardingStructuringFailure.emptyTranscript);

      final result = await service.createTaskFromTranscript(
        transcript: '   ',
        categoryId: categoryId,
      );

      expect(result.created, isFalse);
      expect(result.title, isEmpty);
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFailed,
          reason: 'emptyTranscript',
          provider: any(named: 'provider'),
        ),
      ).called(1);
      verifyNever(
        () => persistence.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      );
      verifyNever(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFloorUsed,
          provider: any(named: 'provider'),
        ),
      );
    });

    test(
      'does not record floor-used when the floor task fails to persist',
      () async {
        stubStructureFailure(OnboardingStructuringFailure.requestFailed);
        stubCreateTask(null);

        final result = await service.createTaskFromTranscript(
          transcript: 'do the thing',
          categoryId: categoryId,
        );

        expect(result.created, isFalse);
        expect(result.title, 'do the thing');
        verifyNever(
          () => metrics.recordEvent(
            OnboardingEventName.structuringFloorUsed,
            provider: any(named: 'provider'),
          ),
        );
      },
    );
  });

  group('provider wiring', () {
    late MockOnboardingTaskStructuringService wiredStructuring;
    late MockPersistenceLogic wiredPersistence;
    late MockOnboardingMetricsRepository wiredMetrics;

    setUp(() {
      wiredStructuring = MockOnboardingTaskStructuringService();
      wiredPersistence = MockPersistenceLogic();
      wiredMetrics = MockOnboardingMetricsRepository();
      // The provider builds AutoChecklistService and resolves PersistenceLogic
      // and the metrics repo from getIt, with no explicit clock.
      getIt
        ..registerSingleton<JournalDb>(MockJournalDb())
        ..registerSingleton<DomainLogger>(MockDomainLogger())
        ..registerSingleton<PersistenceLogic>(wiredPersistence)
        ..registerSingleton<OnboardingMetricsRepository>(wiredMetrics);
    });
    tearDown(() async {
      await getIt.reset();
    });

    test('builds a service from app providers that creates a task', () async {
      when(
        () => wiredStructuring.structure(
          transcript: any(named: 'transcript'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer(
        (_) async =>
            const OnboardingStructuredTask(title: 'Wired', checklistItems: []),
      );
      when(
        () => wiredPersistence.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => TestTaskFactory.create(id: 'wired-task'));
      when(
        () => wiredMetrics.recordEvent(
          any(),
          provider: any(named: 'provider'),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      ).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          onboardingTaskStructuringServiceProvider.overrideWithValue(
            wiredStructuring,
          ),
          checklistRepositoryProvider.overrideWithValue(
            MockChecklistRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final wired = container.read(onboardingCaptureToTaskServiceProvider);
      final result = await wired.createTaskFromTranscript(
        transcript: 'hello',
        categoryId: categoryId,
      );

      // Proves the provider wired the structuring service, persistence, and
      // metrics repo together.
      expect(result.isRealAha, isTrue);
      expect(result.title, 'Wired');
      verify(
        () => wiredMetrics.recordEvent(
          OnboardingEventName.realAha,
          provider: any(named: 'provider'),
        ),
      ).called(1);
    });
  });
}
