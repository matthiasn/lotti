part of '../skill_inference_runner_test.dart';

extension _ImageGenerationInputCases on _SkillInferenceTestSetup {
  void registerImageGenerationGuards() {
    test('logs error when skill is null', () async {
      final result = AutomationResult(
        handled: true,
        resolvedProfile: ResolvedProfile(
          thinkingModelId: 'models/gemini-flash',
          thinkingProvider: testInferenceProvider(),
        ),
      );
      stubLoggingException();

      await runner.runImageGeneration(
        entryId: 'entry-1',
        automationResult: result,
        linkedTaskId: 'task-1',
      );

      verify(
        () => mockLoggingService.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'runImageGeneration',
        ),
      ).called(1);
    });

    test('logs error when profile is null', () async {
      final result = AutomationResult(
        handled: true,
        skill: testImageGenSkill,
      );
      stubLoggingException();

      await runner.runImageGeneration(
        entryId: 'entry-1',
        automationResult: result,
        linkedTaskId: 'task-1',
      );

      verify(
        () => mockLoggingService.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'runImageGeneration',
        ),
      ).called(1);
    });

    test('logs error when no image generation provider', () async {
      final result = AutomationResult(
        handled: true,
        resolvedProfile: ResolvedProfile(
          thinkingModelId: 'models/gemini-flash',
          thinkingProvider: testInferenceProvider(),
          // imageGenerationProvider/ModelId intentionally omitted
        ),
        skill: testImageGenSkill,
      );
      stubLoggingException();

      await runner.runImageGeneration(
        entryId: 'entry-1',
        automationResult: result,
        linkedTaskId: 'task-1',
      );

      verifyZeroInteractions(mockCloudRepo);
      verify(
        () => mockLoggingService.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'runImageGeneration',
        ),
      ).called(1);
    });

    test(
      'rejects non-text-bearing entities (Task) and never calls generator',
      () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenAnswer((_) async => makeTaskEntity('entry-1'));
        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'entry-1',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-1',
        );

        verifyNever(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            impactCollector: any(named: 'impactCollector'),
          ),
        );
        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runImageGeneration',
          ),
        ).called(1);
      },
    );

    test('logs error when getEntity returns null', () async {
      when(
        () => mockAiInputRepo.getEntity('missing-img'),
      ).thenAnswer((_) async => null);
      stubLoggingException();

      await runner.runImageGeneration(
        entryId: 'missing-img',
        automationResult: makeImageGenResult(),
        linkedTaskId: 'task-1',
      );

      verifyNever(
        () => mockCloudRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          impactCollector: any(named: 'impactCollector'),
        ),
      );
      verify(
        () => mockLoggingService.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'runImageGeneration',
        ),
      ).called(1);
    });
  }

  void registerImageGenerationOverrides() {
    test(
      'overrideModelId routes image generation to the override model + '
      'provider instead of the profile slot — the cover-art picker uses '
      'this seam to generate one cover with a non-default image model',
      () async {
        final textEntry = makeTextEntry(
          id: 'text-override',
          markdown: 'A neon city at night',
          categoryId: 'cat-img',
        );
        final taskEntity = makeTaskEntity('task-override-img');

        final overrideProvider =
            AiConfig.inferenceProvider(
                  id: 'p-override-img',
                  baseUrl: 'https://override-img.example.com',
                  name: 'Override Image Provider',
                  inferenceProviderType: InferenceProviderType.openAi,
                  apiKey: 'override-key',
                  createdAt: DateTime(2024),
                )
                as AiConfigInferenceProvider;
        final overrideModel =
            AiConfig.model(
                  id: 'override-img-model',
                  name: 'Nano Banana',
                  providerModelId: 'nano-banana-v2',
                  inferenceProviderId: 'p-override-img',
                  createdAt: DateTime(2024),
                  inputModalities: const [Modality.text],
                  outputModalities: const [Modality.image],
                  isReasoningModel: false,
                )
                as AiConfigModel;

        when(
          () => mockAiConfigRepo.getConfigById('override-img-model'),
        ).thenAnswer((_) async => overrideModel);
        when(
          () => mockAiConfigRepo.getConfigById('p-override-img'),
        ).thenAnswer((_) async => overrideProvider);

        when(
          () => mockAiInputRepo.getEntity('text-override'),
        ).thenAnswer((_) async => textEntry);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-override-img'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-override-img'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockTaskSummaryResolver.resolve('task-override-img'),
        ).thenAnswer((_) async => 'brief');
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
          () => mockJournalRepo.getJournalEntityById('task-override-img'),
        ).thenAnswer((_) async => taskEntity);
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
          ),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageGeneration(
          entryId: 'text-override',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-override-img',
          overrideModelId: 'override-img-model',
        );

        // Generation targeted the override model + provider, NOT the
        // profile slot's `models/gemini-image` / `p-image`.
        verify(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: 'nano-banana-v2',
            provider: overrideProvider,
            systemMessage: any(named: 'systemMessage'),
            referenceImages: any(named: 'referenceImages'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).called(1);
      },
    );
  }

  void registerImageGenerationTranscriptInput() {
    test(
      'threads the [No transcription available] placeholder into the '
      'prompt for an audio entry without transcript or entry text',
      () async {
        // No entryText and no transcripts → _resolveEntryContent falls
        // through to the placeholder for runImageGeneration too.
        final audioEntity = makeAudioEntity(id: 'audio-img');
        final taskEntity = makeTaskEntity('task-audio-img');

        when(
          () => mockAiInputRepo.getEntity('audio-img'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-audio-img'),
        ).thenAnswer((_) async => '{"id": "task-audio-img"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-audio-img'),
        ).thenAnswer((_) async => '{"linked": []}');
        when(
          () => mockTaskSummaryResolver.resolve('task-audio-img'),
        ).thenAnswer((_) async => 'Audio task brief');
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
            id: 'gen-img-audio',
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
          () => mockJournalRepo.getJournalEntityById('task-audio-img'),
        ).thenAnswer((_) async => taskEntity);
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
          ),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageGeneration(
          entryId: 'audio-img',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-audio-img',
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
        expect(prompt, contains('[No transcription available]'));
      },
    );
  }
}
