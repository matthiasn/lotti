part of '../skill_inference_runner_test.dart';

extension _PromptGenerationRoutingCases on _SkillInferenceTestSetup {
  void registerPromptGenerationImages() {
    test(
      'uses multimodal inference and forwards every selected task image',
      () async {
        final visionModel =
            AiConfig.model(
                  id: 'vision-model',
                  name: 'Vision model',
                  providerModelId: 'models/gemini-flash',
                  inferenceProviderId: 'p-flash',
                  createdAt: DateTime(2024),
                  inputModalities: const [Modality.text, Modality.image],
                  outputModalities: const [Modality.text],
                  isReasoningModel: true,
                )
                as AiConfigModel;
        final textEntry = makeTextEntry(
          id: 'text-with-images',
          markdown: 'Rebuild this interface.',
          categoryId: 'cat-vision',
        );
        const images = [
          ProcessedReferenceImage(
            base64Data: 'first-image',
            mimeType: 'image/jpeg',
          ),
          ProcessedReferenceImage(
            base64Data: 'second-image',
            mimeType: 'image/jpeg',
          ),
        ];

        when(
          () => mockAiInputRepo.getEntity('text-with-images'),
        ).thenAnswer((_) async => textEntry);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-vision'),
        ).thenAnswer((_) async => '{"id":"task-vision"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-vision'),
        ).thenAnswer((_) async => '{"linked":[]}');
        when(
          () => mockCloudRepo.generateWithImages(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) => Stream.value(
            makeStreamChunk('## Summary\nUI\n\n## Prompt\nImplement it'),
          ),
        );
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);
        stubLoggingEvent();

        await runner.runPromptGeneration(
          entryId: 'text-with-images',
          automationResult: makePromptGenerationResult(
            thinkingModel: visionModel,
          ),
          linkedTaskId: 'task-vision',
          referenceImages: images,
        );

        final capturedImages =
            verify(
                  () => mockCloudRepo.generateWithImages(
                    any(),
                    model: any(named: 'model'),
                    temperature: any(named: 'temperature'),
                    baseUrl: any(named: 'baseUrl'),
                    apiKey: any(named: 'apiKey'),
                    images: captureAny(named: 'images'),
                    provider: any(named: 'provider'),
                    systemMessage: any(named: 'systemMessage'),
                    impactCollector: any(named: 'impactCollector'),
                  ),
                ).captured.single
                as List<String>;
        expect(capturedImages, ['first-image', 'second-image']);
        verifyNever(
          () => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        );
      },
    );

    test(
      'drops selected images when a stale override falls back to a '
      'text-only profile model',
      () async {
        final textModel =
            AiConfig.model(
                  id: 'text-model',
                  name: 'Text-only model',
                  providerModelId: 'models/gemini-flash',
                  inferenceProviderId: 'p-flash',
                  createdAt: DateTime(2024),
                  inputModalities: const [Modality.text],
                  outputModalities: const [Modality.text],
                  isReasoningModel: true,
                )
                as AiConfigModel;
        final textEntry = makeTextEntry(
          id: 'text-stale-vision',
          markdown: 'Describe the implementation.',
        );
        const images = [
          ProcessedReferenceImage(
            base64Data: 'stale-image',
            mimeType: 'image/jpeg',
          ),
        ];

        when(
          () => mockAiConfigRepo.getConfigById('stale-vision-model'),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiInputRepo.getEntity('text-stale-vision'),
        ).thenAnswer((_) async => textEntry);
        when(
          () => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) => Stream.value(makeStreamChunk('Text-only fallback')),
        );
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);
        stubLoggingEvent();

        await runner.runPromptGeneration(
          entryId: 'text-stale-vision',
          automationResult: makePromptGenerationResult(
            thinkingModel: textModel,
          ),
          referenceImages: images,
          overrideModelId: 'stale-vision-model',
        );

        verify(
          () => mockCloudRepo.generate(
            any(),
            model: 'models/gemini-flash',
            temperature: null,
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).called(1);
        verifyNever(
          () => mockCloudRepo.generateWithImages(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        );
        verify(
          () => mockLoggingService.log(
            LogDomain.ai,
            any<String>(
              that: allOf(
                contains('Dropping 1 selected image'),
                contains('models/gemini-flash'),
              ),
            ),
            subDomain: 'runPromptGeneration',
          ),
        ).called(1);
      },
    );

    test(
      'logs missing model metadata separately when dropping selected images',
      () async {
        final textEntry = makeTextEntry(
          id: 'text-missing-model-metadata',
          markdown: 'Describe the implementation.',
        );
        const images = [
          ProcessedReferenceImage(
            base64Data: 'unroutable-image',
            mimeType: 'image/jpeg',
          ),
        ];

        when(
          () => mockAiInputRepo.getEntity('text-missing-model-metadata'),
        ).thenAnswer((_) async => textEntry);
        when(
          () => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) => Stream.value(makeStreamChunk('Text-only request')),
        );
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);
        stubLoggingEvent();

        await runner.runPromptGeneration(
          entryId: 'text-missing-model-metadata',
          automationResult: makePromptGenerationResult(),
          referenceImages: images,
        );

        verify(
          () => mockLoggingService.log(
            LogDomain.ai,
            any<String>(
              that: allOf(
                contains('Dropping 1 selected image'),
                contains('model metadata is unavailable'),
                contains('models/gemini-flash'),
              ),
            ),
            subDomain: 'runPromptGeneration',
          ),
        ).called(1);
        verifyNever(
          () => mockLoggingService.log(
            LogDomain.ai,
            any<String>(that: contains('does not accept chat images')),
            subDomain: 'runPromptGeneration',
          ),
        );
      },
    );

    test(
      'does not send selected images to a dedicated Mistral OCR model',
      () async {
        final ocrProvider = testInferenceProvider(
          id: 'p-mistral-ocr',
          inferenceProviderType: InferenceProviderType.mistral,
        );
        final ocrModel =
            AiConfig.model(
                  id: 'ocr-model',
                  name: 'Mistral OCR',
                  providerModelId: 'mistral-ocr-latest',
                  inferenceProviderId: ocrProvider.id,
                  createdAt: DateTime(2024),
                  inputModalities: const [Modality.text, Modality.image],
                  outputModalities: const [Modality.text],
                  isReasoningModel: false,
                )
                as AiConfigModel;
        final textEntry = makeTextEntry(
          id: 'text-ocr-model',
          markdown: 'Generate an implementation prompt.',
        );
        const images = [
          ProcessedReferenceImage(
            base64Data: 'must-not-reach-ocr',
            mimeType: 'image/jpeg',
          ),
        ];

        when(
          () => mockAiInputRepo.getEntity('text-ocr-model'),
        ).thenAnswer((_) async => textEntry);
        when(
          () => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) => Stream.value(makeStreamChunk('Text-only request')),
        );
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);
        stubLoggingEvent();

        await runner.runPromptGeneration(
          entryId: 'text-ocr-model',
          automationResult: makePromptGenerationResult(
            thinkingModel: ocrModel,
            thinkingProvider: ocrProvider,
          ),
          referenceImages: images,
        );

        verify(
          () => mockCloudRepo.generate(
            any(),
            model: 'mistral-ocr-latest',
            temperature: null,
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: ocrProvider,
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).called(1);
        verifyNever(
          () => mockCloudRepo.generateWithImages(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        );
      },
    );
  }

  void registerPromptGenerationModelSelection() {
    test('uses high-end thinking model when configured', () async {
      final audioEntity =
          JournalEntity.journalAudio(
                meta: Metadata(
                  id: 'audio-prompt',
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
                  plainText: 'Fix the login bug',
                  markdown: 'Fix the login bug',
                ),
              )
              as JournalAudio;

      final highEndProvider = testInferenceProvider(id: 'p-pro');

      when(
        () => mockAiInputRepo.getEntity('audio-prompt'),
      ).thenAnswer((_) async => audioEntity);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
      ).thenAnswer((_) async => '{"id": "task-1", "title": "Login"}');
      when(
        () => mockAiInputRepo.buildLinkedTasksJson('task-1'),
      ).thenAnswer((_) async => '{"linked": []}');
      when(
        () => mockCloudRepo.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          makeStreamChunk('## Summary\nFix login\n\n'),
          makeStreamChunk('## Prompt\nPlease fix the login bug'),
        ]),
      );
      when(
        () => mockAiInputRepo.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);
      stubLoggingEvent();

      await runner.runPromptGeneration(
        entryId: 'audio-prompt',
        automationResult: makePromptGenerationResult(
          thinkingHighEndModelId: 'models/gemini-pro',
          thinkingHighEndProvider: highEndProvider,
        ),
        linkedTaskId: 'task-1',
      );

      // Verify it used the high-end model, not the regular thinking model.
      verify(
        () => mockCloudRepo.generate(
          any(),
          model: 'models/gemini-pro',
          temperature: any(named: 'temperature'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).called(1);
    });

    test('falls back to thinking model when high-end not set', () async {
      final audioEntity =
          JournalEntity.journalAudio(
                meta: Metadata(
                  id: 'audio-fallback',
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
                  plainText: 'Some transcript',
                  markdown: 'Some transcript',
                ),
              )
              as JournalAudio;

      when(
        () => mockAiInputRepo.getEntity('audio-fallback'),
      ).thenAnswer((_) async => audioEntity);
      when(
        () => mockCloudRepo.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          makeStreamChunk('## Summary\nDo something\n\n## Prompt\nDo it'),
        ]),
      );
      when(
        () => mockAiInputRepo.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);
      stubLoggingEvent();

      // No high-end model configured — should fall back to regular thinking.
      await runner.runPromptGeneration(
        entryId: 'audio-fallback',
        automationResult: makePromptGenerationResult(),
      );

      verify(
        () => mockCloudRepo.generate(
          any(),
          model: 'models/gemini-flash',
          temperature: any(named: 'temperature'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).called(1);
    });
  }
}
