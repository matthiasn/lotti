part of '../skill_inference_runner_test.dart';

extension _TranscriptionContextAndErrorsCases on _SkillInferenceTestSetup {
  void registerTranscriptionContextAndErrors() {
    test('builds task context when linkedTaskId is provided', () async {
      final audioEntity = makeAudioEntity();

      await createStubAudioFile();

      when(
        () => mockAiInputRepo.getEntity('audio-1'),
      ).thenAnswer((_) async => audioEntity);
      when(
        () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
      ).thenAnswer((_) async => []);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
      ).thenAnswer((_) async => '{"id": "task-1"}');
      when(
        () => mockTaskSummaryResolver.resolve('task-1'),
      ).thenAnswer((_) async => 'Task summary text');
      when(
        () => mockCloudRepo.generateWithAudio(
          any(),
          model: any(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([makeStreamChunk('Transcribed text')]),
      );
      when(
        () => mockJournalRepo.updateJournalEntity(any()),
      ).thenAnswer((_) async => true);
      stubLoggingEvent();

      await runner.runTranscription(
        audioEntryId: 'audio-1',
        automationResult: makeTranscriptionResult(),
        linkedTaskId: 'task-1',
      );

      verify(
        () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
      ).called(1);
      verify(() => mockTaskSummaryResolver.resolve('task-1')).called(1);
    });

    test(
      'overrideModelId routes the run to the override model + its '
      'parent provider instead of the profile slot — the popup-menu '
      'picker uses this seam to send one voice note to a non-default '
      'model without mutating the profile',
      () async {
        final audioEntity = makeAudioEntity();
        await createStubAudioFile();

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
          name: 'Mistral Cloud',
          providerModelId: 'mistral/voxtral-mini',
          inferenceProviderId: 'p-override',
          createdAt: DateTime(2024),
          inputModalities: const [Modality.audio, Modality.text],
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
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
        ).thenAnswer((_) async => const <String>[]);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([makeStreamChunk('Override transcript')]),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: makeTranscriptionResult(),
          overrideModelId: 'override-model-id',
        );

        // Inference targeted the override model + provider, NOT the
        // profile slot's `whisper-1` / `p-audio`.
        verify(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: 'mistral/voxtral-mini',
            audioBase64: any(named: 'audioBase64'),
            baseUrl: 'https://override.example.com',
            apiKey: any(named: 'apiKey'),
            provider: overrideProvider,
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).called(1);

        // Saved transcript records the OVERRIDE model id, not the
        // profile's — important so audit logs reflect what actually
        // ran for this entry.
        final captured = verify(
          () => mockJournalRepo.updateJournalEntity(captureAny()),
        ).captured;
        final updated = captured.first as JournalAudio;
        expect(
          updated.data.transcripts!.last.model,
          'mistral/voxtral-mini',
        );
      },
    );

    test(
      'a stale override modelId (not resolvable to an AiConfigModel) '
      'falls back to the profile slot — stranding the user with a '
      '"transcription does nothing" outcome is worse than ignoring '
      'a deleted-between-picker-and-runner override',
      () async {
        final audioEntity = makeAudioEntity();
        await createStubAudioFile();

        when(
          () => mockAiConfigRepo.getConfigById('stale-id'),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
        ).thenAnswer((_) async => const <String>[]);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
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

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: makeTranscriptionResult(),
          overrideModelId: 'stale-id',
        );

        // Inference used the profile slot model (`whisper-1`) — the
        // stale override was ignored.
        verify(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: 'whisper-1',
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).called(1);
      },
    );

    test(
      'an override modelId whose parent provider does not resolve to '
      'an AiConfigInferenceProvider falls back to the profile slot — '
      'mirrors the image-analysis wrong-provider-type guard',
      () async {
        final audioEntity = makeAudioEntity();
        await createStubAudioFile();

        final orphanModel = AiConfig.model(
          id: 'override-model-id',
          name: 'Orphaned Whisper',
          providerModelId: 'orphan-whisper',
          inferenceProviderId: 'p-missing',
          createdAt: DateTime(2024),
          inputModalities: const [Modality.audio],
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
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
        ).thenAnswer((_) async => const <String>[]);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
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

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: makeTranscriptionResult(),
          overrideModelId: 'override-model-id',
        );

        // The orphaned override is ignored; the profile slot model runs.
        verify(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: 'whisper-1',
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).called(1);
      },
    );

    test('logs exception on failure', () async {
      when(
        () => mockAiInputRepo.getEntity('entry-1'),
      ).thenThrow(Exception('DB error'));
      stubLoggingException();

      await runner.runTranscription(
        audioEntryId: 'entry-1',
        automationResult: makeTranscriptionResult(),
      );

      verify(
        () => mockLoggingService.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'runTranscription',
        ),
      ).called(1);
      expect(
        container.read(
          inferenceErrorControllerProvider((
            id: 'entry-1',
            aiResponseType: AiResponseType.audioTranscription,
          )),
        ),
        contains('DB error'),
      );
    });

    test('surfaces structured transcription failure detail', () async {
      final audioEntity = makeAudioEntity();
      await createStubAudioFile();

      when(
        () => mockAiInputRepo.getEntity('audio-1'),
      ).thenAnswer((_) async => audioEntity);
      when(
        () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
      ).thenAnswer((_) async => []);
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockCloudRepo.generateWithAudio(
          any(),
          model: any(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer(
        (_) => Stream.error(
          TranscriptionException(
            'All Voxtral providers failed',
            provider: 'Melious',
            statusCode: 503,
          ),
        ),
      );
      stubLoggingException();

      await runner.runTranscription(
        audioEntryId: 'audio-1',
        automationResult: makeTranscriptionResult(),
      );

      expect(
        container.read(
          inferenceErrorControllerProvider((
            id: 'audio-1',
            aiResponseType: AiResponseType.audioTranscription,
          )),
        ),
        'HTTP 503 · Melious · All Voxtral providers failed',
      );
      expect(
        container.read(
          inferenceStatusControllerProvider((
            id: 'audio-1',
            aiResponseType: AiResponseType.audioTranscription,
          )),
        ),
        InferenceStatus.error,
      );
    });

    // A caller *waiting* on the transcript cannot see any of the above:
    // this method swallows the exception and writes no `entryText`, so a
    // provider outage is indistinguishable from a slow model until the
    // caller's own timeout expires. `onError` is that missing signal.
    test('reports a failed run through onError', () async {
      final audioEntity = makeAudioEntity();
      await createStubAudioFile();

      when(
        () => mockAiInputRepo.getEntity('audio-1'),
      ).thenAnswer((_) async => audioEntity);
      when(
        () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
      ).thenAnswer((_) async => []);
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockCloudRepo.generateWithAudio(
          any(),
          model: any(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer(
        (_) => Stream.error(
          TranscriptionException(
            'All Voxtral providers failed',
            provider: 'Melious',
            statusCode: 503,
          ),
        ),
      );
      stubLoggingException();

      final errors = <Object>[];
      await runner.runTranscription(
        audioEntryId: 'audio-1',
        automationResult: makeTranscriptionResult(),
        onError: errors.add,
      );

      expect(errors, hasLength(1));
      expect(errors.single, isA<TranscriptionException>());
    });

    // The hook is for failures only. A caller that treats it as a
    // completion signal would abandon a run that is about to succeed.
    test('leaves onError untouched when the run succeeds', () async {
      final audioEntity = makeAudioEntity();
      await createStubAudioFile();

      when(
        () => mockAiInputRepo.getEntity('audio-1'),
      ).thenAnswer((_) async => audioEntity);
      when(
        () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
      ).thenAnswer((_) async => []);
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockCloudRepo.generateWithAudio(
          any(),
          model: any(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          makeStreamChunk('We talked about her job search.'),
        ]),
      );
      when(
        () => mockJournalRepo.updateJournalEntity(any()),
      ).thenAnswer((_) async => true);
      stubLoggingEvent();

      final errors = <Object>[];
      await runner.runTranscription(
        audioEntryId: 'audio-1',
        automationResult: makeTranscriptionResult(),
        onError: errors.add,
      );

      expect(errors, isEmpty);
      expect(
        container.read(
          inferenceStatusControllerProvider((
            id: 'audio-1',
            aiResponseType: AiResponseType.audioTranscription,
          )),
        ),
        InferenceStatus.idle,
      );
    });
  }
}
