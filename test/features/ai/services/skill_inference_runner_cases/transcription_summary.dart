part of '../skill_inference_runner_test.dart';

extension _TranscriptionSummaryCases on _SkillInferenceTestSetup {
  void registerTranscriptionSummary() {
    group('transcription triggers the audio summary', () {
      /// A transcript over the summarization floor, returned by the
      /// transcription call so the follow-up has something to summarize.
      final longTranscript = List.generate(
        8,
        (i) => 'We discussed migration step $i and who owns it.',
      ).join(' ');

      AutomationResult makeTranscriptionResultWithSummary({
        bool automate = true,
        bool assignSummarySkill = true,
        bool transcriptionWasAutomated = true,
        AiConfigModel? thinkingModel,
      }) => AutomationResult(
        handled: true,
        resolvedProfile: ResolvedProfile(
          thinkingModelId: 'models/gemini-flash',
          thinkingProvider: testInferenceProvider(id: 'p-flash'),
          thinkingModel: thinkingModel,
          transcriptionModelId: 'whisper-1',
          transcriptionProvider: testInferenceProvider(id: 'p-flash'),
          skillAssignments: [
            const SkillAssignment(
              skillId: skillTranscribeContextId,
              automate: true,
            ),
            if (assignSummarySkill)
              SkillAssignment(
                skillId: skillAudioSummaryId,
                automate: automate,
              ),
          ],
        ),
        skill: testSkill,
        // Only the automated paths set an assignment. Its absence is how the
        // summary hook tells a manual transcription from an automatic one.
        skillAssignment: transcriptionWasAutomated
            ? const SkillAssignment(
                skillId: skillTranscribeContextId,
                automate: true,
              )
            : null,
      );

      Future<void> stubTranscriptionThrough(JournalAudio audioEntity) async {
        await createStubAudioFile();
        // The summary reads the entry back AFTER transcription persisted the
        // transcript onto it. A stub pinned to the pre-transcription entity
        // would hand the summary an empty transcript and it would correctly
        // skip — passing the gate tests for the wrong reason. Mirror the real
        // sequence instead: reads return whatever was last written.
        var current = audioEntity;
        when(
          () => mockAiInputRepo.getEntity(audioEntity.meta.id),
        ).thenAnswer((_) async => current);
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((invocation) async {
          final written = invocation.positionalArguments.first;
          if (written is JournalAudio) current = written;
          return true;
        });
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
        ).thenAnswer((_) async => '{"id":"task-1"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson(any()),
        ).thenAnswer((_) async => '{"linked": []}');
        when(
          () => mockJournalRepo.getLinkedToEntities(
            linkedTo: any(named: 'linkedTo'),
          ),
        ).thenAnswer((_) async => <JournalEntity>[]);
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
          (_) => Stream.fromIterable([makeStreamChunk(longTranscript)]),
        );
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            id: any(named: 'id'),
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((invocation) async => makePersistedResponse(invocation));
        stubLoggingEvent();
      }

      /// The `generate` invocation the summary path would make.
      void Function() summaryCall() =>
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
          );

      void verifySummarized() => verify(summaryCall()).called(1);
      void verifyNotSummarized() => verifyNever(summaryCall());

      test(
        'summarizes after a task-linked transcription when the profile '
        'automates the summary skill',
        () async {
          final audio = makeAudioEntity();
          await stubTranscriptionThrough(audio);
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
            (_) => Stream.fromIterable([
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
                              EntrySummaryToolArgs.oneLiner:
                                  'Migration owners agreed.',
                              EntrySummaryToolArgs.tldr:
                                  'Each step has an owner.',
                              EntrySummaryToolArgs.summary: '## Owners',
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
            ]),
          );

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResultWithSummary(),
            linkedTaskId: 'task-1',
          );

          verifySummarized();
          final data =
              verify(
                    () => mockAiInputRepo.createAiResponseEntry(
                      id: any(named: 'id'),
                      data: captureAny(named: 'data'),
                      start: any(named: 'start'),
                      linkedId: any(named: 'linkedId'),
                      categoryId: any(named: 'categoryId'),
                    ),
                  ).captured.single
                  as AiResponseData;
          expect(data.type, AiResponseType.audioSummary);
          expect(data.oneLiner, 'Migration owners agreed.');
        },
      );

      test(
        'does NOT summarize a recording with no resolved task — the summary '
        'is framed by a task, and a check-in or standalone note has none',
        () async {
          final audio = makeAudioEntity();
          await stubTranscriptionThrough(audio);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResultWithSummary(),
          );

          verifyNotSummarized();
        },
      );

      test(
        'does NOT summarize when the profile assigns the skill but leaves '
        'automation off — the checkbox is the consent',
        () async {
          final audio = makeAudioEntity();
          await stubTranscriptionThrough(audio);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResultWithSummary(
              automate: false,
            ),
            linkedTaskId: 'task-1',
          );

          verifyNotSummarized();
        },
      );

      test(
        'does NOT summarize when the profile has no summary assignment at all',
        () async {
          final audio = makeAudioEntity();
          await stubTranscriptionThrough(audio);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResultWithSummary(
              assignSummarySkill: false,
            ),
            linkedTaskId: 'task-1',
          );

          verifyNotSummarized();
        },
      );

      test(
        'does NOT summarize when the transcription was manual — a button press '
        'consents to the transcript asked for, not to a second model call',
        () async {
          final audio = makeAudioEntity();
          await stubTranscriptionThrough(audio);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResultWithSummary(
              transcriptionWasAutomated: false,
            ),
            linkedTaskId: 'task-1',
          );

          verifyNotSummarized();
        },
      );

      test(
        'a failing summary leaves the transcript persisted and does not mark '
        'the transcription run as an error — a retry would re-transcribe '
        'audio that transcribed fine',
        () async {
          final audio = makeAudioEntity();
          await stubTranscriptionThrough(audio);
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
          ).thenThrow(Exception('summary model exploded'));
          stubLoggingException();

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResultWithSummary(),
            linkedTaskId: 'task-1',
          );

          // The transcript still landed on the audio entry.
          final persisted =
              verify(
                    () => mockJournalRepo.updateJournalEntity(captureAny()),
                  ).captured.last
                  as JournalAudio;
          expect(persisted.entryText?.plainText, longTranscript);
          expect(persisted.data.transcripts, hasLength(1));

          // And the transcription run itself never reported an error status.
          expect(
            container.read(
              inferenceStatusControllerProvider((
                id: 'audio-1',
                aiResponseType: AiResponseType.audioTranscription,
              )),
            ),
            isNot(InferenceStatus.error),
          );
        },
      );

      test(
        "a failure thrown outside the summary's status tracking is logged "
        'and swallowed, so the persisted transcript still stands',
        () async {
          final audio = makeAudioEntity();
          await stubTranscriptionThrough(audio);
          stubLoggingException();
          // The skip notice for a tool-less thinking model is logged before
          // status tracking starts; a logger failing there is the one way
          // for the summary call itself to throw.
          final loggerFailure = StateError('log sink closed');
          when(
            () => mockLoggingService.log(
              any<LogDomain>(),
              any<String>(),
              subDomain: 'runAudioSummary',
            ),
          ).thenThrow(loggerFailure);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResultWithSummary(
              thinkingModel:
                  AiConfig.model(
                        id: 'flash-no-tools',
                        name: 'Flash without tools',
                        providerModelId: 'models/gemini-flash',
                        inferenceProviderId: 'p-flash',
                        createdAt: DateTime(2024),
                        inputModalities: const [Modality.text],
                        outputModalities: const [Modality.text],
                        isReasoningModel: false,
                      )
                      as AiConfigModel,
            ),
            linkedTaskId: 'task-1',
          );

          verifyNotSummarized();
          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              loggerFailure,
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'maybeRunAudioSummary',
            ),
          ).called(1);
          final persisted =
              verify(
                    () => mockJournalRepo.updateJournalEntity(captureAny()),
                  ).captured.last
                  as JournalAudio;
          expect(persisted.entryText?.plainText, longTranscript);
        },
      );
    });
  }
}
