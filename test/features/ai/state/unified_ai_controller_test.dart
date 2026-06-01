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
import 'package:lotti/features/ai/skills/built_in_skills.dart';
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
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';
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
  late MockDomainLogger mockDomainLogger;
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
    mockDomainLogger = MockDomainLogger();
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
    if (getIt.isRegistered<DomainLogger>()) {
      getIt.unregister<DomainLogger>();
    }
    getIt.registerSingleton<DomainLogger>(mockDomainLogger);

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
      () => mockDomainLogger.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockDomainLogger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
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

  group('UnifiedAiState equality', () {
    test('compares message and error fields and derives hashCode', () {
      final errorA = Exception('boom-a');
      final errorB = Exception('boom-b');

      const base = UnifiedAiState(message: 'hello');
      const sameAsBase = UnifiedAiState(message: 'hello');
      const differentMessage = UnifiedAiState(message: 'world');
      final withErrorA = UnifiedAiState(message: 'hello', error: errorA);
      final withSameErrorA = UnifiedAiState(message: 'hello', error: errorA);
      final withErrorB = UnifiedAiState(message: 'hello', error: errorB);

      // identical short-circuit and field-by-field equality.
      expect(base, equals(base));
      expect(base, equals(sameAsBase));

      // Differing message => not equal.
      expect(base == differentMessage, isFalse);

      // Same message but one carries an error => line 44 (error mismatch).
      expect(base == withErrorA, isFalse);

      // Same message + same error instance => equal, and hashCode matches.
      expect(withErrorA == withSameErrorA, isTrue);
      expect(withErrorA.hashCode, withSameErrorA.hashCode);

      // Same message but different error instances => not equal.
      expect(withErrorA == withErrorB, isFalse);

      // hashCode (lines 46-47) folds both message and error in; the
      // no-error state and the with-error state must differ.
      expect(base.hashCode, sameAsBase.hashCode);
      expect(base.hashCode == withErrorA.hashCode, isFalse);

      // Type guard branch: a non-UnifiedAiState object is never equal.
      // ignore: unrelated_type_equality_checks
      expect(base == 'hello', isFalse);
    });
  });

  group('UnifiedAiController', () {
    test(
      'joins an in-flight run instead of starting a second inference',
      () async {
        final promptConfig = AiConfigPrompt(
          id: 'prompt-join',
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
        var runInferenceCallCount = 0;

        final testContainer = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            aiConfigByIdProvider('prompt-join').overrideWith(
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
        ).thenAnswer((_) async {
          runInferenceCallCount++;
          await completer.future;
        });

        final controller = testContainer.read(
          unifiedAiControllerProvider((
            entityId: 'join-entity',
            promptId: 'prompt-join',
          )).notifier,
        );

        // First call starts the run (still in-flight, blocked on completer).
        final first = controller.runInference(linkedEntityId: 'linked-1');
        // Second call, while the first is still in-flight, must join the
        // existing future (lines 197-203) rather than start a new run.
        final second = controller.runInference(linkedEntityId: 'linked-2');

        // The "already running" branch logs the join with the active run id.
        verify(
          () => mockDomainLogger.log(
            LogDomain.ai,
            any<String>(
              that: allOf(
                contains('already running for join-entity'),
                contains('Joining existing run'),
                contains('incoming linked: linked-2'),
                contains('active linked: linked-1'),
              ),
            ),
            subDomain: 'runInference',
          ),
        ).called(1);

        completer.complete();
        await first;
        await second;

        // The repository only ran a single inference despite two calls.
        expect(runInferenceCallCount, 1);
        verify(
          () => mockRepository.runInference(
            entityId: 'join-entity',
            promptConfig: promptConfig,
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            linkedEntityId: 'linked-1',
          ),
        ).called(1);
      },
    );

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
          () => mockDomainLogger.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'runInference',
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

      final testContainer = ProviderContainer(
        overrides: [
          skillRegistryProvider.overrideWithValue([transcriptionSkill]),
          createEntryControllerOverride(audioEntity),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        entryControllerProvider(id: audioEntity.id).future,
      );

      final hasSkills = await testContainer.read(
        hasAvailableSkillsProvider((
          entityId: audioEntity.id,
          linkedFromId: null,
        )).future,
      );

      expect(hasSkills, true);
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

      final testContainer = ProviderContainer(
        overrides: [
          skillRegistryProvider.overrideWithValue(const []),
          createEntryControllerOverride(journalEntry),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        entryControllerProvider(id: journalEntry.id).future,
      );

      final hasSkills = await testContainer.read(
        hasAvailableSkillsProvider((
          entityId: journalEntry.id,
          linkedFromId: null,
        )).future,
      );

      expect(hasSkills, false);
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

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([
              transcriptionSkill,
              promptSkill,
            ]),
            createEntryControllerOverride(audioEntity),
          ],
        );
        containersToDispose.add(testContainer);

        await testContainer.read(
          entryControllerProvider(id: audioEntity.id).future,
        );

        final skills = await testContainer.read(
          availableSkillsForEntityProvider((
            entityId: audioEntity.id,
            linkedFromId: null,
          )).future,
        );

        // Both transcription and promptGeneration pass the filter for
        // JournalAudio entities.
        expect(skills.length, 2);
        expect(skills.map((s) => s.id), contains('skill-transcription'));
        expect(skills.map((s) => s.id), contains('skill-prompt'));
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

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([imageSkill, promptSkill]),
            createEntryControllerOverride(imageEntity),
          ],
        );
        containersToDispose.add(testContainer);

        await testContainer.read(
          entryControllerProvider(id: imageEntity.id).future,
        );

        final skills = await testContainer.read(
          availableSkillsForEntityProvider((
            entityId: imageEntity.id,
            linkedFromId: null,
          )).future,
        );

        // Only imageAnalysis passes — promptGeneration requires audio
        // modality, which is filtered out for JournalImage entities.
        expect(skills.length, 1);
        expect(skills.map((s) => s.id), contains('skill-image'));
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

      final testContainer = ProviderContainer(
        overrides: [
          skillRegistryProvider.overrideWithValue([
            audioOnlySkill,
            promptSkill,
          ]),
          createEntryControllerOverride(taskEntity),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        entryControllerProvider(id: taskEntity.id).future,
      );

      final skills = await testContainer.read(
        availableSkillsForEntityProvider((
          entityId: taskEntity.id,
          linkedFromId: null,
        )).future,
      );

      // Both audio-only skills are filtered out for Task entities —
      // transcription and promptGeneration both require audio modality.
      expect(skills, isEmpty);
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

      final testContainer = ProviderContainer(
        overrides: [
          skillRegistryProvider.overrideWithValue([imageOnlySkill]),
          createEntryControllerOverride(taskEntity),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        entryControllerProvider(id: taskEntity.id).future,
      );

      final skills = await testContainer.read(
        availableSkillsForEntityProvider((
          entityId: taskEntity.id,
          linkedFromId: null,
        )).future,
      );

      expect(skills, isEmpty);
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

      final testContainer = ProviderContainer(
        overrides: [
          skillRegistryProvider.overrideWithValue(const []),
          createEntryControllerOverride(taskEntity),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        entryControllerProvider(id: taskEntity.id).future,
      );

      final skills = await testContainer.read(
        availableSkillsForEntityProvider((
          entityId: taskEntity.id,
          linkedFromId: null,
        )).future,
      );

      expect(skills, isEmpty);
    });

    test(
      'filters out text-modality skills for non-text entities '
      '(measurements, ratings, etc.)',
      () async {
        // MeasurementEntry carries numeric data, no free-form text — text
        // skills should be hidden.
        final measurementEntity = MeasurementEntry(
          meta: Metadata(
            id: 'measure-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: MeasurementData(
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            value: 42,
            dataTypeId: 'weight-kg',
          ),
        );

        final textSkill = createSkill(
          id: 'skill-text-only',
          name: 'Generate Coding Prompt',
          skillType: SkillType.promptGeneration,
          modalities: [Modality.text],
        );

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([textSkill]),
            createEntryControllerOverride(measurementEntity),
          ],
        );
        containersToDispose.add(testContainer);

        await testContainer.read(
          entryControllerProvider(id: measurementEntity.id).future,
        );

        final skills = await testContainer.read(
          availableSkillsForEntityProvider((
            entityId: measurementEntity.id,
            linkedFromId: null,
          )).future,
        );
        // No skills survive — the measurement entry can't satisfy text
        // modality.
        expect(skills, isEmpty);
      },
    );

    test(
      'keeps text-modality skills for the four text-bearing surfaces',
      () async {
        final textSkill = createSkill(
          id: 'skill-text-only',
          name: 'Generate Coding Prompt',
          skillType: SkillType.promptGeneration,
          modalities: [Modality.text],
        );

        Future<List<AiConfigSkill>> readFor(JournalEntity entity) async {
          final c = ProviderContainer(
            overrides: [
              skillRegistryProvider.overrideWithValue([textSkill]),
              createEntryControllerOverride(entity),
            ],
          );
          containersToDispose.add(c);
          await c.read(entryControllerProvider(id: entity.id).future);
          return c.read(
            availableSkillsForEntityProvider((
              entityId: entity.id,
              linkedFromId: null,
            )).future,
          );
        }

        final journalEntry = JournalEntry(
          meta: Metadata(
            id: 'entry-text',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
        );
        final audio = JournalAudio(
          meta: Metadata(
            id: 'audio-text',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            audioFile: 'a.mp3',
            audioDirectory: '/x',
            duration: const Duration(seconds: 30),
          ),
        );
        final task = Task(
          meta: Metadata(
            id: 'task-text',
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
            title: 'T',
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
        );
        final image = JournalImage(
          meta: Metadata(
            id: 'image-text',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15),
            imageId: 'img-1',
            imageFile: 't.jpg',
            imageDirectory: '/x',
          ),
        );

        expect((await readFor(journalEntry)).map((s) => s.id), [
          'skill-text-only',
        ]);
        expect((await readFor(audio)).map((s) => s.id), ['skill-text-only']);
        expect((await readFor(task)).map((s) => s.id), ['skill-text-only']);
        expect((await readFor(image)).map((s) => s.id), ['skill-text-only']);
      },
    );

    test('hides fullTask skills for standalone audio entries', () async {
      final audioEntity = JournalAudio(
        meta: Metadata(
          id: 'audio-standalone',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: AudioData(
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          audioFile: 'a.mp3',
          audioDirectory: '/x',
          duration: const Duration(seconds: 30),
        ),
      );

      final plainTranscribe = createSkill(
        id: 'skill-transcribe-plain',
        name: 'Transcribe',
        skillType: SkillType.transcription,
        modalities: [Modality.audio],
      );
      final taskContextTranscribe =
          AiConfig.skill(
                id: 'skill-transcribe-task',
                name: 'Transcribe (Task Context)',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.transcription,
                requiredInputModalities: [Modality.audio],
                contextPolicy: ContextPolicy.fullTask,
                systemInstructions: 'System',
                userInstructions: 'User',
              )
              as AiConfigSkill;
      final coverArt =
          AiConfig.skill(
                id: 'skill-cover-art',
                name: 'Cover Art',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.imageGeneration,
                requiredInputModalities: [Modality.text],
                contextPolicy: ContextPolicy.fullTask,
                systemInstructions: 'System',
                userInstructions: 'User',
              )
              as AiConfigSkill;

      final testContainer = ProviderContainer(
        overrides: [
          skillRegistryProvider.overrideWithValue([
            plainTranscribe,
            taskContextTranscribe,
            coverArt,
          ]),
          createEntryControllerOverride(audioEntity),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        entryControllerProvider(id: audioEntity.id).future,
      );

      final standaloneSkills = await testContainer.read(
        availableSkillsForEntityProvider((
          entityId: audioEntity.id,
          linkedFromId: null,
        )).future,
      );
      expect(standaloneSkills.map((s) => s.id), ['skill-transcribe-plain']);

      // With a linked task, the full-task skills are no longer hidden — the
      // text-only cover-art skill still passes for an audio entity because
      // it accepts text modality.
      final linkedSkills = await testContainer.read(
        availableSkillsForEntityProvider((
          entityId: audioEntity.id,
          linkedFromId: 'task-99',
        )).future,
      );
      expect(
        linkedSkills.map((s) => s.id),
        containsAll(['skill-transcribe-plain', 'skill-transcribe-task']),
      );
    });

    test('returns empty list when entity not found', () async {
      final testContainer = ProviderContainer(
        overrides: [
          skillRegistryProvider.overrideWithValue(const []),
          // No entry controller override — entity will not be found
          entryControllerProvider(id: 'nonexistent').overrideWith(
            FakeEntryControllerNull.new,
          ),
        ],
      );
      containersToDispose.add(testContainer);

      final provider = availableSkillsForEntityProvider((
        entityId: 'nonexistent',
        linkedFromId: null,
      ));
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
          skillRegistryProvider.overrideWithValue(const []),
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
          overrideModelId: null,
        )).future,
      );

      // Should return early without invoking the runner
      verifyZeroInteractions(mockRunner);
    });

    test(
      'returns early when no linkedTaskId and entity has no category',
      () async {
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

        // Standalone audio entry with no category — no profile resolvable.
        final audioEntity = JournalAudio(
          meta: Metadata(
            id: 'entity-1',
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
            duration: const Duration(minutes: 1),
          ),
        );
        when(
          () => mockJournalDb.journalEntityById('entity-1'),
        ).thenAnswer((_) async => audioEntity);

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([skill]),
            profileAutomationResolverProvider.overrideWithValue(mockResolver),
            skillInferenceRunnerProvider.overrideWithValue(mockRunner),
            journalDbProvider.overrideWithValue(mockJournalDb),
          ],
        );
        containersToDispose.add(testContainer);

        await testContainer.read(
          triggerSkillProvider((
            entityId: 'entity-1',
            skillId: 'skill-1',
            linkedTaskId: null,
            referenceImages: null,
            overrideModelId: null,
          )).future,
        );

        // Should return early without invoking the runner.
        verifyZeroInteractions(mockRunner);
        verifyNever(
          () => mockResolver.resolveForCategory(any()),
        );
      },
    );

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
          skillRegistryProvider.overrideWithValue([skill]),
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
          overrideModelId: null,
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
          skillRegistryProvider.overrideWithValue([skill]),
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
          overrideModelId: null,
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

    test(
      'resolves via category and runs transcription for standalone audio',
      () async {
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

        final audioEntity = JournalAudio(
          meta: Metadata(
            id: 'standalone-audio-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            categoryId: 'cat-journal',
          ),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            audioFile: 'voice.mp3',
            audioDirectory: '/recordings',
            duration: const Duration(minutes: 2),
          ),
        );

        final thinkingProvider =
            AiConfig.inferenceProvider(
                  id: 'ollama-prov',
                  name: 'Ollama',
                  inferenceProviderType: InferenceProviderType.ollama,
                  apiKey: '',
                  baseUrl: 'http://localhost:11434',
                  createdAt: DateTime(2024, 3, 15),
                )
                as AiConfigInferenceProvider;
        final transcriptionProvider =
            AiConfig.inferenceProvider(
                  id: 'ollama-voxtral',
                  name: 'Ollama (Voxtral)',
                  inferenceProviderType: InferenceProviderType.ollama,
                  apiKey: '',
                  baseUrl: 'http://localhost:11434',
                  createdAt: DateTime(2024, 3, 15),
                )
                as AiConfigInferenceProvider;
        final resolvedProfile = ResolvedProfile(
          thinkingModelId: 'thinking-model',
          thinkingProvider: thinkingProvider,
          transcriptionModelId: 'voxtral',
          transcriptionProvider: transcriptionProvider,
        );

        when(
          () => mockJournalDb.journalEntityById('standalone-audio-1'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockResolver.resolveForCategory('cat-journal'),
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
            skillRegistryProvider.overrideWithValue([skill]),
            profileAutomationResolverProvider.overrideWithValue(mockResolver),
            skillInferenceRunnerProvider.overrideWithValue(mockRunner),
            journalDbProvider.overrideWithValue(mockJournalDb),
          ],
        );
        containersToDispose.add(testContainer);

        await testContainer.read(
          triggerSkillProvider((
            entityId: 'standalone-audio-1',
            skillId: 'skill-transcribe',
            linkedTaskId: null,
            referenceImages: null,
            overrideModelId: null,
          )).future,
        );

        verify(
          () => mockResolver.resolveForCategory('cat-journal'),
        ).called(1);
        verifyNever(() => mockResolver.resolveForTask(any()));
        verify(
          () => mockRunner.runTranscription(
            audioEntryId: 'standalone-audio-1',
            automationResult: any(named: 'automationResult'),
          ),
        ).called(1);
      },
    );

    test(
      'aborts standalone fullTask skill without invoking resolver',
      () async {
        final skill =
            AiConfig.skill(
                  id: 'skill-cover-art',
                  name: 'Cover Art',
                  createdAt: DateTime(2024, 3, 15),
                  skillType: SkillType.imageGeneration,
                  requiredInputModalities: [Modality.text],
                  contextPolicy: ContextPolicy.fullTask,
                  systemInstructions: 'System',
                  userInstructions: 'User',
                )
                as AiConfigSkill;

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([skill]),
            profileAutomationResolverProvider.overrideWithValue(mockResolver),
            skillInferenceRunnerProvider.overrideWithValue(mockRunner),
            journalDbProvider.overrideWithValue(mockJournalDb),
          ],
        );
        containersToDispose.add(testContainer);

        await testContainer.read(
          triggerSkillProvider((
            entityId: 'standalone-audio-2',
            skillId: 'skill-cover-art',
            linkedTaskId: null,
            referenceImages: null,
            overrideModelId: null,
          )).future,
        );

        verifyZeroInteractions(mockRunner);
        verifyNever(() => mockResolver.resolveForTask(any()));
        verifyNever(() => mockResolver.resolveForCategory(any()));
      },
    );

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
          skillRegistryProvider.overrideWithValue([skill]),
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
          overrideModelId: null,
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

    test(
      'threads overrideModelId from TriggerSkillParams to '
      'SkillInferenceRunner.runImageAnalysis when the skill type is '
      'imageAnalysis — the popup picker sets this field when the user '
      'routes one photo to a non-default model, and the trigger must '
      'forward it to the runner so the per-invocation override '
      'actually takes effect',
      () async {
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
            overrideModelId: any(named: 'overrideModelId'),
          ),
        ).thenAnswer((_) async {});

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([skill]),
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
            overrideModelId: 'override-vision-model-id',
          )).future,
        );

        verify(
          () => mockRunner.runImageAnalysis(
            imageEntryId: 'image-entry-1',
            automationResult: any(named: 'automationResult'),
            linkedTaskId: 'task-img',
            overrideModelId: 'override-vision-model-id',
          ),
        ).called(1);
      },
    );

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
          entryId: any(named: 'entryId'),
          automationResult: any(named: 'automationResult'),
          linkedTaskId: any(named: 'linkedTaskId'),
        ),
      ).thenAnswer((_) async {});

      final testContainer = ProviderContainer(
        overrides: [
          skillRegistryProvider.overrideWithValue([skill]),
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
          overrideModelId: null,
        )).future,
      );

      verify(
        () => mockRunner.runPromptGeneration(
          entryId: 'audio-entry-2',
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
          entryId: any(named: 'entryId'),
          automationResult: any(named: 'automationResult'),
          linkedTaskId: any(named: 'linkedTaskId'),
          referenceImages: any(named: 'referenceImages'),
        ),
      ).thenAnswer((_) async {});

      final testContainer = ProviderContainer(
        overrides: [
          skillRegistryProvider.overrideWithValue([skill]),
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
          overrideModelId: null,
        )).future,
      );

      verify(
        () => mockRunner.runImageGeneration(
          entryId: 'audio-entry-3',
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
          entryId: any(named: 'entryId'),
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
          skillRegistryProvider.overrideWithValue([skill]),
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
          overrideModelId: null,
        )).future,
      );

      verify(
        () => mockRunner.runImageGeneration(
          entryId: 'audio-entry-4',
          automationResult: any(named: 'automationResult'),
          linkedTaskId: 'task-imggen2',
          referenceImages: refImages,
        ),
      ).called(1);
    });

    test(
      'routes imagePromptGeneration skills through runPromptGeneration',
      () async {
        final skill =
            AiConfig.skill(
                  id: 'skill-img-prompt',
                  name: 'Generate Image Prompt',
                  createdAt: DateTime(2024, 3, 15),
                  skillType: SkillType.imagePromptGeneration,
                  requiredInputModalities: [Modality.text],
                  contextPolicy: ContextPolicy.fullTask,
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
          thinkingModelId: 'thinking-model',
          thinkingProvider: thinkingProvider,
        );

        when(
          () => mockResolver.resolveForTask('task-img-prompt'),
        ).thenAnswer((_) async => resolvedProfile);

        when(
          () => mockRunner.runPromptGeneration(
            entryId: any(named: 'entryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        ).thenAnswer((_) async {});

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([skill]),
            profileAutomationResolverProvider.overrideWithValue(mockResolver),
            skillInferenceRunnerProvider.overrideWithValue(mockRunner),
          ],
        );
        containersToDispose.add(testContainer);

        await testContainer.read(
          triggerSkillProvider((
            entityId: 'entry-img-prompt',
            skillId: 'skill-img-prompt',
            linkedTaskId: 'task-img-prompt',
            referenceImages: null,
            overrideModelId: null,
          )).future,
        );

        verify(
          () => mockRunner.runPromptGeneration(
            entryId: 'entry-img-prompt',
            automationResult: any(named: 'automationResult'),
            linkedTaskId: 'task-img-prompt',
          ),
        ).called(1);
        verifyNever(
          () => mockRunner.runImageGeneration(
            entryId: any(named: 'entryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
            referenceImages: any(named: 'referenceImages'),
          ),
        );
      },
    );

    test(
      'throws and logs when imageGeneration skill runs without a linkedTaskId',
      () async {
        // An imageGeneration skill with the default ContextPolicy.none is NOT
        // hidden for standalone entries and is NOT caught by the fullTask
        // early-return guard, so it reaches the switch with a null
        // linkedTaskId. The imageGeneration case then throws a StateError
        // (line 579), which is caught and routed to loggingService.error
        // (line 597).
        final skill =
            AiConfig.skill(
                  id: 'skill-imggen-no-task',
                  name: 'Generate Cover Art',
                  createdAt: DateTime(2024, 3, 15),
                  skillType: SkillType.imageGeneration,
                  requiredInputModalities: [Modality.text],
                  systemInstructions: 'System',
                  userInstructions: 'User',
                )
                as AiConfigSkill;

        final entity = JournalEntry(
          meta: Metadata(
            id: 'entry-imggen',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            categoryId: 'cat-imggen',
          ),
        );

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
          () => mockJournalDb.journalEntityById('entry-imggen'),
        ).thenAnswer((_) async => entity);
        when(
          () => mockResolver.resolveForCategory('cat-imggen'),
        ).thenAnswer((_) async => resolvedProfile);

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([skill]),
            profileAutomationResolverProvider.overrideWithValue(mockResolver),
            skillInferenceRunnerProvider.overrideWithValue(mockRunner),
            journalDbProvider.overrideWithValue(mockJournalDb),
          ],
        );
        containersToDispose.add(testContainer);

        // The provider swallows the thrown StateError in its catch block, so
        // the awaited future resolves normally.
        await testContainer.read(
          triggerSkillProvider((
            entityId: 'entry-imggen',
            skillId: 'skill-imggen-no-task',
            linkedTaskId: null,
            referenceImages: null,
            overrideModelId: null,
          )).future,
        );

        // The runner was never asked to generate an image because the guard
        // threw before reaching it.
        verifyNever(
          () => mockRunner.runImageGeneration(
            entryId: any(named: 'entryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
            referenceImages: any(named: 'referenceImages'),
          ),
        );

        // The caught StateError is logged via loggingService.error with the
        // entity id embedded in the message.
        final captured = verify(
          () => mockDomainLogger.error(
            LogDomain.ai,
            captureAny<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'triggerSkillProvider',
          ),
        ).captured;
        expect(captured.single, isA<StateError>());
        expect(
          (captured.single as StateError).message,
          contains('Image generation requires a linkedTaskId'),
        );
        expect(
          (captured.single as StateError).message,
          contains('entry-imggen'),
        );
      },
    );
  });
}
