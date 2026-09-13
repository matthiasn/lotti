part of '../skill_inference_runner_test.dart';

extension _ImageAnalysisTierCases on _SkillInferenceTestSetup {
  void registerImageAnalysisTiers() {
    group('tiered analysis', () {
      /// A vision model that can call tools — the condition for tiers.
      AiConfigModel toolCapableVisionModel() =>
          AiConfig.model(
                id: 'vision-tools',
                name: 'Vision with tools',
                providerModelId: 'vision-model',
                inferenceProviderId: 'p-vision',
                createdAt: DateTime(2024),
                inputModalities: const [Modality.text, Modality.image],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
                supportsFunctionCalling: true,
              )
              as AiConfigModel;

      AutomationResult resultWithVisionModel({AiConfigModel? model}) =>
          AutomationResult(
            handled: true,
            resolvedProfile: ResolvedProfile(
              thinkingModelId: 'models/gemini-3-flash-preview',
              thinkingProvider: testInferenceProvider(),
              imageRecognitionModelId: 'vision-model',
              imageRecognitionProvider: testInferenceProvider(
                id: 'p-vision',
              ),
              imageRecognitionModel: model,
            ),
            skill: testImageSkill,
            skillAssignment: const SkillAssignment(
              skillId: 'skill-vision',
              automate: true,
            ),
          );

      Future<void> stubImageOnDisk() async {
        final imageDir = Directory('${tempDir.path}/images');
        await imageDir.create(recursive: true);
        await File(
          '${imageDir.path}/test.jpg',
        ).writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
      }

      void stubImageInference(
        List<CreateChatCompletionStreamResponse> chunks,
      ) {
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
            tools: any(named: 'tools'),
            toolChoice: any(named: 'toolChoice'),
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer((_) => Stream.fromIterable(chunks));
      }

      CreateChatCompletionStreamResponse tierChunk({
        Map<String, Object?> overrides = const {},
      }) => CreateChatCompletionStreamResponse(
        id: 'resp-img',
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
                          'Dashboard shows the error rate flat at 0.2%.',
                      EntrySummaryToolArgs.tldr:
                          'The rollout has not moved the error rate.',
                      EntrySummaryToolArgs.summary:
                          '## Observed\n- Error rate 0.2%',
                      ...overrides,
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
      );

      setUp(() {
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => makeImageEntity());
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockJournalRepo.getLinkedToEntities(
            linkedTo: any(named: 'linkedTo'),
          ),
        ).thenAnswer((_) async => <JournalEntity>[]);
      });

      test(
        'a tool-capable vision model publishes tiers, and the tool summary '
        'becomes the analysis body',
        () async {
          _registerInteractionCapture();
          await stubImageOnDisk();
          stubImageInference([tierChunk()]);
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (invocation) async => makePersistedResponse(invocation),
          );
          stubLoggingEvent();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: resultWithVisionModel(
              model: toolCapableVisionModel(),
            ),
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

          expect(
            data.oneLiner,
            'Dashboard shows the error rate flat at 0.2%.',
          );
          expect(data.tldr, 'The rollout has not moved the error rate.');
          expect(data.response, '## Observed\n- Error rate 0.2%');
          expect(data.type, AiResponseType.imageAnalysis);
        },
      );

      for (final invalidTier in <String, Map<String, Object?>>{
        'overlong one-liner': {
          EntrySummaryToolArgs.oneLiner: 'x' * 149,
        },
        'empty TLDR': {EntrySummaryToolArgs.tldr: '   '},
      }.entries) {
        test(
          'preserves image analysis with an ${invalidTier.key} '
          'and no streamed prose',
          () async {
            final attribution = _registerInteractionCapture();
            await stubImageOnDisk();
            stubImageInference([tierChunk(overrides: invalidTier.value)]);
            when(
              () => mockAiInputRepo.createAiResponseEntry(
                id: any(named: 'id'),
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: any(named: 'linkedId'),
                categoryId: any(named: 'categoryId'),
              ),
            ).thenAnswer(
              (invocation) async => makePersistedResponse(invocation),
            );
            stubLoggingEvent();

            await runner.runImageAnalysis(
              imageEntryId: 'img-1',
              automationResult: resultWithVisionModel(
                model: toolCapableVisionModel(),
              ),
            );

            final data =
                verify(
                      () => mockAiInputRepo.createAiResponseEntry(
                        id: any(named: 'id'),
                        data: captureAny(named: 'data'),
                        start: any(named: 'start'),
                        linkedId: 'img-1',
                        categoryId: any(named: 'categoryId'),
                      ),
                    ).captured.single
                    as AiResponseData;
            expect(data.response, '## Observed\n- Error rate 0.2%');
            expect(data.oneLiner, isNull);
            expect(data.tldr, isNull);
            expect(data.type, AiResponseType.imageAnalysis);
            expect(
              _capturedEvents(attribution).single.responseDigest,
              sha256.convert(utf8.encode(data.response)).toString(),
            );
          },
        );
      }

      test(
        'attaches the publishing tool and pins the model to it only when '
        'the vision model can call tools',
        () async {
          _registerInteractionCapture();
          await stubImageOnDisk();
          stubImageInference([tierChunk()]);
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (invocation) async => makePersistedResponse(invocation),
          );
          stubLoggingEvent();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: resultWithVisionModel(
              model: toolCapableVisionModel(),
            ),
          );

          final captured = verify(
            () => mockCloudRepo.generateWithImages(
              captureAny(),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              images: any(named: 'images'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              tools: captureAny(named: 'tools'),
              toolChoice: captureAny(named: 'toolChoice'),
              geminiThinkingMode: any(named: 'geminiThinkingMode'),
              impactCollector: any(named: 'impactCollector'),
            ),
          ).captured;

          final userMessage = captured[0] as String;
          final tools = captured[1] as List<ChatCompletionTool>?;
          expect(tools, hasLength(1));
          expect(tools!.single.function.name, entrySummaryToolName);
          expect(captured[2], isNotNull);
          // The prompt must actually ask for the tool, or a model free to
          // ignore it would answer in prose.
          expect(userMessage, contains(entrySummaryToolName));
          expect(userMessage, contains('oneLiner'));
        },
      );

      test(
        'a vision model without tool support keeps the prose contract '
        'exactly as before — no tool, no pin, no tier instruction',
        () async {
          _registerInteractionCapture();
          await stubImageOnDisk();
          stubImageInference([makeStreamChunk('A photo of a sunset')]);
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (invocation) async => makePersistedResponse(invocation),
          );
          stubLoggingEvent();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            // No model metadata at all — the common case for a profile whose
            // vision slot predates capability tracking.
            automationResult: resultWithVisionModel(),
          );

          final captured = verify(
            () => mockCloudRepo.generateWithImages(
              captureAny(),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              images: any(named: 'images'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              tools: captureAny(named: 'tools'),
              toolChoice: captureAny(named: 'toolChoice'),
              geminiThinkingMode: any(named: 'geminiThinkingMode'),
              impactCollector: any(named: 'impactCollector'),
            ),
          ).captured;

          expect(captured[1], isNull);
          expect(captured[2], isNull);
          expect(
            captured[0] as String,
            isNot(contains(entrySummaryToolName)),
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
          expect(data.response, 'A photo of a sunset');
          expect(data.oneLiner, isNull);
          expect(data.tldr, isNull);
        },
      );

      test(
        'does NOT ask for tiers on a provider whose image path drops tools, '
        'however capable the model claims to be — the prompt would tell it '
        'to call a tool it was never handed',
        () async {
          _registerInteractionCapture();
          await stubImageOnDisk();
          stubImageInference([makeStreamChunk('A photo of a sunset')]);
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (invocation) async => makePersistedResponse(invocation),
          );
          stubLoggingEvent();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: AutomationResult(
              handled: true,
              resolvedProfile: ResolvedProfile(
                thinkingModelId: 'models/gemini-3-flash-preview',
                thinkingProvider: testInferenceProvider(),
                imageRecognitionModelId: 'vision-model',
                // Ollama's image client has no tool parameters at all.
                imageRecognitionProvider: testInferenceProvider(
                  id: 'p-ollama',
                  inferenceProviderType: InferenceProviderType.ollama,
                ),
                imageRecognitionModel: toolCapableVisionModel(),
              ),
              skill: testImageSkill,
              skillAssignment: const SkillAssignment(
                skillId: 'skill-vision',
                automate: true,
              ),
            ),
          );

          final captured = verify(
            () => mockCloudRepo.generateWithImages(
              captureAny(),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              images: any(named: 'images'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              tools: captureAny(named: 'tools'),
              toolChoice: captureAny(named: 'toolChoice'),
              geminiThinkingMode: any(named: 'geminiThinkingMode'),
              impactCollector: any(named: 'impactCollector'),
            ),
          ).captured;

          expect(captured[1], isNull);
          expect(captured[2], isNull);
          expect(
            captured[0] as String,
            isNot(contains(entrySummaryToolName)),
          );
        },
      );

      test(
        'records the persisted analysis for provenance, not the empty '
        'stream body a tool call leaves behind',
        () async {
          final attribution = _registerInteractionCapture();
          await stubImageOnDisk();
          stubImageInference([tierChunk()]);
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (invocation) async => makePersistedResponse(invocation),
          );
          stubLoggingEvent();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: resultWithVisionModel(
              model: toolCapableVisionModel(),
            ),
          );

          final event = _capturedEvents(attribution).single;
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

          // The digest must be of the analysis actually stored, or it can
          // never verify the entry it is supposed to describe — and every
          // tiered analysis would share the digest of an empty string.
          expect(
            event.responseDigest,
            sha256.convert(utf8.encode(data.response)).toString(),
          );
          expect(
            event.responseDigest,
            isNot(sha256.convert(utf8.encode('')).toString()),
          );
        },
      );

      test(
        'a model that answers in prose despite the tool still gets its '
        'analysis saved — losing an analysis to reclaim a one-liner would '
        'be a bad trade',
        () async {
          _registerInteractionCapture();
          await stubImageOnDisk();
          stubImageInference([
            makeStreamChunk('A dashboard screenshot showing 0.2% errors'),
          ]);
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (invocation) async => makePersistedResponse(invocation),
          );
          stubLoggingEvent();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: resultWithVisionModel(
              model: toolCapableVisionModel(),
            ),
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

          expect(
            data.response,
            'A dashboard screenshot showing 0.2% errors',
          );
          expect(data.oneLiner, isNull);
          expect(data.tldr, isNull);
        },
      );
    });
  }
}
