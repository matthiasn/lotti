import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Entry controller that returns null (entity not found).

/// File-level factory for the boilerplate [AiConfigPrompt] blocks; only the
/// parts that vary between tests are parameters.
AiConfigPrompt _makePromptConfig({
  String id = 'prompt-1',
  String name = 'Test Prompt',
  AiResponseType aiResponseType = AiResponseType.audioTranscription,
  List<InputDataType> requiredInputData = const [InputDataType.task],
}) {
  return AiConfigPrompt(
    id: id,
    name: name,
    systemMessage: 'System',
    userMessage: 'User',
    defaultModelId: 'model-1',
    modelIds: const ['model-1'],
    createdAt: DateTime(2024, 3, 15),
    useReasoning: false,
    requiredInputData: requiredInputData,
    aiResponseType: aiResponseType,
  );
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

  setUp(() async {
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

    // setUpTestGetIt registers its own DomainLogger/JournalDb/
    // UpdateNotifications; swap in this file's mocks so stubs and verify
    // calls hit the right instances.
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockDomainLogger)
          ..registerSingleton<AiConfigRepository>(mockAiConfigRepository)
          ..registerSingleton<EditorStateService>(mockEditorStateService)
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
      },
    );

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

  tearDown(() async {
    // Dispose all containers created during tests
    for (final c in containersToDispose) {
      c.dispose();
    }
    containersToDispose.clear();
    container.dispose();
    await tearDownTestGetIt();
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
        final promptConfig = _makePromptConfig(
          id: 'prompt-join',
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
        final promptConfig = _makePromptConfig(
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

          // Simulate progress updates synchronously — listeners fire per
          // state assignment, so no delays are needed (fake-time policy).
          onStatusChange(InferenceStatus.running);
          statusChangeCount++;
          onProgress('Starting inference...');
          progressUpdates.add('Starting inference...');
          onProgress('Processing...');
          progressUpdates.add('Processing...');
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

        // Drive async execution — the mock fires synchronously, so a
        // microtask flush is all that's needed.
        async.flushMicrotasks();

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
      final promptConfig = _makePromptConfig(
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
        final promptConfig = _makePromptConfig(
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

    test('handles a promptId that resolves to no config', () {
      fakeAsync((async) {
        final states = <UnifiedAiState>[];

        // aiConfigByIdProvider returns null → _performInference throws
        // 'Invalid prompt configuration', and the catch-block's second
        // config lookup also gets null so no status update is attempted.
        container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            aiConfigByIdProvider(
              'missing-prompt',
            ).overrideWith((ref) => Future.value()),
          ],
        );

        final subscription = container.listen(
          unifiedAiControllerProvider((
            entityId: 'test-entity',
            promptId: 'missing-prompt',
          )),
          (previous, next) {
            states.add(next);
          },
          fireImmediately: true,
        );

        container.read(
          triggerNewInferenceProvider((
            entityId: 'test-entity',
            promptId: 'missing-prompt',
            linkedEntityId: null,
          )).future,
        );

        async.flushMicrotasks();

        // The thrown 'Invalid prompt configuration' is logged …
        verify(
          () => mockDomainLogger.error(
            LogDomain.ai,
            any<Object>(
              that: predicate<Object>(
                (e) => e.toString().contains('Invalid prompt configuration'),
              ),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'runInference',
          ),
        ).called(1);
        // … the inference repo is never reached …
        verifyNever(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        );
        // … and the original exception surfaces in controller state.
        expect(
          states.any(
            (s) => s.error.toString().contains('Invalid prompt configuration'),
          ),
          true,
        );

        subscription.close();
      });
    });
  });
}
