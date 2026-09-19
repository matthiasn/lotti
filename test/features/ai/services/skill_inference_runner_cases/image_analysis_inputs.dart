part of '../skill_inference_runner_test.dart';

extension _ImageAnalysisInputCases on _SkillInferenceTestSetup {
  void registerImageAnalysisGuards() {
    test(
      'throws StateError when skill is null in AutomationResult',
      () async {
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-3-flash-preview',
            thinkingProvider: testInferenceProvider(),
            imageRecognitionModelId: 'vision-model',
            imageRecognitionProvider: testInferenceProvider(id: 'p-vision'),
          ),
        );

        expect(
          () => runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: result,
          ),
          throwsStateError,
        );
      },
    );

    test(
      'throws StateError when profile is null in AutomationResult',
      () async {
        final result = AutomationResult(
          handled: true,
          skill: testImageSkill,
        );

        expect(
          () => runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: result,
          ),
          throwsStateError,
        );
      },
    );

    test(
      'returns early when image recognition provider is null',
      () async {
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-3-flash-preview',
            thinkingProvider: testInferenceProvider(),
          ),
          skill: testImageSkill,
          skillAssignment: const SkillAssignment(
            skillId: 'skill-vision',
            automate: true,
          ),
        );

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: result,
        );

        verifyZeroInteractions(mockCloudRepo);
        verifyZeroInteractions(mockAiInputRepo);
      },
    );

    test(
      'refuses to send an image whose file resolves outside the documents '
      'directory (symlink escape) and never calls the model',
      () async {
        final outsideDir = await Directory.systemTemp.createTemp(
          'skill_runner_outside_',
        );
        addTearDown(() => outsideDir.delete(recursive: true));
        final secret = File('${outsideDir.path}/secret.jpg')
          ..writeAsBytesSync([0xFF, 0xD8]);
        await Directory('${tempDir.path}/images').create(recursive: true);
        Link('${tempDir.path}/images/test.jpg').createSync(secret.path);
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => makeImageEntity());
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        stubLoggingException();

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
        );

        final logged = verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            captureAny<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).captured.single;
        expect(
          logged,
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'No image data available for img-1',
          ),
        );
        verifyZeroInteractions(mockCloudRepo);
      },
    );

    test('returns early when entity is null', () async {
      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenAnswer((_) async => null);

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
      );

      verifyZeroInteractions(mockCloudRepo);
    });

    test('returns early when entity is not JournalImage', () async {
      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenAnswer((_) async => makeTaskEntity('img-1'));

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
      );

      verifyZeroInteractions(mockCloudRepo);
    });
  }

  void registerImageAnalysisInputsAndOverrides() {
    test('returns early on empty image analysis response', () async {
      final imageEntity = makeImageEntity();

      await createStubImageFile();

      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenAnswer((_) async => imageEntity);
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockCloudRepo.generateWithImages(
          any(),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          images: any(named: 'images'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).thenAnswer((_) => Stream.fromIterable([]));

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
      );

      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
    });

    test('returns empty list for missing image file', () async {
      final imageEntity = makeImageEntity(
        imageFile: 'nonexistent.jpg',
      );

      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenAnswer((_) async => imageEntity);
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
      );

      // Should not call inference — no image data.
      verifyZeroInteractions(mockCloudRepo);
    });

    test('returns empty when image file does not exist', () async {
      final imageEntity = makeImageEntity(
        imageDirectory: '/nonexistent/',
        imageFile: 'missing.jpg',
      );

      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenAnswer((_) async => imageEntity);
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
      );

      // Should not call inference — file does not exist.
      verifyZeroInteractions(mockCloudRepo);
    });

    test('rejects path traversal in image path', () async {
      final imageEntity = makeImageEntity(
        imageDirectory: '/images/../../',
        imageFile: 'etc/passwd',
      );

      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenAnswer((_) async => imageEntity);
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
      );

      // Should not call inference — path escapes documents directory.
      verifyZeroInteractions(mockCloudRepo);
    });

    test('builds task context when linkedTaskId is provided', () async {
      final imageEntity = makeImageEntity();

      await createStubImageFile();

      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenAnswer((_) async => imageEntity);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
      ).thenAnswer((_) async => '{"id": "task-1"}');
      when(
        () => mockAiInputRepo.buildLinkedTasksJson('task-1'),
      ).thenAnswer((_) async => '{"linked": []}');
      when(
        () => mockTaskSummaryResolver.resolve('task-1'),
      ).thenAnswer((_) async => 'Task summary');
      when(
        () => mockCloudRepo.generateWithImages(
          any(),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          images: any(named: 'images'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([makeStreamChunk('Analysis')]),
      );
      when(
        () => mockJournalRepo.updateJournalEntity(any()),
      ).thenAnswer((_) async => true);
      stubLoggingEvent();

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
        linkedTaskId: 'task-1',
      );

      verify(
        () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
      ).called(1);
      verify(
        () => mockAiInputRepo.buildLinkedTasksJson('task-1'),
      ).called(1);
      verify(() => mockTaskSummaryResolver.resolve('task-1')).called(1);
    });

    test('logs exception on failure', () async {
      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenThrow(Exception('DB error'));
      stubLoggingException();

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
      );

      verify(
        () => mockLoggingService.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'runImageAnalysis',
        ),
      ).called(1);
    });

    test(
      'overrideModelId routes the run to the override model + its '
      'parent provider instead of the profile slot — the popup-menu '
      'picker uses this seam to send one photo to a non-default '
      'model without mutating the profile',
      () async {
        final imageEntity = makeImageEntity();
        await createStubImageFile();

        final overrideProvider =
            AiConfig.inferenceProvider(
                  id: 'p-override',
                  baseUrl: 'https://override.example.com',
                  name: 'Override Provider',
                  inferenceProviderType: InferenceProviderType.openAi,
                  apiKey: 'override-key',
                  createdAt: DateTime(2024),
                )
                as AiConfigInferenceProvider;
        final overrideModel = AiConfig.model(
          id: 'override-model-id',
          name: 'Claude Sonnet Vision',
          providerModelId: 'claude-sonnet',
          inferenceProviderId: 'p-override',
          createdAt: DateTime(2024),
          inputModalities: const [Modality.image, Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );

        when(
          () => mockAiConfigRepo.getConfigById('override-model-id'),
        ).thenAnswer((_) async => overrideModel);
        when(
          () => mockAiConfigRepo.getConfigById('p-override'),
        ).thenAnswer((_) async => overrideProvider);
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            makeStreamChunk('Override analysis'),
          ]),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
          overrideModelId: 'override-model-id',
        );

        // Inference targeted the override model + provider, NOT the
        // profile slot's `vision-model` / `p-vision`.
        verify(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: 'https://override.example.com',
            apiKey: any(named: 'apiKey'),
            model: 'claude-sonnet',
            temperature: null,
            images: any(named: 'images'),
            provider: overrideProvider,
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).called(1);
      },
    );

    test(
      'a stale override modelId (not resolvable to an AiConfigModel) '
      'falls back to the profile slot — stranding the user with an '
      '"image analysis does nothing" outcome is worse than ignoring '
      'a deleted-between-picker-and-runner override',
      () async {
        final imageEntity = makeImageEntity();
        await createStubImageFile();

        when(
          () => mockAiConfigRepo.getConfigById('stale-id'),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            makeStreamChunk('Fell back to profile'),
          ]),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
          overrideModelId: 'stale-id',
        );

        // Inference used the profile slot model (`vision-model`)
        // routed via the profile slot's provider `p-vision` — the
        // stale override was ignored. Pinning the provider too
        // catches a hypothetical regression where the runner
        // chooses the right model but the wrong provider.
        verify(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: 'vision-model',
            temperature: null,
            images: any(named: 'images'),
            provider: testInferenceProvider(id: 'p-vision'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).called(1);
      },
    );

    test(
      'an override modelId whose parent provider does not resolve to '
      'an AiConfigInferenceProvider falls back to the profile slot — '
      'a model row pointing at a stale/deleted provider should not '
      'strand the run, same defensive principle as the missing-model '
      'fallback',
      () async {
        final imageEntity = makeImageEntity();
        await createStubImageFile();

        final orphanModel = AiConfig.model(
          id: 'override-model-id',
          name: 'Orphaned Vision',
          providerModelId: 'orphan-model',
          inferenceProviderId: 'p-missing',
          createdAt: DateTime(2024),
          inputModalities: const [Modality.image, Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );

        when(
          () => mockAiConfigRepo.getConfigById('override-model-id'),
        ).thenAnswer((_) async => orphanModel);
        when(
          () => mockAiConfigRepo.getConfigById('p-missing'),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            makeStreamChunk('Fell back to profile'),
          ]),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
          overrideModelId: 'override-model-id',
        );

        // Same provider-pinning as the stale-override case above:
        // verifying provider `p-vision` (the profile slot) catches
        // wrong-provider routing that a model-only check would miss.
        verify(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: 'vision-model',
            temperature: null,
            images: any(named: 'images'),
            provider: testInferenceProvider(id: 'p-vision'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).called(1);
      },
    );
  }
}
