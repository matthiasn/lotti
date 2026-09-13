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
  }
}
