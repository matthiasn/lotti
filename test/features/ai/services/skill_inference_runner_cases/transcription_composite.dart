part of '../skill_inference_runner_test.dart';

/// The composite step: a speech-to-text engine's transcript in a task's
/// context is held back, corrected against the speech dictionary by the
/// summary call, and written once.
extension _TranscriptionCompositeCases on _SkillInferenceTestSetup {
  void registerTranscriptionComposite() {
    group('composite transcription', () {
      const raw =
          'Today we moved the build to Cuban Eddies and it stayed green. '
          'Next the staging cluster moves too, once Cuban Eddies has the new '
          'ingress. Everyone agreed the rollout can start on Monday morning.';
      const corrected =
          'Today we moved the build to Kubernetes and it stayed green. '
          'Next the staging cluster moves too, once Cuban Eddies has the new '
          'ingress. Everyone agreed the rollout can start on Monday morning.';

      final kubernetes = SpeechDictionaryEntry(
        id: speechDictionaryEntryId('Kubernetes'),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        term: 'Kubernetes',
        vectorClock: null,
        misheardAs: const ['Cooper Netties'],
      );

      AiConfigInferenceProvider whisper() => testInferenceProvider(
        id: 'p-whisper',
        inferenceProviderType: InferenceProviderType.whisper,
      );

      /// A transcription on [transcriptionProvider] for a profile that
      /// automates it and, with [automatesSummary], the summary too;
      /// [automated] false is the user's own tap. [postProcessingModel] is
      /// the profile's audio post-processing slot, on provider `p-post`;
      /// [postProcessingUnavailable] is that slot set but unresolvable here.
      AutomationResult transcriptionFor({
        required AiConfigInferenceProvider transcriptionProvider,
        bool automated = true,
        bool automatesSummary = true,
        AiConfigSkill? skill,
        AiConfigModel? thinkingModel,
        AiConfigModel? postProcessingModel,
        bool postProcessingUnavailable = false,
      }) => AutomationResult(
        handled: true,
        resolvedProfile: ResolvedProfile(
          thinkingModelId: 'models/gemini-flash',
          thinkingProvider: testInferenceProvider(id: 'p-flash'),
          thinkingModel: thinkingModel,
          audioPostProcessingModelId: postProcessingModel?.providerModelId,
          audioPostProcessingProvider: postProcessingModel == null
              ? null
              : testInferenceProvider(id: 'p-post'),
          audioPostProcessingModel: postProcessingModel,
          audioPostProcessingModelUnavailable: postProcessingUnavailable,
          transcriptionModelId: 'whisper-large-v3',
          transcriptionProvider: transcriptionProvider,
          skillAssignments: [
            const SkillAssignment(
              skillId: skillTranscribeContextId,
              automate: true,
            ),
            if (automatesSummary)
              const SkillAssignment(
                skillId: skillAudioSummaryId,
                automate: true,
              ),
          ],
        ),
        skill: skill ?? findBuiltInSkill(skillTranscribeContextId),
        skillAssignment: automated
            ? const SkillAssignment(
                skillId: skillTranscribeContextId,
                automate: true,
              )
            : null,
      );

      /// Every text write the run makes, in order.
      late List<String?> textWrites;

      /// The summary call, once made.
      Invocation? lastSummaryCall;

      /// Stubs the run end to end. The audio reads back what was last
      /// written; [editAfterTranscript] stands for the user typing into the
      /// recording while its summary runs.
      Future<void> stubRun({
        String transcript = raw,
        String? editAfterTranscript,
        List<SpeechDictionaryEntry> dictionary = const [],
      }) async {
        await createStubAudioFile();
        textWrites = [];
        lastSummaryCall = null;
        var current = makeAudioEntity();
        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => current);
        when(
          () => mockJournalRepo.updateJournalEntity(
            any(),
            onlyIfUnchanged: any(named: 'onlyIfUnchanged'),
          ),
        ).thenAnswer((invocation) async {
          final written = invocation.positionalArguments.first as JournalAudio;
          textWrites.add(written.entryText?.plainText);
          current = written;
          if (editAfterTranscript != null &&
              (written.data.transcripts?.isNotEmpty ?? false)) {
            current = written.copyWith(
              entryText: EntryText(
                plainText: editAfterTranscript,
                markdown: editAfterTranscript,
              ),
            );
          }
          return true;
        });
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(any()),
        ).thenAnswer((_) async => [for (final e in dictionary) e.term]);
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryEntries(any()),
        ).thenAnswer((_) async => dictionary);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
        ).thenAnswer((_) async => null);
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
        ).thenAnswer((_) => Stream.fromIterable([makeStreamChunk(transcript)]));
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
        stubLoggingException();
      }

      /// The summary call publishes the tiers and [corrections]; null makes
      /// it narrate instead, twice, so the summary fails.
      void stubSummary(List<Map<String, String>>? corrections) {
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
        ).thenAnswer((invocation) {
          lastSummaryCall = invocation;
          if (corrections == null) {
            return Stream.fromIterable([makeStreamChunk('A summary.')]);
          }
          return Stream.fromIterable([
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
                          name: recordingSummaryToolName,
                          arguments: jsonEncode({
                            EntrySummaryToolArgs.oneLiner: 'Build moved.',
                            EntrySummaryToolArgs.tldr: 'Rollout on Monday.',
                            EntrySummaryToolArgs.summary: '## Rollout',
                            TranscriptNameCorrectionToolArgs.corrections:
                                corrections,
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
          ]);
        });
      }

      /// The occurrence in the first sentence was the term; the second one
      /// is left for the model to judge, and it did not report it.
      const firstOccurrence = [
        {
          TranscriptNameCorrectionToolArgs.heard: 'Cuban Eddies',
          TranscriptNameCorrectionToolArgs.term: 'Kubernetes',
          TranscriptNameCorrectionToolArgs.context:
              'moved the build to Cuban Eddies and',
        },
      ];

      test('holds the transcript back and writes it corrected, once', () async {
        await stubRun(dictionary: [kubernetes]);
        stubSummary(firstOccurrence);

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: transcriptionFor(transcriptionProvider: whisper()),
          linkedTaskId: 'task-1',
        );

        // The transcript is saved with no text, and the text is written
        // once — corrected, the second occurrence left as heard.
        expect(textWrites, [null, corrected]);
        // Both writes apply only to the version they were built on, so an
        // edit stored in between refuses them (TranscriptionRun.tla,
        // GuardedFill).
        expect(
          verify(
            () => mockJournalRepo.updateJournalEntity(
              any(),
              onlyIfUnchanged: captureAny(named: 'onlyIfUnchanged'),
            ),
          ).captured,
          [true, true],
        );
        verify(
          () => mockSpeechDictionaryRepository.learnMisheardForms([
            (from: 'Cuban Eddies', to: 'Kubernetes'),
          ]),
        ).called(1);
        final prompt = lastSummaryCall!.positionalArguments.first as String;
        expect(prompt, contains('**Speech Dictionary:**'));
        expect(
          prompt,
          contains('- Kubernetes (misheard before as: Cooper Netties)'),
        );
      });

      test('a re-transcription corrects the new transcript and replaces the '
          'old text', () async {
        await stubRun(dictionary: [kubernetes]);
        // The recording already has text from an earlier transcription.
        final earlier = makeAudioEntity(plainText: 'An older take.');
        var current = earlier;
        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => current);
        when(
          () => mockJournalRepo.updateJournalEntity(
            any(),
            onlyIfUnchanged: any(named: 'onlyIfUnchanged'),
          ),
        ).thenAnswer((invocation) async {
          current = invocation.positionalArguments.first as JournalAudio;
          textWrites.add(current.entryText?.plainText);
          return true;
        });
        stubSummary(firstOccurrence);

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: transcriptionFor(transcriptionProvider: whisper()),
          linkedTaskId: 'task-1',
        );

        // The old text is kept while held, then replaced by the corrected
        // new transcript — what the model was shown.
        expect(textWrites, ['An older take.', corrected]);
        final prompt = lastSummaryCall!.positionalArguments.first as String;
        expect(prompt, contains(raw));
        expect(prompt, isNot(contains('An older take.')));
      });

      test('a correction it cannot learn is still written', () async {
        await stubRun(dictionary: [kubernetes]);
        stubSummary(firstOccurrence);
        when(
          () => mockSpeechDictionaryRepository.learnMisheardForms(any()),
        ).thenThrow(StateError('dictionary closed'));

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: transcriptionFor(transcriptionProvider: whisper()),
          linkedTaskId: 'task-1',
        );

        expect(textWrites, [null, corrected]);
        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(that: isA<StateError>()),
            stackTrace: any(named: 'stackTrace', that: isNotNull),
            subDomain: 'runAudioSummary.learnMisheardForms',
          ),
        ).called(1);
      });

      test('a text write refused every time is logged, never thrown', () async {
        await stubRun(dictionary: [kubernetes]);
        stubSummary(firstOccurrence);
        var writes = 0;
        var current = makeAudioEntity();
        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => current);
        when(
          () => mockJournalRepo.updateJournalEntity(
            any(),
            onlyIfUnchanged: any(named: 'onlyIfUnchanged'),
          ),
        ).thenAnswer((invocation) async {
          // The transcript's own write lands; every text write is refused.
          if (++writes > 1) return false;
          current = invocation.positionalArguments.first as JournalAudio;
          return true;
        });

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: transcriptionFor(transcriptionProvider: whisper()),
          linkedTaskId: 'task-1',
        );

        // The transcript's write, then three refused text writes.
        expect(writes, 4);
        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(that: isA<StateError>()),
            stackTrace: any(named: 'stackTrace', that: isNotNull),
            subDomain: 'runTranscription.writeText',
          ),
        ).called(1);
      });

      // The run reports through its status tracking and writes the held
      // text in a `finally`; a logger failing while it reports a refused
      // write is the one way for a failure to escape it. The follow-up's
      // catch keeps it from failing a transcription that was saved.
      test(
        "a failure thrown outside the summary's status tracking is logged "
        'and swallowed, so the saved transcript still stands',
        () async {
          await stubRun(dictionary: [kubernetes]);
          stubSummary(firstOccurrence);
          var current = makeAudioEntity();
          when(
            () => mockAiInputRepo.getEntity('audio-1'),
          ).thenAnswer((_) async => current);
          final saved = <JournalAudio>[];
          when(
            () => mockJournalRepo.updateJournalEntity(
              any(),
              onlyIfUnchanged: any(named: 'onlyIfUnchanged'),
            ),
          ).thenAnswer((invocation) async {
            // The transcript's own write lands; every text write is refused.
            if (saved.isNotEmpty) return false;
            current = invocation.positionalArguments.first as JournalAudio;
            saved.add(current);
            return true;
          });
          final loggerFailure = StateError('log sink closed');
          when(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(),
              stackTrace: any(named: 'stackTrace'),
              subDomain: 'runTranscription.writeText',
            ),
          ).thenThrow(loggerFailure);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: transcriptionFor(
              transcriptionProvider: whisper(),
            ),
            linkedTaskId: 'task-1',
          );

          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              loggerFailure,
              stackTrace: any(named: 'stackTrace'),
              subDomain: 'maybeRunAudioSummary',
            ),
          ).called(1);
          expect(saved.single.data.transcripts?.last.transcript, raw);
        },
      );

      test('a recording deleted while its summary ran gets no text', () async {
        await stubRun(dictionary: [kubernetes]);
        stubSummary(firstOccurrence);
        var current = makeAudioEntity();
        // Gone once the model has answered: the re-read before persisting
        // finds nothing.
        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => lastSummaryCall == null ? current : null);
        when(
          () => mockJournalRepo.updateJournalEntity(
            any(),
            onlyIfUnchanged: any(named: 'onlyIfUnchanged'),
          ),
        ).thenAnswer((invocation) async {
          current = invocation.positionalArguments.first as JournalAudio;
          textWrites.add(current.entryText?.plainText);
          return true;
        });

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: transcriptionFor(transcriptionProvider: whisper()),
          linkedTaskId: 'task-1',
        );

        expect(lastSummaryCall, isNotNull);
        expect(textWrites, [null]);
        verifyNever(
          () => mockAiInputRepo.createAiResponseEntry(
            id: any(named: 'id'),
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        );
      });

      test('writes the raw transcript when the summary fails', () async {
        await stubRun(dictionary: [kubernetes]);
        stubSummary(null);

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: transcriptionFor(transcriptionProvider: whisper()),
          linkedTaskId: 'task-1',
        );

        expect(textWrites, [null, raw]);
        verifyNever(
          () => mockSpeechDictionaryRepository.learnMisheardForms(any()),
        );
      });

      test('keeps an edit made while the summary ran', () async {
        await stubRun(
          dictionary: [kubernetes],
          editAfterTranscript: 'My own words.',
        );
        stubSummary(firstOccurrence);

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: transcriptionFor(transcriptionProvider: whisper()),
          linkedTaskId: 'task-1',
        );

        // Only the transcript's own write: the corrected text never lands.
        expect(textWrites, [null]);
      });

      test('corrects a note too short to summarize', () async {
        const short = 'Deploy to Cuban Eddies.';
        await stubRun(transcript: short, dictionary: [kubernetes]);
        stubSummary([
          {
            TranscriptNameCorrectionToolArgs.heard: 'Cuban Eddies',
            TranscriptNameCorrectionToolArgs.term: 'Kubernetes',
            TranscriptNameCorrectionToolArgs.context: 'Deploy to Cuban Eddies',
          },
        ]);

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: transcriptionFor(transcriptionProvider: whisper()),
          linkedTaskId: 'task-1',
        );

        expect(textWrites, [null, 'Deploy to Kubernetes.']);
      });

      test('a multimodal model writes its text at once and its summary '
          'corrects nothing', () async {
        await stubRun(dictionary: [kubernetes]);
        stubSummary(firstOccurrence);

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: transcriptionFor(
            transcriptionProvider: testInferenceProvider(id: 'p-gemini'),
          ),
          linkedTaskId: 'task-1',
        );

        expect(textWrites, [raw]);
        verifyNever(
          () => mockSpeechDictionaryRepository.learnMisheardForms(any()),
        );
      });

      test('the user asking for a transcription in the task context gets the '
          'composite step', () async {
        await stubRun(dictionary: [kubernetes]);
        stubSummary(firstOccurrence);

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: transcriptionFor(
            transcriptionProvider: whisper(),
            automated: false,
          ),
          linkedTaskId: 'task-1',
        );

        expect(textWrites, [null, corrected]);
      });

      // The category automates speech recognition in the task context and
      // nothing else: the run must be the same composite step the AI menu
      // starts, through to the corrected text and the linked summary.
      test(
        'the category automating speech recognition in the task context '
        'alone still gets the composite step and its summary',
        () async {
          await stubRun(dictionary: [kubernetes]);
          stubSummary(firstOccurrence);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: transcriptionFor(
              transcriptionProvider: whisper(),
              automatesSummary: false,
            ),
            linkedTaskId: 'task-1',
          );

          expect(textWrites, [null, corrected]);
          expect(lastSummaryCall, isNotNull);
          final response =
              verify(
                    () => mockAiInputRepo.createAiResponseEntry(
                      id: any(named: 'id'),
                      data: captureAny(named: 'data'),
                      start: any(named: 'start'),
                      linkedId: 'audio-1',
                      categoryId: any(named: 'categoryId'),
                    ),
                  ).captured.single
                  as AiResponseData;
          expect(response.type, AiResponseType.audioSummary);
        },
      );

      // The direct speech-to-text fallback, run without an inference
      // profile, puts its transcription model in the thinking slot.
      test(
        'a profile whose thinking model cannot call tools schedules no '
        'summary and writes the transcript at once',
        () async {
          await stubRun(dictionary: [kubernetes]);
          stubSummary(firstOccurrence);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: transcriptionFor(
              transcriptionProvider: whisper(),
              automatesSummary: false,
              thinkingModel: testAiModel(providerModelId: 'whisper-large-v3'),
            ),
            linkedTaskId: 'task-1',
          );

          expect(textWrites, [raw]);
          expect(lastSummaryCall, isNull);
        },
      );

      for (final automated in [true, false]) {
        test(
          "the composite step runs on the profile's audio post-processing "
          'model when one is set — '
          '${automated ? 'started by the category' : 'started by hand'}',
          () async {
            await stubRun(dictionary: [kubernetes]);
            stubSummary(firstOccurrence);

            await runner.runTranscription(
              audioEntryId: 'audio-1',
              automationResult: transcriptionFor(
                transcriptionProvider: whisper(),
                automated: automated,
                postProcessingModel: testAiModel(
                  id: 'post-row',
                  providerModelId: 'post-native',
                ).copyWith(supportsFunctionCalling: true),
              ),
              linkedTaskId: 'task-1',
            );

            expect(textWrites, [null, corrected]);
            expect(lastSummaryCall!.namedArguments[#model], 'post-native');
            expect(
              (lastSummaryCall!.namedArguments[#provider]
                      as AiConfigInferenceProvider)
                  .id,
              'p-post',
            );
            final data =
                verify(
                      () => mockAiInputRepo.createAiResponseEntry(
                        id: any(named: 'id'),
                        data: captureAny(named: 'data'),
                        start: any(named: 'start'),
                        linkedId: 'audio-1',
                        categoryId: any(named: 'categoryId'),
                      ),
                    ).captured.single
                    as AiResponseData;
            expect(data.model, 'post-native');
          },
        );
      }

      test(
        'without a post-processing model the composite step runs on the '
        'thinking model, as before',
        () async {
          await stubRun(dictionary: [kubernetes]);
          stubSummary(firstOccurrence);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: transcriptionFor(
              transcriptionProvider: whisper(),
            ),
            linkedTaskId: 'task-1',
          );

          expect(textWrites, [null, corrected]);
          expect(
            lastSummaryCall!.namedArguments[#model],
            'models/gemini-flash',
          );
        },
      );

      test(
        'a tool-capable post-processing model gets the summary although the '
        'thinking model cannot call tools',
        () async {
          await stubRun(dictionary: [kubernetes]);
          stubSummary(firstOccurrence);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: transcriptionFor(
              transcriptionProvider: whisper(),
              automatesSummary: false,
              thinkingModel: testAiModel(providerModelId: 'whisper-large-v3'),
              postProcessingModel: testAiModel(
                id: 'post-row',
                providerModelId: 'post-native',
              ).copyWith(supportsFunctionCalling: true),
            ),
            linkedTaskId: 'task-1',
          );

          expect(textWrites, [null, corrected]);
          expect(lastSummaryCall!.namedArguments[#model], 'post-native');
        },
      );

      for (final toollessThinking in [false, true]) {
        test(
          'a post-processing model this device cannot resolve fails the step '
          'visibly and never falls back to the thinking model — the '
          'transcript is still written, uncorrected'
          '${toollessThinking ? ', however unable that thinking model' : ''}',
          () async {
            await stubRun(dictionary: [kubernetes]);
            stubSummary(firstOccurrence);

            await runner.runTranscription(
              audioEntryId: 'audio-1',
              automationResult: transcriptionFor(
                transcriptionProvider: whisper(),
                postProcessingUnavailable: true,
                thinkingModel: toollessThinking
                    ? testAiModel(providerModelId: 'whisper-large-v3')
                    : null,
              ),
              linkedTaskId: 'task-1',
            );

            expect(textWrites, [null, raw]);
            expect(lastSummaryCall, isNull);
            verifyNever(
              () => mockAiInputRepo.createAiResponseEntry(
                id: any(named: 'id'),
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: any(named: 'linkedId'),
                categoryId: any(named: 'categoryId'),
              ),
            );
            for (final id in ['audio-1', 'task-1']) {
              expect(
                container.read(
                  inferenceStatusControllerProvider((
                    id: id,
                    aiResponseType: AiResponseType.audioSummary,
                  )),
                ),
                InferenceStatus.error,
              );
              expect(
                container.read(
                  inferenceErrorControllerProvider((
                    id: id,
                    aiResponseType: AiResponseType.audioSummary,
                  )),
                ),
                contains('Audio post-processing model unavailable'),
              );
            }
          },
        );
      }

      test(
        'a check-in with no task is framed by the person it is about, and a '
        'name it expects is corrected though the dictionary does not know it',
        () async {
          // No dictionary term reaches the recording; only the check-in's
          // expected name does.
          await stubRun();
          stubSummary(firstOccurrence);
          final person = fallbackRelationshipEntry;
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'audio-1'),
          ).thenAnswer((_) async => [person]);
          when(
            () => mockAiInputRepo.getEntity(person.meta.id),
          ).thenAnswer((_) async => person);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: transcriptionFor(
              transcriptionProvider: whisper(),
              automated: false,
            ),
            knownTerms: const ['Kubernetes'],
          );

          expect(textWrites, [null, corrected]);
          final prompt = lastSummaryCall!.positionalArguments.first as String;
          expect(prompt, contains('**Person Context:**'));
          expect(prompt, contains('"name": "Fallback Person"'));
          expect(prompt, contains('**Speech Dictionary:**\n'));
          expect(prompt, contains('- Kubernetes'));
          expect(prompt, isNot(contains('**Task Context:**')));
        },
      );

      for (final automated in [true, false]) {
        test(
          'the plain transcription on a speech-to-text engine is corrected '
          'too — ${automated ? 'automated without an automated summary' : 'asked for by the user'}',
          () async {
            await stubRun(dictionary: [kubernetes]);
            stubSummary(firstOccurrence);

            await runner.runTranscription(
              audioEntryId: 'audio-1',
              automationResult: transcriptionFor(
                transcriptionProvider: whisper(),
                automated: automated,
                automatesSummary: false,
                skill: findBuiltInSkill(skillTranscribeId),
              ),
              linkedTaskId: 'task-1',
            );

            expect(textWrites, [null, corrected]);
            expect(lastSummaryCall, isNotNull);
          },
        );
      }

      test(
        'a multimodal model asked by hand writes its text at once and '
        'chains nothing — it read the dictionary in its own prompt',
        () async {
          await stubRun(dictionary: [kubernetes]);
          stubSummary(firstOccurrence);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: transcriptionFor(
              transcriptionProvider: testInferenceProvider(id: 'p-omni'),
              automated: false,
              skill: findBuiltInSkill(skillTranscribeId),
            ),
            linkedTaskId: 'task-1',
          );

          expect(textWrites, [raw]);
          expect(lastSummaryCall, isNull);
        },
      );

      test('a summary of a recording left without text fills it', () async {
        await stubRun(dictionary: [kubernetes]);
        stubSummary(firstOccurrence);
        // A held transcription whose composite step never finished.
        final held = makeAudioEntity().copyWith(
          data: makeAudioEntity().data.copyWith(
            transcripts: [
              AudioTranscript(
                created: DateTime(2024),
                library: 'whisper',
                model: 'whisper-large-v3',
                detectedLanguage: '-',
                transcript: raw,
              ),
            ],
          ),
        );
        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => held);
        when(
          () => mockJournalRepo.updateJournalEntity(
            any(),
            onlyIfUnchanged: any(named: 'onlyIfUnchanged'),
          ),
        ).thenAnswer((invocation) async {
          textWrites.add(
            (invocation.positionalArguments.first as JournalAudio)
                .entryText
                ?.plainText,
          );
          return true;
        });

        await runner.runAudioSummary(
          audioEntryId: 'audio-1',
          automationResult: AutomationResult(
            handled: true,
            skill: findBuiltInSkill(skillAudioSummaryId),
            resolvedProfile: ResolvedProfile(
              thinkingModelId: 'models/gemini-flash',
              thinkingProvider: testInferenceProvider(id: 'p-flash'),
            ),
          ),
          linkedTaskId: 'task-1',
        );

        expect(textWrites, [corrected]);
      });
    });
  }
}
