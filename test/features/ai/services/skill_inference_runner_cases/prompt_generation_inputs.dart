part of '../skill_inference_runner_test.dart';

extension _PromptGenerationInputCases on _SkillInferenceTestSetup {
  void registerPromptGenerationGuards() {
    test('throws StateError when skill is null', () async {
      final result = AutomationResult(
        handled: true,
        resolvedProfile: ResolvedProfile(
          thinkingModelId: 'models/gemini-flash',
          thinkingProvider: testInferenceProvider(),
        ),
      );

      expect(
        () => runner.runPromptGeneration(
          entryId: 'entry-1',
          automationResult: result,
        ),
        throwsStateError,
      );
    });

    test('throws StateError when profile is null', () async {
      final result = AutomationResult(
        handled: true,
        skill: testPromptGenSkill,
      );

      expect(
        () => runner.runPromptGeneration(
          entryId: 'entry-1',
          automationResult: result,
        ),
        throwsStateError,
      );
    });

    test(
      'rejects non-text-bearing entities (Task) and never calls inference',
      () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenAnswer((_) async => makeTaskEntity('entry-1'));
        stubLoggingException();

        await runner.runPromptGeneration(
          entryId: 'entry-1',
          automationResult: makePromptGenerationResult(),
        );

        verifyZeroInteractions(mockCloudRepo);
        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runPromptGeneration',
          ),
        ).called(1);
      },
    );

    test('logs error when getEntity returns null', () async {
      when(
        () => mockAiInputRepo.getEntity('missing-1'),
      ).thenAnswer((_) async => null);
      stubLoggingException();

      await runner.runPromptGeneration(
        entryId: 'missing-1',
        automationResult: makePromptGenerationResult(),
      );

      verifyZeroInteractions(mockCloudRepo);
      verify(
        () => mockLoggingService.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'runPromptGeneration',
        ),
      ).called(1);
    });

    test(
      'succeeds on a JournalEntry source and threads markdown into prompt',
      () async {
        final textEntry = makeTextEntry(
          id: 'text-prompt',
          markdown: '# Heading\n\nFix the **login** flow.',
          plainText: 'Heading\n\nFix the login flow.',
          categoryId: 'cat-text',
        );

        when(
          () => mockAiInputRepo.getEntity('text-prompt'),
        ).thenAnswer((_) async => textEntry);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-text'),
        ).thenAnswer(
          (_) async =>
              '{"id":"task-text","logEntries":[{"entryType":"image",'
              '"aiResponses":[{"text":"Linked visual analysis"}]}]}',
        );
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-text'),
        ).thenAnswer((_) async => '{"linked": []}');
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
            makeStreamChunk('## Summary\nLogin\n\n## Prompt\nDo the work'),
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
          entryId: 'text-prompt',
          automationResult: makePromptGenerationResult(),
          linkedTaskId: 'task-text',
        );

        // Builder should have used markdown (preferred over plainText) and
        // injected it under the **Entry Notes:** header.
        final captured = verify(
          () => mockCloudRepo.generate(
            captureAny(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).captured;
        final userMessage = captured.first as String;
        expect(userMessage, contains('**Entry Notes:**'));
        expect(userMessage, contains('Fix the **login** flow.'));
        expect(userMessage, contains('Linked visual analysis'));

        final responseCaptured = verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: captureAny(named: 'data'),
            start: any(named: 'start'),
            linkedId: captureAny(named: 'linkedId'),
            categoryId: captureAny(named: 'categoryId'),
          ),
        ).captured;
        // Coding prompt links to the parent task, not the source text entry.
        expect(responseCaptured[1], 'task-text');
        expect(responseCaptured[2], 'cat-text');
      },
    );
  }

  void registerPromptGenerationNoteInputs() {
    test(
      'falls back to plainText when JournalEntry has no markdown',
      () async {
        final textEntry = makeTextEntry(
          id: 'text-plain',
          plainText: 'Plain only body',
        );

        when(
          () => mockAiInputRepo.getEntity('text-plain'),
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
          entryId: 'text-plain',
          automationResult: makePromptGenerationResult(),
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
            impactCollector: any(named: 'impactCollector'),
          ),
        ).captured;
        final userMessage = captured.first as String;
        expect(userMessage, contains('Plain only body'));
      },
    );

    test(
      'injects [Empty note] placeholder when JournalEntry has no text',
      () async {
        final textEntry = makeTextEntry(id: 'text-empty');

        when(
          () => mockAiInputRepo.getEntity('text-empty'),
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
          entryId: 'text-empty',
          automationResult: makePromptGenerationResult(),
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
            impactCollector: any(named: 'impactCollector'),
          ),
        ).captured;
        final userMessage = captured.first as String;
        expect(userMessage, contains('[Empty note]'));
      },
    );
  }

  void registerPromptGenerationTranscriptInputs() {
    test(
      'extracts transcript from latest transcript when no entryText',
      () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-transcript',
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                  ),
                  data: AudioData(
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    duration: const Duration(minutes: 1),
                    audioDirectory: '/audio/',
                    audioFile: 'test.aac',
                    transcripts: [
                      AudioTranscript(
                        created: DateTime(2024),
                        library: 'whisper',
                        model: 'whisper-1',
                        detectedLanguage: 'en',
                        transcript: 'Old transcript',
                        processingTime: const Duration(seconds: 5),
                      ),
                      AudioTranscript(
                        created: DateTime(2024, 6),
                        library: 'whisper',
                        model: 'whisper-2',
                        detectedLanguage: 'en',
                        transcript: 'Latest transcript',
                        processingTime: const Duration(seconds: 3),
                      ),
                    ],
                  ),
                )
                as JournalAudio;

        when(
          () => mockAiInputRepo.getEntity('audio-transcript'),
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
          (_) => Stream.fromIterable([makeStreamChunk('Generated prompt')]),
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
          entryId: 'audio-transcript',
          automationResult: makePromptGenerationResult(),
        );

        // Verify the user message contains the latest transcript.
        final generateCall = verify(
          () => mockCloudRepo.generate(
            captureAny(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).captured;
        final userMessage = generateCall.first as String;
        expect(userMessage, contains('Latest transcript'));
      },
    );

    test('returns early on empty response', () async {
      final audioEntity =
          JournalEntity.journalAudio(
                meta: Metadata(
                  id: 'audio-empty',
                  createdAt: DateTime(2024),
                  updatedAt: DateTime(2024),
                  dateFrom: DateTime(2024),
                  dateTo: DateTime(2024),
                ),
                data: AudioData(
                  dateFrom: DateTime(2024),
                  dateTo: DateTime(2024),
                  duration: const Duration(minutes: 1),
                  audioDirectory: '/audio/',
                  audioFile: 'test.aac',
                ),
                entryText: const EntryText(
                  plainText: 'Some text',
                  markdown: 'Some text',
                ),
              )
              as JournalAudio;

      when(
        () => mockAiInputRepo.getEntity('audio-empty'),
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
      ).thenAnswer((_) => Stream.fromIterable([]));
      stubLoggingException();

      await runner.runPromptGeneration(
        entryId: 'audio-empty',
        automationResult: makePromptGenerationResult(),
      );

      verifyNever(
        () => mockAiInputRepo.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      );
    });
  }

  void registerPromptGenerationFailure() {
    test('logs exception on failure', () async {
      when(
        () => mockAiInputRepo.getEntity('entry-1'),
      ).thenThrow(Exception('DB error'));
      stubLoggingException();

      await runner.runPromptGeneration(
        entryId: 'entry-1',
        automationResult: makePromptGenerationResult(),
      );

      verify(
        () => mockLoggingService.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'runPromptGeneration',
        ),
      ).called(1);
    });
  }
}
