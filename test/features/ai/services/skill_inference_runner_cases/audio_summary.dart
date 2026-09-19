part of '../skill_inference_runner_test.dart';

extension _AudioSummaryCases on _SkillInferenceTestSetup {
  void registerAudioSummary() {
    group('runAudioSummary', () {
      final testAudioSummarySkill =
          AiConfig.skill(
                id: 'skill-audio-summary',
                name: 'Summarize Recording',
                skillType: SkillType.audioSummary,
                requiredInputModalities: const [Modality.audio],
                contextPolicy: ContextPolicy.fullTask,
                systemInstructions: 'You summarize recordings.',
                userInstructions: 'Summarize the recording.',
                createdAt: DateTime(2024),
              )
              as AiConfigSkill;

      AutomationResult makeAudioSummaryResult({AiConfigModel? thinkingModel}) =>
          AutomationResult(
            handled: true,
            resolvedProfile: ResolvedProfile(
              thinkingModelId:
                  thinkingModel?.providerModelId ?? 'models/gemini-flash',
              thinkingProvider: testInferenceProvider(id: 'p-flash'),
              thinkingModel: thinkingModel,
            ),
            skill: testAudioSummarySkill,
          );

      /// A transcript comfortably over the 200-char summarization floor.
      final longTranscript = List.generate(
        8,
        (i) => 'We discussed migration step $i and who owns it.',
      ).join(' ');

      CreateChatCompletionStreamResponse makeToolCallChunk({
        String oneLiner = 'Agreed to ship the export flow behind a flag.',
        String tldr = 'The team chose a flagged rollout.',
        String summary = '## Decisions\n- Ship behind a flag',
        String toolName = entrySummaryToolName,
        String? rawArguments,
        CompletionUsage? usage,
      }) => CreateChatCompletionStreamResponse(
        id: 'resp-tool',
        choices: [
          ChatCompletionStreamResponseChoice(
            delta: ChatCompletionStreamResponseDelta(
              toolCalls: [
                ChatCompletionStreamMessageToolCallChunk(
                  index: 0,
                  id: 'call-1',
                  function: ChatCompletionStreamMessageFunctionCall(
                    name: toolName,
                    arguments:
                        rawArguments ??
                        jsonEncode({
                          EntrySummaryToolArgs.oneLiner: oneLiner,
                          EntrySummaryToolArgs.tldr: tldr,
                          EntrySummaryToolArgs.summary: summary,
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

      void stubGenerate(
        List<CreateChatCompletionStreamResponse> Function() chunks,
      ) {
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
        ).thenAnswer((_) => Stream.fromIterable(chunks()));
      }

      void stubPersistence(JournalAudio entity) {
        when(
          () => mockAiInputRepo.getEntity(entity.meta.id),
        ).thenAnswer((_) async => entity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
        ).thenAnswer((_) async => '{"id":"task-1","title":"Ship export"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson(any()),
        ).thenAnswer((_) async => '{"linked": []}');
        when(
          () => mockJournalRepo.getLinkedToEntities(
            linkedTo: any(named: 'linkedTo'),
          ),
        ).thenAnswer((_) async => <JournalEntity>[]);
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            id: any(named: 'id'),
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((invocation) async => makePersistedResponse(invocation));
      }

      test('throws StateError when skill is null', () async {
        expect(
          () => runner.runAudioSummary(
            audioEntryId: 'audio-1',
            automationResult: AutomationResult(
              handled: true,
              resolvedProfile: ResolvedProfile(
                thinkingModelId: 'models/gemini-flash',
                thinkingProvider: testInferenceProvider(),
              ),
            ),
          ),
          throwsStateError,
        );
      });

      test('throws StateError when profile is null', () async {
        expect(
          () => runner.runAudioSummary(
            audioEntryId: 'audio-1',
            automationResult: AutomationResult(
              handled: true,
              skill: testAudioSummarySkill,
            ),
          ),
          throwsStateError,
        );
      });

      test(
        'persists all three tiers, linked to the AUDIO entry rather than the '
        'task — the summary describes this recording',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-sum',
            plainText: longTranscript,
            categoryId: 'cat-audio',
          );
          stubPersistence(audio);
          stubGenerate(() => [makeToolCallChunk()]);
          stubLoggingEvent();

          await runner.runAudioSummary(
            audioEntryId: 'audio-sum',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          final captured = verify(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: captureAny(named: 'data'),
              start: any(named: 'start'),
              linkedId: captureAny(named: 'linkedId'),
              categoryId: captureAny(named: 'categoryId'),
            ),
          ).captured;
          final data = captured[0] as AiResponseData;

          expect(
            data.oneLiner,
            'Agreed to ship the export flow behind a flag.',
          );
          expect(data.tldr, 'The team chose a flagged rollout.');
          expect(data.response, '## Decisions\n- Ship behind a flag');
          expect(data.type, AiResponseType.audioSummary);
          expect(data.skillId, 'skill-audio-summary');
          expect(captured[1], 'audio-sum');
          expect(captured[2], 'cat-audio');
        },
      );

      test(
        'sends the FULL transcript with no truncation, however long, and pins '
        'the summary tool',
        () async {
          final hugeTranscript = List.generate(
            2000,
            (i) => 'Sentence $i about the migration plan.',
          ).join(' ');
          final audio = makeAudioEntity(
            id: 'audio-huge',
            plainText: hugeTranscript,
          );
          stubPersistence(audio);
          stubGenerate(() => [makeToolCallChunk()]);
          stubLoggingEvent();

          await runner.runAudioSummary(
            audioEntryId: 'audio-huge',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          final captured = verify(
            () => mockCloudRepo.generate(
              captureAny(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              tools: captureAny(named: 'tools'),
              toolChoice: captureAny(named: 'toolChoice'),
              geminiThinkingMode: any(named: 'geminiThinkingMode'),
              impactCollector: any(named: 'impactCollector'),
            ),
          ).captured;

          final userMessage = captured[0] as String;
          expect(userMessage, contains('Sentence 0 about'));
          expect(userMessage, contains('Sentence 1999 about'));
          expect(userMessage, isNot(contains('...')));

          final tools = captured[1] as List<ChatCompletionTool>?;
          expect(tools, hasLength(1));
          expect(tools!.first.function.name, entrySummaryToolName);
          expect(captured[2], isNotNull);
        },
      );

      test(
        'injects the task context so the summary is framed by the task as it '
        'is right now',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-ctx',
            plainText: longTranscript,
          );
          stubPersistence(audio);
          stubGenerate(() => [makeToolCallChunk()]);
          stubLoggingEvent();

          await runner.runAudioSummary(
            audioEntryId: 'audio-ctx',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          final userMessage =
              verify(
                    () => mockCloudRepo.generate(
                      captureAny(),
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
                  ).captured.first
                  as String;

          expect(userMessage, contains('**Task Context:**'));
          expect(userMessage, contains('Ship export'));
          expect(userMessage, contains('**Entry Notes:**'));
        },
      );

      test(
        'skips a transcript under the summarization floor without calling '
        'inference or persisting anything',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-short',
            plainText: 'Too short to be worth a model call.',
          );
          stubPersistence(audio);
          stubLoggingEvent();

          await runner.runAudioSummary(
            audioEntryId: 'audio-short',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          verifyNever(
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
          );
          verifyNever(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          );
        },
      );

      test(
        'skips when the resolved thinking model cannot call tools — a pinned '
        'tool call at such a model can never return a summary',
        () async {
          final toollessModel =
              AiConfig.model(
                    id: 'toolless',
                    name: 'Toolless model',
                    providerModelId: 'models/toolless',
                    inferenceProviderId: 'p-flash',
                    createdAt: DateTime(2024),
                    inputModalities: const [Modality.text],
                    outputModalities: const [Modality.text],
                    isReasoningModel: false,
                  )
                  as AiConfigModel;
          stubLoggingEvent();

          await runner.runAudioSummary(
            audioEntryId: 'audio-toolless',
            automationResult: makeAudioSummaryResult(
              thinkingModel: toollessModel,
            ),
            linkedTaskId: 'task-1',
          );

          verifyZeroInteractions(mockCloudRepo);
          verifyNever(() => mockAiInputRepo.getEntity(any()));
        },
      );

      test(
        'retries once when the model narrates instead of calling the tool, '
        'and succeeds on the retry',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-retry',
            plainText: longTranscript,
          );
          stubPersistence(audio);
          var call = 0;
          stubGenerate(() {
            call++;
            return call == 1
                ? [makeStreamChunk('Here is a summary in prose.')]
                : [makeToolCallChunk()];
          });
          stubLoggingEvent();

          await runner.runAudioSummary(
            audioEntryId: 'audio-retry',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          expect(call, 2);
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
          expect(data.oneLiner, isNotEmpty);
        },
      );

      test(
        'bills the tokens of BOTH attempts, so a model that needed prompting '
        'twice does not look cheaper than it was',
        () async {
          final attribution = _registerInteractionCapture();
          final audio = makeAudioEntity(
            id: 'audio-usage',
            plainText: longTranscript,
          );
          stubPersistence(audio);
          var call = 0;
          stubGenerate(() {
            call++;
            return call == 1
                ? [
                    makeStreamChunk(
                      'Prose, not a tool call.',
                      usage: const CompletionUsage(
                        promptTokens: 100,
                        completionTokens: 10,
                        totalTokens: 110,
                      ),
                    ),
                  ]
                : [
                    makeToolCallChunk(
                      usage: const CompletionUsage(
                        promptTokens: 120,
                        completionTokens: 30,
                        totalTokens: 150,
                      ),
                    ),
                  ];
          });
          stubLoggingEvent();

          await runner.runAudioSummary(
            audioEntryId: 'audio-usage',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          final event = _capturedEvents(attribution).single;
          expect(event.inputTokens, 220);
          expect(event.outputTokens, 40);
          expect(event.totalTokens, 260);
        },
      );

      test(
        'gives up after one failed retry without persisting a partial summary',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-giveup',
            plainText: longTranscript,
          );
          stubPersistence(audio);
          stubGenerate(() => [makeStreamChunk('Still prose.')]);
          stubLoggingEvent();
          stubLoggingException();

          await runner.runAudioSummary(
            audioEntryId: 'audio-giveup',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          verifyNever(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          );
          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runAudioSummary',
            ),
          ).called(1);
        },
      );

      test(
        'reports a summary the repository could not persist as a failure '
        'and never finalizes its attribution',
        () async {
          final attribution = _registerInteractionCapture();
          final audio = makeAudioEntity(
            id: 'audio-unsaved',
            plainText: longTranscript,
          );
          stubPersistence(audio);
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => null);
          stubGenerate(() => [makeToolCallChunk()]);
          stubLoggingEvent();
          stubLoggingException();

          await runner.runAudioSummary(
            audioEntryId: 'audio-unsaved',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          final logged = verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              captureAny<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runAudioSummary',
            ),
          ).captured.single;
          expect(
            logged,
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Failed to persist audio summary for audio-unsaved',
            ),
          );
          verifyNever(() => attribution.service.finalize(any()));
        },
      );

      test(
        'rejects a non-audio source rather than summarizing whatever it finds',
        () async {
          when(
            () => mockAiInputRepo.getEntity('not-audio'),
          ).thenAnswer((_) async => makeTaskEntity('not-audio'));
          stubLoggingException();

          await runner.runAudioSummary(
            audioEntryId: 'not-audio',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          verifyZeroInteractions(mockCloudRepo);
          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runAudioSummary',
            ),
          ).called(1);
        },
      );

      test(
        'persists nothing when the recording is deleted mid-run — a summary '
        'linked to a gone entry would be detached',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-vanished',
            plainText: longTranscript,
          );
          stubPersistence(audio);
          // First read (step 1) finds it; the pre-persist re-read does not.
          var reads = 0;
          when(() => mockAiInputRepo.getEntity('audio-vanished')).thenAnswer((
            _,
          ) async {
            reads++;
            return reads == 1 ? audio : null;
          });
          stubGenerate(() => [makeToolCallChunk()]);
          stubLoggingEvent();
          stubLoggingException();

          await runner.runAudioSummary(
            audioEntryId: 'audio-vanished',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          verifyNever(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          );
        },
      );

      test(
        'sums cost and environmental impact across both attempts, and keeps '
        'the cached-token and reasoning details a retry would otherwise drop',
        () async {
          final attribution = _registerInteractionCapture();
          final audio = makeAudioEntity(
            id: 'audio-impact',
            plainText: longTranscript,
          );
          stubPersistence(audio);

          var call = 0;
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
            call++;
            // Each attempt reports impact into ITS OWN collector, the way a
            // Melious response does.
            final collector =
                invocation.namedArguments[#impactCollector]
                    as InferenceImpactCollector?;
            collector?.impact = call == 1
                ? const MeliousCallImpact(
                    energyKwh: 1,
                    carbonGCo2: 10,
                    waterLiters: 0.5,
                    costCredits: 3,
                    dataCenter: 'eu-west',
                    providerId: 'melious',
                  )
                : const MeliousCallImpact(
                    energyKwh: 2,
                    carbonGCo2: 20,
                    waterLiters: 1.5,
                    costCredits: 7,
                  );
            final usage = call == 1
                ? const CompletionUsage(
                    promptTokens: 100,
                    completionTokens: 10,
                    totalTokens: 110,
                    promptTokensDetails: PromptTokensDetails(cachedTokens: 40),
                    completionTokensDetails: CompletionTokensDetails(
                      reasoningTokens: 5,
                    ),
                  )
                : const CompletionUsage(
                    promptTokens: 120,
                    completionTokens: 30,
                    totalTokens: 150,
                    promptTokensDetails: PromptTokensDetails(cachedTokens: 20),
                    completionTokensDetails: CompletionTokensDetails(
                      reasoningTokens: 7,
                    ),
                  );
            return Stream.fromIterable([
              if (call == 1)
                makeStreamChunk('Prose, not a tool call.', usage: usage)
              else
                makeToolCallChunk(usage: usage),
            ]);
          });
          stubLoggingEvent();

          await runner.runAudioSummary(
            audioEntryId: 'audio-impact',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          final event = _capturedEvents(attribution).single;
          // Additive quantities are summed across attempts.
          expect(event.inputTokens, 220);
          expect(event.outputTokens, 40);
          // Cached input and reasoning tokens survive the merge — the
          // non-retry path reports them, so the retry path must too.
          expect(event.cachedInputTokens, 60);
          expect(event.thoughtsTokens, 12);
          // Both provider charges are billed, not just the retry's.
          expect(event.credits, 10);
        },
      );

      test(
        'bills both attempts even when the retry also fails — a model that '
        'never produces a summary must not look free',
        () async {
          final attribution = _registerInteractionCapture();
          final audio = makeAudioEntity(
            id: 'audio-billed-failure',
            plainText: longTranscript,
          );
          stubPersistence(audio);
          stubGenerate(
            () => [
              makeStreamChunk(
                'Still prose.',
                usage: const CompletionUsage(
                  promptTokens: 50,
                  completionTokens: 5,
                  totalTokens: 55,
                ),
              ),
            ],
          );
          stubLoggingEvent();
          stubLoggingException();

          await runner.runAudioSummary(
            audioEntryId: 'audio-billed-failure',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          final event = _capturedEvents(attribution).single;
          expect(event.inputTokens, 100);
          expect(event.outputTokens, 10);
          verifyNever(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          );
        },
      );

      test(
        'reassembles a tool call streamed across many argument fragments — '
        'the shape every real provider sends',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-fragments',
            plainText: longTranscript,
          );
          stubPersistence(audio);

          final fullArgs = jsonEncode({
            EntrySummaryToolArgs.oneLiner: 'Fragmented but complete.',
            EntrySummaryToolArgs.tldr: 'Reassembled from chunks.',
            EntrySummaryToolArgs.summary: '## Body',
          });
          // Name first with no arguments, then the JSON one character at a
          // time with no id and no name — the accumulator has only the index
          // to go on.
          final chunks = <CreateChatCompletionStreamResponse>[
            makeToolCallChunk(rawArguments: ''),
            for (final ch in fullArgs.split(''))
              CreateChatCompletionStreamResponse(
                id: 'resp-tool',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      toolCalls: [
                        ChatCompletionStreamMessageToolCallChunk(
                          index: 0,
                          function: ChatCompletionStreamMessageFunctionCall(
                            arguments: ch,
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
          ];
          stubGenerate(() => chunks);
          stubLoggingEvent();

          await runner.runAudioSummary(
            audioEntryId: 'audio-fragments',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

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

          expect(data.oneLiner, 'Fragmented but complete.');
          expect(data.tldr, 'Reassembled from chunks.');
        },
      );

      test(
        'marks every parent task stale so each parent agent wakes on its own '
        'subscription, not just the resolved one',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-parents',
            plainText: longTranscript,
          );
          stubPersistence(audio);
          when(
            () => mockJournalRepo.getLinkedToEntities(
              linkedTo: 'audio-parents',
            ),
          ).thenAnswer(
            (_) async => [makeTaskEntity('task-other')],
          );
          stubGenerate(() => [makeToolCallChunk()]);
          stubLoggingEvent();

          await runner.runAudioSummary(
            audioEntryId: 'audio-parents',
            automationResult: makeAudioSummaryResult(),
            linkedTaskId: 'task-1',
          );

          final notifications =
              getIt<UpdateNotifications>() as MockUpdateNotifications;
          verify(
            () => notifications.notify({
              'task-1',
              propagatedNotification('task-1'),
              'task-other',
              propagatedNotification('task-other'),
            }),
          ).called(1);
        },
      );
    });
  }
}
