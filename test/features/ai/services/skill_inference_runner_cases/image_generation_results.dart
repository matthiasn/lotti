part of '../skill_inference_runner_test.dart';

extension _ImageGenerationResultCases on _SkillInferenceTestSetup {
  void registerImageGenerationSourceAndCoverArt() {
    test(
      'accepts a JournalEntry source and threads its text into the prompt',
      () async {
        final textEntry = makeTextEntry(
          id: 'text-img',
          markdown: 'Sunset over mountains, painterly style',
          categoryId: 'cat-img',
        );
        final taskEntity = makeTaskEntity('task-text-img');

        when(
          () => mockAiInputRepo.getEntity('text-img'),
        ).thenAnswer((_) async => textEntry);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-text-img'),
        ).thenAnswer((_) async => '{"id": "task-text-img"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-text-img'),
        ).thenAnswer((_) async => '{"linked": []}');
        when(
          () => mockTaskSummaryResolver.resolve('task-text-img'),
        ).thenAnswer((_) async => 'Mountain photography brief');
        when(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            referenceImages: any(named: 'referenceImages'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) async => const GeneratedImage(
            bytes: [0x89, 0x50, 0x4E, 0x47],
            mimeType: 'image/png',
          ),
        );

        final mockPersistenceLogic = MockPersistenceLogic();
        getIt
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockLoggingService);

        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            flag: any(named: 'flag'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => Metadata(
            id: 'gen-img',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            categoryId: 'cat-img',
          ),
        );
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
            linkCollapsed: any(named: 'linkCollapsed'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockJournalRepo.getJournalEntityById('task-text-img'),
        ).thenAnswer((_) async => taskEntity);
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
          ),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageGeneration(
          entryId: 'text-img',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-text-img',
        );

        final captured = verify(
          () => mockCloudRepo.generateImage(
            prompt: captureAny(named: 'prompt'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            referenceImages: any(named: 'referenceImages'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).captured;
        final prompt = captured.first as String;
        expect(prompt, contains('**Entry Notes:**'));
        expect(prompt, contains('Sunset over mountains, painterly style'));
      },
    );

    test(
      'sets coverArtId to the imported JournalImage entity id, not the '
      'internal pre-generation id — regression: createImageEntry derives '
      'the real entity id from a uuidV5 hash of the encoded ImageData, so '
      'it never equals the caller-supplied ImageData.imageId used for '
      'attribution tracking. Using the wrong id here silently breaks '
      'cover art: the task points at an id nothing is ever stored under',
      () async {
        final textEntry = makeTextEntry(
          id: 'text-img-cover',
          markdown: 'A lighthouse at dusk',
          categoryId: 'cat-img',
        );
        final taskEntity = makeTaskEntity('task-cover-id');

        when(
          () => mockAiInputRepo.getEntity('text-img-cover'),
        ).thenAnswer((_) async => textEntry);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-cover-id'),
        ).thenAnswer((_) async => '{"id": "task-cover-id"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-cover-id'),
        ).thenAnswer((_) async => '{"linked": []}');
        when(
          () => mockTaskSummaryResolver.resolve('task-cover-id'),
        ).thenAnswer((_) async => 'Lighthouse brief');
        when(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            referenceImages: any(named: 'referenceImages'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) async => const GeneratedImage(
            bytes: [0x89, 0x50, 0x4E, 0x47],
            mimeType: 'image/png',
          ),
        );

        final mockPersistenceLogic = MockPersistenceLogic();
        getIt
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockLoggingService);

        // The real entity id, deliberately different from anything the
        // production code could derive from ImageData.imageId — proves
        // the fix reads this value back rather than reusing the
        // pre-generated attribution id.
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            flag: any(named: 'flag'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => Metadata(
            id: 'the-real-persisted-image-entity-id',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            categoryId: 'cat-img',
          ),
        );
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
            linkCollapsed: any(named: 'linkCollapsed'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockJournalRepo.getJournalEntityById('task-cover-id'),
        ).thenAnswer((_) async => taskEntity);
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
          ),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageGeneration(
          entryId: 'text-img-cover',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-cover-id',
        );

        final capturedTaskData =
            verify(
                  () => mockPersistenceLogic.updateTask(
                    journalEntityId: 'task-cover-id',
                    taskData: captureAny(named: 'taskData'),
                  ),
                ).captured.single
                as TaskData;

        expect(
          capturedTaskData.coverArtId,
          'the-real-persisted-image-entity-id',
        );
      },
    );
  }

  void registerImageGenerationResult() {
    test(
      'happy path: generates cover art, imports image, and updates task',
      () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-gen',
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    categoryId: 'cat-1',
                  ),
                  data: AudioData(
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    duration: const Duration(minutes: 1),
                    audioDirectory: '/audio/',
                    audioFile: 'test.aac',
                  ),
                  entryText: const EntryText(
                    plainText: 'A sunset over a mountain landscape',
                    markdown: 'A sunset over a mountain landscape',
                  ),
                )
                as JournalAudio;

        final taskEntity = makeTaskEntity('task-gen');

        // Stub entity fetching.
        when(
          () => mockAiInputRepo.getEntity('audio-gen'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-gen'),
        ).thenAnswer((_) async => '{"id": "task-gen"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-gen'),
        ).thenAnswer(
          (_) async => '{"linked_from": [], "linked_to": []}',
        );
        when(
          () => mockTaskSummaryResolver.resolve('task-gen'),
        ).thenAnswer((_) async => 'A task about mountain photography');

        // Stub image generation.
        when(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            referenceImages: any(named: 'referenceImages'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) async => const GeneratedImage(
            bytes: [0x89, 0x50, 0x4E, 0x47], // PNG header
            mimeType: 'image/png',
          ),
        );

        // Register PersistenceLogic mock in getIt for importGeneratedImageBytes
        // and task update.
        final mockPersistenceLogic = MockPersistenceLogic();
        getIt
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockLoggingService);

        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            flag: any(named: 'flag'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => Metadata(
            id: 'generated-img-id',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            categoryId: 'cat-1',
          ),
        );
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
            linkCollapsed: any(named: 'linkCollapsed'),
          ),
        ).thenAnswer((_) async => true);

        // Stub task fetching for cover art assignment.
        when(
          () => mockJournalRepo.getJournalEntityById('task-gen'),
        ).thenAnswer((_) async => taskEntity);

        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
          ),
        ).thenAnswer((_) async => true);

        stubLoggingEvent();

        // Create a container with the trigger provider overridden.
        final mockTrigger = MockAutomaticImageAnalysisTrigger();
        when(
          () => mockTrigger.triggerAutomaticImageAnalysis(
            imageEntryId: any(named: 'imageEntryId'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        ).thenAnswer((_) async => true);

        // Rebuild runner with a container that has the trigger override.
        final testContainer = ProviderContainer(
          overrides: [
            automaticImageAnalysisTriggerProvider.overrideWithValue(
              mockTrigger,
            ),
          ],
        );
        addTearDown(testContainer.dispose);

        late final Ref capturedRef;
        final refProvider = Provider<void>((ref) {
          capturedRef = ref;
        });
        testContainer.read(refProvider);

        final testRunner = SkillInferenceRunner(
          ref: capturedRef,
          cloudRepository: mockCloudRepo,
          aiInputRepository: mockAiInputRepo,
          journalRepository: mockJournalRepo,
          loggingService: mockLoggingService,
          promptBuilderHelper: mockPromptBuilderHelper,
          taskSummaryResolver: mockTaskSummaryResolver,
        );

        await testRunner.runImageGeneration(
          entryId: 'audio-gen',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-gen',
        );

        // Verify image generation was called.
        verify(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: 'models/gemini-image',
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            referenceImages: any(named: 'referenceImages'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).called(1);

        // Verify task was updated with cover art.
        verify(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: 'task-gen',
            taskData: any(named: 'taskData'),
          ),
        ).called(1);

        // Verify success event was logged.
        verify(
          () => mockLoggingService.log(
            LogDomain.ai,
            any<String>(that: contains('image generation completed')),
            subDomain: 'runImageGeneration',
          ),
        ).called(1);

        // Verify automatic image analysis was triggered.
        verify(
          () => mockTrigger.triggerAutomaticImageAnalysis(
            imageEntryId: any(named: 'imageEntryId'),
            linkedTaskId: 'task-gen',
          ),
        ).called(1);
      },
    );
  }

  void registerImageGenerationReferenceImages() {
    test(
      'happy path with reference images passes them to generateImage',
      () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-ref',
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                  ),
                  data: AudioData(
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    duration: const Duration(minutes: 1),
                    audioDirectory: '/audio/',
                    audioFile: 'test.aac',
                  ),
                  entryText: const EntryText(
                    plainText: 'Like the previous style',
                    markdown: 'Like the previous style',
                  ),
                )
                as JournalAudio;

        final taskEntity = makeTaskEntity('task-ref');

        when(
          () => mockAiInputRepo.getEntity('audio-ref'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-ref'),
        ).thenAnswer((_) async => '{"id": "task-ref"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-ref'),
        ).thenAnswer(
          (_) async => '{"linked_from": [], "linked_to": []}',
        );
        when(
          () => mockTaskSummaryResolver.resolve('task-ref'),
        ).thenAnswer((_) async => null);

        const refImages = [
          ProcessedReferenceImage(
            base64Data: 'abc123',
            mimeType: 'image/jpeg',
          ),
        ];

        when(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            referenceImages: any(named: 'referenceImages'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) async => const GeneratedImage(
            bytes: [0xFF, 0xD8, 0xFF, 0xE0], // JPEG header
            mimeType: 'image/jpeg',
          ),
        );

        // setUp resets getIt per test, so register unconditionally —
        // matching the sibling happy-path tests' setup strategy.
        final mockPersistenceLogic = MockPersistenceLogic();
        getIt.registerSingleton<PersistenceLogic>(mockPersistenceLogic);

        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            flag: any(named: 'flag'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => Metadata(
            id: 'gen-img-ref',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
          ),
        );
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
            linkCollapsed: any(named: 'linkCollapsed'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
          ),
        ).thenAnswer((_) async => true);

        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockLoggingService);

        when(
          () => mockJournalRepo.getJournalEntityById('task-ref'),
        ).thenAnswer((_) async => taskEntity);

        stubLoggingEvent();

        final mockTrigger = MockAutomaticImageAnalysisTrigger();
        when(
          () => mockTrigger.triggerAutomaticImageAnalysis(
            imageEntryId: any(named: 'imageEntryId'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        ).thenAnswer((_) async => true);

        final testContainer = ProviderContainer(
          overrides: [
            automaticImageAnalysisTriggerProvider.overrideWithValue(
              mockTrigger,
            ),
          ],
        );
        addTearDown(testContainer.dispose);

        late final Ref capturedRef;
        final refProvider = Provider<void>((ref) {
          capturedRef = ref;
        });
        testContainer.read(refProvider);

        final testRunner = SkillInferenceRunner(
          ref: capturedRef,
          cloudRepository: mockCloudRepo,
          aiInputRepository: mockAiInputRepo,
          journalRepository: mockJournalRepo,
          loggingService: mockLoggingService,
          promptBuilderHelper: mockPromptBuilderHelper,
          taskSummaryResolver: mockTaskSummaryResolver,
        );

        await testRunner.runImageGeneration(
          entryId: 'audio-ref',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-ref',
          referenceImages: refImages,
        );

        // Verify reference images were passed through.
        verify(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: 'models/gemini-image',
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            referenceImages: refImages,
            impactCollector: any(named: 'impactCollector'),
          ),
        ).called(1);
      },
    );
  }
}
