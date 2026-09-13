part of '../skill_inference_runner_test.dart';

extension _ImageAnalysisPersistenceCases on _SkillInferenceTestSetup {
  void registerImageAnalysisPersistence() {
    test('happy path: analyzes image and saves result', () async {
      final imageEntity = makeImageEntity();

      // Create the image file on disk.
      final imageDir = Directory('${tempDir.path}/images');
      await imageDir.create(recursive: true);
      final imageFile = File('${imageDir.path}/test.jpg');
      await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenAnswer((_) async => imageEntity);
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);

      // Cloud inference returns streaming response.
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
        (_) => Stream.fromIterable([
          makeStreamChunk('A photo of '),
          makeStreamChunk('a sunset'),
        ]),
      );

      when(
        () => mockJournalRepo.updateJournalEntity(any()),
      ).thenAnswer((_) async => true);
      stubLoggingEvent();

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
      );

      // Verify cloud inference was called with image data.
      verify(
        () => mockCloudRepo.generateWithImages(
          any(),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          model: 'vision-model',
          temperature: null,
          images: [
            base64Encode([0xFF, 0xD8, 0xFF, 0xE0]),
          ],
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).called(1);

      // Verify journal entity was updated.
      final captured = verify(
        () => mockJournalRepo.updateJournalEntity(captureAny()),
      ).captured;
      expect(captured, hasLength(1));

      final updatedEntity = captured.first as JournalImage;
      expect(
        updatedEntity.entryText?.plainText,
        'A photo of a sunset',
      );
    });

    test(
      'analyzes the migrated real-world screenshot instead of reporting no image data',
      () async {
        const entryId = 'dfb5db6b-215c-5d1f-b05a-53830b125fad';
        var imageEntity = makeImageEntity(
          id: entryId,
          imageDirectory: 'images/2026-08-15/',
          imageFile: '$entryId.screenshot.jpg',
        );
        final corrected = imageEntity.copyWith(
          data: imageEntity.data.copyWith(
            imageDirectory: '/images/2026-08-15/',
          ),
        );
        final migrationDb = MockJournalDb();
        final migrationPersistence = MockPersistenceLogic();
        when(
          () => migrationDb.getJournalEntities(
            types: const ['JournalImage'],
            starredStatuses: const [true, false],
            privateStatuses: const [true, false],
            flaggedStatuses: [
              for (final flag in EntryFlag.values) flag.index,
            ],
            ids: null,
            limit: 200,
            // ignore: avoid_redundant_argument_values
            offset: 0,
          ),
        ).thenAnswer((_) async => [imageEntity]);
        when(
          () => migrationPersistence.updateJournalEntity(
            corrected,
            imageEntity.meta,
          ),
        ).thenAnswer((_) async {
          imageEntity = corrected;
          return true;
        });
        final legacyFile = File(
          getLegacyMalformedImagePath(
            imageEntity,
            documentsDirectory: tempDir.path,
          ),
        );
        await legacyFile.parent.create(recursive: true);
        await legacyFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
        final migration = ImagePathMigrationService(
          documentsDirectory: tempDir,
          journalDb: migrationDb,
          persistenceLogic: migrationPersistence,
          logger: mockLoggingService,
        );

        final report = await migration.migrateAll();

        expect(report.affected, 1);
        when(
          () => mockAiInputRepo.getEntity(entryId),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
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
          (_) => Stream.value(makeStreamChunk('Recovered screenshot')),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageAnalysis(
          imageEntryId: entryId,
          automationResult: makeImageAnalysisResult(),
        );

        verify(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: 'vision-model',
            temperature: null,
            images: [
              base64Encode([0xFF, 0xD8, 0xFF, 0xE0]),
            ],
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).called(1);
      },
    );

    test('persists attributed image analysis as an AI response', () async {
      final attribution = _registerInteractionCapture();
      final imageEntity = makeImageEntity();
      await createStubImageFile();
      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenAnswer((_) async => imageEntity);
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);
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
        (_) => Stream.value(makeStreamChunk('Attributed sunset analysis')),
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

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
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
      expect(data.response, 'Attributed sunset analysis');
      expect(data.skillId, testImageSkill.id);
      expect(data.type, AiResponseType.imageAnalysis);
      expect(data.aiAttribution, isNotNull);
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      expect(_capturedEvents(attribution), hasLength(1));
      verify(() => attribution.service.finalize(any())).called(1);
    });

    test(
      'marks every parent task dirty with the standard child-changed '
      'pairs once the attributed analysis is stored, skipping non-task '
      'parents',
      () async {
        _registerInteractionCapture();
        final imageEntity = makeImageEntity();
        await createStubImageFile();
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-1'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'img-1'),
        ).thenAnswer(
          (_) async => [
            TestTaskFactory.create(id: 'task-1'),
            TestTaskFactory.create(id: 'task-2'),
            // A non-task parent (e.g. a plain journal entry linking the
            // image) must NOT receive a synthetic stale notification.
            JournalEntity.journalEntry(
              meta: TestMetadataFactory.create(id: 'non-task-parent'),
            ),
          ],
        );
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
          (_) => Stream.value(makeStreamChunk('Datum: 05.10.26')),
        );
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
          automationResult: makeImageAnalysisResult(),
          linkedTaskId: 'task-1',
        );

        // The same token pairs updateDbEntity emits when the image itself
        // is edited — for BOTH parent tasks, not just the resolved
        // linkedTaskId: each parent's subscription picks it up on the
        // normal throttled wake — deliberately NOT an immediate
        // throttle-bypassing content wake.
        final notifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => notifications.notify({
            'task-1',
            propagatedNotification('task-1'),
            'task-2',
            propagatedNotification('task-2'),
          }),
        ).called(1);
      },
    );

    test(
      'falls back to the resolved task pair when the parent lookup fails',
      () async {
        _registerInteractionCapture();
        final imageEntity = makeImageEntity();
        await createStubImageFile();
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-1'),
        ).thenAnswer((_) async => '{}');
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'img-1'),
        ).thenThrow(Exception('db unavailable'));
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
          (_) => Stream.value(makeStreamChunk('Datum: 05.10.26')),
        );
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
          automationResult: makeImageAnalysisResult(),
          linkedTaskId: 'task-1',
        );

        // The analysis is already persisted, so a failed parent lookup
        // degrades to notifying just the resolved task, never to aborting.
        final notifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => notifications.notify({
            'task-1',
            propagatedNotification('task-1'),
          }),
        ).called(1);
      },
    );

    test(
      'emits no task notification when the analyzed image has no linked '
      'task',
      () async {
        _registerInteractionCapture();
        final imageEntity = makeImageEntity();
        await createStubImageFile();
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'img-1'),
        ).thenAnswer((_) async => <JournalEntity>[]);
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
          (_) => Stream.value(makeStreamChunk('A standalone photo')),
        );
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
          automationResult: makeImageAnalysisResult(),
        );

        final notifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verifyNever(() => notifications.notify(any()));
      },
    );

    test('appends analysis to existing entryText', () async {
      final imageEntity =
          JournalEntity.journalImage(
                meta: Metadata(
                  id: 'img-1',
                  createdAt: DateTime(2024),
                  updatedAt: DateTime(2024),
                  dateFrom: DateTime(2024),
                  dateTo: DateTime(2024),
                ),
                data: ImageData(
                  imageId: 'img-1',
                  imageFile: 'test.jpg',
                  imageDirectory: '/images/',
                  capturedAt: DateTime(2024),
                ),
                entryText: const EntryText(
                  plainText: 'Previous text',
                  markdown: 'Previous text',
                ),
              )
              as JournalImage;

      await createStubImageFile();

      when(
        () => mockAiInputRepo.getEntity('img-1'),
      ).thenAnswer((_) async => imageEntity);
      when(
        () => mockTaskSummaryResolver.resolve(any()),
      ).thenAnswer((_) async => null);
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
        (_) => Stream.fromIterable([makeStreamChunk('New analysis')]),
      );
      when(
        () => mockJournalRepo.updateJournalEntity(any()),
      ).thenAnswer((_) async => true);
      stubLoggingEvent();

      await runner.runImageAnalysis(
        imageEntryId: 'img-1',
        automationResult: makeImageAnalysisResult(),
      );

      final captured = verify(
        () => mockJournalRepo.updateJournalEntity(captureAny()),
      ).captured;
      final updated = captured.first as JournalImage;
      expect(
        updated.entryText?.markdown,
        'Previous text\n\nNew analysis',
      );
    });
  }
}
