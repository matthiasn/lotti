part of '../skill_inference_runner_test.dart';

/// Saving the transcript back onto the recording, and one run per recording
/// at a time — the fixes `specs/tla/TranscriptionRun.tla` pins with its
/// `CheckWrite`, `RetryConflict`, `KeepConcurrentEdit` and `SingleFlight`
/// switches.
extension _TranscriptionSaveCases on _SkillInferenceTestSetup {
  void registerTranscriptionSave() {
    group('saving the transcript', () {
      const transcriptText = 'Penguins queue at the dock';

      InferenceStatus statusOf(String id) => container.read(
        inferenceStatusControllerProvider((
          id: id,
          aiResponseType: AiResponseType.audioTranscription,
        )),
      );

      void stubInference(
        Stream<CreateChatCompletionStreamResponse> Function() stream,
      ) {
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
        ).thenAnswer((_) => stream());
      }

      void Function() inferenceCall() =>
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          );

      /// The first read returns [first]; every later read (the re-read before
      /// each write attempt) returns what [reread] gives for that attempt.
      Future<void> stubRun({
        required JournalAudio first,
        required bool Function(int attempt) writeLands,
        JournalAudio Function(int attempt)? reread,
      }) async {
        await createStubAudioFile();
        var reads = 0;
        when(() => mockAiInputRepo.getEntity(first.meta.id)).thenAnswer((
          _,
        ) async {
          reads++;
          return reads == 1 ? first : (reread?.call(reads - 1) ?? first);
        });
        var writes = 0;
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => writeLands(++writes));
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        stubInference(
          () => Stream.fromIterable([makeStreamChunk(transcriptText)]),
        );
        stubLoggingEvent();
        stubLoggingException();
      }

      List<JournalAudio> writes() => verify(
        () => mockJournalRepo.updateJournalEntity(captureAny()),
      ).captured.cast<JournalAudio>();

      test(
        'a write the database never takes fails the run instead of '
        'reporting a transcript nobody can find',
        () async {
          final attribution = _registerInteractionCapture();
          await stubRun(first: makeAudioEntity(), writeLands: (_) => false);
          final errors = <Object>[];

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
            onError: errors.add,
          );

          expect(writes(), hasLength(3));
          expect(
            errors.single,
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('was not saved after 3 attempts'),
            ),
          );
          expect(statusOf('audio-1'), InferenceStatus.error);
          // No succeeded record for work whose output does not exist.
          verifyNever(() => attribution.service.finalize(any()));
        },
      );

      test(
        'a write refused because a synced edit landed is re-read and '
        'retried, carrying the edit',
        () async {
          final attribution = _registerInteractionCapture();
          final audio = makeAudioEntity();
          // The peer starred the recording while the model was listening.
          final starredByPeer = audio.copyWith(
            meta: audio.meta.copyWith(starred: true),
          );
          await stubRun(
            first: audio,
            reread: (attempt) => attempt == 1 ? audio : starredByPeer,
            writeLands: (attempt) => attempt == 2,
          );
          final errors = <Object>[];

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
            onError: errors.add,
          );

          final attempts = writes();
          expect(attempts, hasLength(2));
          expect(attempts.last.meta.starred, isTrue);
          expect(attempts.last.entryText?.plainText, transcriptText);
          expect(
            attempts.last.data.transcripts?.map((t) => t.transcript),
            [transcriptText],
          );
          expect(errors, isEmpty);
          expect(statusOf('audio-1'), InferenceStatus.idle);
          final record =
              verify(
                    () => attribution.service.finalize(captureAny()),
                  ).captured.single
                  as AiWorkAttribution;
          expect(record.status, AiWorkStatus.succeeded);
        },
      );

      test(
        'text edited while the model was listening is kept, and the '
        'transcript joins the history',
        () async {
          final audio = makeAudioEntity();
          final edited = makeAudioEntity(
            plainText: 'Typed while it was listening',
          );
          await stubRun(
            first: audio,
            reread: (_) => edited,
            writeLands: (_) => true,
          );

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
          );

          final written = writes().single;
          expect(written.entryText?.plainText, 'Typed while it was listening');
          expect(
            written.data.transcripts?.map((t) => t.transcript),
            [transcriptText],
          );
        },
      );

      test(
        're-transcribing replaces text that was there before the run',
        () async {
          final audio = makeAudioEntity(plainText: 'Earlier words');
          await stubRun(first: audio, writeLands: (_) => true);

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
          );

          expect(writes().single.entryText?.plainText, transcriptText);
        },
      );

      test(
        'a second request while one is in flight joins it: one inference, '
        'one transcript, and both callers see the outcome',
        () async {
          await stubRun(first: makeAudioEntity(), writeLands: (_) => true);
          final inference =
              StreamController<CreateChatCompletionStreamResponse>();
          addTearDown(inference.close);
          stubInference(() => inference.stream);
          final errors = <Object>[];
          var joinedDone = false;

          final first = runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
            onError: errors.add,
          );
          await pumpEventQueue();
          final joined = runner
              .runTranscription(
                audioEntryId: 'audio-1',
                automationResult: makeTranscriptionResult(),
                onError: errors.add,
              )
              .whenComplete(() => joinedDone = true);
          await pumpEventQueue();

          verify(inferenceCall()).called(1);
          expect(joinedDone, isFalse);

          inference.add(makeStreamChunk(transcriptText));
          await inference.close();
          await Future.wait([first, joined]);

          verifyNever(inferenceCall());
          expect(writes(), hasLength(1));
          expect(errors, isEmpty);
          expect(statusOf('audio-1'), InferenceStatus.idle);
        },
      );

      test(
        'a joined request receives the run failure through onError',
        () async {
          await stubRun(first: makeAudioEntity(), writeLands: (_) => true);
          final inference =
              StreamController<CreateChatCompletionStreamResponse>();
          addTearDown(inference.close);
          stubInference(() => inference.stream);
          final firstErrors = <Object>[];
          final joinedErrors = <Object>[];

          final first = runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
            onError: firstErrors.add,
          );
          await pumpEventQueue();
          final joined = runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
            onError: joinedErrors.add,
          );
          await pumpEventQueue();
          final failure = TranscriptionException('Upstream unavailable');
          inference.addError(failure);
          await Future.wait([first, joined]);

          expect(firstErrors.single, same(failure));
          expect(joinedErrors.single, same(failure));
          verify(inferenceCall()).called(1);
        },
      );

      test('a request after the run finished transcribes again', () async {
        await stubRun(first: makeAudioEntity(), writeLands: (_) => true);

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: makeTranscriptionResult(),
        );
        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: makeTranscriptionResult(),
        );

        verify(inferenceCall()).called(2);
      });
    });
  }
}
