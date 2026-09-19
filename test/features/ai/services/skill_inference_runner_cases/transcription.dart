part of '../skill_inference_runner_test.dart';

extension _TranscriptionCases on _SkillInferenceTestSetup {
  void registerTranscription() {
    test(
      'throws StateError when skill is null in AutomationResult',
      () async {
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-3-flash-preview',
            thinkingProvider: testInferenceProvider(),
            transcriptionModelId: 'whisper-1',
            transcriptionProvider: testInferenceProvider(id: 'p-audio'),
          ),
        );

        expect(
          () => runner.runTranscription(
            audioEntryId: 'entry-1',
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
          skill: testSkill,
        );

        expect(
          () => runner.runTranscription(
            audioEntryId: 'entry-1',
            automationResult: result,
          ),
          throwsStateError,
        );
      },
    );

    test('returns early when transcription provider is null', () async {
      final result = AutomationResult(
        handled: true,
        resolvedProfile: ResolvedProfile(
          thinkingModelId: 'models/gemini-3-flash-preview',
          thinkingProvider: testInferenceProvider(),
        ),
        skill: testSkill,
        skillAssignment: const SkillAssignment(
          skillId: 'skill-transcribe',
          automate: true,
        ),
      );

      await runner.runTranscription(
        audioEntryId: 'entry-1',
        automationResult: result,
      );

      verifyZeroInteractions(mockCloudRepo);
      verifyZeroInteractions(mockAiInputRepo);
    });

    test('returns early when entity is null', () async {
      when(
        () => mockAiInputRepo.getEntity('entry-1'),
      ).thenAnswer((_) async => null);

      await runner.runTranscription(
        audioEntryId: 'entry-1',
        automationResult: makeTranscriptionResult(),
      );

      verifyZeroInteractions(mockCloudRepo);
    });

    test('returns early when entity is not JournalAudio', () async {
      when(
        () => mockAiInputRepo.getEntity('entry-1'),
      ).thenAnswer((_) async => makeTaskEntity('entry-1'));

      await runner.runTranscription(
        audioEntryId: 'entry-1',
        automationResult: makeTranscriptionResult(),
      );

      verifyZeroInteractions(mockCloudRepo);
    });

    test('happy path: transcribes audio and saves result', () async {
      final audioEntity = makeAudioEntity();

      // Create the audio file on disk.
      final audioDir = Directory('${tempDir.path}/audio');
      await audioDir.create(recursive: true);
      final audioFile = File('${audioDir.path}/test.aac');
      await audioFile.writeAsBytes([0x48, 0x65, 0x6c, 0x6c, 0x6f]);

      // 1. First fetch returns the audio entity.
      when(
        () => mockAiInputRepo.getEntity('audio-1'),
      ).thenAnswer((_) async => audioEntity);

      // 2. Speech dictionary terms.
      when(
        () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
      ).thenAnswer((_) async => ['Flutter', 'Dart']);

      // 3. No linked task context.
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);

      // 4. Cloud inference returns streaming response.
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
          makeStreamChunk('Hello '),
          makeStreamChunk('World'),
        ]),
      );

      // 5. Re-fetch for current state returns same entity.
      // EntityStateHelper calls getEntity again.
      when(
        () => mockAiInputRepo.getEntity('audio-1'),
      ).thenAnswer((_) async => audioEntity);

      // 6. Save journal entity.
      when(
        () => mockJournalRepo.updateJournalEntity(any()),
      ).thenAnswer((_) async => true);

      // 7. Logging.
      stubLoggingEvent();

      await runner.runTranscription(
        audioEntryId: 'audio-1',
        automationResult: makeTranscriptionResult(),
      );

      // Verify cloud inference was called.
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

      // Verify journal entity was updated.
      final captured = verify(
        () => mockJournalRepo.updateJournalEntity(captureAny()),
      ).captured;
      expect(captured, hasLength(1));

      final updatedEntity = captured.first as JournalAudio;
      expect(updatedEntity.entryText?.plainText, 'Hello World');
      expect(updatedEntity.data.transcripts, isNotNull);
      expect(updatedEntity.data.transcripts!.last.transcript, 'Hello World');
      expect(updatedEntity.data.transcripts!.last.model, 'whisper-1');
    });

    // The dictionary alone never rewrites words: only a caller that knows
    // who the recording is about opts into correction.
    for (final (knownTerms, sentTerms, storedText) in [
      (
        const ['Frida Kjellsen', 'Wanja'],
        const ['Frida Kjellsen', 'Wanja', 'Waddle One'],
        'Wanja war mit Frida Kjellsen auf der Waddle One.',
      ),
      (
        const <String>[],
        const ['Waddle One', 'wanja'],
        'Vanja war mit Frieda Kellsen auf der Waddle One.',
      ),
    ]) {
      test(
        'with ${knownTerms.length} known terms, sends $sentTerms and stores '
        '"$storedText"',
        () async {
          const heard = 'Vanja war mit Frieda Kellsen auf der Waddle One.';
          final audioEntity = makeAudioEntity();
          await createStubAudioFile();
          when(
            () => mockAiInputRepo.getEntity('audio-1'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
          ).thenAnswer((_) async => ['Waddle One', 'wanja']);
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
          ).thenAnswer((_) => Stream.value(makeStreamChunk(heard)));
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);
          stubLoggingEvent();

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
            knownTerms: knownTerms,
          );

          final sent = verify(
            () => mockCloudRepo.generateWithAudio(
              any(),
              model: any(named: 'model'),
              audioBase64: any(named: 'audioBase64'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              speechDictionaryTerms: captureAny(named: 'speechDictionaryTerms'),
            ),
          ).captured.single;
          // With known terms, the dictionary's "wanja" repeats one and is
          // dropped; the known terms lead.
          expect(sent, sentTerms);
          final saved =
              verify(
                    () => mockJournalRepo.updateJournalEntity(captureAny()),
                  ).captured.single
                  as JournalAudio;
          expect(saved.entryText?.plainText, storedText);
          expect(
            saved.data.transcripts!.last.transcript,
            heard,
            reason: 'history keeps what the provider returned',
          );
        },
      );
    }

    group('names the phonetic pass cannot reach', () {
      const heard = 'Vanja traf Commander Pip Frostbite.';
      const knownTerms = ['Commander Pip Frostbeak', 'Wanja'];

      CreateChatCompletionStreamResponse correctionChunk(
        List<Map<String, String>> corrections, {
        CompletionUsage? usage,
      }) => CreateChatCompletionStreamResponse(
        id: 'resp-names',
        choices: [
          ChatCompletionStreamResponseChoice(
            delta: ChatCompletionStreamResponseDelta(
              toolCalls: [
                ChatCompletionStreamMessageToolCallChunk(
                  index: 0,
                  id: 'call-names',
                  function: ChatCompletionStreamMessageFunctionCall(
                    name: transcriptNameCorrectionToolName,
                    arguments: jsonEncode({
                      TranscriptNameCorrectionToolArgs.corrections: corrections,
                    }),
                  ),
                ),
              ],
            ),
            index: 0,
          ),
        ],
        object: 'chat.completion.chunk',
        created: DateTime(2024).millisecondsSinceEpoch ~/ 1000,
        usage: usage,
      );

      Future<JournalAudio> transcribe(
        Stream<CreateChatCompletionStreamResponse> Function() modelAnswer,
      ) async {
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
        ).thenAnswer((_) => Stream.value(makeStreamChunk(heard)));
        when(
          () => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            tools: any(named: 'tools'),
            toolChoice: any(named: 'toolChoice'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer((_) => modelAnswer());
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();
        stubLoggingException();

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: makeTranscriptionResult(),
          knownTerms: knownTerms,
        );
        return verify(
              () => mockJournalRepo.updateJournalEntity(captureAny()),
            ).captured.single
            as JournalAudio;
      }

      test(
        'the thinking model corrects a name after the phonetic pass, on '
        'the text that pass left, and history keeps what was heard',
        () async {
          final saved = await transcribe(
            () => Stream.value(
              correctionChunk([
                {'heard': 'Frostbite', 'term': 'Frostbeak'},
                // Refused in code: not a listed name.
                {'heard': 'Commander', 'term': 'Admiral'},
              ]),
            ),
          );

          expect(
            saved.entryText?.plainText,
            'Wanja traf Commander Pip Frostbeak.',
          );
          expect(saved.data.transcripts!.last.transcript, heard);
          final sent =
              verify(
                    () => mockCloudRepo.generate(
                      captureAny(),
                      model: 'models/gemini-3-flash-preview',
                      temperature: any(named: 'temperature'),
                      baseUrl: any(named: 'baseUrl'),
                      apiKey: any(named: 'apiKey'),
                      provider: any(named: 'provider'),
                      systemMessage: any(named: 'systemMessage'),
                      tools: [transcriptNameCorrectionTool],
                      toolChoice: any(named: 'toolChoice'),
                      impactCollector: any(named: 'impactCollector'),
                    ),
                  ).captured.single
                  as String;
          expect(sent, contains('- Commander Pip Frostbeak'));
          expect(
            sent,
            contains('Wanja traf Commander Pip Frostbite.'),
            reason: 'the model reads the phonetic pass result',
          );
        },
      );

      test('a failing model call keeps the phonetic result and still saves '
          'the transcript', () async {
        final saved = await transcribe(
          () => Stream.error(Exception('model offline')),
        );

        expect(
          saved.entryText?.plainText,
          'Wanja traf Commander Pip Frostbite.',
        );
      });

      test(
        "the model's call is recorded with the transcription's spend",
        () async {
          final attribution = _registerInteractionCapture();

          await transcribe(
            () => Stream.value(
              correctionChunk(
                const [],
                usage: const CompletionUsage(
                  promptTokens: 40,
                  completionTokens: 5,
                  totalTokens: 45,
                ),
              ),
            ),
          );

          final events = _capturedEvents(attribution);
          expect(
            events.map((e) => e.interactionKind),
            [
              AiInteractionKind.audioTranscription,
              AiInteractionKind.textGeneration,
            ],
          );
          expect(events.last.providerModelId, 'models/gemini-3-flash-preview');
          expect(events.last.inputTokens, 40);
          verify(
            () => attribution.service.prepareCompletion(
              attributionId: any(named: 'attributionId'),
              outputs: any(named: 'outputs'),
              status: any(named: 'status'),
              errorCode: any(named: 'errorCode'),
              errorSummary: any(named: 'errorSummary'),
            ),
          ).called(1);
        },
      );
    });

    for (final accountingFails in [false, true]) {
      test(
        'preserves transcription failure and incurred accounting (writeFails=$accountingFails)',
        () async {
          final attribution = _registerInteractionCapture();
          if (accountingFails) {
            when(
              () => attribution.service.recordInteraction(
                attributionId: any(named: 'attributionId'),
                event: any(named: 'event'),
              ),
            ).thenThrow(StateError('Synthetic ledger failure'));
          }
          final entity = makeAudioEntity(categoryId: 'cat-audio');
          await createStubAudioFile();
          when(
            () => mockAiInputRepo.getEntity('audio-1'),
          ).thenAnswer((_) async => entity);
          when(
            () => mockPromptBuilderHelper.getSpeechDictionaryTerms(entity),
          ).thenAnswer((_) async => []);
          when(
            () => mockTaskSummaryResolver.resolve(any()),
          ).thenAnswer((_) async => null);
          final failure = TranscriptionException(
            'Upstream unavailable',
            provider: 'Melious',
            statusCode: 503,
            completedSegments: 1,
            partialUsage: const CompletionUsage(
              promptTokens: 10,
              completionTokens: 5,
              totalTokens: 15,
            ),
            partialImpact: const MeliousCallImpact(
              costCredits: 2,
              energyKwh: 0.5,
            ),
          );
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
          ).thenAnswer((_) => Stream.error(failure));
          stubLoggingException();
          Object? reported;
          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
            onError: (error) => reported = error,
          );
          final event = _capturedEvents(attribution).single;
          expect(event.inputTokens, 10);
          expect(event.outputTokens, 5);
          expect(event.totalTokens, 15);
          expect(event.credits, 2);
          expect(event.energyKwh, 0.5);
          if (accountingFails) {
            verifyNever(() => attribution.service.finalize(any()));
          } else {
            final record =
                verify(
                      () => attribution.service.finalize(captureAny()),
                    ).captured.single
                    as AiWorkAttribution;
            expect(record.status, AiWorkStatus.failed);
            expect(record.errorCode, 'transcription_incomplete');
          }
          expect(reported, same(failure));
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );
    }

    test(
      'records a consumption event with tokens from the response usage '
      'and no environmental impact (transcription endpoint reports none)',
      () async {
        final attribution = _registerInteractionCapture();
        final audioEntity = makeAudioEntity(categoryId: 'cat-audio');
        await createStubAudioFile();

        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(
            audioEntity,
          ),
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
            makeStreamChunk('Hello'),
            makeStreamChunk(
              ' World',
              usage: const CompletionUsage(
                promptTokens: 120,
                completionTokens: 45,
                totalTokens: 165,
                promptTokensDetails: PromptTokensDetails(cachedTokens: 30),
                completionTokensDetails: CompletionTokensDetails(
                  reasoningTokens: 12,
                ),
              ),
            ),
          ]),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: makeTranscriptionResult(),
        );

        final event = _capturedEvents(attribution).single;
        expect(event.entryId, 'audio-1');
        expect(event.taskId, isNull);
        expect(event.categoryId, 'cat-audio');
        expect(event.skillId, 'skill-transcribe');
        expect(
          event.responseType,
          AiConsumptionResponseType.audioTranscription,
        );
        expect(event.providerModelId, 'whisper-1');
        expect(event.providerType, InferenceProviderType.gemini);
        expect(event.inputTokens, 120);
        expect(event.outputTokens, 45);
        expect(event.totalTokens, 165);
        expect(event.cachedInputTokens, 30);
        expect(event.thoughtsTokens, 12);
        // The /audio/transcriptions endpoint never reports impact.
        expect(event.credits, isNull);
        expect(event.energyKwh, isNull);
        expect(event.carbonGCo2, isNull);
        expect(event.dataCenter, isNull);
      },
    );

    test(
      'hands a Melious transcription an impact collector and records the '
      'impact the adapter reported into it',
      () async {
        final attribution = _registerInteractionCapture();
        final audioEntity = makeAudioEntity(categoryId: 'cat-audio');
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
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer((invocation) {
          // The Melious adapter reports impact out of band by writing into
          // the collector the runner passed down.
          (invocation.namedArguments[#impactCollector]
                  as InferenceImpactCollector?)
              ?.impact = const MeliousCallImpact(
            costCredits: 1.5,
            energyKwh: 0.02,
            dataCenter: 'DE',
          );
          return Stream.value(makeStreamChunk('Waddle One is ready'));
        });
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: AutomationResult(
            handled: true,
            resolvedProfile: ResolvedProfile(
              thinkingModelId: 'models/gemini-3-flash-preview',
              thinkingProvider: testInferenceProvider(),
              transcriptionModelId: 'voxtral-mini',
              transcriptionProvider: testInferenceProvider(
                id: 'p-melious',
                inferenceProviderType: InferenceProviderType.melious,
              ),
            ),
            skill: testSkill,
          ),
        );

        final collector =
            verify(
                  () => mockCloudRepo.generateWithAudio(
                    any(),
                    model: 'voxtral-mini',
                    audioBase64: any(named: 'audioBase64'),
                    baseUrl: any(named: 'baseUrl'),
                    apiKey: any(named: 'apiKey'),
                    provider: any(named: 'provider'),
                    systemMessage: any(named: 'systemMessage'),
                    speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
                    impactCollector: captureAny(named: 'impactCollector'),
                  ),
                ).captured.single
                as InferenceImpactCollector?;
        expect(collector, isNotNull);

        final event = _capturedEvents(attribution).single;
        expect(event.providerType, InferenceProviderType.melious);
        expect(event.credits, 1.5);
        expect(event.energyKwh, 0.02);
        expect(event.dataCenter, 'DE');
        final saved =
            verify(
                  () => mockJournalRepo.updateJournalEntity(captureAny()),
                ).captured.single
                as JournalAudio;
        expect(saved.data.transcripts!.last.transcript, 'Waddle One is ready');
      },
    );

    test(
      'forwards the resolved Gemini thinking mode for Gemini 3 targets',
      () async {
        final audioEntity = makeAudioEntity();
        final audioDir = Directory('${tempDir.path}/audio');
        await audioDir.create(recursive: true);
        await File(
          '${audioDir.path}/test.aac',
        ).writeAsBytes([0x48, 0x65]);

        final geminiModelRow = testAiModel(
          id: 'gemini-3-row',
          providerModelId: 'gemini-3-flash-preview',
          inferenceProviderId: 'p-audio',
        ).copyWith(geminiThinkingMode: GeminiThinkingMode.high);
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-3-flash-preview',
            thinkingProvider: testInferenceProvider(),
            transcriptionModelId: 'gemini-3-flash-preview',
            transcriptionProvider: testInferenceProvider(id: 'p-audio'),
            transcriptionModel: geminiModelRow,
          ),
          skill: testSkill,
          skillAssignment: const SkillAssignment(
            skillId: 'skill-transcribe',
            automate: true,
          ),
        );

        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(
            audioEntity,
          ),
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
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([makeStreamChunk('Hello')]),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: result,
        );

        // The model row's saved default thinking mode reaches the cloud
        // call because the target is a Gemini 3 model on a Gemini
        // provider and no per-invocation override was given.
        verify(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: 'gemini-3-flash-preview',
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            geminiThinkingMode: GeminiThinkingMode.high,
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).called(1);
      },
    );

    test(
      'a per-invocation thinking mode override beats the model default',
      () async {
        final audioEntity = makeAudioEntity();
        final audioDir = Directory('${tempDir.path}/audio');
        await audioDir.create(recursive: true);
        await File(
          '${audioDir.path}/test.aac',
        ).writeAsBytes([0x48, 0x65]);

        final geminiModelRow = testAiModel(
          id: 'gemini-3-row',
          providerModelId: 'gemini-3-flash-preview',
          inferenceProviderId: 'p-audio',
        ).copyWith(geminiThinkingMode: GeminiThinkingMode.high);
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-3-flash-preview',
            thinkingProvider: testInferenceProvider(),
            transcriptionModelId: 'gemini-3-flash-preview',
            transcriptionProvider: testInferenceProvider(id: 'p-audio'),
            transcriptionModel: geminiModelRow,
          ),
          skill: testSkill,
          skillAssignment: const SkillAssignment(
            skillId: 'skill-transcribe',
            automate: true,
          ),
        );

        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(
            audioEntity,
          ),
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
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([makeStreamChunk('Hello')]),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: result,
          geminiThinkingMode: GeminiThinkingMode.minimal,
        );

        verify(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: 'gemini-3-flash-preview',
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            geminiThinkingMode: GeminiThinkingMode.minimal,
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).called(1);
      },
    );

    test('returns early on empty transcription response', () async {
      final audioEntity = makeAudioEntity();

      // Create the audio file on disk.
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

      // Return empty stream (no chunks).
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
      ).thenAnswer((_) => Stream.fromIterable([]));

      await runner.runTranscription(
        audioEntryId: 'audio-1',
        automationResult: makeTranscriptionResult(),
      );

      // Should not save — empty response.
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      expect(
        container.read(
          inferenceErrorControllerProvider((
            id: 'audio-1',
            aiResponseType: AiResponseType.audioTranscription,
          )),
        ),
        contains('Empty transcription response'),
      );
    });
  }
}
