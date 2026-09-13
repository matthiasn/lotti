part of '../skill_inference_runner_test.dart';

extension _PromptGenerationPersistenceCases on _SkillInferenceTestSetup {
  void registerPromptGenerationAttribution() {
    test(
      'persists generated prompts with their attribution carrier',
      () async {
        final attribution = _registerInteractionCapture();
        final textEntry = makeTextEntry(
          id: 'text-attributed',
          markdown: 'Implement the attributed change.',
          categoryId: 'cat-attributed',
        );
        when(
          () => mockAiInputRepo.getEntity('text-attributed'),
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
          (_) => Stream.value(
            makeStreamChunk('## Summary\nChange\n\n## Prompt\nImplement it'),
          ),
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

        await runner.runPromptGeneration(
          entryId: 'text-attributed',
          automationResult: makePromptGenerationResult(),
        );

        final data =
            verify(
                  () => mockAiInputRepo.createAiResponseEntry(
                    id: any(named: 'id'),
                    data: captureAny(named: 'data'),
                    start: any(named: 'start'),
                    linkedId: 'text-attributed',
                    categoryId: 'cat-attributed',
                  ),
                ).captured.single
                as AiResponseData;
        expect(data.aiAttribution, isNotNull);
        expect(_capturedEvents(attribution), hasLength(1));
        verify(() => attribution.service.finalize(any())).called(1);
      },
    );
  }

  void registerPromptGenerationPersistence() {
    test('happy path: generates prompt and saves AiResponseEntry', () async {
      final audioEntity =
          JournalEntity.journalAudio(
                meta: Metadata(
                  id: 'audio-happy',
                  createdAt: DateTime(2024),
                  updatedAt: DateTime(2024),
                  dateFrom: DateTime(2024),
                  dateTo: DateTime(2024),
                  categoryId: 'cat-1',
                ),
                data: AudioData(
                  dateFrom: DateTime(2024),
                  dateTo: DateTime(2024),
                  duration: const Duration(minutes: 1),
                  audioDirectory: '/audio/',
                  audioFile: 'test.aac',
                ),
                entryText: const EntryText(
                  plainText: 'Fix the login bug on mobile',
                  markdown: 'Fix the login bug on mobile',
                ),
              )
              as JournalAudio;

      when(
        () => mockAiInputRepo.getEntity('audio-happy'),
      ).thenAnswer((_) async => audioEntity);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-happy'),
      ).thenAnswer((_) async => '{"id": "task-happy"}');
      when(
        () => mockAiInputRepo.buildLinkedTasksJson('task-happy'),
      ).thenAnswer((_) async => '{"linked_from": [], "linked_to": []}');
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
          makeStreamChunk('## Summary\nFix login bug\n\n'),
          makeStreamChunk('## Prompt\nFix the login bug on mobile'),
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
        entryId: 'audio-happy',
        automationResult: makePromptGenerationResult(),
        linkedTaskId: 'task-happy',
      );

      // Verify AiResponseEntry was created with correct data.
      final captured = verify(
        () => mockAiInputRepo.createAiResponseEntry(
          data: captureAny(named: 'data'),
          start: any(named: 'start'),
          linkedId: captureAny(named: 'linkedId'),
          categoryId: captureAny(named: 'categoryId'),
        ),
      ).captured;

      final data = captured[0] as AiResponseData;
      expect(data.type, AiResponseType.promptGeneration);
      expect(data.response, contains('Fix login bug'));
      expect(data.model, 'models/gemini-flash');

      // Coding prompts attach to the parent task (like cover art), not the
      // triggering audio entry, so later prompts inherit them as context.
      final linkedId = captured[1] as String;
      expect(linkedId, 'task-happy');

      final categoryId = captured[2] as String?;
      expect(categoryId, 'cat-1');
    });

    test(
      'coding prompt links to the source entry when there is no task',
      () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-no-task',
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    categoryId: 'cat-1',
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

        when(
          () => mockAiInputRepo.getEntity('audio-no-task'),
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
            makeStreamChunk('## Prompt\nFix the login bug'),
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
          entryId: 'audio-no-task',
          automationResult: makePromptGenerationResult(),
          // No linkedTaskId — nothing to attach to but the entry itself.
        );

        final captured = verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: captureAny(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).captured;
        expect(captured.single, 'audio-no-task');
      },
    );

    test(
      'image-prompt generation keeps the source-entry link even with a task',
      () async {
        final imagePromptSkill =
            AiConfig.skill(
                  id: 'skill-image-prompt-gen',
                  name: 'Generate Image Prompt',
                  skillType: SkillType.imagePromptGeneration,
                  requiredInputModalities: const [Modality.audio],
                  contextPolicy: ContextPolicy.fullTask,
                  systemInstructions: 'You are a prompt engineer.',
                  userInstructions: 'Generate an image prompt.',
                  useReasoning: true,
                  createdAt: DateTime(2024),
                )
                as AiConfigSkill;

        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-image-prompt',
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    categoryId: 'cat-1',
                  ),
                  data: AudioData(
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    duration: const Duration(minutes: 1),
                    audioDirectory: '/audio/',
                    audioFile: 'test.aac',
                  ),
                  entryText: const EntryText(
                    plainText: 'A serene mountain lake',
                    markdown: 'A serene mountain lake',
                  ),
                )
                as JournalAudio;

        when(
          () => mockAiInputRepo.getEntity('audio-image-prompt'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-img'),
        ).thenAnswer((_) async => '{"id": "task-img"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-img'),
        ).thenAnswer((_) async => '{"linked_from": [], "linked_to": []}');
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
            makeStreamChunk('## Prompt\nA serene mountain lake at dawn'),
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
          entryId: 'audio-image-prompt',
          automationResult: AutomationResult(
            handled: true,
            resolvedProfile: ResolvedProfile(
              thinkingModelId: 'models/gemini-flash',
              thinkingProvider: testInferenceProvider(id: 'p-flash'),
            ),
            skill: imagePromptSkill,
          ),
          linkedTaskId: 'task-img',
        );

        // Only AiResponseType.promptGeneration (coding) re-targets to the
        // task; image-prompt generation stays linked to the source entry.
        final captured = verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: captureAny(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).captured;
        expect(captured.single, 'audio-image-prompt');
      },
    );
  }

  void registerPromptGenerationSkillIdentity() {
    test('persists skillId on the AiResponseEntry data', () async {
      final textEntry = makeTextEntry(
        id: 'text-skill-id',
        markdown: 'Some prompt input',
      );

      when(
        () => mockAiInputRepo.getEntity('text-skill-id'),
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
        (_) => Stream.fromIterable([makeStreamChunk('out')]),
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
        entryId: 'text-skill-id',
        automationResult: makePromptGenerationResult(),
      );

      final captured = verify(
        () => mockAiInputRepo.createAiResponseEntry(
          data: captureAny(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).captured;
      final data = captured.single as AiResponseData;
      // The automation result uses `testPromptGenSkill` whose id is
      // 'skill-prompt-gen' — that exact ID must be persisted so the card
      // can render the right skill name.
      expect(data.skillId, 'skill-prompt-gen');
    });

    test(
      'persists imagePromptGeneration responses under the matching '
      'AiResponseType',
      () async {
        final imagePromptSkill =
            AiConfig.skill(
                  id: 'skill-img-prompt',
                  name: 'Generate Image Prompt',
                  skillType: SkillType.imagePromptGeneration,
                  requiredInputModalities: const [Modality.text],
                  contextPolicy: ContextPolicy.fullTask,
                  systemInstructions: 'sys',
                  userInstructions: 'usr',
                  useReasoning: true,
                  createdAt: DateTime(2024),
                )
                as AiConfigSkill;

        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-flash',
            thinkingProvider: testInferenceProvider(),
          ),
          skill: imagePromptSkill,
        );

        final textEntry = makeTextEntry(
          id: 'text-img-prompt',
          markdown: 'A serene watercolor of mist over pines',
        );

        when(
          () => mockAiInputRepo.getEntity('text-img-prompt'),
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
          (_) => Stream.fromIterable([
            makeStreamChunk('## Summary\n…\n## Prompt\nWatercolor scene'),
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
          entryId: 'text-img-prompt',
          automationResult: result,
        );

        final captured = verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: captureAny(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).captured;
        final data = captured.single as AiResponseData;
        expect(data.type, AiResponseType.imagePromptGeneration);
      },
    );
  }
}
