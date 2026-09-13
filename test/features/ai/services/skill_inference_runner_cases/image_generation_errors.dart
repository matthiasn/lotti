part of '../skill_inference_runner_test.dart';

extension _ImageGenerationErrorCases on _SkillInferenceTestSetup {
  String? imageGenError(String id) =>
      container.read(imageGenerationErrorControllerProvider(id));

  void stubImageGenPipeline(String entryId, String taskId) {
    when(
      () => mockAiInputRepo.getEntity(entryId),
    ).thenAnswer(
      (_) async =>
          makeTextEntry(id: entryId, markdown: 'A scene', categoryId: 'c'),
    );
    when(
      () => mockAiInputRepo.buildTaskDetailsJson(id: taskId),
    ).thenAnswer((_) async => '{}');
    when(
      () => mockAiInputRepo.buildLinkedTasksJson(taskId),
    ).thenAnswer((_) async => '{}');
    when(
      () => mockTaskSummaryResolver.resolve(taskId),
    ).thenAnswer((_) async => 'brief');
  }

  void registerImageGenerationAccountingAndErrors() {
    test(
      'records the billed call with its Melious impact even when the '
      'linked task disappeared mid-flight (recording happens before the '
      'task-existence check)',
      () async {
        final attribution = _registerInteractionCapture();
        stubImageGenPipeline('img-gone', 'task-gone');
        when(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            referenceImages: any(named: 'referenceImages'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer((invocation) async {
          // The Melious adapter reports impact out of band by writing into
          // the collector the runner passed down.
          (invocation.namedArguments[#impactCollector]
                  as InferenceImpactCollector?)
              ?.impact = const MeliousCallImpact(
            costCredits: 0.75,
            energyKwh: 0.01,
            carbonGCo2: 2.5,
            waterLiters: 0.6,
            renewablePercent: 90,
            pue: 1.1,
            dataCenter: 'FI',
            providerId: 'upstream-img',
          );
          return const GeneratedImage(
            bytes: [0x89, 0x50, 0x4E, 0x47],
            mimeType: 'image/png',
          );
        });
        // The linked task is gone by the time the generated image returns.
        when(
          () => mockJournalRepo.getJournalEntityById('task-gone'),
        ).thenAnswer((_) async => null);
        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'img-gone',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-gone',
        );

        // The run itself fails on the task-existence check afterwards…
        final loggedError =
            verify(
                  () => mockLoggingService.error(
                    LogDomain.ai,
                    captureAny<Object>(),
                    stackTrace: any<StackTrace?>(named: 'stackTrace'),
                    subDomain: 'runImageGeneration',
                  ),
                ).captured.single
                as Object;
        expect(loggedError, isA<StateError>());

        // …but the billed call was already recorded, without a category
        // (there is no task left to read it from) and without token counts
        // (image generation is a single request, not a token stream).
        final event = _capturedEvents(attribution).single;
        expect(event.entryId, 'img-gone');
        expect(event.taskId, 'task-gone');
        expect(event.categoryId, isNull);
        expect(event.skillId, 'skill-image-gen');
        expect(
          event.responseType,
          AiConsumptionResponseType.imageGeneration,
        );
        expect(event.providerModelId, 'models/gemini-image');
        expect(event.inputTokens, isNull);
        expect(event.outputTokens, isNull);
        expect(event.totalTokens, isNull);
        expect(event.credits, 0.75);
        expect(event.energyKwh, 0.01);
        expect(event.carbonGCo2, 2.5);
        expect(event.waterLiters, 0.6);
        expect(event.renewablePercent, 90);
        expect(event.pue, 1.1);
        expect(event.dataCenter, 'FI');
        expect(event.upstreamProviderId, 'upstream-img');
      },
    );

    test(
      'publishes the provider reason to the error controller on rejection',
      () async {
        stubImageGenPipeline('img-rej', 'task-rej');
        when(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            referenceImages: any(named: 'referenceImages'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenThrow(
          ImageGenerationException(
            'blocked',
            providerReason: 'PROHIBITED_CONTENT',
          ),
        );
        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'img-rej',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-rej',
        );

        // Set for both the entry and the linked task (the UI watches the
        // task) so the cover-art modal can surface the verbatim reason.
        expect(imageGenError('task-rej'), 'PROHIBITED_CONTENT');
        expect(imageGenError('img-rej'), 'PROHIBITED_CONTENT');
      },
    );

    test(
      'leaves the error reason null when the failure has no provider reason',
      () async {
        stubImageGenPipeline('img-net', 'task-net');
        when(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            referenceImages: any(named: 'referenceImages'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenThrow(Exception('network down'));
        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'img-net',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-net',
        );

        expect(imageGenError('task-net'), isNull);
      },
    );
  }

  void registerImageGenerationFailure() {
    test('logs exception on failure', () async {
      when(
        () => mockAiInputRepo.getEntity('entry-1'),
      ).thenThrow(Exception('DB error'));
      stubLoggingException();

      await runner.runImageGeneration(
        entryId: 'entry-1',
        automationResult: makeImageGenResult(),
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
  }

  void registerImageGenerationPersistenceErrors() {
    test(
      'logs error when linked task not found before cover art save',
      () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-err-1',
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
                    plainText: 'test',
                    markdown: 'test',
                  ),
                )
                as JournalAudio;

        when(
          () => mockAiInputRepo.getEntity('audio-err-1'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-err-1'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-err-1'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockTaskSummaryResolver.resolve('task-err-1'),
        ).thenAnswer((_) async => null);

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

        // Linked task not found
        when(
          () => mockJournalRepo.getJournalEntityById('task-err-1'),
        ).thenAnswer((_) async => null);

        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'audio-err-1',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-err-1',
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(
              that: isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('not found before cover art save'),
              ),
            ),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runImageGeneration',
          ),
        ).called(1);
      },
    );

    test(
      'logs error when image import fails',
      () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-err-2',
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
                    plainText: 'test',
                    markdown: 'test',
                  ),
                )
                as JournalAudio;

        final taskEntity = makeTaskEntity('task-err-2');

        when(
          () => mockAiInputRepo.getEntity('audio-err-2'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-err-2'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-err-2'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockTaskSummaryResolver.resolve('task-err-2'),
        ).thenAnswer((_) async => null);

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

        when(
          () => mockJournalRepo.getJournalEntityById('task-err-2'),
        ).thenAnswer((_) async => taskEntity);

        // Mock PersistenceLogic so createDbEntity throws (causing
        // importGeneratedImageBytes to return null).
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
            id: 'gen-img-err2',
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
        ).thenThrow(Exception('DB write failed'));

        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'audio-err-2',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-err-2',
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

    test(
      'logs error when task update returns false',
      () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-err-3',
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
                    plainText: 'test',
                    markdown: 'test',
                  ),
                )
                as JournalAudio;

        final taskEntity = makeTaskEntity('task-err-3');

        when(
          () => mockAiInputRepo.getEntity('audio-err-3'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-err-3'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-err-3'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockTaskSummaryResolver.resolve('task-err-3'),
        ).thenAnswer((_) async => null);

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

        when(
          () => mockJournalRepo.getJournalEntityById('task-err-3'),
        ).thenAnswer((_) async => taskEntity);

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
            id: 'gen-img-err3',
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

        // updateTask returns false (task disappeared)
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
          ),
        ).thenAnswer((_) async => false);

        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'audio-err-3',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-err-3',
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(
              that: isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('disappeared before cover art update'),
              ),
            ),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runImageGeneration',
          ),
        ).called(1);
      },
    );
  }
}
