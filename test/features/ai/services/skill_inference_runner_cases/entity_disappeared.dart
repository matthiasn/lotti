part of '../skill_inference_runner_test.dart';

extension _EntityDisappearedCases on _SkillInferenceTestSetup {
  void registerEntityDisappeared() {
    group('runTranscription entity-disappeared guard', () {
      test(
        'throws StateError (caught and logged) when audio entity disappears '
        'between transcription and save — second getEntity returns null',
        () async {
          final audioEntity = makeAudioEntity();

          final audioDir = Directory('${tempDir.path}/audio');
          await audioDir.create(recursive: true);
          await File(
            '${audioDir.path}/test.aac',
          ).writeAsBytes([0x48, 0x65, 0x6c, 0x6c, 0x6f]);

          // First call (entity fetch) returns the audio entity;
          // second call (EntityStateHelper re-fetch) returns null
          // to simulate the entity vanishing mid-run.
          var callCount = 0;
          when(
            () => mockAiInputRepo.getEntity('audio-1'),
          ).thenAnswer((_) async {
            callCount++;
            return callCount == 1 ? audioEntity : null;
          });

          when(
            () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
          ).thenAnswer((_) async => []);
          when(
            () => mockTaskSummaryResolver.resolve(any()),
          ).thenAnswer((_) async => null);

          // Return a non-empty response so we reach the re-fetch step.
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
            (_) => Stream.fromIterable([makeStreamChunk('Hello World')]),
          );

          stubLoggingException();

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
          );

          // The StateError is caught by _withStatusTracking and forwarded to
          // the logging service — no entity update must have been attempted.
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(
                that: isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('disappeared mid-run'),
                ),
              ),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runTranscription',
            ),
          ).called(1);
        },
      );
    });

    group('runImageAnalysis entity-disappeared guard', () {
      test(
        'throws StateError (caught and logged) when image entity disappears '
        'between analysis and save — second getEntity returns null',
        () async {
          final imageEntity = makeImageEntity();

          final imageDir = Directory('${tempDir.path}/images');
          await imageDir.create(recursive: true);
          await File(
            '${imageDir.path}/test.jpg',
          ).writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

          // First call returns the image entity; second call (re-fetch for
          // EntityStateHelper) returns null to simulate disappearance.
          var callCount = 0;
          when(
            () => mockAiInputRepo.getEntity('img-1'),
          ).thenAnswer((_) async {
            callCount++;
            return callCount == 1 ? imageEntity : null;
          });

          when(
            () => mockTaskSummaryResolver.resolve(any()),
          ).thenAnswer((_) async => null);

          // Return a non-empty response so we reach the re-fetch step.
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
            (_) => Stream.fromIterable([makeStreamChunk('A photo of a cat')]),
          );

          stubLoggingException();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: makeImageAnalysisResult(),
          );

          // The StateError is caught by _withStatusTracking and forwarded to
          // the logging service — no journal update must have been attempted.
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(
                that: isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('disappeared mid-run'),
                ),
              ),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runImageAnalysis',
            ),
          ).called(1);
        },
      );
    });

    group('response persistence failure', () {
      void stubResponseEntryNotPersisted() {
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            id: any(named: 'id'),
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);
      }

      void verifyPersistFailureLogged(String message, String subDomain) {
        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(
              that: isA<StateError>().having(
                (e) => e.message,
                'message',
                message,
              ),
            ),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: subDomain,
          ),
        ).called(1);
      }

      test(
        'reports an attributed image analysis whose response entry was not '
        'stored as a failed run and never finalizes the attribution',
        () async {
          final attribution = _registerInteractionCapture();
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
          ).thenAnswer(
            (_) => Stream.value(makeStreamChunk('Penguins queue at the dock')),
          );
          stubResponseEntryNotPersisted();
          stubLoggingEvent();
          stubLoggingException();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: makeImageAnalysisResult(),
          );

          verifyPersistFailureLogged(
            'Failed to persist image analysis for img-1',
            'runImageAnalysis',
          );
          verifyNever(() => attribution.service.finalize(any()));
          expect(
            container.read(
              inferenceStatusControllerProvider((
                id: 'img-1',
                aiResponseType: AiResponseType.imageAnalysis,
              )),
            ),
            InferenceStatus.error,
          );
        },
      );

      test(
        'reports an audio summary whose response entry was not stored as a '
        'failed run',
        () async {
          final summarySkill =
              AiConfig.skill(
                    id: 'skill-audio-summary',
                    name: 'Summarize Recording',
                    skillType: SkillType.audioSummary,
                    requiredInputModalities: const [Modality.audio],
                    systemInstructions: 'You summarize recordings.',
                    userInstructions: 'Summarize the recording.',
                    createdAt: DateTime(2024),
                  )
                  as AiConfigSkill;
          final transcript = List.generate(
            8,
            (i) => 'Crate $i of herring left the Waddle depot on time.',
          ).join(' ');
          final audio = makeAudioEntity(id: 'audio-sum', plainText: transcript);
          when(
            () => mockAiInputRepo.getEntity('audio-sum'),
          ).thenAnswer((_) async => audio);
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
              geminiThinkingMode: any(named: 'geminiThinkingMode'),
              impactCollector: any(named: 'impactCollector'),
            ),
          ).thenAnswer(
            (_) => Stream.value(
              CreateChatCompletionStreamResponse(
                id: 'resp-tool',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      toolCalls: [
                        ChatCompletionStreamMessageToolCallChunk(
                          index: 0,
                          id: 'call-1',
                          function: ChatCompletionStreamMessageFunctionCall(
                            name: entrySummaryToolName,
                            arguments: jsonEncode({
                              EntrySummaryToolArgs.oneLiner: 'Herring shipped.',
                              EntrySummaryToolArgs.tldr: 'All crates left.',
                              EntrySummaryToolArgs.summary: '## Shipping',
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
              ),
            ),
          );
          stubResponseEntryNotPersisted();
          stubLoggingEvent();
          stubLoggingException();

          await runner.runAudioSummary(
            audioEntryId: 'audio-sum',
            automationResult: AutomationResult(
              handled: true,
              resolvedProfile: ResolvedProfile(
                thinkingModelId: 'models/gemini-flash',
                thinkingProvider: testInferenceProvider(id: 'p-flash'),
              ),
              skill: summarySkill,
            ),
          );

          verifyPersistFailureLogged(
            'Failed to persist audio summary for audio-sum',
            'runAudioSummary',
          );
          expect(
            container.read(
              inferenceStatusControllerProvider((
                id: 'audio-sum',
                aiResponseType: AiResponseType.audioSummary,
              )),
            ),
            InferenceStatus.error,
          );
        },
      );
    });
  }
}
