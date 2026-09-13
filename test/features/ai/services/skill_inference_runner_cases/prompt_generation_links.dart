part of '../skill_inference_runner_test.dart';

extension _PromptGenerationLinkCases on _SkillInferenceTestSetup {
  void registerPromptGenerationLinks() {
    // Dual-link behaviour: a coding prompt is created linked to its parent
    // task AND additionally linked back to the source entry.
    group('dual link to task and source entry', () {
      AiResponseEntry makeResponseEntry(String id) => AiResponseEntry(
        meta: Metadata(
          id: id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const AiResponseData(
          model: 'models/gemini-flash',
          systemMessage: '',
          prompt: 'p',
          thoughts: '',
          response: 'r',
          type: AiResponseType.promptGeneration,
        ),
      );

      void stubGenerate() {
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
            makeStreamChunk('## Summary\nX\n\n## Prompt\nDo the work'),
          ]),
        );
      }

      void stubCreateResponse(AiResponseEntry? entry) {
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => entry);
      }

      test(
        'links prompt to parent task and back to the source entry',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-dual',
            plainText: 'notes',
            markdown: 'notes',
            categoryId: 'cat-dual',
          );
          when(
            () => mockAiInputRepo.getEntity('audio-dual'),
          ).thenAnswer((_) async => audio);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-dual'),
          ).thenAnswer((_) async => '{"id": "task-dual"}');
          when(
            () => mockAiInputRepo.buildLinkedTasksJson('task-dual'),
          ).thenAnswer((_) async => '{"linked": []}');
          stubGenerate();
          stubCreateResponse(makeResponseEntry('resp-dual'));
          when(
            () => mockAiInputRepo.createLink(
              fromId: any(named: 'fromId'),
              toId: any(named: 'toId'),
            ),
          ).thenAnswer((_) async => true);
          stubLoggingEvent();

          await runner.runPromptGeneration(
            entryId: 'audio-dual',
            automationResult: makePromptGenerationResult(),
            linkedTaskId: 'task-dual',
          );

          // Primary link → parent task.
          final captured = verify(
            () => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: captureAny(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).captured;
          expect(captured.single, 'task-dual');

          // Secondary link → source entry, pointing at the new response.
          verify(
            () => mockAiInputRepo.createLink(
              fromId: 'audio-dual',
              toId: 'resp-dual',
            ),
          ).called(1);
        },
      );

      test(
        'does not add a second link when there is no parent task',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-solo',
            plainText: 'notes',
            markdown: 'notes',
            categoryId: 'cat-solo',
          );
          when(
            () => mockAiInputRepo.getEntity('audio-solo'),
          ).thenAnswer((_) async => audio);
          stubGenerate();
          stubCreateResponse(makeResponseEntry('resp-solo'));
          stubLoggingEvent();

          await runner.runPromptGeneration(
            entryId: 'audio-solo',
            automationResult: makePromptGenerationResult(),
          );

          // Primary link falls back to the source entry itself…
          final captured = verify(
            () => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: captureAny(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).captured;
          expect(captured.single, 'audio-solo');

          // …so no duplicate self-link is created.
          verifyNever(
            () => mockAiInputRepo.createLink(
              fromId: any(named: 'fromId'),
              toId: any(named: 'toId'),
            ),
          );
        },
      );

      test(
        'does not add a second link when the response entry is null',
        () async {
          final audio = makeAudioEntity(
            id: 'audio-null',
            plainText: 'notes',
            markdown: 'notes',
            categoryId: 'cat-null',
          );
          when(
            () => mockAiInputRepo.getEntity('audio-null'),
          ).thenAnswer((_) async => audio);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-null'),
          ).thenAnswer((_) async => '{"id": "task-null"}');
          when(
            () => mockAiInputRepo.buildLinkedTasksJson('task-null'),
          ).thenAnswer((_) async => '{"linked": []}');
          stubGenerate();
          stubCreateResponse(null);
          stubLoggingEvent();

          await runner.runPromptGeneration(
            entryId: 'audio-null',
            automationResult: makePromptGenerationResult(),
            linkedTaskId: 'task-null',
          );

          verifyNever(
            () => mockAiInputRepo.createLink(
              fromId: any(named: 'fromId'),
              toId: any(named: 'toId'),
            ),
          );
        },
      );

      // Sets up a task-linked audio prompt whose secondary link fails, so the
      // failure-handling branches can be exercised. Returns after the run.
      Future<void> runWithFailingLink({
        required Object linkOutcome,
      }) async {
        final audio = makeAudioEntity(
          id: 'audio-fail',
          plainText: 'notes',
          markdown: 'notes',
          categoryId: 'cat-fail',
        );
        when(
          () => mockAiInputRepo.getEntity('audio-fail'),
        ).thenAnswer((_) async => audio);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-fail'),
        ).thenAnswer((_) async => '{"id": "task-fail"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-fail'),
        ).thenAnswer((_) async => '{"linked": []}');
        stubGenerate();
        stubCreateResponse(makeResponseEntry('resp-fail'));
        final linkStub = when(
          () => mockAiInputRepo.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        );
        if (linkOutcome is bool) {
          linkStub.thenAnswer((_) async => linkOutcome);
        } else {
          linkStub.thenThrow(linkOutcome);
        }
        stubLoggingEvent();
        _stubLoggingExceptionFor(mockLoggingService);

        await runner.runPromptGeneration(
          entryId: 'audio-fail',
          automationResult: makePromptGenerationResult(),
          linkedTaskId: 'task-fail',
        );
      }

      test(
        'logs and completes when the secondary link returns false',
        () async {
          await runWithFailingLink(linkOutcome: false);

          // Primary write still succeeded; the failed back-link is logged,
          // not surfaced as a run failure.
          verify(
            () => mockAiInputRepo.createLink(
              fromId: 'audio-fail',
              toId: 'resp-fail',
            ),
          ).called(1);
          verify(
            () => mockLoggingService.log(
              LogDomain.ai,
              any<String>(that: contains('not created')),
              subDomain: 'runPromptGeneration',
            ),
          ).called(1);
        },
      );

      test(
        'logs and does not rethrow when the secondary link throws',
        () async {
          // Must not throw: the prompt is already persisted, so a link
          // failure cannot be allowed to fail the whole run.
          await expectLater(
            runWithFailingLink(linkOutcome: Exception('db down')),
            completes,
          );

          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runPromptGeneration',
              message: any<String>(
                named: 'message',
                that: contains('failed'),
              ),
            ),
          ).called(1);
        },
      );
    });
  }
}
