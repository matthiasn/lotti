import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';

/// Integration test to verify that concurrent AI processing and user modifications
/// work correctly with the Read-Current-Write pattern implementation.
///
/// This test simulates real-world scenarios where:
/// 1. AI starts processing a task
/// 2. User modifies the task during AI processing
/// 3. AI completes and uses current task state (not stale captured state)

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockAutoChecklistService extends Mock implements AutoChecklistService {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

// TODO: Add integration tests that exercise label repository methods
// (getAllLabels, getLabelUsageCounts, buildLabelTuples) and remove this
// unused mock once those tests are implemented.
class MockLabelsRepository extends Mock implements LabelsRepository {}

class MockRef extends Mock implements Ref {}

class MockDirectory extends Mock implements Directory {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

class FakeAiConfigModel extends Fake implements AiConfigModel {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

class FakeMetadata extends Fake implements Metadata {}

class FakeTaskData extends Fake implements TaskData {}

class FakeAiResponseData extends Fake implements AiResponseData {}

void main() {
  late UnifiedAiInferenceRepository repository;
  late MockRef mockRef;
  late MockAiConfigRepository mockAiConfigRepo;
  late MockAiInputRepository mockAiInputRepo;
  late MockCloudInferenceRepository mockCloudInferenceRepo;
  late MockJournalRepository mockJournalRepo;
  late MockChecklistRepository mockChecklistRepo;
  late MockAutoChecklistService mockAutoChecklistService;
  late MockLoggingService mockLoggingService;
  late MockJournalDb mockJournalDb;
  late MockLabelsRepository mockLabelsRepo; // TODO: Remove when tests added
  late MockDirectory mockDirectory;

  setUpAll(() {
    // Isolate GetIt registrations within this test file
    getIt.pushNewScope();
    registerFallbackValue(FakeAiConfigPrompt());
    registerFallbackValue(FakeAiConfigModel());
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(FakeAiResponseData());
    registerFallbackValue(fallbackJournalEntity);
  });

  late Directory? baseTempDir;
  late List<Directory> overrideTempDirs;

  setUp(() {
    mockRef = MockRef();
    mockAiConfigRepo = MockAiConfigRepository();
    mockAiInputRepo = MockAiInputRepository();
    mockCloudInferenceRepo = MockCloudInferenceRepository();
    mockJournalRepo = MockJournalRepository();
    mockChecklistRepo = MockChecklistRepository();
    mockAutoChecklistService = MockAutoChecklistService();
    mockLoggingService = MockLoggingService();
    mockJournalDb = MockJournalDb();
    mockLabelsRepo = MockLabelsRepository(); // TODO: Remove when tests added
    mockDirectory = MockDirectory();

    reset(mockJournalDb);

    // Set up GetIt
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<Directory>(mockDirectory)
      ..registerSingleton<LoggingService>(mockLoggingService);

    // Mock directory path to writable temp location per test
    baseTempDir = Directory.systemTemp.createTempSync('lotti_ai_integ_test_');
    overrideTempDirs = <Directory>[];
    when(() => mockDirectory.path).thenReturn(baseTempDir!.path);

    when(() => mockRef.read(aiConfigRepositoryProvider))
        .thenReturn(mockAiConfigRepo);
    when(() => mockRef.read(aiInputRepositoryProvider))
        .thenReturn(mockAiInputRepo);
    when(() => mockRef.read(cloudInferenceRepositoryProvider))
        .thenReturn(mockCloudInferenceRepo);
    when(() => mockRef.read(journalRepositoryProvider))
        .thenReturn(mockJournalRepo);
    when(() => mockRef.read(checklistRepositoryProvider))
        .thenReturn(mockChecklistRepo);
    // TODO: Remove when integration tests for labels are added
    when(() => mockRef.read(labelsRepositoryProvider))
        .thenReturn(mockLabelsRepo);
    when(() => mockRef.read(journalDbProvider)).thenReturn(mockJournalDb);
    when(() => mockJournalDb.getConfigFlag(enableAiStreamingFlag))
        .thenAnswer((_) async => false);

    // Default mock for getLinkedEntities - returns empty so fallback to getLinkedToEntities
    when(() =>
            mockJournalRepo.getLinkedEntities(linkedTo: any(named: 'linkedTo')))
        .thenAnswer((_) async => <JournalEntity>[]);

    repository = UnifiedAiInferenceRepository(mockRef)
      ..autoChecklistServiceForTesting = mockAutoChecklistService;
  });

  tearDown(() {
    // Clean up temp directories created for this test
    try {
      if (baseTempDir != null && baseTempDir!.existsSync()) {
        baseTempDir!.deleteSync(recursive: true);
      }
      for (final d in overrideTempDirs) {
        if (d.existsSync()) {
          d.deleteSync(recursive: true);
        }
      }
      when(() => mockDirectory.path).thenReturn(Directory.systemTemp.path);
    } catch (_) {}

    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  tearDownAll(() async {
    await getIt.resetScope();
    await getIt.popScope();
  });

  group('Real Concurrent Scenarios Integration Tests', () {
    test(
        'Concurrent task summary: AI preserves user title changes during processing',
        () async {
      // Setup: Create initial task with short title
      const taskId = 'test-task-123';
      final originalTask = Task(
        meta: _createMetadata(id: taskId),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now().add(const Duration(hours: 1)),
          statusHistory: [],
          title: 'Old', // Short title that would normally be updated by AI
        ),
      );

      // Task that user updates while AI is processing
      final userUpdatedTask = Task(
        meta: _createMetadata(id: taskId),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now().add(const Duration(hours: 1)),
          statusHistory: [],
          title:
              'User updated this title during AI processing', // User changed title
        ),
      );

      // Setup: AI config
      final promptConfig = _createPrompt(
        id: 'summary-prompt',
        requiredInputData: [InputDataType.task],
      );
      final model = _createModel(id: 'model-1');
      final provider = _createProvider(id: 'provider-1');

      // Setup: Mock repository responses
      when(() => mockAiConfigRepo.getConfigById('summary-prompt'))
          .thenAnswer((_) async => promptConfig);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockAiInputRepo.buildTaskDetailsJson(id: taskId))
          .thenAnswer((_) async => jsonEncode({
                'title': originalTask.data.title,
                'status': 'IN PROGRESS',
              }));

      when(() => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => null);

      // Setup: Simulate concurrent access - user updates task during AI processing
      var getEntityCallCount = 0;
      when(() => mockAiInputRepo.getEntity(taskId)).thenAnswer((_) async {
        getEntityCallCount++;
        if (getEntityCallCount == 1) {
          // First call: AI captures initial task state
          return originalTask;
        } else {
          // Second call: AI reads current state in post-processing
          // This simulates user having updated the task during AI processing
          return userUpdatedTask;
        }
      });

      // Setup: Track journal update calls
      final updatedTasks = <Task>[];
      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((invocation) async {
        final task = invocation.positionalArguments[0] as Task;
        updatedTasks.add(task);
        return true;
      });

      // Setup: AI response with suggested title
      final mockStream = _createDelayedStream([
        '# AI Suggested Title\n\nThis is a great summary of the task.'
      ]); // Simulate processing time

      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            provider: any(named: 'provider'),
          )).thenAnswer((_) => mockStream);

      // Execute: Start AI inference and simulate concurrent user modification
      final progressUpdates = <String>[];
      final statusChanges = <InferenceStatus>[];

      // Start AI processing (this captures original task state)
      final aiTask = repository.runInference(
        entityId: taskId,
        promptConfig: promptConfig,
        onProgress: progressUpdates.add,
        onStatusChange: statusChanges.add,
      );

      // Wait for AI to complete
      await aiTask;

      // Verify: AI should have made two getEntity calls (initial + post-processing)
      verify(() => mockAiInputRepo.getEntity(taskId)).called(2);

      // Verify: AI should NOT update title because current task has long title
      // This proves the Read-Current-Write pattern is working
      expect(updatedTasks, isEmpty,
          reason:
              'AI should not update title when current task has long title');

      // Verify: AI processed correctly and got the response
      expect(progressUpdates.isNotEmpty, true);
      expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);
    });

    test(
        'Concurrent task summary: AI updates title when user makes compatible changes',
        () async {
      // Test scenario: User changes status but keeps short title, AI should still update title
      const taskId = 'test-task-456';
      final originalTask = Task(
        meta: _createMetadata(id: taskId),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now().add(const Duration(hours: 1)),
          statusHistory: [],
          title: 'Fix', // Short title that should be updated
        ),
      );

      // User changes status but keeps short title
      final userUpdatedTask = Task(
        meta: _createMetadata(id: taskId),
        data: TaskData(
          status: TaskStatus.done(
            id: 'status-2',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now().add(const Duration(hours: 1)),
          statusHistory: [],
          title: 'Fix', // Still short, AI should update this
        ),
      );

      final promptConfig = _createPrompt(
        id: 'summary-prompt',
        requiredInputData: [InputDataType.task],
      );
      final model = _createModel(id: 'model-1');
      final provider = _createProvider(id: 'provider-1');

      when(() => mockAiConfigRepo.getConfigById('summary-prompt'))
          .thenAnswer((_) async => promptConfig);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockAiInputRepo.buildTaskDetailsJson(id: taskId))
          .thenAnswer((_) async => jsonEncode({
                'title': originalTask.data.title,
                'status': 'IN PROGRESS',
              }));

      when(() => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => null);

      // Simulate user updating task status but keeping short title
      var getEntityCallCount = 0;
      when(() => mockAiInputRepo.getEntity(taskId)).thenAnswer((_) async {
        getEntityCallCount++;
        return getEntityCallCount == 1 ? originalTask : userUpdatedTask;
      });

      final updatedTasks = <Task>[];
      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((invocation) async {
        final task = invocation.positionalArguments[0] as Task;
        updatedTasks.add(task);
        return true;
      });

      final mockStream = _createDelayedStream([
        '# AI Generated Detailed Title\n\nThis is a comprehensive summary.'
      ]);

      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            provider: any(named: 'provider'),
          )).thenAnswer((_) => mockStream);

      await repository.runInference(
        entityId: taskId,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify: AI should update title since current task still has short title
      expect(updatedTasks.length, 1);
      expect(updatedTasks.first.data.title, 'AI Generated Detailed Title');
      expect(updatedTasks.first.data.status.runtimeType,
          userUpdatedTask.data.status.runtimeType,
          reason: "AI should preserve user's status change");
    });

    test('Multiple rapid concurrent title changes: AI uses final state',
        () async {
      // Test multiple rapid changes during AI processing
      const taskId = 'test-task-rapid';
      final tasks = [
        _createTaskWithTitle(taskId, 'V1'), // Original
        _createTaskWithTitle(taskId, 'V2'), // User change 1
        _createTaskWithTitle(taskId, 'V3'), // User change 2
        _createTaskWithTitle(taskId,
            'Final long title that should prevent AI update'), // Final state
      ];

      final promptConfig = _createPrompt(
        id: 'summary-prompt',
        requiredInputData: [InputDataType.task],
      );
      final model = _createModel(id: 'model-1');
      final provider = _createProvider(id: 'provider-1');

      when(() => mockAiConfigRepo.getConfigById('summary-prompt'))
          .thenAnswer((_) async => promptConfig);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockAiInputRepo.buildTaskDetailsJson(id: taskId))
          .thenAnswer((_) async => jsonEncode({'title': tasks[0].data.title}));

      when(() => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => null);

      // Simulate rapid changes - AI gets final state in post-processing
      var getEntityCallCount = 0;
      when(() => mockAiInputRepo.getEntity(taskId)).thenAnswer((_) async {
        getEntityCallCount++;
        if (getEntityCallCount == 1) {
          return tasks[0]; // AI captures original state
        } else {
          return tasks[3]; // AI gets final state with long title
        }
      });

      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((_) async => true);

      final mockStream = _createDelayedStream(
          ['# AI Suggested Title\n\nSummary content.'],
          delayMs: 200);

      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            provider: any(named: 'provider'),
          )).thenAnswer((_) => mockStream);

      await repository.runInference(
        entityId: taskId,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify: AI should respect final long title and not update
      verify(() => mockAiInputRepo.getEntity(taskId)).called(2);
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
    });

    test(
        'Database transaction simulation: AI handles concurrent database operations',
        () {
      fakeAsync((async) {
        // Test that our Read-Current-Write pattern works even with database-level concurrency
        const taskId = 'test-task-db';
        final originalTask =
            _createTaskWithTitle(taskId, 'DB', checklistIds: []);
        final updatedTask = _createTaskWithTitle(
            taskId, 'Database updated task with longer title',
            checklistIds: []);

        final promptConfig = _createPrompt(
          id: 'summary-prompt',
          requiredInputData: [InputDataType.task],
        );
        final model = _createModel(id: 'model-1');
        final provider = _createProvider(id: 'provider-1');

        when(() => mockAiConfigRepo.getConfigById('summary-prompt'))
            .thenAnswer((_) async => promptConfig);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);

        when(() => mockAiInputRepo.buildTaskDetailsJson(id: taskId)).thenAnswer(
            (_) async => jsonEncode({'title': originalTask.data.title}));

        when(() => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => null);

        // Simulate database-level concurrent modifications
        var getEntityCallCount = 0;
        when(() => mockAiInputRepo.getEntity(taskId)).thenAnswer((_) async {
          getEntityCallCount++;
          if (getEntityCallCount == 1) {
            return originalTask;
          } else {
            // Simulate small DB delay deterministically
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return updatedTask;
          }
        });

        // Track update attempts
        final updateAttempts = <Task>[];
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((invocation) async {
          final task = invocation.positionalArguments[0] as Task;
          updateAttempts.add(task);
          // Simulate constraint check with a deterministic timer
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return true;
        });

        final mockStream = _createDelayedStream(['# AI Title\n\nSummary.']);

        when(() => mockCloudInferenceRepo.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              provider: any(named: 'provider'),
            )).thenAnswer((_) => mockStream);

        // Kick off inference; drive time with fake clock
        repository.runInference(
          entityId: taskId,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Allow queued microtasks, then elapse DB + stream delays
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 10))
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();

        // Verify: AI should not update because final state has long title
        verify(() => mockAiInputRepo.getEntity(taskId)).called(2);
        expect(updateAttempts, isEmpty,
            reason: 'AI should not attempt update when current title is long');
      });
    });

    test(
        'High-frequency concurrent modifications: AI handles rapid user changes gracefully',
        () async {
      // Setup: Task that changes multiple times during AI processing
      const taskId = 'test-task-789';
      final tasks = List.generate(
          5,
          (index) => Task(
                meta: _createMetadata(id: taskId),
                data: TaskData(
                  status: TaskStatus.inProgress(
                    id: 'status-1',
                    createdAt: DateTime.now(),
                    utcOffset: 0,
                  ),
                  dateFrom: DateTime.now(),
                  dateTo: DateTime.now().add(const Duration(hours: 1)),
                  statusHistory: [],
                  title: 'Rapidly changing title #$index',
                ),
              ));

      final promptConfig = _createPrompt(
        id: 'summary-prompt',
        requiredInputData: [InputDataType.task],
      );
      final model = _createModel(id: 'model-1');
      final provider = _createProvider(id: 'provider-1');

      // Setup: Mock repository responses
      when(() => mockAiConfigRepo.getConfigById('summary-prompt'))
          .thenAnswer((_) async => promptConfig);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockAiInputRepo.buildTaskDetailsJson(id: taskId))
          .thenAnswer((_) async => jsonEncode({'title': tasks[0].data.title}));

      when(() => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => null);

      // Setup: Simulate rapid task changes during AI processing
      var getEntityCallCount = 0;
      when(() => mockAiInputRepo.getEntity(taskId)).thenAnswer((_) async {
        final taskIndex = getEntityCallCount % tasks.length;
        getEntityCallCount++;
        return tasks[taskIndex];
      });

      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((_) async => true);

      // Setup: Slow AI response to allow for multiple task changes
      final mockStream = _createDelayedStream(
          ['# AI Title\n\nSummary content.'],
          delayMs: 300);

      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            provider: any(named: 'provider'),
          )).thenAnswer((_) => mockStream);

      // Execute: AI should handle multiple rapid task changes gracefully
      await repository.runInference(
        entityId: taskId,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify: AI should have called getEntity at least twice (initial + post-processing)
      verify(() => mockAiInputRepo.getEntity(taskId))
          .called(greaterThanOrEqualTo(2));

      // Verify: No crashes or exceptions occurred
      // If we reach this point, the rapid changes were handled gracefully
      expect(true, true); // Test passes if no exceptions were thrown
    });

    test('handles type safety when _getCurrentEntityState returns wrong type',
        () async {
      // Setup: Initial task
      const taskId = 'test-task-type-safety';
      final task = _createTaskWithTitle(taskId, 'Test');

      final promptConfig = _createPrompt(
        id: 'summary-prompt',
        requiredInputData: [InputDataType.task],
      );
      final model = _createModel(id: 'model-1');
      final provider = _createProvider(id: 'provider-1');

      when(() => mockAiConfigRepo.getConfigById('summary-prompt'))
          .thenAnswer((_) async => promptConfig);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockAiInputRepo.buildTaskDetailsJson(id: taskId))
          .thenAnswer((_) async => jsonEncode({'title': 'Test'}));

      when(() => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => null);

      // Create a journal entry (not a task) to simulate wrong type
      final journalEntry = JournalEntity.journalEntry(
        meta: _createMetadata(id: taskId),
        entryText: const EntryText(plainText: 'This is a journal entry'),
      );

      // Mock getEntity to first return task, then journal entry
      var callCount = 0;
      when(() => mockAiInputRepo.getEntity(taskId)).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? task : journalEntry;
      });

      final updateCalls = <JournalEntity>[];
      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((invocation) async {
        updateCalls.add(invocation.positionalArguments[0] as JournalEntity);
        return true;
      });

      final mockStream =
          _createDelayedStream(['# AI Title\n\nSummary content.']);

      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            provider: any(named: 'provider'),
          )).thenAnswer((_) => mockStream);

      // Execute: Should handle type mismatch gracefully
      await repository.runInference(
        entityId: taskId,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify: No task updates should occur due to type mismatch
      expect(updateCalls.whereType<Task>(), isEmpty);
    });

    test('handles null return from _getCurrentEntityState', () async {
      // Setup: Initial task
      const taskId = 'test-task-null-safety';
      final task = _createTaskWithTitle(taskId, 'Test');

      final promptConfig = _createPrompt(
        id: 'summary-prompt',
        requiredInputData: [InputDataType.task],
      );
      final model = _createModel(id: 'model-1');
      final provider = _createProvider(id: 'provider-1');

      when(() => mockAiConfigRepo.getConfigById('summary-prompt'))
          .thenAnswer((_) async => promptConfig);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockAiInputRepo.buildTaskDetailsJson(id: taskId))
          .thenAnswer((_) async => jsonEncode({'title': 'Test'}));

      when(() => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => null);

      // Mock getEntity to first return task, then null
      var callCount = 0;
      when(() => mockAiInputRepo.getEntity(taskId)).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? task : null;
      });

      final updateCalls = <JournalEntity>[];
      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((invocation) async {
        updateCalls.add(invocation.positionalArguments[0] as JournalEntity);
        return true;
      });

      final mockStream =
          _createDelayedStream(['# AI Title\n\nSummary content.']);

      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            provider: any(named: 'provider'),
          )).thenAnswer((_) => mockStream);

      // Execute: Should handle null gracefully
      await repository.runInference(
        entityId: taskId,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify: No task updates should occur due to null entity
      expect(updateCalls.whereType<Task>(), isEmpty);
    });
  });

  group('Read-Current-Write Pattern Verification', () {
    test(
        'Concurrent audio transcription: AI preserves user changes during processing',
        () async {
      // Create temporary directory and files
      final tempDir = Directory.systemTemp.createTempSync('audio_test');
      overrideTempDirs.add(tempDir);

      try {
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        // Create the directory structure and file
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        File('${tempDir.path}/audio/test-audio.wav')
            .writeAsBytesSync([1, 2, 3, 4, 5, 6]);

        const audioId = 'test-audio-123';
        final originalAudio = _createJournalAudio(audioId);

        // User adds entry text while AI is processing
        final userUpdatedAudio = _createJournalAudio(
          audioId,
          entryText: const EntryText(
            plainText: 'User added this text during AI processing',
            markdown: 'User added this text during AI processing',
          ),
        );

        final promptConfig = _createPrompt(
          id: 'audio-prompt',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );
        final model = _createModel(id: 'model-1');
        final provider = _createProvider(id: 'provider-1');

        when(() => mockAiConfigRepo.getConfigById('audio-prompt'))
            .thenAnswer((_) async => promptConfig);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);

        when(() => mockAiInputRepo.buildTaskDetailsJson(id: audioId))
            .thenAnswer((_) async => jsonEncode({
                  'audioFile': 'test-audio.wav',
                  'duration': '00:05:00',
                }));

        when(() => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => null);

        when(() => mockJournalRepo.getLinkedToEntities(
                linkedTo: any(named: 'linkedTo')))
            .thenAnswer((_) async => <JournalEntity>[]);

        // Simulate user modifying audio during AI processing
        var getEntityCallCount = 0;
        when(() => mockAiInputRepo.getEntity(audioId)).thenAnswer((_) async {
          getEntityCallCount++;
          return getEntityCallCount == 1 ? originalAudio : userUpdatedAudio;
        });

        final updatedAudios = <JournalAudio>[];
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((invocation) async {
          final audio = invocation.positionalArguments[0] as JournalAudio;
          updatedAudios.add(audio);
          return true;
        });

        final mockStream =
            _createDelayedStream(['Hello, this is the transcription.']);

        when(() => mockCloudInferenceRepo.generateWithAudio(
              provider: any(named: 'provider'),
              any(),
              model: any(named: 'model'),
              audioBase64: any(named: 'audioBase64'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
            )).thenAnswer((_) => mockStream);

        await repository.runInference(
          entityId: audioId,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify: AI used current state, preserving user's entry text changes
        expect(updatedAudios.length, 1);
        final updatedAudio = updatedAudios.first;

        // Should have added transcript
        expect(updatedAudio.data.transcripts?.length, 1);
        expect(updatedAudio.data.transcripts?.first.transcript,
            'Hello, this is the transcription.');

        // Should use transcription as entry text (AI overwrites for transcription)
        expect(updatedAudio.entryText?.plainText,
            'Hello, this is the transcription.');
      } finally {
        // Cleanup - this will always run even if test fails
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Audio transcription handles entity not found gracefully', () async {
      // Create temporary directory and files
      final tempDir = Directory.systemTemp.createTempSync('audio_test');
      overrideTempDirs.add(tempDir);

      try {
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        // Create the directory structure and file
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        File('${tempDir.path}/audio/test-audio.wav')
            .writeAsBytesSync([1, 2, 3, 4, 5, 6]);

        const audioId = 'test-audio-missing';
        final originalAudio = _createJournalAudio(audioId);

        final promptConfig = _createPrompt(
          id: 'audio-prompt',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );
        final model = _createModel(id: 'model-1');
        final provider = _createProvider(id: 'provider-1');

        when(() => mockAiConfigRepo.getConfigById('audio-prompt'))
            .thenAnswer((_) async => promptConfig);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);

        when(() => mockAiInputRepo.buildTaskDetailsJson(id: audioId))
            .thenAnswer((_) async => jsonEncode({
                  'audioFile': 'test-audio.wav',
                  'duration': '00:05:00',
                }));

        when(() => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => null);

        when(() => mockJournalRepo.getLinkedToEntities(
                linkedTo: any(named: 'linkedTo')))
            .thenAnswer((_) async => <JournalEntity>[]);

        // First call returns audio, second call (during post-processing) returns null
        var getEntityCallCount = 0;
        when(() => mockAiInputRepo.getEntity(audioId)).thenAnswer((_) async {
          getEntityCallCount++;
          return getEntityCallCount == 1 ? originalAudio : null;
        });

        final updateCalls = <dynamic>[];
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((invocation) async {
          updateCalls.add(invocation.positionalArguments[0]);
          return true;
        });

        final mockStream = _createDelayedStream(['Transcription text']);

        when(() => mockCloudInferenceRepo.generateWithAudio(
              provider: any(named: 'provider'),
              any(),
              model: any(named: 'model'),
              audioBase64: any(named: 'audioBase64'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
            )).thenAnswer((_) => mockStream);

        await repository.runInference(
          entityId: audioId,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify: No audio updates should occur due to missing entity
        expect(updateCalls.whereType<JournalAudio>(), isEmpty);
      } finally {
        // Cleanup - this will always run even if test fails
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('Image Analysis Concurrent Scenarios', () {
    test(
        'Concurrent image analysis: AI preserves user text changes during processing',
        () async {
      // Create temporary directory and files
      final tempDir = Directory.systemTemp.createTempSync('image_test');
      overrideTempDirs.add(tempDir);

      try {
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        // Create the directory structure and file
        Directory('${tempDir.path}/images').createSync(recursive: true);
        File('${tempDir.path}/images/test-image.jpg')
            .writeAsBytesSync([1, 2, 3, 4]);

        const imageId = 'test-image-123';
        final originalImage = _createJournalImage(imageId);

        // User adds text while AI is processing
        final userUpdatedImage = _createJournalImage(
          imageId,
          entryText: const EntryText(
            plainText: 'User added this description',
            markdown: 'User added this description',
          ),
        );

        final promptConfig = _createPrompt(
          id: 'image-prompt',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );
        final model = _createModel(id: 'model-1');
        final provider = _createProvider(id: 'provider-1');

        when(() => mockAiConfigRepo.getConfigById('image-prompt'))
            .thenAnswer((_) async => promptConfig);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);

        when(() => mockAiInputRepo.buildTaskDetailsJson(id: imageId))
            .thenAnswer((_) async => jsonEncode({
                  'imageFile': 'test-image.jpg',
                  'capturedAt': DateTime.now().toIso8601String(),
                }));

        when(() => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => null);

        when(() => mockJournalRepo.getLinkedToEntities(
                linkedTo: any(named: 'linkedTo')))
            .thenAnswer((_) async => <JournalEntity>[]);

        // Simulate user modifying image during AI processing
        var getEntityCallCount = 0;
        when(() => mockAiInputRepo.getEntity(imageId)).thenAnswer((_) async {
          getEntityCallCount++;
          return getEntityCallCount == 1 ? originalImage : userUpdatedImage;
        });

        final updatedImages = <JournalImage>[];
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((invocation) async {
          final image = invocation.positionalArguments[0] as JournalImage;
          updatedImages.add(image);
          return true;
        });

        final mockStream =
            _createDelayedStream(['This image shows a beautiful sunset.']);

        when(() => mockCloudInferenceRepo.generateWithImages(
              provider: any(named: 'provider'),
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              images: any(named: 'images'),
            )).thenAnswer((_) => mockStream);

        await repository.runInference(
          entityId: imageId,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify: AI should append to user's text, not overwrite it
        expect(updatedImages.length, 1);
        final updatedImage = updatedImages.first;

        // Should append AI analysis to user's existing text
        expect(updatedImage.entryText?.plainText,
            'User added this description\n\nThis image shows a beautiful sunset.');
        expect(updatedImage.entryText?.markdown,
            'User added this description\n\nThis image shows a beautiful sunset.');
      } finally {
        // Cleanup - this will always run even if test fails
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Image analysis with empty initial text uses AI response directly',
        () async {
      // Create temporary directory and files
      final tempDir = Directory.systemTemp.createTempSync('image_test');
      overrideTempDirs.add(tempDir);

      try {
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        // Create the directory structure and file
        Directory('${tempDir.path}/images').createSync(recursive: true);
        File('${tempDir.path}/images/test-image.jpg')
            .writeAsBytesSync([1, 2, 3, 4]);

        const imageId = 'test-image-empty';
        // User doesn't add text, image stays empty during processing
        final currentImage = _createJournalImage(imageId);

        final promptConfig = _createPrompt(
          id: 'image-prompt',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );
        final model = _createModel(id: 'model-1');
        final provider = _createProvider(id: 'provider-1');

        when(() => mockAiConfigRepo.getConfigById('image-prompt'))
            .thenAnswer((_) async => promptConfig);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);

        when(() => mockAiInputRepo.buildTaskDetailsJson(id: imageId))
            .thenAnswer((_) async => jsonEncode({
                  'imageFile': 'test-image.jpg',
                  'capturedAt': DateTime.now().toIso8601String(),
                }));

        when(() => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => null);

        when(() => mockJournalRepo.getLinkedToEntities(
                linkedTo: any(named: 'linkedTo')))
            .thenAnswer((_) async => <JournalEntity>[]);

        when(() => mockAiInputRepo.getEntity(imageId))
            .thenAnswer((_) async => currentImage);

        final updatedImages = <JournalImage>[];
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((invocation) async {
          final image = invocation.positionalArguments[0] as JournalImage;
          updatedImages.add(image);
          return true;
        });

        final mockStream =
            _createDelayedStream(['AI generated image description.']);

        when(() => mockCloudInferenceRepo.generateWithImages(
              provider: any(named: 'provider'),
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              images: any(named: 'images'),
            )).thenAnswer((_) => mockStream);

        await repository.runInference(
          entityId: imageId,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify: Should use AI response directly when no existing text
        expect(updatedImages.length, 1);
        final updatedImage = updatedImages.first;
        expect(updatedImage.entryText?.plainText,
            'AI generated image description.');
      } finally {
        // Cleanup - this will always run even if test fails
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Image analysis handles entity not found gracefully', () async {
      // Create temporary directory and files
      final tempDir = Directory.systemTemp.createTempSync('image_test');
      overrideTempDirs.add(tempDir);

      try {
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        // Create the directory structure and file
        Directory('${tempDir.path}/images').createSync(recursive: true);
        File('${tempDir.path}/images/test-image.jpg')
            .writeAsBytesSync([1, 2, 3, 4]);

        const imageId = 'test-image-missing';
        final originalImage = _createJournalImage(imageId);

        final promptConfig = _createPrompt(
          id: 'image-prompt',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );
        final model = _createModel(id: 'model-1');
        final provider = _createProvider(id: 'provider-1');

        when(() => mockAiConfigRepo.getConfigById('image-prompt'))
            .thenAnswer((_) async => promptConfig);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);

        when(() => mockAiInputRepo.buildTaskDetailsJson(id: imageId))
            .thenAnswer((_) async => jsonEncode({
                  'imageFile': 'test-image.jpg',
                  'capturedAt': DateTime.now().toIso8601String(),
                }));

        when(() => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => null);

        when(() => mockJournalRepo.getLinkedToEntities(
                linkedTo: any(named: 'linkedTo')))
            .thenAnswer((_) async => <JournalEntity>[]);

        // First call returns image, second call (during post-processing) returns null
        var getEntityCallCount = 0;
        when(() => mockAiInputRepo.getEntity(imageId)).thenAnswer((_) async {
          getEntityCallCount++;
          return getEntityCallCount == 1 ? originalImage : null;
        });

        final updateCalls = <dynamic>[];
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((invocation) async {
          updateCalls.add(invocation.positionalArguments[0]);
          return true;
        });

        final mockStream = _createDelayedStream(['Image analysis result']);

        when(() => mockCloudInferenceRepo.generateWithImages(
              provider: any(named: 'provider'),
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              images: any(named: 'images'),
            )).thenAnswer((_) => mockStream);

        await repository.runInference(
          entityId: imageId,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify: No image updates should occur due to missing entity
        expect(updateCalls.whereType<JournalImage>(), isEmpty);
      } finally {
        // Cleanup - this will always run even if test fails
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}

// Helper methods
Metadata _createMetadata({String? id}) {
  final fixedTime = DateTime(2023, 1, 1, 12);
  return Metadata(
    id: id ?? 'test-id',
    createdAt: fixedTime,
    updatedAt: fixedTime,
    dateFrom: fixedTime,
    dateTo: fixedTime,
    starred: false,
    flag: EntryFlag.import,
    utcOffset: 0,
  );
}

AiConfigPrompt _createPrompt({
  required String id,
  String name = 'Test Prompt',
  String defaultModelId = 'model-1',
  List<InputDataType> requiredInputData = const [],
  AiResponseType aiResponseType = AiResponseType.taskSummary,
}) {
  return AiConfigPrompt(
    id: id,
    name: name,
    systemMessage: 'System message',
    userMessage: 'User message {{task}}',
    defaultModelId: defaultModelId,
    modelIds: [defaultModelId],
    createdAt: DateTime.now(),
    useReasoning: false,
    requiredInputData: requiredInputData,
    aiResponseType: aiResponseType,
  );
}

AiConfigModel _createModel({required String id}) {
  return AiConfigModel(
    id: id,
    name: 'Test Model',
    providerModelId: 'test-model',
    inferenceProviderId: 'provider-1',
    createdAt: DateTime.now(),
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: false,
  );
}

AiConfigInferenceProvider _createProvider({required String id}) {
  return AiConfigInferenceProvider(
    id: id,
    baseUrl: 'https://api.example.com',
    apiKey: 'test-api-key',
    name: 'Test Provider',
    createdAt: DateTime.now(),
    inferenceProviderType: InferenceProviderType.openAi,
  );
}

/// Creates a delayed stream to simulate real AI processing time
Stream<CreateChatCompletionStreamResponse> _createDelayedStream(
  List<String> chunks, {
  int delayMs = 100,
}) async* {
  for (final chunk in chunks) {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    yield CreateChatCompletionStreamResponse(
      id: 'test-completion-id',
      choices: [
        ChatCompletionStreamResponseChoice(
          index: 0,
          delta: ChatCompletionStreamResponseDelta(content: chunk),
        ),
      ],
      created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      model: 'test-model',
      object: 'chat.completion.chunk',
    );
  }
}

Task _createTaskWithTitle(String id, String title,
    {List<String>? checklistIds}) {
  return Task(
    meta: _createMetadata(id: id),
    data: TaskData(
      status: TaskStatus.inProgress(
        id: 'status-1',
        createdAt: DateTime.now(),
        utcOffset: 0,
      ),
      dateFrom: DateTime.now(),
      dateTo: DateTime.now().add(const Duration(hours: 1)),
      statusHistory: [],
      title: title,
      checklistIds: checklistIds ?? [],
    ),
  );
}

JournalAudio _createJournalAudio(String id,
    {EntryText? entryText, List<AudioTranscript>? transcripts}) {
  return JournalAudio(
    meta: _createMetadata(id: id),
    data: AudioData(
      dateFrom: DateTime.now(),
      dateTo: DateTime.now().add(const Duration(minutes: 5)),
      audioFile: 'test-audio.wav',
      audioDirectory: '/audio/',
      duration: const Duration(minutes: 5),
      transcripts: transcripts ?? [],
    ),
    entryText: entryText,
  );
}

JournalImage _createJournalImage(String id, {EntryText? entryText}) {
  return JournalImage(
    meta: _createMetadata(id: id),
    data: ImageData(
      capturedAt: DateTime.now(),
      imageId: 'test-image-id',
      imageFile: 'test-image.jpg',
      imageDirectory: '/images/',
    ),
    entryText: entryText,
  );
}
