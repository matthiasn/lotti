part of '../skill_inference_runner_test.dart';

extension _PromptGenerationPropertyCases on _SkillInferenceTestSetup {
  void registerPromptGenerationProperties() {
    glados.Glados(
      glados.any.promptStreamScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'matches generated prompt stream persistence and status semantics',
      (scenario) async {
        final localCloudRepo = MockCloudInferenceRepository();
        final localAiInputRepo = MockAiInputRepository();
        final localJournalRepo = MockJournalRepository();
        final localLoggingService = MockDomainLogger();
        final localPromptBuilderHelper = MockPromptBuilderHelper();
        final localTaskSummaryResolver = MockTaskSummaryResolver();
        final localContainer = ProviderContainer();

        void stubLocalLoggingException() {
          when(
            () => localLoggingService.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).thenReturn(null);
        }

        void stubLocalLoggingEvent() {
          when(
            () => localLoggingService.log(
              any<LogDomain>(),
              any<String>(),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).thenReturn(null);
        }

        try {
          late final Ref localRef;
          final refProvider = Provider<void>((ref) {
            localRef = ref;
          });
          localContainer.read(refProvider);

          final localRunner = SkillInferenceRunner(
            ref: localRef,
            cloudRepository: localCloudRepo,
            aiInputRepository: localAiInputRepo,
            journalRepository: localJournalRepo,
            loggingService: localLoggingService,
            promptBuilderHelper: localPromptBuilderHelper,
            taskSummaryResolver: localTaskSummaryResolver,
          );

          final entry = makeTextEntry(
            id: 'generated-prompt-entry',
            markdown: 'Generate a useful implementation prompt.',
            plainText: 'Generate a useful implementation prompt.',
            categoryId: 'cat-generated',
          );
          final linkedTaskId = scenario.includeLinkedTask
              ? 'generated-linked-task'
              : null;

          when(
            () => localAiInputRepo.getEntity('generated-prompt-entry'),
          ).thenAnswer((_) async => entry);
          if (linkedTaskId != null) {
            when(
              () => localAiInputRepo.buildTaskDetailsJson(id: linkedTaskId),
            ).thenAnswer((_) async => '{"id": "$linkedTaskId"}');
            when(
              () => localAiInputRepo.buildLinkedTasksJson(linkedTaskId),
            ).thenAnswer((_) async => '{"linked": []}');
            when(
              () => localAiInputRepo.buildCategoryKnowledge(linkedTaskId),
            ).thenAnswer((_) async => null);
          }
          when(
            () => localCloudRepo.generate(
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
            (_) => Stream.fromIterable(
              scenario.parts.map((part) => makeStreamChunk(part.content)),
            ),
          );

          if (scenario.shouldPersist) {
            when(
              () => localAiInputRepo.createAiResponseEntry(
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: any(named: 'linkedId'),
                categoryId: any(named: 'categoryId'),
              ),
            ).thenAnswer(
              (invocation) async => makePersistedResponse(invocation),
            );
            stubLocalLoggingEvent();
          } else {
            stubLocalLoggingException();
          }

          await localRunner.runPromptGeneration(
            entryId: 'generated-prompt-entry',
            automationResult: makePromptGenerationResult(),
            linkedTaskId: linkedTaskId,
          );

          final status = localContainer.read(
            inferenceStatusControllerProvider((
              id: 'generated-prompt-entry',
              aiResponseType: AiResponseType.promptGeneration,
            )),
          );
          expect(
            status,
            scenario.shouldPersist
                ? InferenceStatus.idle
                : InferenceStatus.error,
            reason: '$scenario',
          );
          if (linkedTaskId != null) {
            expect(
              localContainer.read(
                inferenceStatusControllerProvider((
                  id: linkedTaskId,
                  aiResponseType: AiResponseType.promptGeneration,
                )),
              ),
              status,
              reason: '$scenario',
            );
          }

          if (!scenario.shouldPersist) {
            verifyNever(
              () => localAiInputRepo.createAiResponseEntry(
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: any(named: 'linkedId'),
                categoryId: any(named: 'categoryId'),
              ),
            );
            verify(
              () => localLoggingService.error(
                LogDomain.ai,
                any<Object>(),
                stackTrace: any<StackTrace?>(named: 'stackTrace'),
                subDomain: 'runPromptGeneration',
              ),
            ).called(1);
            return;
          }

          final captured = verify(
            () => localAiInputRepo.createAiResponseEntry(
              data: captureAny(named: 'data'),
              start: any(named: 'start'),
              linkedId: captureAny(named: 'linkedId'),
              categoryId: captureAny(named: 'categoryId'),
            ),
          ).captured;
          final data = captured[0] as AiResponseData;
          expect(
            data.response,
            scenario.expectedResponse,
            reason: '$scenario',
          );
          expect(data.type, AiResponseType.promptGeneration);
          expect(data.skillId, testPromptGenSkill.id);
          // Coding prompts link to the parent task when one exists,
          // otherwise fall back to the source entry.
          expect(
            captured[1],
            scenario.includeLinkedTask
                ? 'generated-linked-task'
                : 'generated-prompt-entry',
          );
          expect(captured[2], 'cat-generated');
        } finally {
          localContainer.dispose();
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.promptGenerationScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches generated prompt source, model, and status semantics',
      (scenario) async {
        final bench = _GeneratedSkillRunnerBench.create();

        try {
          const entryId = 'generated-source-entry';
          final linkedTaskId = scenario.streamScenario.includeLinkedTask
              ? 'generated-source-linked-task'
              : null;
          final entity = switch (scenario.sourceKind) {
            _GeneratedPromptSourceKind.journalEntry => makeTextEntry(
              id: entryId,
              markdown: 'Generated **markdown** source',
              plainText: 'Generated plain source',
              categoryId: 'cat-generated',
            ),
            _GeneratedPromptSourceKind.journalAudio => makeAudioEntity(
              id: entryId,
              plainText: 'Generated audio transcript',
              categoryId: 'cat-generated',
            ),
            _GeneratedPromptSourceKind.missingEntity => null,
            _GeneratedPromptSourceKind.taskEntity => makeTaskEntity(entryId),
          };

          when(
            () => bench.aiInputRepository.getEntity(entryId),
          ).thenAnswer((_) async => entity);
          if (scenario.hasTextBearingEntity && linkedTaskId != null) {
            when(
              () => bench.aiInputRepository.buildTaskDetailsJson(
                id: linkedTaskId,
              ),
            ).thenAnswer((_) async => '{"id": "$linkedTaskId"}');
            when(
              () => bench.aiInputRepository.buildLinkedTasksJson(
                linkedTaskId,
              ),
            ).thenAnswer((_) async => '{"linked": []}');
            when(
              () => bench.aiInputRepository.buildCategoryKnowledge(
                linkedTaskId,
              ),
            ).thenAnswer((_) async => null);
          }
          if (scenario.hasTextBearingEntity) {
            when(
              () => bench.cloudRepository.generate(
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
              (_) => Stream.fromIterable(
                scenario.streamScenario.parts.map(
                  (part) => makeStreamChunk(part.content),
                ),
              ),
            );
          }

          if (scenario.shouldPersist) {
            when(
              () => bench.aiInputRepository.createAiResponseEntry(
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: any(named: 'linkedId'),
                categoryId: any(named: 'categoryId'),
              ),
            ).thenAnswer(
              (invocation) async => makePersistedResponse(invocation),
            );
            bench.stubLoggingEvent();
          } else {
            bench.stubLoggingException();
          }

          final automationResult = scenario.useHighEndModel
              ? makePromptGenerationResult(
                  thinkingHighEndModelId: scenario.expectedModel,
                  thinkingHighEndProvider: testInferenceProvider(id: 'p-pro'),
                )
              : makePromptGenerationResult();

          await bench.runner.runPromptGeneration(
            entryId: entryId,
            automationResult: automationResult,
            linkedTaskId: linkedTaskId,
          );

          final expectedStatus = scenario.shouldPersist
              ? InferenceStatus.idle
              : InferenceStatus.error;
          expect(
            bench.promptStatus(entryId),
            expectedStatus,
            reason: '$scenario',
          );
          if (linkedTaskId != null) {
            expect(
              bench.promptStatus(linkedTaskId),
              expectedStatus,
              reason: '$scenario',
            );
          }

          if (!scenario.hasTextBearingEntity) {
            verifyNever(
              () => bench.cloudRepository.generate(
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
          } else {
            final generatedCall = verify(
              () => bench.cloudRepository.generate(
                captureAny(),
                model: scenario.expectedModel,
                temperature: any(named: 'temperature'),
                baseUrl: any(named: 'baseUrl'),
                apiKey: any(named: 'apiKey'),
                provider: any(named: 'provider'),
                systemMessage: any(named: 'systemMessage'),
                impactCollector: any(named: 'impactCollector'),
              ),
            ).captured;
            final prompt = generatedCall.single as String;
            final expectedSourceText =
                scenario.sourceKind == _GeneratedPromptSourceKind.journalAudio
                ? 'Generated audio transcript'
                : 'Generated **markdown** source';
            expect(prompt, contains(expectedSourceText), reason: '$scenario');
          }

          if (!scenario.shouldPersist) {
            verifyNever(
              () => bench.aiInputRepository.createAiResponseEntry(
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: any(named: 'linkedId'),
                categoryId: any(named: 'categoryId'),
              ),
            );
            verify(
              () => bench.loggingService.error(
                LogDomain.ai,
                any<Object>(),
                stackTrace: any<StackTrace?>(named: 'stackTrace'),
                subDomain: 'runPromptGeneration',
              ),
            ).called(1);
            return;
          }

          final captured = verify(
            () => bench.aiInputRepository.createAiResponseEntry(
              data: captureAny(named: 'data'),
              start: any(named: 'start'),
              linkedId: captureAny(named: 'linkedId'),
              categoryId: captureAny(named: 'categoryId'),
            ),
          ).captured;
          final data = captured[0] as AiResponseData;
          expect(
            data.response,
            scenario.streamScenario.expectedResponse,
            reason: '$scenario',
          );
          expect(data.model, scenario.expectedModel, reason: '$scenario');
          expect(data.type, AiResponseType.promptGeneration);
          expect(data.skillId, testPromptGenSkill.id);
          // Coding prompts link to the parent task when one exists,
          // otherwise fall back to the source entry.
          expect(captured[1], linkedTaskId ?? entryId);
          expect(captured[2], 'cat-generated');
          verify(
            () => bench.loggingService.log(
              LogDomain.ai,
              any<String>(),
              subDomain: 'runPromptGeneration',
            ),
          ).called(1);
        } finally {
          bench.dispose();
        }
      },
      tags: 'glados',
    );
  }
}
