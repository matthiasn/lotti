// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart' show toDbEntity;
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
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
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
import '../../../widget_test_utils.dart';

/// Entry controller that returns null (entity not found).
class FakeEntryControllerNull extends EntryController {
  @override
  Future<EntryState?> build() async => null;
}

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
    when(
      () => mockJournalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockJournalDb.getLinkedEntities(any()),
    ).thenAnswer((_) async => <JournalEntity>[]);
    when(
      () => mockJournalDb.getLinkedToEntities(any()),
    ).thenAnswer((_) async => <JournalDbEntity>[]);

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
        entryControllerProvider(audioEntity.id).future,
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
        entryControllerProvider(journalEntry.id).future,
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
      final promptConfig = _makePromptConfig(
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
        final promptConfig = _makePromptConfig();

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
            inferenceStatusControllerProvider((
              id: 'audio-entry-id',
              aiResponseType: AiResponseType.audioTranscription,
            )),
            (previous, next) {
              mainEntityStatuses.add(next);
            },
            fireImmediately: true,
          )
          // Listen to inference status for linked entity
          ..listen(
            inferenceStatusControllerProvider((
              id: 'linked-task-id',
              aiResponseType: AiResponseType.audioTranscription,
            )),
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

          // Simulate status changes synchronously — listeners fire per
          // state assignment, so no delay is needed (fake-time policy).
          onStatusChange(InferenceStatus.running);
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

        // Drive async execution — the mock fires synchronously, so a
        // microtask flush is all that's needed.
        async.flushMicrotasks();

        // Both entities should have received the same status updates
        expect(mainEntityStatuses, contains(InferenceStatus.idle));
        expect(mainEntityStatuses, contains(InferenceStatus.running));
        expect(linkedEntityStatuses, contains(InferenceStatus.idle));
        expect(linkedEntityStatuses, contains(InferenceStatus.running));
      });
    });

    test('updates error status for linked entity on failure', () {
      fakeAsync((async) {
        final promptConfig = _makePromptConfig();

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
            inferenceStatusControllerProvider((
              id: 'audio-entry-id',
              aiResponseType: AiResponseType.audioTranscription,
            )),
            (previous, next) {
              mainEntityStatuses.add(next);
            },
            fireImmediately: true,
          )
          // Listen to inference status for linked entity
          ..listen(
            inferenceStatusControllerProvider((
              id: 'linked-task-id',
              aiResponseType: AiResponseType.audioTranscription,
            )),
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

          // Simulate running status then error — synchronous, no delay
          // needed (fake-time policy).
          onStatusChange(InferenceStatus.running);
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

        // Drive async execution — the mock fires synchronously, so a
        // microtask flush is all that's needed.
        async.flushMicrotasks();

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
      ContextPolicy contextPolicy = ContextPolicy.none,
      String? description,
    }) {
      return AiConfig.skill(
            id: id,
            name: name,
            createdAt: DateTime(2024, 3, 15),
            skillType: skillType,
            requiredInputModalities: modalities,
            contextPolicy: contextPolicy,
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
          entryControllerProvider(audioEntity.id).future,
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
          entryControllerProvider(imageEntity.id).future,
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
        entryControllerProvider(taskEntity.id).future,
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
        entryControllerProvider(taskEntity.id).future,
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
        entryControllerProvider(taskEntity.id).future,
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
          entryControllerProvider(measurementEntity.id).future,
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
          await c.read(entryControllerProvider(entity.id).future);
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
      final compactCoverArt =
          AiConfig.skill(
                id: 'skill-cover-art-compact',
                name: 'Cover Art Compact',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.imageGeneration,
                requiredInputModalities: [Modality.text],
                contextPolicy: ContextPolicy.taskSummary,
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
            compactCoverArt,
          ]),
          createEntryControllerOverride(audioEntity),
        ],
      );
      containersToDispose.add(testContainer);

      await testContainer.read(
        entryControllerProvider(audioEntity.id).future,
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
        containsAll([
          'skill-transcribe-plain',
          'skill-transcribe-task',
          'skill-cover-art',
          'skill-cover-art-compact',
        ]),
      );
    });

    test(
      'shows fullTask prompt skills for audio entries linked from a task',
      () async {
        final now = DateTime(2024, 3, 15);
        final audioEntity = JournalAudio(
          meta: Metadata(
            id: 'audio-task-linked',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: AudioData(
            dateFrom: now,
            dateTo: now,
            audioFile: 'task-note.mp3',
            audioDirectory: '/x',
            duration: const Duration(seconds: 30),
          ),
        );
        final linkedTask = Task(
          meta: Metadata(
            id: 'task-parent',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: TaskData(
            title: 'Parent task',
            status: TaskStatus.open(
              id: 'status-task',
              createdAt: now,
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: now,
            dateTo: now,
          ),
        );
        final plainTranscribe = createSkill(
          id: 'skill-transcribe-plain',
          name: 'Transcribe',
          skillType: SkillType.transcription,
          modalities: [Modality.audio],
        );
        final codingPrompt = createSkill(
          id: 'skill-coding-prompt',
          name: 'Generate Coding Prompt',
          skillType: SkillType.promptGeneration,
          modalities: [Modality.text],
          contextPolicy: ContextPolicy.fullTask,
        );

        when(
          () => mockJournalDb.getLinkedToEntities(audioEntity.id),
        ).thenAnswer((_) async => [toDbEntity(linkedTask)]);

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([
              plainTranscribe,
              codingPrompt,
            ]),
            createEntryControllerOverride(audioEntity),
          ],
        );
        containersToDispose.add(testContainer);

        await testContainer.read(
          entryControllerProvider(audioEntity.id).future,
        );

        final skills = await testContainer.read(
          availableSkillsForEntityProvider((
            entityId: audioEntity.id,
            linkedFromId: null,
          )).future,
        );

        expect(skills.map((s) => s.id), [
          'skill-transcribe-plain',
          'skill-coding-prompt',
        ]);
      },
    );

    test(
      'hides imageGeneration skills for a Task entity because the runner '
      'requires a note or audio source entry',
      () async {
        final taskEntity = Task(
          meta: Metadata(
            id: 'task-cover-filter',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            title: 'Task-only cover source',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
        );
        final coverArtSkill =
            AiConfig.skill(
                  id: 'skill-cover-task-filter',
                  name: 'Generate Cover Art',
                  createdAt: DateTime(2024, 3, 15),
                  skillType: SkillType.imageGeneration,
                  requiredInputModalities: [Modality.text],
                  contextPolicy: ContextPolicy.taskSummary,
                  systemInstructions: 'System',
                  userInstructions: 'User',
                )
                as AiConfigSkill;

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([coverArtSkill]),
            createEntryControllerOverride(taskEntity),
          ],
        );
        containersToDispose.add(testContainer);

        await testContainer.read(
          entryControllerProvider(taskEntity.id).future,
        );

        final skills = await testContainer.read(
          availableSkillsForEntityProvider((
            entityId: taskEntity.id,
            linkedFromId: null,
          )).future,
        );

        expect(skills, isEmpty);
      },
    );

    test('returns empty list when entity not found', () async {
      final testContainer = ProviderContainer(
        overrides: [
          skillRegistryProvider.overrideWithValue(const []),
          // No entry controller override — entity will not be found
          entryControllerProvider('nonexistent').overrideWith(
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

    // Property: for any generated (entity kind, linkedFrom, skill) triple,
    // the provider returns the skill iff the modality and context-policy
    // predicates are simultaneously satisfied. Covers the combinations the
    // hand-written examples skip (multi-modality skills, dictionaryOnly,
    // fullTask without task context, ...).
    glados.Glados(
      glados.any.skillFilterScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'matches the documented filter predicate for any combination',
      (
        scenario,
      ) async {
        final entity = scenario.buildEntity();
        final skill =
            AiConfig.skill(
                  id: 'generated-skill',
                  name: 'Generated',
                  createdAt: DateTime(2024, 3, 15),
                  skillType: scenario.skillType,
                  requiredInputModalities: scenario.modalities,
                  contextPolicy: scenario.contextPolicy,
                  systemInstructions: 'sys',
                  userInstructions: 'user',
                )
                as AiConfigSkill;

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([skill]),
            createEntryControllerOverride(entity),
          ],
        );
        try {
          await testContainer.read(
            entryControllerProvider(entity.meta.id).future,
          );
          final skills = await testContainer.read(
            availableSkillsForEntityProvider((
              entityId: entity.meta.id,
              linkedFromId: scenario.hasLinkedFrom ? 'linked-from-1' : null,
            )).future,
          );

          expect(
            skills.map((s) => s.id),
            scenario.expectIncluded ? ['generated-skill'] : isEmpty,
            reason: '$scenario',
          );
        } finally {
          testContainer.dispose();
        }
      },
      tags: 'glados',
    );
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
          geminiThinkingMode: null,
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
            geminiThinkingMode: null,
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
          geminiThinkingMode: null,
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
          overrideModelId: any(named: 'overrideModelId'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
          geminiThinkingMode: null,
        )).future,
      );

      verify(
        () => mockRunner.runTranscription(
          audioEntryId: 'audio-entry-1',
          automationResult: any(named: 'automationResult'),
          linkedTaskId: 'task-1',
          overrideModelId: any(named: 'overrideModelId'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
        ),
      ).called(1);
    });

    test(
      'logs and swallows a StateError thrown by the runner',
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
        final resolvedProfile = ResolvedProfile(
          thinkingModelId: 'thinking-model',
          thinkingProvider: thinkingProvider,
          transcriptionModelId: 'transcription-model',
          transcriptionProvider: thinkingProvider,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => resolvedProfile);
        when(
          () => mockRunner.runTranscription(
            audioEntryId: any(named: 'audioEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
            overrideModelId: any(named: 'overrideModelId'),
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
          ),
        ).thenThrow(StateError('runner blew up'));

        final testContainer = ProviderContainer(
          overrides: [
            skillRegistryProvider.overrideWithValue([skill]),
            profileAutomationResolverProvider.overrideWithValue(mockResolver),
            skillInferenceRunnerProvider.overrideWithValue(mockRunner),
          ],
        );
        containersToDispose.add(testContainer);

        // The provider catches the error and routes it to the logger —
        // the future itself completes normally.
        await testContainer.read(
          triggerSkillProvider((
            entityId: 'audio-entry-1',
            skillId: 'skill-transcribe',
            linkedTaskId: 'task-1',
            referenceImages: null,
            overrideModelId: null,
            geminiThinkingMode: null,
          )).future,
        );

        verify(
          () => mockDomainLogger.error(
            LogDomain.ai,
            any<Object>(that: isA<StateError>()),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'triggerSkillProvider',
          ),
        ).called(1);
      },
    );

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
            overrideModelId: any(named: 'overrideModelId'),
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
            geminiThinkingMode: null,
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
            overrideModelId: any(named: 'overrideModelId'),
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
            geminiThinkingMode: null,
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
          overrideModelId: any(named: 'overrideModelId'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
          geminiThinkingMode: null,
        )).future,
      );

      verify(
        () => mockRunner.runImageAnalysis(
          imageEntryId: 'image-entry-1',
          automationResult: any(named: 'automationResult'),
          linkedTaskId: 'task-img',
          overrideModelId: any(named: 'overrideModelId'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
            geminiThinkingMode: null,
          )).future,
        );

        verify(
          () => mockRunner.runImageAnalysis(
            imageEntryId: 'image-entry-1',
            automationResult: any(named: 'automationResult'),
            linkedTaskId: 'task-img',
            overrideModelId: 'override-vision-model-id',
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
          overrideModelId: any(named: 'overrideModelId'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
          geminiThinkingMode: null,
        )).future,
      );

      verify(
        () => mockRunner.runPromptGeneration(
          entryId: 'audio-entry-2',
          automationResult: any(named: 'automationResult'),
          linkedTaskId: 'task-prompt',
          overrideModelId: any(named: 'overrideModelId'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
        ),
      ).called(1);
    });

    test(
      'resolves a graph-linked task before routing prompt generation',
      () async {
        final now = DateTime(2024, 3, 15);
        final skill =
            AiConfig.skill(
                  id: 'skill-prompt',
                  name: 'Generate Coding Prompt',
                  createdAt: now,
                  skillType: SkillType.promptGeneration,
                  requiredInputModalities: [Modality.text],
                  contextPolicy: ContextPolicy.fullTask,
                  systemInstructions: 'System',
                  userInstructions: 'User',
                )
                as AiConfigSkill;
        final audioEntity = JournalAudio(
          meta: Metadata(
            id: 'audio-entry-graph',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: AudioData(
            dateFrom: now,
            dateTo: now,
            audioFile: 'prompt-note.mp3',
            audioDirectory: '/x',
            duration: const Duration(minutes: 1),
          ),
        );
        final linkedTask = Task(
          meta: Metadata(
            id: 'task-graph-parent',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: TaskData(
            title: 'Graph parent',
            status: TaskStatus.open(
              id: 'status-graph',
              createdAt: now,
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: now,
            dateTo: now,
          ),
        );
        final thinkingProvider =
            AiConfig.inferenceProvider(
                  id: 'gemini-prov',
                  name: 'Gemini',
                  inferenceProviderType: InferenceProviderType.gemini,
                  apiKey: 'key',
                  baseUrl: 'https://generativelanguage.googleapis.com',
                  createdAt: now,
                )
                as AiConfigInferenceProvider;
        final resolvedProfile = ResolvedProfile(
          thinkingModelId: 'flash',
          thinkingProvider: thinkingProvider,
        );

        when(
          () => mockJournalDb.journalEntityById(audioEntity.id),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockJournalDb.getLinkedToEntities(audioEntity.id),
        ).thenAnswer((_) async => [toDbEntity(linkedTask)]);
        when(
          () => mockResolver.resolveForTask(linkedTask.id),
        ).thenAnswer((_) async => resolvedProfile);
        when(
          () => mockRunner.runPromptGeneration(
            entryId: any(named: 'entryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
            overrideModelId: any(named: 'overrideModelId'),
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
            entityId: audioEntity.id,
            skillId: skill.id,
            linkedTaskId: null,
            referenceImages: null,
            overrideModelId: null,
            geminiThinkingMode: null,
          )).future,
        );

        verify(() => mockResolver.resolveForTask(linkedTask.id)).called(1);
        verifyNever(() => mockResolver.resolveForCategory(any()));
        verify(
          () => mockRunner.runPromptGeneration(
            entryId: audioEntity.id,
            automationResult: any(named: 'automationResult'),
            linkedTaskId: linkedTask.id,
            overrideModelId: any(named: 'overrideModelId'),
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
          ),
        ).called(1);
      },
    );

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
          geminiThinkingMode: null,
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

    test(
      'threads overrideModelId from TriggerSkillParams to runImageGeneration '
      '— the cover-art provider->model picker sets this field when the user '
      'routes one generation to a non-default image model, and the trigger '
      'must forward it so the per-invocation override takes effect',
      () async {
        final skill =
            AiConfig.skill(
                  id: 'skill-imggen-override',
                  name: 'Generate Cover Art',
                  createdAt: DateTime(2024, 3, 15),
                  skillType: SkillType.imageGeneration,
                  requiredInputModalities: const [Modality.text],
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
          () => mockResolver.resolveForTask('task-imggen-override'),
        ).thenAnswer((_) async => resolvedProfile);

        when(
          () => mockRunner.runImageGeneration(
            entryId: any(named: 'entryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
            referenceImages: any(named: 'referenceImages'),
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
            entityId: 'audio-entry-override',
            skillId: 'skill-imggen-override',
            linkedTaskId: 'task-imggen-override',
            referenceImages: null,
            overrideModelId: 'override-img-model',
            geminiThinkingMode: null,
          )).future,
        );

        verify(
          () => mockRunner.runImageGeneration(
            entryId: 'audio-entry-override',
            automationResult: any(named: 'automationResult'),
            linkedTaskId: 'task-imggen-override',
            referenceImages: any(named: 'referenceImages'),
            overrideModelId: 'override-img-model',
          ),
        ).called(1);
      },
    );

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
          geminiThinkingMode: null,
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
            overrideModelId: any(named: 'overrideModelId'),
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
            geminiThinkingMode: null,
          )).future,
        );

        verify(
          () => mockRunner.runPromptGeneration(
            entryId: 'entry-img-prompt',
            automationResult: any(named: 'automationResult'),
            linkedTaskId: 'task-img-prompt',
            overrideModelId: any(named: 'overrideModelId'),
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
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
            geminiThinkingMode: null,
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

  group('linked entity inference', () {
    late MockUnifiedAiInferenceRepository mockRepositoryLinked;
    late MockDomainLogger mockLoggingServiceLinked;
    late AiConfigPrompt asrPromptConfig;
    late AiConfigPrompt taskSummaryPromptConfig;

    setUp(() {
      getIt.allowReassignment = true;
      mockRepositoryLinked = MockUnifiedAiInferenceRepository();
      mockLoggingServiceLinked = MockDomainLogger();

      getIt.registerSingleton<DomainLogger>(mockLoggingServiceLinked);

      when(
        () => mockLoggingServiceLinked.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      when(
        () => mockLoggingServiceLinked.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      final now = DateTime(2024, 3, 15);
      asrPromptConfig =
          AiConfig.prompt(
                id: 'asr-prompt',
                name: 'Audio Transcription',
                systemMessage: 'Transcribe audio',
                userMessage: 'Please transcribe this audio',
                defaultModelId: 'whisper-1',
                modelIds: ['whisper-1'],
                createdAt: now,
                useReasoning: false,
                requiredInputData: [InputDataType.audioFiles],
                aiResponseType: AiResponseType.audioTranscription,
                description: 'Transcribes audio to text',
              )
              as AiConfigPrompt;

      taskSummaryPromptConfig =
          AiConfig.prompt(
                id: 'task-summary-prompt',
                name: 'Task Summary',
                systemMessage: 'Summarize task',
                userMessage: 'Please summarize this task',
                defaultModelId: 'gpt-4',
                modelIds: ['gpt-4'],
                createdAt: now,
                useReasoning: false,
                requiredInputData: [InputDataType.task],
                aiResponseType: AiResponseType.taskSummary,
                description: 'Generates task summaries',
              )
              as AiConfigPrompt;
    });

    tearDown(() {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt.unregister<DomainLogger>();
      }
      getIt.allowReassignment = false;
    });

    group('LinkedEntityId Functionality Tests', () {
      test('linkedEntityId is passed through the inference chain', () {
        fakeAsync((async) {
          // Arrange
          const audioEntryId = 'audio-123';
          const linkedTaskId = 'task-456';
          const asrPromptId = 'asr-prompt';

          final container = ProviderContainer(
            overrides: [
              unifiedAiInferenceRepositoryProvider.overrideWithValue(
                mockRepositoryLinked,
              ),
              aiConfigByIdProvider(asrPromptId).overrideWith(
                (ref) => Future.value(asrPromptConfig),
              ),
            ],
          );

          var capturedEntityId = '';
          var capturedLinkedEntityId = '';
          var inferenceStatusUpdates = 0;

          when(
            () => mockRepositoryLinked.runInference(
              entityId: any(named: 'entityId'),
              promptConfig: any(named: 'promptConfig'),
              onProgress: any(named: 'onProgress'),
              onStatusChange: any(named: 'onStatusChange'),
              linkedEntityId: any(named: 'linkedEntityId'),
            ),
          ).thenAnswer((invocation) async {
            capturedEntityId = invocation.namedArguments[#entityId] as String;
            capturedLinkedEntityId =
                (invocation.namedArguments[#linkedEntityId] as String?) ?? '';
            final onStatusChange =
                invocation.namedArguments[#onStatusChange]
                    as void Function(InferenceStatus);

            onStatusChange(InferenceStatus.running);
            onStatusChange(InferenceStatus.idle);
          });

          // Track status updates for linked entity
          container.listen(
            inferenceStatusControllerProvider((
              id: linkedTaskId,
              aiResponseType: AiResponseType.audioTranscription,
            )),
            (previous, next) {
              inferenceStatusUpdates++;
            },
          );

          // Act
          var finished = false;
          container
              .read(
                triggerNewInferenceProvider((
                  entityId: audioEntryId,
                  promptId: asrPromptId,
                  linkedEntityId: linkedTaskId,
                )).future,
              )
              .then((_) => finished = true);

          async.flushMicrotasks();

          // Assert
          expect(finished, isTrue);
          expect(
            capturedEntityId,
            audioEntryId,
          ); // Main entity is used for inference
          expect(capturedLinkedEntityId, linkedTaskId);
          expect(
            inferenceStatusUpdates,
            greaterThan(0),
          ); // Linked entity received updates

          // Verify logging includes linkedEntityId
          verify(
            () => mockLoggingServiceLinked.log(
              LogDomain.ai,
              any<String>(
                that: contains(
                  'Starting unified AI inference for $audioEntryId (prompt: $asrPromptId, linked: $linkedTaskId',
                ),
              ),
              subDomain: 'runInference',
            ),
          ).called(1);

          container.dispose();
        });
      });

      test('status updates propagate to both main and linked entities', () {
        fakeAsync((async) {
          // Arrange
          const audioEntryId = 'audio-123';
          const linkedTaskId = 'task-456';
          const asrPromptId = 'asr-prompt';

          final container = ProviderContainer(
            overrides: [
              unifiedAiInferenceRepositoryProvider.overrideWithValue(
                mockRepositoryLinked,
              ),
              aiConfigByIdProvider(asrPromptId).overrideWith(
                (ref) => Future.value(asrPromptConfig),
              ),
            ],
          );

          final mainEntityStatuses = <InferenceStatus>[];
          final linkedEntityStatuses = <InferenceStatus>[];

          // Track status changes
          container
            ..listen(
              inferenceStatusControllerProvider((
                id: audioEntryId,
                aiResponseType: AiResponseType.audioTranscription,
              )),
              (previous, next) {
                mainEntityStatuses.add(next);
              },
              fireImmediately: true,
            )
            ..listen(
              inferenceStatusControllerProvider((
                id: linkedTaskId,
                aiResponseType: AiResponseType.audioTranscription,
              )),
              (previous, next) {
                linkedEntityStatuses.add(next);
              },
              fireImmediately: true,
            );

          when(
            () => mockRepositoryLinked.runInference(
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

            // Simulate the full lifecycle
            onStatusChange(InferenceStatus.running);
            onStatusChange(InferenceStatus.idle);
          });

          // Act: run the provider and drive fake time deterministically
          var finished = false;
          container
              .read(
                triggerNewInferenceProvider((
                  entityId: audioEntryId,
                  promptId: asrPromptId,
                  linkedEntityId: linkedTaskId,
                )).future,
              )
              .then((_) => finished = true);

          async
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 1))
            ..flushMicrotasks();

          // Assert - both entities should have the same status sequence
          expect(mainEntityStatuses, contains(InferenceStatus.running));
          expect(mainEntityStatuses, contains(InferenceStatus.idle));
          expect(linkedEntityStatuses, contains(InferenceStatus.running));
          expect(linkedEntityStatuses, contains(InferenceStatus.idle));

          // The sequences should be identical (after initial state)
          final mainSequence = mainEntityStatuses.skip(1).toList();
          final linkedSequence = linkedEntityStatuses.skip(1).toList();
          expect(mainSequence, equals(linkedSequence));

          container.dispose();
          expect(finished, isTrue);
        });
      });

      test('error status propagates to linked entity on failure', () {
        fakeAsync((async) {
          // Arrange
          const audioEntryId = 'audio-123';
          const linkedTaskId = 'task-456';
          const asrPromptId = 'asr-prompt';

          final container = ProviderContainer(
            overrides: [
              unifiedAiInferenceRepositoryProvider.overrideWithValue(
                mockRepositoryLinked,
              ),
              aiConfigByIdProvider(asrPromptId).overrideWith(
                (ref) => Future.value(asrPromptConfig),
              ),
            ],
          );

          var mainEntityErrorStatus = false;
          var linkedEntityErrorStatus = false;

          // Track error status
          container
            ..listen(
              inferenceStatusControllerProvider((
                id: audioEntryId,
                aiResponseType: AiResponseType.audioTranscription,
              )),
              (previous, next) {
                if (next == InferenceStatus.error) {
                  mainEntityErrorStatus = true;
                }
              },
            )
            ..listen(
              inferenceStatusControllerProvider((
                id: linkedTaskId,
                aiResponseType: AiResponseType.audioTranscription,
              )),
              (previous, next) {
                if (next == InferenceStatus.error) {
                  linkedEntityErrorStatus = true;
                }
              },
            );

          when(
            () => mockRepositoryLinked.runInference(
              entityId: any(named: 'entityId'),
              promptConfig: any(named: 'promptConfig'),
              onProgress: any(named: 'onProgress'),
              onStatusChange: any(named: 'onStatusChange'),
              linkedEntityId: any(named: 'linkedEntityId'),
            ),
          ).thenThrow(Exception('Network error'));

          // Act
          container.read(
            triggerNewInferenceProvider((
              entityId: audioEntryId,
              promptId: asrPromptId,
              linkedEntityId: linkedTaskId,
            )).future,
          );

          async.flushMicrotasks();

          // Assert
          expect(mainEntityErrorStatus, true);
          expect(linkedEntityErrorStatus, true);

          container.dispose();
        });
      });
    });

    group('Sequential Inference Execution Tests', () {
      test('ASR completes before task summary begins', () {
        fakeAsync((async) {
          // Arrange
          const audioEntryId = 'audio-123';
          const taskId = 'task-456';
          const asrPromptId = 'asr-prompt';
          const taskSummaryPromptId = 'task-summary-prompt';

          final container = ProviderContainer(
            overrides: [
              unifiedAiInferenceRepositoryProvider.overrideWithValue(
                mockRepositoryLinked,
              ),
              aiConfigByIdProvider(asrPromptId).overrideWith(
                (ref) => Future.value(asrPromptConfig),
              ),
              aiConfigByIdProvider(taskSummaryPromptId).overrideWith(
                (ref) => Future.value(taskSummaryPromptConfig),
              ),
            ],
          );

          final executionOrder = <String>[];

          when(
            () => mockRepositoryLinked.runInference(
              entityId: any(named: 'entityId'),
              promptConfig: any(named: 'promptConfig'),
              onProgress: any(named: 'onProgress'),
              onStatusChange: any(named: 'onStatusChange'),
              linkedEntityId: any(named: 'linkedEntityId'),
            ),
          ).thenAnswer((invocation) async {
            final promptConfig =
                invocation.namedArguments[#promptConfig] as AiConfigPrompt;
            final onProgress =
                invocation.namedArguments[#onProgress] as void Function(String);
            final onStatusChange =
                invocation.namedArguments[#onStatusChange]
                    as void Function(InferenceStatus);

            if (promptConfig.aiResponseType ==
                AiResponseType.audioTranscription) {
              executionOrder.add('ASR_START');
              onStatusChange(InferenceStatus.running);
              onProgress('Transcribing audio...');
              onProgress('Transcription complete: "Hello world"');
              onStatusChange(InferenceStatus.idle);
              executionOrder.add('ASR_COMPLETE');
            } else if (promptConfig.aiResponseType ==
                AiResponseType.taskSummary) {
              executionOrder.add('TASK_SUMMARY_START');
              onStatusChange(InferenceStatus.running);
              onProgress('Generating task summary...');
              onProgress('Summary: Task updated with transcription');
              onStatusChange(InferenceStatus.idle);
              executionOrder.add('TASK_SUMMARY_COMPLETE');
            }
          });

          // Act - simulate the sequential flow
          // First, trigger ASR with linked task ID
          container.read(
            triggerNewInferenceProvider((
              entityId: audioEntryId,
              promptId: asrPromptId,
              linkedEntityId: taskId,
            )).future,
          );

          async.flushMicrotasks();

          // Then trigger task summary
          container.read(
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: taskSummaryPromptId,
              linkedEntityId: null,
            )).future,
          );

          async.flushMicrotasks();

          // Assert - verify sequential execution
          expect(executionOrder, [
            'ASR_START',
            'ASR_COMPLETE',
            'TASK_SUMMARY_START',
            'TASK_SUMMARY_COMPLETE',
          ]);

          // Verify that ASR was called before task summary
          final asrStartIndex = executionOrder.indexOf('ASR_START');
          final asrCompleteIndex = executionOrder.indexOf('ASR_COMPLETE');
          final taskSummaryStartIndex = executionOrder.indexOf(
            'TASK_SUMMARY_START',
          );

          expect(asrStartIndex, lessThan(asrCompleteIndex));
          expect(asrCompleteIndex, lessThan(taskSummaryStartIndex));

          container.dispose();
        });
      });

      test('task summary waits for ASR to complete before starting', () {
        fakeAsync((async) {
          // Arrange
          const audioEntryId = 'audio-123';
          const taskId = 'task-456';
          const asrPromptId = 'asr-prompt';
          const taskSummaryPromptId = 'task-summary-prompt';

          final container = ProviderContainer(
            overrides: [
              unifiedAiInferenceRepositoryProvider.overrideWithValue(
                mockRepositoryLinked,
              ),
              aiConfigByIdProvider(asrPromptId).overrideWith(
                (ref) => Future.value(asrPromptConfig),
              ),
              aiConfigByIdProvider(taskSummaryPromptId).overrideWith(
                (ref) => Future.value(taskSummaryPromptConfig),
              ),
            ],
          );

          final executionOrder = <String>[];

          when(
            () => mockRepositoryLinked.runInference(
              entityId: any(named: 'entityId'),
              promptConfig: any(named: 'promptConfig'),
              onProgress: any(named: 'onProgress'),
              onStatusChange: any(named: 'onStatusChange'),
              linkedEntityId: any(named: 'linkedEntityId'),
            ),
          ).thenAnswer((invocation) async {
            final promptConfig =
                invocation.namedArguments[#promptConfig] as AiConfigPrompt;
            final onStatusChange =
                invocation.namedArguments[#onStatusChange]
                    as void Function(InferenceStatus);

            if (promptConfig.aiResponseType ==
                AiResponseType.audioTranscription) {
              executionOrder.add('ASR_START');
              onStatusChange(InferenceStatus.running);
              onStatusChange(InferenceStatus.idle);
              executionOrder.add('ASR_END');
            } else if (promptConfig.aiResponseType ==
                AiResponseType.taskSummary) {
              executionOrder.add('TASK_SUMMARY_START');
              onStatusChange(InferenceStatus.running);
              onStatusChange(InferenceStatus.idle);
              executionOrder.add('TASK_SUMMARY_END');
            }
          });

          // Act
          // Start ASR
          var asrDone = false;
          container
              .read(
                triggerNewInferenceProvider((
                  entityId: audioEntryId,
                  promptId: asrPromptId,
                  linkedEntityId: taskId,
                )).future,
              )
              .then((_) => asrDone = true);

          async.flushMicrotasks();
          expect(asrDone, isTrue);

          // Then start task summary
          var taskSummaryDone = false;
          container
              .read(
                triggerNewInferenceProvider((
                  entityId: taskId,
                  promptId: taskSummaryPromptId,
                  linkedEntityId: null,
                )).future,
              )
              .then((_) => taskSummaryDone = true);

          async.flushMicrotasks();
          expect(taskSummaryDone, isTrue);

          // Assert - task summary should start after ASR ends
          expect(executionOrder, [
            'ASR_START',
            'ASR_END',
            'TASK_SUMMARY_START',
            'TASK_SUMMARY_END',
          ]);

          // Verify ordering
          final asrEndIndex = executionOrder.indexOf('ASR_END');
          final taskSummaryStartIndex = executionOrder.indexOf(
            'TASK_SUMMARY_START',
          );
          expect(
            asrEndIndex,
            lessThan(taskSummaryStartIndex),
            reason: 'Task summary should start after ASR completes',
          );

          container.dispose();
        });
      });

      test('linked entity shows both ASR and task summary animations', () {
        fakeAsync((async) {
          // Arrange
          const audioEntryId = 'audio-123';
          const taskId = 'task-456';
          const asrPromptId = 'asr-prompt';
          const taskSummaryPromptId = 'task-summary-prompt';

          final container = ProviderContainer(
            overrides: [
              unifiedAiInferenceRepositoryProvider.overrideWithValue(
                mockRepositoryLinked,
              ),
              aiConfigByIdProvider(asrPromptId).overrideWith(
                (ref) => Future.value(asrPromptConfig),
              ),
              aiConfigByIdProvider(taskSummaryPromptId).overrideWith(
                (ref) => Future.value(taskSummaryPromptConfig),
              ),
            ],
          );

          final taskEntityStatuses = <Map<String, dynamic>>[];

          // Track status changes for the task entity for both response types
          container
            ..listen(
              inferenceStatusControllerProvider((
                id: taskId,
                aiResponseType: AiResponseType.audioTranscription,
              )),
              (previous, next) {
                taskEntityStatuses.add({
                  'type': 'ASR',
                  'status': next,
                });
              },
            )
            ..listen(
              inferenceStatusControllerProvider((
                id: taskId,
                aiResponseType: AiResponseType.taskSummary,
              )),
              (previous, next) {
                taskEntityStatuses.add({
                  'type': 'TaskSummary',
                  'status': next,
                });
              },
            );

          when(
            () => mockRepositoryLinked.runInference(
              entityId: any(named: 'entityId'),
              promptConfig: any(named: 'promptConfig'),
              onProgress: any(named: 'onProgress'),
              onStatusChange: any(named: 'onStatusChange'),
              linkedEntityId: any(named: 'linkedEntityId'),
            ),
          ).thenAnswer((invocation) async {
            final promptConfig =
                invocation.namedArguments[#promptConfig] as AiConfigPrompt;
            final onStatusChange =
                invocation.namedArguments[#onStatusChange]
                    as void Function(InferenceStatus);

            if (promptConfig.aiResponseType ==
                AiResponseType.audioTranscription) {
              onStatusChange(InferenceStatus.running);
              onStatusChange(InferenceStatus.idle);
            } else if (promptConfig.aiResponseType ==
                AiResponseType.taskSummary) {
              onStatusChange(InferenceStatus.running);
              onStatusChange(InferenceStatus.idle);
            }
          });

          // Act
          // Trigger ASR with linked task
          container.read(
            triggerNewInferenceProvider((
              entityId: audioEntryId,
              promptId: asrPromptId,
              linkedEntityId: taskId,
            )).future,
          );

          async.flushMicrotasks();

          // Trigger task summary
          container.read(
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: taskSummaryPromptId,
              linkedEntityId: null,
            )).future,
          );

          async.flushMicrotasks();

          // Assert - task entity should have received status updates for both
          // types
          final asrStatuses = taskEntityStatuses
              .where((s) => s['type'] == 'ASR')
              .map((s) => s['status'])
              .toList();
          final taskSummaryStatuses = taskEntityStatuses
              .where((s) => s['type'] == 'TaskSummary')
              .map((s) => s['status'])
              .toList();

          // Should have ASR status updates
          expect(asrStatuses, contains(InferenceStatus.running));
          expect(asrStatuses, contains(InferenceStatus.idle));

          // Should have task summary status updates
          expect(taskSummaryStatuses, contains(InferenceStatus.running));
          expect(taskSummaryStatuses, contains(InferenceStatus.idle));

          container.dispose();
        });
      });
    });
  });
}

/// One generated (entity kind, linkedFrom, skill shape) combination for the
/// availability-filter property, with the oracle predicate inlined.
class _SkillFilterScenario {
  _SkillFilterScenario(int seed)
    : entityKind = seed % 4,
      hasLinkedFrom = (seed ~/ 4).isEven,
      skillType = SkillType.values[(seed ~/ 8) % SkillType.values.length],
      contextPolicy =
          ContextPolicy.values[(seed ~/ 40) % ContextPolicy.values.length],
      modalities = [
        if (seed & 256 != 0) Modality.audio,
        if (seed & 512 != 0) Modality.image,
        if (seed & 1024 != 0) Modality.text,
      ];

  final int entityKind; // 0=JournalEntry 1=JournalAudio 2=Task 3=JournalImage
  final bool hasLinkedFrom;
  final SkillType skillType;
  final ContextPolicy contextPolicy;
  final List<Modality> modalities;

  JournalEntity buildEntity() {
    final date = DateTime(2024, 3, 15);
    final meta = Metadata(
      id: 'entity-prop',
      createdAt: date,
      updatedAt: date,
      dateFrom: date,
      dateTo: date,
    );
    return switch (entityKind) {
      0 => JournalEntity.journalEntry(meta: meta),
      1 => JournalEntity.journalAudio(
        meta: meta,
        data: AudioData(
          dateFrom: date,
          dateTo: date,
          audioFile: 'p.m4a',
          audioDirectory: '/p',
          duration: const Duration(minutes: 1),
        ),
      ),
      2 => JournalEntity.task(
        meta: meta,
        data: TaskData(
          status: TaskStatus.open(id: 's', createdAt: date, utcOffset: 0),
          dateFrom: date,
          dateTo: date,
          statusHistory: const [],
          title: 'Prop task',
        ),
      ),
      _ => JournalEntity.journalImage(
        meta: meta,
        data: ImageData(
          capturedAt: date,
          imageId: 'img',
          imageFile: 'p.jpg',
          imageDirectory: '/p',
        ),
      ),
    };
  }

  bool get expectIncluded {
    final isTask = entityKind == 2;
    final hasTaskContext = isTask || hasLinkedFrom;
    if (skillType == SkillType.imageGeneration &&
        (!hasTaskContext || (entityKind != 0 && entityKind != 1))) {
      return false;
    }
    if (!hasTaskContext && contextPolicy == ContextPolicy.fullTask) {
      return false;
    }
    if (modalities.contains(Modality.audio) && entityKind != 1) return false;
    if (modalities.contains(Modality.image) && entityKind != 3) return false;
    // All four entity kinds carry text, so the text guard never rejects.
    return true;
  }

  @override
  String toString() =>
      '_SkillFilterScenario(kind: $entityKind, linked: $hasLinkedFrom, '
      'type: $skillType, policy: $contextPolicy, modalities: $modalities)';
}

extension _AnySkillFilterScenario on glados.Any {
  glados.Generator<_SkillFilterScenario> get skillFilterScenario =>
      glados.IntAnys(this).intInRange(0, 1 << 12).map(_SkillFilterScenario.new);
}
