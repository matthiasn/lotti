import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../mocks/mocks.dart';

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

/// Entry controller that returns null (entity not found).
class FakeEntryControllerNull extends EntryController {
  @override
  Future<EntryState?> build({required String id}) async => null;
}

void main() {
  late ProviderContainer container;
  final containersToDispose = <ProviderContainer>[];
  late MockUnifiedAiInferenceRepository mockRepository;
  late MockLoggingService mockLoggingService;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockCategoryRepository mockCategoryRepository;
  late MockEditorStateService mockEditorStateService;
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;

  setUpAll(() {
    registerFallbackValue(FakeAiConfigPrompt());
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(
      const AutomationResult(handled: true),
    );
    // Register a fallback for JournalEntity (sealed class, use real type)
    registerFallbackValue(
      JournalEntry(
        meta: Metadata(
          id: 'fallback-entry',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      ),
    );
  });

  setUp(() {
    mockRepository = MockUnifiedAiInferenceRepository();
    mockLoggingService = MockLoggingService();
    mockAiConfigRepository = MockAiConfigRepository();
    mockCategoryRepository = MockCategoryRepository();
    mockEditorStateService = MockEditorStateService();
    mockJournalDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockUpdateNotifications = MockUpdateNotifications();

    // Set up mock behavior for UpdateNotifications
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    if (getIt.isRegistered<AiConfigRepository>()) {
      getIt.unregister<AiConfigRepository>();
    }
    getIt.registerSingleton<AiConfigRepository>(mockAiConfigRepository);

    if (getIt.isRegistered<EditorStateService>()) {
      getIt.unregister<EditorStateService>();
    }
    getIt.registerSingleton<EditorStateService>(mockEditorStateService);

    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    getIt.registerSingleton<JournalDb>(mockJournalDb);

    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
    getIt.registerSingleton<PersistenceLogic>(mockPersistenceLogic);

    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    // Set up default mock behavior for AI config repository
    when(
      () => mockAiConfigRepository.watchConfigsByType(AiConfigType.prompt),
    ).thenAnswer((_) => Stream.value([]));

    container = ProviderContainer(
      overrides: [
        unifiedAiInferenceRepositoryProvider.overrideWithValue(mockRepository),
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
      ],
    );

    // Mock logging methods
    when(
      () => mockLoggingService.captureEvent(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    // Dispose all containers created during tests
    for (final c in containersToDispose) {
      c.dispose();
    }
    containersToDispose.clear();
    container.dispose();
  });

  group('UnifiedAiController', () {
    test('successfully runs inference and updates state', () {
      fakeAsync((async) {
        final promptConfig = AiConfigPrompt(
          id: 'prompt-1',
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'User',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );

        final progressUpdates = <String>[];
        var statusChangeCount = 0;
        final stateUpdates = <String>[];

        // Override the aiConfigByIdProvider to return our test prompt
        final testContainer = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            aiConfigByIdProvider('prompt-1').overrideWith(
              (ref) => Future.value(promptConfig),
            ),
          ],
        );
        containersToDispose.add(testContainer);

        when(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).thenAnswer((invocation) async {
          final onProgress =
              invocation.namedArguments[#onProgress] as void Function(String);
          final onStatusChange =
              invocation.namedArguments[#onStatusChange]
                  as void Function(InferenceStatus);

          // Simulate progress updates
          onStatusChange(InferenceStatus.running);
          statusChangeCount++;
          onProgress('Starting inference...');
          progressUpdates.add('Starting inference...');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          onProgress('Processing...');
          progressUpdates.add('Processing...');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          onProgress('Complete!');
          progressUpdates.add('Complete!');
          onStatusChange(InferenceStatus.idle);
          statusChangeCount++;
        });

        // Listen to the provider to capture state updates
        final subscription = testContainer.listen(
          unifiedAiControllerProvider((
            entityId: 'test-entity',
            promptId: 'prompt-1',
          )),
          (previous, next) {
            stateUpdates.add(next.message);
          },
          fireImmediately: true,
        );

        // Trigger inference explicitly since it no longer runs automatically
        testContainer.read(
          triggerNewInferenceProvider((
            entityId: 'test-entity',
            promptId: 'prompt-1',
            linkedEntityId: null,
          )).future,
        );

        // Drive async execution through all delays
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 10))
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 10))
          ..flushMicrotasks();

        // Verify inference was called
        verify(
          () => mockRepository.runInference(
            entityId: 'test-entity',
            promptConfig: promptConfig,
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).called(1);

        // Verify progress updates
        expect(progressUpdates.length, 3);
        expect(progressUpdates, [
          'Starting inference...',
          'Processing...',
          'Complete!',
        ]);

        // Verify status changes
        expect(statusChangeCount, 2);

        // Verify state updates
        expect(stateUpdates.contains(''), true); // Initial state
        expect(stateUpdates.contains('Starting inference...'), true);
        expect(stateUpdates.contains('Processing...'), true);
        expect(stateUpdates.contains('Complete!'), true);

        // Clean up
        subscription.close();
      });
    });

    test('deduplicates concurrent inference requests', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime(2024, 3, 15),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        // ignore: deprecated_member_use_from_same_package
        aiResponseType: AiResponseType.taskSummary,
      );

      final completer = Completer<void>();
      var runCount = 0;

      final testContainer = ProviderContainer(
        overrides: [
          unifiedAiInferenceRepositoryProvider.overrideWithValue(
            mockRepository,
          ),
          aiConfigByIdProvider('prompt-1').overrideWith(
            (ref) => Future.value(promptConfig),
          ),
        ],
      );
      containersToDispose.add(testContainer);

      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
          linkedEntityId: any(named: 'linkedEntityId'),
        ),
      ).thenAnswer((invocation) async {
        runCount++;
        final onStatusChange =
            invocation.namedArguments[#onStatusChange]
                as void Function(InferenceStatus);
        onStatusChange(InferenceStatus.running);
        await completer.future;
        onStatusChange(InferenceStatus.idle);
      });

      final future1 = testContainer.read(
        triggerNewInferenceProvider((
          entityId: 'test-entity',
          promptId: 'prompt-1',
          linkedEntityId: null,
        )).future,
      );

      final future2 = testContainer.read(
        triggerNewInferenceProvider((
          entityId: 'test-entity',
          promptId: 'prompt-1',
          linkedEntityId: null,
        )).future,
      );

      expect(future1, same(future2));

      completer.complete();

      await Future.wait([future1, future2]);

      verify(
        () => mockRepository.runInference(
          entityId: 'test-entity',
          promptConfig: promptConfig,
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
          linkedEntityId: any(named: 'linkedEntityId'),
        ),
      ).called(1);
      expect(runCount, 1);
    });

    test('handles errors during inference', () {
      fakeAsync((async) {
        final promptConfig = AiConfigPrompt(
          id: 'prompt-1',
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'User',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );

        final stateUpdates = <String>[];

        // Override the aiConfigByIdProvider to return our test prompt
        container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            aiConfigByIdProvider('prompt-1').overrideWith(
              (ref) => Future.value(promptConfig),
            ),
          ],
        );

        when(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).thenAnswer((invocation) async {
          final onStatusChange =
              invocation.namedArguments[#onStatusChange]
                  as void Function(InferenceStatus);
          onStatusChange(InferenceStatus.running);
          throw Exception('Test error');
        });

        // Listen to the provider to capture state updates
        final subscription = container.listen(
          unifiedAiControllerProvider((
            entityId: 'test-entity',
            promptId: 'prompt-1',
          )),
          (previous, next) {
            stateUpdates.add(next.message);
          },
          fireImmediately: true,
        );

        // Trigger inference explicitly since it no longer runs automatically
        container.read(
          triggerNewInferenceProvider((
            entityId: 'test-entity',
            promptId: 'prompt-1',
            linkedEntityId: null,
          )).future,
        );

        // Drive async execution
        async.flushMicrotasks();

        // Verify error handling
        verify(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'UnifiedAiController',
            subDomain: 'runInference',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);

        // Verify state updates - should contain error message
        expect(
          stateUpdates.any((s) => s.contains('error') || s.contains('Error')),
          true,
        );

        // Clean up
        subscription.close();
      });
    });
  });

  group('hasAvailableSkills provider', () {
    test('returns true when skills are available', () async {
      final audioEntity = JournalAudio(
        meta: Metadata(
          id: 'audio-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: AudioData(
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          audioFile: 'test.mp3',
          audioDirectory: '/test',
          duration: const Duration(minutes: 5),
        ),
      );

      final transcriptionSkill =
          AiConfig.skill(
                id: 'skill-transcription',
                name: 'Transcription',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.transcription,
                requiredInputModalities: [Modality.audio],
                systemInstructions: 'System',
                userInstructions: 'User',
              )
              as AiConfigSkill;

      // Mock the AI config stream for skills
      when(
        () => mockAiConfigRepository.watchConfigsByType(AiConfigType.skill),
      ).thenAnswer((_) => Stream.value([transcriptionSkill]));

      // Create container with entry controller override
      final testContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
          createEntryControllerOverride(audioEntity),
        ],
      );
      containersToDispose.add(testContainer);

      // Keep aiConfigByTypeController alive during the test
      final skillConfigSub = testContainer.listen(
        aiConfigByTypeControllerProvider(configType: AiConfigType.skill),
        (_, _) {},
      );

      // Wait for entry controller to be ready
      await testContainer.read(
        entryControllerProvider(id: audioEntity.id).future,
      );

      // Wait for config provider to be ready
      await testContainer.read(
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.skill,
        ).future,
      );

      final hasSkills = await testContainer.read(
        hasAvailableSkillsProvider(audioEntity.id).future,
      );

      expect(hasSkills, true);
      skillConfigSub.close();
    });

    test('returns false when no skills are available', () async {
      final journalEntry = JournalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );

      // Mock the AI config stream for skills with empty list
      when(
        () => mockAiConfigRepository.watchConfigsByType(AiConfigType.skill),
      ).thenAnswer((_) => Stream.value([]));

      // Create container with entry controller override
      final testContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
          createEntryControllerOverride(journalEntry),
        ],
      );
      containersToDispose.add(testContainer);

      // Keep aiConfigByTypeController alive during the test
      final skillConfigSub = testContainer.listen(
        aiConfigByTypeControllerProvider(configType: AiConfigType.skill),
        (_, _) {},
      );

      // Wait for entry controller to be ready
      await testContainer.read(
        entryControllerProvider(id: journalEntry.id).future,
      );

      // Wait for config provider to be ready
      await testContainer.read(
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.skill,
        ).future,
      );

      final hasSkills = await testContainer.read(
        hasAvailableSkillsProvider(journalEntry.id).future,
      );

      expect(hasSkills, false);
      skillConfigSub.close();
    });
  });

  group('triggerNewInference provider', () {
    test('triggers inference when called', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime(2024, 3, 15),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        // ignore: deprecated_member_use_from_same_package
        aiResponseType: AiResponseType.taskSummary,
      );

      // Override the aiConfigByIdProvider to return our test prompt
      container = ProviderContainer(
        overrides: [
          unifiedAiInferenceRepositoryProvider.overrideWithValue(
            mockRepository,
          ),
          aiConfigByIdProvider('prompt-1').overrideWith(
            (ref) => Future.value(promptConfig),
          ),
        ],
      );

      var runInferenceCallCount = 0;

      // Set up mock for runInference
      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
          linkedEntityId: any(named: 'linkedEntityId'),
        ),
      ).thenAnswer((invocation) async {
        runInferenceCallCount++;
      });

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider((
          entityId: 'test-entity',
          promptId: 'prompt-1',
          linkedEntityId: null,
        )).future,
      );

      // Verify inference was called
      expect(runInferenceCallCount, 1);

      verify(
        () => mockRepository.runInference(
          entityId: 'test-entity',
          promptConfig: promptConfig,
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
          linkedEntityId: any(named: 'linkedEntityId'),
        ),
      ).called(1);
    });

    test('updates inference status for linked entity when provided', () {
      fakeAsync((async) {
        final promptConfig = AiConfigPrompt(
          id: 'prompt-1',
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'User',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.audioTranscription,
        );

        // Override the aiConfigByIdProvider to return our test prompt
        container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            aiConfigByIdProvider('prompt-1').overrideWith(
              (ref) => Future.value(promptConfig),
            ),
          ],
        );

        // Track status updates for both entities
        final mainEntityStatuses = <InferenceStatus>[];
        final linkedEntityStatuses = <InferenceStatus>[];

        // Listen to inference status for main entity
        container
          ..listen(
            inferenceStatusControllerProvider(
              id: 'audio-entry-id',
              aiResponseType: AiResponseType.audioTranscription,
            ),
            (previous, next) {
              mainEntityStatuses.add(next);
            },
            fireImmediately: true,
          )
          // Listen to inference status for linked entity
          ..listen(
            inferenceStatusControllerProvider(
              id: 'linked-task-id',
              aiResponseType: AiResponseType.audioTranscription,
            ),
            (previous, next) {
              linkedEntityStatuses.add(next);
            },
            fireImmediately: true,
          );

        // Set up mock for runInference
        when(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).thenAnswer((invocation) async {
          final onStatusChange =
              invocation.namedArguments[#onStatusChange]
                  as void Function(InferenceStatus);

          // Simulate status changes
          onStatusChange(InferenceStatus.running);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          onStatusChange(InferenceStatus.idle);
        });

        // Trigger inference with linkedEntityId
        container.read(
          triggerNewInferenceProvider((
            entityId: 'audio-entry-id',
            promptId: 'prompt-1',
            linkedEntityId: 'linked-task-id',
          )).future,
        );

        // Drive async execution through the delay
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 10))
          ..flushMicrotasks();

        // Both entities should have received the same status updates
        expect(mainEntityStatuses, contains(InferenceStatus.idle));
        expect(mainEntityStatuses, contains(InferenceStatus.running));
        expect(linkedEntityStatuses, contains(InferenceStatus.idle));
        expect(linkedEntityStatuses, contains(InferenceStatus.running));
      });
    });

    test('updates error status for linked entity on failure', () {
      fakeAsync((async) {
        final promptConfig = AiConfigPrompt(
          id: 'prompt-1',
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'User',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.audioTranscription,
        );

        // Override the aiConfigByIdProvider to return our test prompt
        container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            aiConfigByIdProvider('prompt-1').overrideWith(
              (ref) => Future.value(promptConfig),
            ),
          ],
        );

        // Track status updates for both entities
        final mainEntityStatuses = <InferenceStatus>[];
        final linkedEntityStatuses = <InferenceStatus>[];

        // Listen to inference status for main entity
        container
          ..listen(
            inferenceStatusControllerProvider(
              id: 'audio-entry-id',
              aiResponseType: AiResponseType.audioTranscription,
            ),
            (previous, next) {
              mainEntityStatuses.add(next);
            },
            fireImmediately: true,
          )
          // Listen to inference status for linked entity
          ..listen(
            inferenceStatusControllerProvider(
              id: 'linked-task-id',
              aiResponseType: AiResponseType.audioTranscription,
            ),
            (previous, next) {
              linkedEntityStatuses.add(next);
            },
            fireImmediately: true,
          );

        // Set up mock for runInference to fail
        when(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).thenAnswer((invocation) async {
          final onStatusChange =
              invocation.namedArguments[#onStatusChange]
                  as void Function(InferenceStatus);

          // Simulate running status then error
          onStatusChange(InferenceStatus.running);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw Exception('Test error');
        });

        // Trigger inference with linkedEntityId
        container.read(
          triggerNewInferenceProvider((
            entityId: 'audio-entry-id',
            promptId: 'prompt-1',
            linkedEntityId: 'linked-task-id',
          )).future,
        );

        // Drive async execution through the delay
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 10))
          ..flushMicrotasks();

        // Both entities should have error status
        expect(mainEntityStatuses, contains(InferenceStatus.running));
        expect(mainEntityStatuses, contains(InferenceStatus.error));
        expect(linkedEntityStatuses, contains(InferenceStatus.running));
        expect(linkedEntityStatuses, contains(InferenceStatus.error));
      });
    });
  });

  group('categoryChanges provider', () {
    test('returns stream of category changes', () async {
      const categoryId = 'test-category';
      final categoryChangesStream = StreamController<CategoryDefinition>();

      final testCategory = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        private: false,
        active: true,
      );

      when(
        () => mockCategoryRepository.watchCategory(categoryId),
      ).thenAnswer((_) => categoryChangesStream.stream);

      // Start listening to the provider
      final subscription = container.listen(
        categoryChangesProvider(categoryId),
        (previous, next) {},
      );

      // Verify watchCategory was called
      verify(() => mockCategoryRepository.watchCategory(categoryId)).called(1);

      // Emit a change
      categoryChangesStream.add(testCategory);

      // Clean up
      await categoryChangesStream.close();
      subscription.close();
    });
  });

  group('availableSkillsForEntityProvider', () {
    AiConfigSkill createSkill({
      required String id,
      required String name,
      required SkillType skillType,
      required List<Modality> modalities,
      String? description,
    }) {
      return AiConfig.skill(
            id: id,
            name: name,
            createdAt: DateTime(2024, 3, 15),
            skillType: skillType,
            requiredInputModalities: modalities,
            systemInstructions: 'System instructions for $name',
            userInstructions: 'User instructions for $name',
            description: description,
          )
          as AiConfigSkill;
    }

    test(
      'returns skills matching audio modality for JournalAudio entities',
      () async {
        final audioEntity = JournalAudio(
          meta: Metadata(
            id: 'audio-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            audioFile: 'test.mp3',
            audioDirectory: '/test',
            duration: const Duration(minutes: 5),
          ),
        );

        final transcriptionSkill = createSkill(
          id: 'skill-transcription',
          name: 'Transcription',
          skillType: SkillType.transcription,
          modalities: [Modality.audio],
        );
        final promptSkill = createSkill(
          id: 'skill-prompt',
          name: 'Coding Prompt',
          skillType: SkillType.promptGeneration,
          modalities: [Modality.audio],
        );

        when(
          () => mockAiConfigRepository.watchConfigsByType(AiConfigType.skill),
        ).thenAnswer(
          (_) => Stream.value([transcriptionSkill, promptSkill]),
        );

        final testContainer = ProviderContainer(
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(
              mockAiConfigRepository,
            ),
            createEntryControllerOverride(audioEntity),
          ],
        );
        containersToDispose.add(testContainer);

        final skillSub = testContainer.listen(
          aiConfigByTypeControllerProvider(configType: AiConfigType.skill),
          (_, _) {},
        );

        await testContainer.read(
          entryControllerProvider(id: audioEntity.id).future,
        );
        await testContainer.read(
          aiConfigByTypeControllerProvider(
            configType: AiConfigType.skill,
          ).future,
        );

        final skills = await testContainer.read(
          availableSkillsForEntityProvider(audioEntity.id).future,
        );

        // Both transcription and promptGeneration require audio modality
        // and pass the filter for JournalAudio entities.
        expect(skills.length, 2);
        expect(skills.map((s) => s.id), contains('skill-transcription'));
        expect(skills.map((s) => s.id), contains('skill-prompt'));
        skillSub.close();
      },
    );

    test(
      'returns skills matching image modality for JournalImage entities',
      () async {
        final imageEntity = JournalImage(
          meta: Metadata(
            id: 'image-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15),
            imageId: 'img-1',
            imageFile: 'test.jpg',
            imageDirectory: '/test',
          ),
        );

        final imageSkill = createSkill(
          id: 'skill-image',
          name: 'Image Analysis',
          skillType: SkillType.imageAnalysis,
          modalities: [Modality.image],
        );
        final promptSkill = createSkill(
          id: 'skill-prompt',
          name: 'Coding Prompt',
          skillType: SkillType.promptGeneration,
          modalities: [Modality.audio],
        );

        when(
          () => mockAiConfigRepository.watchConfigsByType(AiConfigType.skill),
        ).thenAnswer((_) => Stream.value([imageSkill, promptSkill]));

        final testContainer = ProviderContainer(
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(
              mockAiConfigRepository,
            ),
            createEntryControllerOverride(imageEntity),
          ],
        );
        containersToDispose.add(testContainer);

        final skillSub = testContainer.listen(
          aiConfigByTypeControllerProvider(configType: AiConfigType.skill),
          (_, _) {},
        );

        await testContainer.read(
          entryControllerProvider(id: imageEntity.id).future,
        );
        await testContainer.read(
          aiConfigByTypeControllerProvider(
            configType: AiConfigType.skill,
          ).future,
        );

        final skills = await testContainer.read(
          availableSkillsForEntityProvider(imageEntity.id).future,
        );

        // Only imageAnalysis passes — promptGeneration requires audio
        // modality, which is filtered out for JournalImage entities.
        expect(skills.length, 1);
        expect(skills.map((s) => s.id), contains('skill-image'));
        skillSub.close();
      },
    );

    test('filters out audio-only skills for non-audio entities', () async {
      final taskEntity = Task(
        meta: Metadata(
          id: 'task-filter',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );

      final audioOnlySkill = createSkill(
        id: 'skill-audio-only',
        name: 'Transcription',
        skillType: SkillType.transcription,
        modalities: [Modality.audio],
      );
      final promptSkill = createSkill(
        id: 'skill-prompt',
        name: 'Coding Prompt',
        skillType: SkillType.promptGeneration,
        modalities: [Modality.audio],
      );

      when(
        () => mockAiConfigRepository.watchConfigsByType(AiConfigType.skill),
      ).thenAnswer((_) => Stream.value([audioOnlySkill, promptSkill]));

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
          createEntryControllerOverride(taskEntity),
        ],
      );
      containersToDispose.add(testContainer);

      final skillSub = testContainer.listen(
        aiConfigByTypeControllerProvider(configType: AiConfigType.skill),
        (_, _) {},
      );

      await testContainer.read(
        entryControllerProvider(id: taskEntity.id).future,
      );
      await testContainer.read(
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.skill,
        ).future,
      );

      final skills = await testContainer.read(
        availableSkillsForEntityProvider(taskEntity.id).future,
      );

      // Both audio-only skills are filtered out for Task entities —
      // transcription and promptGeneration both require audio modality.
      expect(skills, isEmpty);
      skillSub.close();
    });

    test('filters out image-only skills for non-image entities', () async {
      final taskEntity = Task(
        meta: Metadata(
          id: 'task-filter-img',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );

      final imageOnlySkill = createSkill(
        id: 'skill-image-only',
        name: 'Image Analysis',
        skillType: SkillType.imageAnalysis,
        modalities: [Modality.image],
      );

      when(
        () => mockAiConfigRepository.watchConfigsByType(AiConfigType.skill),
      ).thenAnswer((_) => Stream.value([imageOnlySkill]));

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
          createEntryControllerOverride(taskEntity),
        ],
      );
      containersToDispose.add(testContainer);

      final skillSub = testContainer.listen(
        aiConfigByTypeControllerProvider(configType: AiConfigType.skill),
        (_, _) {},
      );

      await testContainer.read(
        entryControllerProvider(id: taskEntity.id).future,
      );
      await testContainer.read(
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.skill,
        ).future,
      );

      final skills = await testContainer.read(
        availableSkillsForEntityProvider(taskEntity.id).future,
      );

      expect(skills, isEmpty);
      skillSub.close();
    });

    test('returns empty list when no skills configured', () async {
      final taskEntity = Task(
        meta: Metadata(
          id: 'task-no-skills',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );

      when(
        () => mockAiConfigRepository.watchConfigsByType(AiConfigType.skill),
      ).thenAnswer((_) => Stream.value([]));

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
          createEntryControllerOverride(taskEntity),
        ],
      );
      containersToDispose.add(testContainer);

      final skillSub = testContainer.listen(
        aiConfigByTypeControllerProvider(configType: AiConfigType.skill),
        (_, _) {},
      );

      await testContainer.read(
        entryControllerProvider(id: taskEntity.id).future,
      );
      await testContainer.read(
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.skill,
        ).future,
      );

      final skills = await testContainer.read(
        availableSkillsForEntityProvider(taskEntity.id).future,
      );

      expect(skills, isEmpty);
      skillSub.close();
    });

    test('returns empty list when entity not found', () async {
      when(
        () => mockAiConfigRepository.watchConfigsByType(AiConfigType.skill),
      ).thenAnswer((_) => Stream.value([]));

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
          // No entry controller override — entity will not be found
          entryControllerProvider(id: 'nonexistent').overrideWith(
            FakeEntryControllerNull.new,
          ),
        ],
      );
      containersToDispose.add(testContainer);

      final provider = availableSkillsForEntityProvider('nonexistent');
      final completer = Completer<void>();
      testContainer.listen(provider, (_, next) {
        if (next.hasValue && !completer.isCompleted) completer.complete();
      });
      await completer.future;

      final skills = testContainer.read(provider).value;
      expect(skills, isEmpty);
    });
  });

  group('triggerSkillProvider', () {
    late MockProfileAutomationResolver mockResolver;
    late MockSkillInferenceRunner mockRunner;

    setUp(() {
      mockResolver = MockProfileAutomationResolver();
      mockRunner = MockSkillInferenceRunner();
    });

    test('returns early when skill not found', () async {
      final testContainer = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('nonexistent-skill').overrideWith(
            (ref) => Future<AiConfig?>.value(),
          ),
          profileAutomationResolverProvider.overrideWithValue(mockResolver),
          skillInferenceRunnerProvider.overrideWithValue(mockRunner),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        triggerSkillProvider((
          entityId: 'entity-1',
          skillId: 'nonexistent-skill',
          linkedTaskId: 'task-1',
          referenceImages: null,
        )).future,
      );

      // Should return early without invoking the runner
      verifyZeroInteractions(mockRunner);
    });

    test('returns early when no linkedTaskId provided', () async {
      final skill =
          AiConfig.skill(
                id: 'skill-1',
                name: 'Test Skill',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.transcription,
                requiredInputModalities: [Modality.audio],
                systemInstructions: 'System',
                userInstructions: 'User',
              )
              as AiConfigSkill;

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('skill-1').overrideWith(
            (ref) => Future<AiConfig?>.value(skill),
          ),
          profileAutomationResolverProvider.overrideWithValue(mockResolver),
          skillInferenceRunnerProvider.overrideWithValue(mockRunner),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        triggerSkillProvider((
          entityId: 'entity-1',
          skillId: 'skill-1',
          linkedTaskId: null,
          referenceImages: null,
        )).future,
      );

      // Should return early without invoking the runner
      verifyZeroInteractions(mockRunner);
    });

    test('returns early when no profile configured for task', () async {
      final skill =
          AiConfig.skill(
                id: 'skill-2',
                name: 'Transcription',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.transcription,
                requiredInputModalities: [Modality.audio],
                systemInstructions: 'System',
                userInstructions: 'User',
              )
              as AiConfigSkill;

      when(
        () => mockResolver.resolveForTask('task-no-profile'),
      ).thenAnswer((_) async => null);

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('skill-2').overrideWith(
            (ref) => Future<AiConfig?>.value(skill),
          ),
          profileAutomationResolverProvider.overrideWithValue(mockResolver),
          skillInferenceRunnerProvider.overrideWithValue(mockRunner),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        triggerSkillProvider((
          entityId: 'audio-1',
          skillId: 'skill-2',
          linkedTaskId: 'task-no-profile',
          referenceImages: null,
        )).future,
      );

      // Should return early without invoking the runner
      verifyZeroInteractions(mockRunner);
    });

    test('successfully routes transcription skill to runner', () async {
      final skill =
          AiConfig.skill(
                id: 'skill-transcribe',
                name: 'Transcription',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.transcription,
                requiredInputModalities: [Modality.audio],
                systemInstructions: 'System',
                userInstructions: 'User',
              )
              as AiConfigSkill;

      final thinkingProvider =
          AiConfig.inferenceProvider(
                id: 'anthropic-prov',
                name: 'Anthropic',
                inferenceProviderType: InferenceProviderType.anthropic,
                apiKey: 'key',
                baseUrl: 'https://api.anthropic.com',
                createdAt: DateTime(2024, 3, 15),
              )
              as AiConfigInferenceProvider;
      final transcriptionProvider =
          AiConfig.inferenceProvider(
                id: 'gemini-prov',
                name: 'Gemini',
                inferenceProviderType: InferenceProviderType.gemini,
                apiKey: 'key',
                baseUrl: 'https://api.google.com',
                createdAt: DateTime(2024, 3, 15),
              )
              as AiConfigInferenceProvider;

      final resolvedProfile = ResolvedProfile(
        thinkingModelId: 'thinking-model',
        thinkingProvider: thinkingProvider,
        transcriptionModelId: 'transcription-model',
        transcriptionProvider: transcriptionProvider,
      );

      when(
        () => mockResolver.resolveForTask('task-1'),
      ).thenAnswer((_) async => resolvedProfile);

      when(
        () => mockRunner.runTranscription(
          audioEntryId: any(named: 'audioEntryId'),
          automationResult: any(named: 'automationResult'),
          linkedTaskId: any(named: 'linkedTaskId'),
        ),
      ).thenAnswer((_) async {});

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('skill-transcribe').overrideWith(
            (ref) => Future<AiConfig?>.value(skill),
          ),
          profileAutomationResolverProvider.overrideWithValue(mockResolver),
          skillInferenceRunnerProvider.overrideWithValue(mockRunner),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        triggerSkillProvider((
          entityId: 'audio-entry-1',
          skillId: 'skill-transcribe',
          linkedTaskId: 'task-1',
          referenceImages: null,
        )).future,
      );

      verify(
        () => mockRunner.runTranscription(
          audioEntryId: 'audio-entry-1',
          automationResult: any(named: 'automationResult'),
          linkedTaskId: 'task-1',
        ),
      ).called(1);
    });

    test('successfully routes image analysis skill to runner', () async {
      final skill =
          AiConfig.skill(
                id: 'skill-image',
                name: 'Image Analysis',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.imageAnalysis,
                requiredInputModalities: [Modality.image],
                systemInstructions: 'System',
                userInstructions: 'User',
              )
              as AiConfigSkill;

      final thinkingProvider =
          AiConfig.inferenceProvider(
                id: 'anthropic-prov',
                name: 'Anthropic',
                inferenceProviderType: InferenceProviderType.anthropic,
                apiKey: 'key',
                baseUrl: 'https://api.anthropic.com',
                createdAt: DateTime(2024, 3, 15),
              )
              as AiConfigInferenceProvider;
      final imageRecognitionProvider =
          AiConfig.inferenceProvider(
                id: 'openai-prov',
                name: 'OpenAI',
                inferenceProviderType: InferenceProviderType.openAi,
                apiKey: 'key',
                baseUrl: 'https://api.openai.com',
                createdAt: DateTime(2024, 3, 15),
              )
              as AiConfigInferenceProvider;

      final resolvedProfile = ResolvedProfile(
        thinkingModelId: 'thinking-model',
        thinkingProvider: thinkingProvider,
        imageRecognitionModelId: 'image-model',
        imageRecognitionProvider: imageRecognitionProvider,
      );

      when(
        () => mockResolver.resolveForTask('task-img'),
      ).thenAnswer((_) async => resolvedProfile);

      when(
        () => mockRunner.runImageAnalysis(
          imageEntryId: any(named: 'imageEntryId'),
          automationResult: any(named: 'automationResult'),
          linkedTaskId: any(named: 'linkedTaskId'),
        ),
      ).thenAnswer((_) async {});

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('skill-image').overrideWith(
            (ref) => Future<AiConfig?>.value(skill),
          ),
          profileAutomationResolverProvider.overrideWithValue(mockResolver),
          skillInferenceRunnerProvider.overrideWithValue(mockRunner),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        triggerSkillProvider((
          entityId: 'image-entry-1',
          skillId: 'skill-image',
          linkedTaskId: 'task-img',
          referenceImages: null,
        )).future,
      );

      verify(
        () => mockRunner.runImageAnalysis(
          imageEntryId: 'image-entry-1',
          automationResult: any(named: 'automationResult'),
          linkedTaskId: 'task-img',
        ),
      ).called(1);
    });

    test('successfully routes prompt generation skill to runner', () async {
      final skill =
          AiConfig.skill(
                id: 'skill-prompt',
                name: 'Generate Coding Prompt',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.promptGeneration,
                requiredInputModalities: [Modality.audio],
                systemInstructions: 'System',
                userInstructions: 'User',
              )
              as AiConfigSkill;

      final thinkingProvider =
          AiConfig.inferenceProvider(
                id: 'gemini-prov',
                name: 'Gemini',
                inferenceProviderType: InferenceProviderType.gemini,
                apiKey: 'key',
                baseUrl: 'https://generativelanguage.googleapis.com',
                createdAt: DateTime(2024, 3, 15),
              )
              as AiConfigInferenceProvider;

      final resolvedProfile = ResolvedProfile(
        thinkingModelId: 'flash',
        thinkingProvider: thinkingProvider,
      );

      when(
        () => mockResolver.resolveForTask('task-prompt'),
      ).thenAnswer((_) async => resolvedProfile);

      when(
        () => mockRunner.runPromptGeneration(
          audioEntryId: any(named: 'audioEntryId'),
          automationResult: any(named: 'automationResult'),
          linkedTaskId: any(named: 'linkedTaskId'),
        ),
      ).thenAnswer((_) async {});

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('skill-prompt').overrideWith(
            (ref) => Future<AiConfig?>.value(skill),
          ),
          profileAutomationResolverProvider.overrideWithValue(mockResolver),
          skillInferenceRunnerProvider.overrideWithValue(mockRunner),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        triggerSkillProvider((
          entityId: 'audio-entry-2',
          skillId: 'skill-prompt',
          linkedTaskId: 'task-prompt',
          referenceImages: null,
        )).future,
      );

      verify(
        () => mockRunner.runPromptGeneration(
          audioEntryId: 'audio-entry-2',
          automationResult: any(named: 'automationResult'),
          linkedTaskId: 'task-prompt',
        ),
      ).called(1);
    });

    test('successfully routes image generation skill to runner', () async {
      final skill =
          AiConfig.skill(
                id: 'skill-imggen',
                name: 'Generate Cover Art',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.imageGeneration,
                requiredInputModalities: [Modality.text],
                contextPolicy: ContextPolicy.fullTask,
                systemInstructions: 'System',
                userInstructions: 'User',
              )
              as AiConfigSkill;

      final imageGenProvider =
          AiConfig.inferenceProvider(
                id: 'gemini-prov',
                name: 'Gemini',
                inferenceProviderType: InferenceProviderType.gemini,
                apiKey: 'key',
                baseUrl: 'https://generativelanguage.googleapis.com',
                createdAt: DateTime(2024, 3, 15),
              )
              as AiConfigInferenceProvider;

      final resolvedProfile = ResolvedProfile(
        thinkingModelId: 'flash',
        thinkingProvider: imageGenProvider,
        imageGenerationModelId: 'imagen-model',
        imageGenerationProvider: imageGenProvider,
      );

      when(
        () => mockResolver.resolveForTask('task-imggen'),
      ).thenAnswer((_) async => resolvedProfile);

      when(
        () => mockRunner.runImageGeneration(
          audioEntryId: any(named: 'audioEntryId'),
          automationResult: any(named: 'automationResult'),
          linkedTaskId: any(named: 'linkedTaskId'),
          referenceImages: any(named: 'referenceImages'),
        ),
      ).thenAnswer((_) async {});

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('skill-imggen').overrideWith(
            (ref) => Future<AiConfig?>.value(skill),
          ),
          profileAutomationResolverProvider.overrideWithValue(mockResolver),
          skillInferenceRunnerProvider.overrideWithValue(mockRunner),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        triggerSkillProvider((
          entityId: 'audio-entry-3',
          skillId: 'skill-imggen',
          linkedTaskId: 'task-imggen',
          referenceImages: null,
        )).future,
      );

      verify(
        () => mockRunner.runImageGeneration(
          audioEntryId: 'audio-entry-3',
          automationResult: any(named: 'automationResult'),
          linkedTaskId: 'task-imggen',
          // ignore: avoid_redundant_argument_values
          referenceImages: null,
        ),
      ).called(1);
    });

    test('passes reference images to image generation runner', () async {
      final skill =
          AiConfig.skill(
                id: 'skill-imggen2',
                name: 'Generate Cover Art',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.imageGeneration,
                requiredInputModalities: [Modality.text],
                contextPolicy: ContextPolicy.fullTask,
                systemInstructions: 'System',
                userInstructions: 'User',
              )
              as AiConfigSkill;

      final imageGenProvider =
          AiConfig.inferenceProvider(
                id: 'gemini-prov',
                name: 'Gemini',
                inferenceProviderType: InferenceProviderType.gemini,
                apiKey: 'key',
                baseUrl: 'https://generativelanguage.googleapis.com',
                createdAt: DateTime(2024, 3, 15),
              )
              as AiConfigInferenceProvider;

      final resolvedProfile = ResolvedProfile(
        thinkingModelId: 'flash',
        thinkingProvider: imageGenProvider,
        imageGenerationModelId: 'imagen-model',
        imageGenerationProvider: imageGenProvider,
      );

      when(
        () => mockResolver.resolveForTask('task-imggen2'),
      ).thenAnswer((_) async => resolvedProfile);

      when(
        () => mockRunner.runImageGeneration(
          audioEntryId: any(named: 'audioEntryId'),
          automationResult: any(named: 'automationResult'),
          linkedTaskId: any(named: 'linkedTaskId'),
          referenceImages: any(named: 'referenceImages'),
        ),
      ).thenAnswer((_) async {});

      const refImages = [
        ProcessedReferenceImage(
          base64Data: 'abc123',
          mimeType: 'image/png',
          originalId: 'ref-1',
        ),
      ];

      final testContainer = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('skill-imggen2').overrideWith(
            (ref) => Future<AiConfig?>.value(skill),
          ),
          profileAutomationResolverProvider.overrideWithValue(mockResolver),
          skillInferenceRunnerProvider.overrideWithValue(mockRunner),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        triggerSkillProvider((
          entityId: 'audio-entry-4',
          skillId: 'skill-imggen2',
          linkedTaskId: 'task-imggen2',
          referenceImages: refImages,
        )).future,
      );

      verify(
        () => mockRunner.runImageGeneration(
          audioEntryId: 'audio-entry-4',
          automationResult: any(named: 'automationResult'),
          linkedTaskId: 'task-imggen2',
          referenceImages: refImages,
        ),
      ).called(1);
    });

    // Note: null linkedTaskId is already guarded by an early return before
    // the skill type switch. The image generation case has a redundant
    // null check as defense-in-depth, but it's unreachable.
  });
}
