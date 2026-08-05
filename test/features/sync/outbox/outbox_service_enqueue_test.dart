// ignore_for_file: avoid_redundant_argument_values, unnecessary_lambdas

import 'outbox_service_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(configureOutboxServiceTestSuite);

  final harness = OutboxServiceTestHarness();

  late MockSyncDatabase syncDatabase;
  late MockDomainLogger loggingService;
  late MockOutboxRepository repository;
  late MockOutboxMessageSender messageSender;
  late MockOutboxProcessor processor;
  late MockJournalDb journalDb;
  late MockUserActivityService userActivityService;
  late Directory documentsDirectory;
  late TestableOutboxService service;

  TestableOutboxService buildService({
    UserActivityGate? activityGate,
    bool? ownsActivityGate,
    SyncSequenceLogService? sequenceLogService,
    Future<void> Function(String path, String json)? saveJsonHandler,
    Duration postDrainSettle = Duration.zero,
  }) {
    return harness.buildService(
      activityGate: activityGate,
      ownsActivityGate: ownsActivityGate,
      sequenceLogService: sequenceLogService,
      saveJsonHandler: saveJsonHandler,
      postDrainSettle: postDrainSettle,
    );
  }

  setUp(() async {
    await harness.setUp();
    syncDatabase = harness.syncDatabase;
    loggingService = harness.loggingService;
    repository = harness.repository;
    messageSender = harness.messageSender;
    processor = harness.processor;
    journalDb = harness.journalDb;
    userActivityService = harness.userActivityService;
    documentsDirectory = harness.documentsDirectory;
    service = harness.service;
  });

  tearDown(() async {
    await harness.tearDown();
  });

  test('enqueueMessage logs SyncEntityDefinition', () async {
    final def = SyncMessage.entityDefinition(
      entityDefinition: EntityDefinition.measurableDataType(
        id: 'def-1',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        displayName: 'Water',
        description: 'H2O',
        unitName: 'ml',
        version: 1,
        vectorClock: null,
      ),
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(def);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(that: contains('type=SyncEntityDefinition')),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
  });

  test('enqueueMessage logs SyncEntryLink with from/to', () async {
    final link = SyncMessage.entryLink(
      entryLink: EntryLink.basic(
        id: 'l1',
        fromId: 'A',
        toId: 'B',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        updatedAt: DateTime(2024, 3, 15, 10, 30),
        vectorClock: null,
      ),
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(link);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(
          that: allOf([
            contains('type=SyncEntryLink'),
            contains('from=A'),
            contains('to=B'),
          ]),
        ),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
  });

  test('enqueueMessage refreshes JSON before reading descriptor', () async {
    const id = 'checklist-refresh';
    final staleMeta = Metadata(
      id: id,
      createdAt: DateTime(2025, 10, 22, 23, 18, 48, 935417),
      updatedAt: DateTime(2025, 10, 22, 23, 18, 49, 201352),
      dateFrom: DateTime(2025, 10, 22, 23, 18, 48, 935417),
      dateTo: DateTime(2025, 10, 22, 23, 18, 48, 935417),
      categoryId: 'category-1',
      utcOffset: 60,
      timezone: 'WEST',
      vectorClock: const VectorClock({'hostA': 402}),
    );
    final staleChecklist = JournalEntity.checklist(
      meta: staleMeta,
      data: const ChecklistData(
        title: 'Todos',
        linkedChecklistItems: <String>[],
        linkedTasks: <String>['task-1'],
      ),
    );
    final freshChecklist = staleChecklist.copyWith(
      meta: staleChecklist.meta.copyWith(
        vectorClock: const VectorClock({'hostA': 425}),
      ),
    );
    final jsonPath = relativeEntityPath(staleChecklist);
    final file = File('${documentsDirectory.path}$jsonPath')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(staleChecklist));

    when(
      () => journalDb.journalEntityById(id),
    ).thenAnswer((_) async => freshChecklist);

    final message = SyncMessage.journalEntity(
      id: id,
      vectorClock: freshChecklist.meta.vectorClock,
      jsonPath: jsonPath,
      status: SyncEntryStatus.update,
    );

    await service.enqueueMessage(message);

    final stored =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(
      // ignore: avoid_dynamic_calls
      stored['meta']['vectorClock'],
      equals({'hostA': 425}),
    );
  });

  test(
    'enqueueMessage logs missing entity when DB lookup returns null',
    () async {
      const id = 'missing-entity';
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final entity = JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          vectorClock: const VectorClock({'host': 1}),
        ),
        entryText: const EntryText(plainText: 'draft'),
      );
      final jsonPath = relativeEntityPath(entity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(entity.toJson()));

      when(() => journalDb.journalEntityById(id)).thenAnswer((_) async => null);

      final message = SyncMessage.journalEntity(
        id: id,
        jsonPath: jsonPath,
        vectorClock: entity.meta.vectorClock,
        status: SyncEntryStatus.initial,
      );

      await service.enqueueMessage(message);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('enqueueMessage.missingEntity id=$id')),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
      verify(() => syncDatabase.addOutboxItem(any())).called(1);
    },
  );

  test('continues when saveJson throws during refresh', () async {
    const id = 'save-fails';
    final testDate = DateTime(2024, 3, 15, 10, 30);
    final entity = JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        vectorClock: const VectorClock({'host': 1}),
      ),
      entryText: const EntryText(plainText: 'draft'),
    );
    final jsonPath = relativeEntityPath(entity);
    File('${documentsDirectory.path}$jsonPath')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(entity.toJson()));

    when(() => journalDb.journalEntityById(id)).thenAnswer((_) async => entity);

    final failingGate = MockUserActivityGate();
    when(failingGate.waitUntilIdle).thenAnswer((_) async {});
    when(failingGate.dispose).thenAnswer((_) async {});

    final failingService = buildService(
      activityGate: failingGate,
      ownsActivityGate: false,
      saveJsonHandler: (_, _) => Future.error(Exception('disk full')),
    );

    final message = SyncMessage.journalEntity(
      id: id,
      jsonPath: jsonPath,
      vectorClock: entity.meta.vectorClock,
      status: SyncEntryStatus.initial,
    );

    await failingService.enqueueMessage(message);

    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'enqueueMessage.refreshJson',
      ),
    ).called(1);
    verify(() => syncDatabase.addOutboxItem(any())).called(1);
  });

  test('non-journal messages skip JSON refresh lookup', () async {
    clearInteractions(journalDb);

    await service.enqueueMessage(const SyncMessage.aiConfigDelete(id: 'cfg'));

    verifyNever(() => journalDb.journalEntityById(any()));
  });

  test('enqueueMessageOrThrow propagates an outbox write failure', () async {
    when(
      () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
    ).thenThrow(Exception('database write failed'));

    await expectLater(
      service.enqueueMessageOrThrow(
        const SyncMessage.aiConfigDelete(id: 'failing-config'),
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('database write failed'),
        ),
      ),
    );
    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
  });

  test(
    'enqueueNotification saves JSON payload and queues notification',
    () async {
      final notification = _testNotification(
        id: 'notification-id',
        vectorClock: const VectorClock({'hostA': 3}),
      );

      await service.enqueueNotification(
        notification,
        originatingHostId: 'origin-host',
      );

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured, hasLength(1));

      final companion = captured.single as OutboxCompanion;
      expect(companion.subject.value, 'notification:notification-id');
      expect(companion.filePath.value, '/notifications/notification-id.json');
      expect(companion.outboxEntryId.value, 'notification-id');
      expect(companion.priority.value, OutboxPriority.normal.index);

      final queued = SyncMessage.fromJson(
        jsonDecode(companion.message.value) as Map<String, dynamic>,
      );
      expect(queued, isA<SyncNotification>());
      final syncNotification = queued as SyncNotification;
      expect(syncNotification.id, 'notification-id');
      expect(syncNotification.jsonPath, '/notifications/notification-id.json');
      expect(syncNotification.originatingHostId, 'origin-host');
      expect(syncNotification.coveredVectorClocks, [
        const VectorClock({'hostA': 3}),
      ]);

      final payloadFile = File(
        '${documentsDirectory.path}/notifications/notification-id.json',
      );
      expect(payloadFile.existsSync(), isTrue);
      final payload = NotificationEntity.fromJson(
        jsonDecode(payloadFile.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(payload, notification);
    },
  );

  test(
    'enqueueMessage swallows sequence log throws on notification path',
    () async {
      final sequenceLog = MockSyncSequenceLogService();
      when(
        () => sequenceLog.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenThrow(Exception('record sent boom'));

      final notification = _testNotification(
        id: 'throwing-record',
        vectorClock: const VectorClock({'hostA': 4}),
      );
      final relPath = relativeNotificationPath(notification.id);
      File('${documentsDirectory.path}$relPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(notification.toJson()));

      final svc = buildService(sequenceLogService: sequenceLog);

      await svc.enqueueMessage(
        SyncMessage.notification(
          id: notification.id,
          jsonPath: relPath,
          vectorClock: notification.meta.vectorClock,
          originatingHostId: 'hostA',
        ),
      );

      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'recordSent',
        ),
      ).called(1);
    },
  );

  test(
    'enqueueMessage skips and logs when notification jsonPath escapes docs root',
    () async {
      await service.enqueueMessage(
        const SyncMessage.notification(
          id: 'escape',
          jsonPath: '/../escape.json',
          vectorClock: VectorClock({'hostA': 1}),
          originatingHostId: 'hostA',
        ),
      );

      verifyNever(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()));
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: contains('enqueue.skip invalid notification payload path'),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    },
  );

  test('enqueueMessage accepts a notification jsonPath that normalizes to the '
      'docs root itself (docsRoot == fullPath boundary)', () async {
    // '/' splits to no path parts, so the joined full path IS the docs
    // root: the path guard's `docsRoot != fullPath` branch is false and
    // the payload is accepted (length read fails on a directory and is
    // treated as 0 attach bytes).
    await service.enqueueMessage(
      const SyncMessage.notification(
        id: 'root-path',
        jsonPath: '/',
        vectorClock: VectorClock({'hostA': 1}),
        originatingHostId: 'hostA',
      ),
    );

    final captured = verify(
      () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
    ).captured;
    expect(captured, hasLength(1));
    final companion = captured.single as OutboxCompanion;
    expect(companion.subject.value, 'notification:root-path');

    verifyNever(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(
          that: contains('enqueue.skip invalid notification payload path'),
        ),
        subDomain: 'enqueueMessage',
      ),
    );
  });

  test('enqueueNotificationStateUpdate queues inline state update', () async {
    final seenAt = DateTime.utc(2026, 5, 17, 11);

    await service.enqueueNotificationStateUpdate(
      id: 'notification-id',
      seenAt: seenAt,
      vectorClock: const VectorClock({'hostA': 4}),
      originatingHostId: 'hostA',
    );

    final captured = verify(
      () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
    ).captured;
    expect(captured, hasLength(1));

    final companion = captured.single as OutboxCompanion;
    expect(companion.subject.value, 'notificationStateUpdate:notification-id');
    expect(companion.filePath.value, isNull);
    expect(companion.priority.value, OutboxPriority.normal.index);

    final queued = SyncMessage.fromJson(
      jsonDecode(companion.message.value) as Map<String, dynamic>,
    );
    expect(queued, isA<SyncNotificationStateUpdate>());
    final stateUpdate = queued as SyncNotificationStateUpdate;
    expect(stateUpdate.id, 'notification-id');
    expect(stateUpdate.seenAt, seenAt);
    expect(stateUpdate.vectorClock, const VectorClock({'hostA': 4}));
    expect(stateUpdate.originatingHostId, 'hostA');
  });

  test(
    'enqueueMessage routes SyncConsumptionEvent to a low-priority inline row '
    'stamped with this host and its covered clock',
    () async {
      final message = SyncMessage.consumptionEvent(
        event: makeConsumptionEvent(
          vectorClock: const VectorClock({'hostA': 6}),
        ),
        status: SyncEntryStatus.initial,
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured, hasLength(1));
      final companion = captured.single as OutboxCompanion;
      expect(companion.subject.value, 'consumptionEvent:evt-1');
      expect(companion.outboxEntryId.value, 'evt-1');
      // Consumption metrics are best-effort diagnostics — they must never
      // queue-jump user writes.
      expect(companion.priority.value, OutboxPriority.low.index);

      final queued = SyncMessage.fromJson(
        jsonDecode(companion.message.value) as Map<String, dynamic>,
      );
      expect(queued, isA<SyncConsumptionEvent>());
      final consumption = queued as SyncConsumptionEvent;
      expect(consumption.event.id, 'evt-1');
      // prepareMessage stamped this device as the originator and folded the
      // event's own clock into the covered set.
      expect(consumption.originatingHostId, 'hostA');
      expect(consumption.coveredVectorClocks!.single.vclock, {'hostA': 6});
    },
  );

  test('enqueueMessage logs SyncAiConfig', () async {
    final cfg = SyncMessage.aiConfig(
      aiConfig: AiConfig.inferenceProvider(
        id: 'cfg1',
        baseUrl: 'https://example.org',
        apiKey: 'k',
        name: 'p',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.openAi,
      ),
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(cfg);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(that: contains('type=SyncAiConfig')),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
  });

  test('enqueueMessage logs SyncAiConfigDelete', () async {
    const del = SyncMessage.aiConfigDelete(id: 'cfg1');

    await service.enqueueMessage(del);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(that: contains('type=SyncAiConfigDelete')),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
  });

  test('enqueueMessage logs SyncSavedTaskFilter', () async {
    const msg = SyncMessage.savedTaskFilter(
      filter: SavedTaskFilter(
        id: 'stf1',
        name: 'In Progress',
        filter: TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
      ),
      status: SyncEntryStatus.initial,
    );

    await service.enqueueMessage(msg);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(
          that: contains('type=SyncSavedTaskFilter subject=savedTaskFilter'),
        ),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
  });

  test('enqueueMessage logs SyncSavedTaskFilterDelete', () async {
    const del = SyncMessage.savedTaskFilterDelete(id: 'stf1');

    await service.enqueueMessage(del);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(that: contains('type=SyncSavedTaskFilterDelete')),
        subDomain: 'enqueueMessage',
      ),
    ).called(1);
  });

  group('enqueueMessage', () {
    test(
      'stores relative attachment path for initial journal entry and schedules',
      () async {
        final capturedCompanions = <OutboxCompanion>[];
        when(
          () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
        ).thenAnswer((invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
          return 1;
        });

        final testService = buildService();

        final sampleDate = DateTime.utc(2024);
        final metadata = Metadata(
          id: 'entry',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: const VectorClock({'hostA': 1}),
        );
        final imageData = ImageData(
          capturedAt: sampleDate,
          imageId: 'image-id',
          imageFile: 'image.jpg',
          imageDirectory: '/images/',
        );
        final journalEntity = JournalEntity.journalImage(
          meta: metadata,
          data: imageData,
          entryText: const EntryText(plainText: 'Test'),
        );

        const jsonPath = '/entries/test.json';
        File('${documentsDirectory.path}$jsonPath')
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

        final imagePath =
            '${documentsDirectory.path}${imageData.imageDirectory}${imageData.imageFile}';
        File(imagePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(List<int>.filled(10, 42));

        await testService.enqueueMessage(
          const SyncMessage.journalEntity(
            id: 'entry',
            jsonPath: jsonPath,
            vectorClock: VectorClock({'device': 1}),
            status: SyncEntryStatus.initial,
          ),
        );

        expect(capturedCompanions, hasLength(1));
        final companion = capturedCompanions.single;
        expect(companion.filePath.value, getRelativeAssetPath(imagePath));
        expect(companion.subject.value, 'hhash:1');
        expect(companion.status.value, OutboxStatus.pending.index);
        final decodedMessage = SyncMessage.fromJson(
          jsonDecode(companion.message.value) as Map<String, dynamic>,
        );
        final journalMsg = decodedMessage as SyncJournalEntity;
        expect(journalMsg.coveredVectorClocks, isNotNull);
        final coveredCounters = journalMsg.coveredVectorClocks!
            .map((vc) => vc.vclock['device'])
            .whereType<int>()
            .toSet();
        expect(coveredCounters, contains(1));

        // Ensure scheduling happens after enqueue
        expect(testService.enqueueCalls, 1);
        expect(testService.lastDelay, const Duration(seconds: 1));

        // Verify payloadSize includes file length (10 bytes) + JSON length
        expect(companion.payloadSize.value, isNotNull);
        expect(companion.payloadSize.value, greaterThan(10));
      },
    );

    /// Enqueues an image entry whose blob is 10 bytes on disk and returns the
    /// row the writer persisted. Shared by the attachment-policy tests below so
    /// each one differs only in the payload's attachment intent.
    Future<OutboxCompanion> enqueueImageEntry({
      required SyncEntryStatus status,
      bool? includeAttachments,
      String entryId = 'policy-entry',
    }) async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>())).thenAnswer(
        (invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
          return 1;
        },
      );

      final testService = buildService();
      final sampleDate = DateTime.utc(2024);
      final imageData = ImageData(
        capturedAt: sampleDate,
        imageId: 'img-$entryId',
        imageFile: '$entryId.jpg',
        imageDirectory: '/images/',
      );
      final journalEntity = JournalEntity.journalImage(
        meta: Metadata(
          id: entryId,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: const VectorClock({'hostA': 1}),
        ),
        data: imageData,
      );

      final jsonPath = '/entries/$entryId.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));
      File(
          '${documentsDirectory.path}${imageData.imageDirectory}'
          '${imageData.imageFile}',
        )
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(10, 42));

      await testService.enqueueMessage(
        SyncMessage.journalEntity(
          id: entryId,
          jsonPath: jsonPath,
          vectorClock: const VectorClock({'device': 1}),
          status: status,
          includeAttachments: includeAttachments,
        ),
      );

      expect(capturedCompanions, hasLength(1));
      return capturedCompanions.single;
    }

    // Regression: a re-sync or backfill re-send targets a device that holds
    // none of this history, so it must carry the blob even though the entry is
    // not new here. Before the attachment policy landed, `update` status left
    // `filePath` null — which also made the row bundle-eligible, and the
    // dequeue-time bundler ships JSON manifests only. Media never reached a
    // freshly provisioned device at all.
    test(
      'update payload opting into attachments stores the attachment path',
      () async {
        final companion = await enqueueImageEntry(
          status: SyncEntryStatus.update,
          includeAttachments: true,
          entryId: 'resync-entry',
        );

        expect(
          companion.filePath.value,
          endsWith('/images/resync-entry.jpg'),
          reason:
              'a null filePath here would let the bundler pack the row '
              'and silently drop the image',
        );
        // 10 blob bytes are billed to the row, not just the JSON.
        expect(companion.payloadSize.value, greaterThan(10));
      },
    );

    test('ordinary update sends JSON only, without the blob', () async {
      final companion = await enqueueImageEntry(
        status: SyncEntryStatus.update,
        entryId: 'edit-entry',
      );

      expect(
        companion.filePath.value,
        isNull,
        reason:
            'the peer already holds the immutable blob; re-uploading it on '
            'every caption edit would multiply sync traffic',
      );
    });

    test(
      'resend_attachments flag forces the blob onto an ordinary update',
      () async {
        when(
          () => journalDb.getConfigFlag(resendAttachments),
        ).thenAnswer((_) async => true);

        final companion = await enqueueImageEntry(
          status: SyncEntryStatus.update,
          entryId: 'flagged-entry',
        );

        expect(
          companion.filePath.value,
          endsWith('/images/flagged-entry.jpg'),
          reason:
              'the operator escape hatch must survive the bundler, which '
              'means taking effect at enqueue time, not only at send time',
        );
      },
    );

    // Regression: an ordinary edit landing on a pending re-sync row is
    // represented by ONE Matrix event afterwards. If the merge took its
    // attachment decision from the incoming edit alone, that surviving event
    // would carry no blob — and its row, left with a null filePath, would be
    // packed into a bundle, so nothing downstream could recover it either.
    test('a merge keeps the pending re-sync row media-bearing', () async {
      final sampleDate = DateTime.utc(2024);
      const entryId = 'merge-media';

      // Already pending: a re-sync re-send that opted into carrying media.
      const pendingResync = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: '/entries/$entryId.json',
        vectorClock: VectorClock({'hostA': 5}),
        status: SyncEntryStatus.update,
        includeAttachments: true,
      );
      when(() => syncDatabase.findPendingByEntryId(entryId)).thenAnswer(
        (_) async => OutboxItem(
          id: 1,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          status: OutboxStatus.pending.index,
          retries: 0,
          message: jsonEncode(pendingResync.toJson()),
          subject: 'hhash:5',
          filePath: null,
          outboxEntryId: entryId,
          priority: OutboxPriority.low.index,
        ),
      );

      String? capturedFilePath;
      String? capturedMessage;
      int? capturedPayloadSize;
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
          filePath: any(named: 'filePath'),
        ),
      ).thenAnswer((invocation) async {
        capturedFilePath = invocation.namedArguments[#filePath] as String?;
        capturedMessage = invocation.namedArguments[#newMessage] as String?;
        capturedPayloadSize = invocation.namedArguments[#payloadSize] as int?;
        return 1;
      });

      final imageData = ImageData(
        capturedAt: sampleDate,
        imageId: 'img-$entryId',
        imageFile: '$entryId.jpg',
        imageDirectory: '/images/',
      );
      final journalEntity = JournalEntity.journalImage(
        meta: Metadata(
          id: entryId,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: const VectorClock({'hostA': 7}),
        ),
        data: imageData,
      );
      File('${documentsDirectory.path}/entries/$entryId.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));
      File('${documentsDirectory.path}/images/$entryId.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(10, 42));

      final testService = buildService();

      // The incoming edit itself asks for nothing: plain update, no opt-in.
      await testService.enqueueMessage(
        const SyncMessage.journalEntity(
          id: entryId,
          jsonPath: '/entries/$entryId.json',
          vectorClock: VectorClock({'hostA': 7}),
          status: SyncEntryStatus.update,
        ),
      );

      expect(
        capturedFilePath,
        endsWith('/images/$entryId.jpg'),
        reason:
            'the surviving row must still carry the blob the re-sync '
            'asked for, and stay out of the bundler',
      );
      final merged =
          SyncMessage.fromJson(
                jsonDecode(capturedMessage!) as Map<String, dynamic>,
              )
              as SyncJournalEntity;
      expect(merged.includeAttachments, isTrue);
      // The blob's 10 bytes are billed to the merged row too.
      expect(capturedPayloadSize, greaterThan(10));
    });

    test('payloadSize includes file bytes for journal image', () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>())).thenAnswer(
        (invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
          return 1;
        },
      );

      final testService = buildService();

      final sampleDate = DateTime.utc(2024);
      final metadata = Metadata(
        id: 'payload-test',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: const VectorClock({'hostA': 1}),
      );
      final imageData = ImageData(
        capturedAt: sampleDate,
        imageId: 'img-payload',
        imageFile: 'payload-image.jpg',
        imageDirectory: '/images/',
      );
      final journalEntity = JournalEntity.journalImage(
        meta: metadata,
        data: imageData,
        entryText: const EntryText(plainText: 'Payload test'),
      );

      const jsonPath = '/entries/payload-test.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      const fileSize = 5000;
      final imagePath =
          '${documentsDirectory.path}${imageData.imageDirectory}${imageData.imageFile}';
      File(imagePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(fileSize, 42));

      // Build the message to compute expected JSON length
      const syncMessage = SyncMessage.journalEntity(
        id: 'payload-test',
        jsonPath: jsonPath,
        vectorClock: VectorClock({'device': 1}),
        status: SyncEntryStatus.initial,
      );

      await testService.enqueueMessage(syncMessage);

      expect(capturedCompanions, hasLength(1));
      final companion = capturedCompanions.single;

      // payloadSize = JSON message length + file size (5000)
      final payloadSize = companion.payloadSize.value!;
      expect(payloadSize, greaterThanOrEqualTo(fileSize));
      // The JSON portion should be > 0, so total should exceed file size
      expect(payloadSize, greaterThan(fileSize));
    });

    test('payloadSize is JSON length for entry link (no file)', () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>())).thenAnswer(
        (invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
          return 1;
        },
      );

      final testService = buildService();

      final now = DateTime.utc(2024);
      final link = EntryLink.basic(
        id: 'link-payload',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: now,
        updatedAt: now,
        vectorClock: const VectorClock({'hostA': 3}),
      );

      await testService.enqueueMessage(
        SyncMessage.entryLink(entryLink: link, status: SyncEntryStatus.initial),
      );

      expect(capturedCompanions, hasLength(1));
      final companion = capturedCompanions.single;

      // payloadSize should equal the UTF-8 byte length of the JSON message
      final payloadSize = companion.payloadSize.value!;
      final messageByteLength = utf8.encode(companion.message.value).length;
      expect(payloadSize, messageByteLength);
    });

    test('payloadSize is JSON length for simple message types', () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>())).thenAnswer(
        (invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
          return 1;
        },
      );

      final testService = buildService();

      await testService.enqueueMessage(
        const SyncMessage.aiConfigDelete(id: 'cfg-1'),
      );

      expect(capturedCompanions, hasLength(1));
      final companion = capturedCompanions.single;
      final payloadSize = companion.payloadSize.value!;
      final messageByteLength = utf8.encode(companion.message.value).length;
      expect(payloadSize, messageByteLength);
    });

    test('enqueues entry link with coveredVectorClocks populated', () async {
      final capturedCompanions = <OutboxCompanion>[];
      when(() => syncDatabase.addOutboxItem(any<OutboxCompanion>())).thenAnswer(
        (invocation) async {
          capturedCompanions.add(
            invocation.positionalArguments.first as OutboxCompanion,
          );
          return 1;
        },
      );

      final testService = buildService();

      final now = DateTime.utc(2024);
      const linkVc = VectorClock({'hostA': 3});
      final link = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: now,
        updatedAt: now,
        vectorClock: linkVc,
      );

      await testService.enqueueMessage(
        SyncMessage.entryLink(entryLink: link, status: SyncEntryStatus.initial),
      );

      expect(capturedCompanions, hasLength(1));
      final companion = capturedCompanions.single;
      final decodedMessage = SyncMessage.fromJson(
        jsonDecode(companion.message.value) as Map<String, dynamic>,
      );
      final linkMsg = decodedMessage as SyncEntryLink;
      expect(linkMsg.coveredVectorClocks, isNotNull);
      final coveredCounters = linkMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['hostA'])
          .whereType<int>()
          .toSet();
      expect(coveredCounters, contains(3));
    });

    test(
      'merges consecutive updates to same journal entry with coveredVectorClocks',
      () async {
        final sampleDate = DateTime.utc(2024);
        const oldVc = VectorClock({'hostA': 5});
        const newVc = VectorClock({'hostA': 7});

        // Create the "old" message that's already in the outbox
        const oldMessage = SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: '/entries/test.json',
          vectorClock: oldVc,
          status: SyncEntryStatus.update,
        );

        // Existing pending outbox item
        final existingItem = OutboxItem(
          id: 1,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          status: OutboxStatus.pending.index,
          retries: 0,
          message: jsonEncode(oldMessage.toJson()),
          subject: 'hhash:5',
          filePath: null,
          outboxEntryId: 'entry-id',
          priority: OutboxPriority.low.index,
        );

        // Return existing item for this entry
        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);

        // Capture the update call
        String? capturedMessage;
        String? capturedSubject;
        int? capturedPayloadSize;
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((invocation) async {
          capturedMessage = invocation.namedArguments[#newMessage] as String?;
          capturedSubject = invocation.namedArguments[#newSubject] as String?;
          capturedPayloadSize = invocation.namedArguments[#payloadSize] as int?;
          return 1;
        });

        final testService = buildService();

        final metadata = Metadata(
          id: 'entry-id',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: newVc,
        );
        final journalEntity = JournalEntity.journalEntry(
          meta: metadata,
          entryText: const EntryText(plainText: 'Updated text'),
        );

        const jsonPath = '/entries/test.json';
        File('${documentsDirectory.path}$jsonPath')
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

        await testService.enqueueMessage(
          const SyncMessage.journalEntity(
            id: 'entry-id',
            jsonPath: jsonPath,
            vectorClock: newVc,
            status: SyncEntryStatus.update,
          ),
        );

        // Verify updateOutboxMessage was called instead of addOutboxItem
        verify(
          () => syncDatabase.updateOutboxMessage(
            itemId: 1,
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).called(1);
        verifyNever(() => syncDatabase.addOutboxItem(any()));

        // Verify the merged message contains coveredVectorClocks
        expect(capturedMessage, isNotNull);
        final decodedMessage = SyncMessage.fromJson(
          jsonDecode(capturedMessage!) as Map<String, dynamic>,
        );
        expect(decodedMessage, isA<SyncJournalEntity>());
        final journalMsg = decodedMessage as SyncJournalEntity;
        expect(journalMsg.coveredVectorClocks, isNotNull);
        final coveredCounters = journalMsg.coveredVectorClocks!
            .map((vc) => vc.vclock['hostA'])
            .whereType<int>()
            .toSet();
        expect(coveredCounters, containsAll([5, 7]));
        expect(coveredCounters, hasLength(2));
        expect(capturedSubject, 'hhash:7');

        // Verify merged payloadSize = utf8 byte length of merged JSON
        // (no file attachment for text-only journal entry)
        expect(capturedPayloadSize, isNotNull);
        expect(capturedPayloadSize, utf8.encode(capturedMessage!).length);
      },
    );

    test(
      'accumulates multiple covered clocks across successive merges',
      () async {
        final sampleDate = DateTime.utc(2024);
        const vc5 = VectorClock({'hostA': 5});
        const vc6 = VectorClock({'hostA': 6});
        const vc7 = VectorClock({'hostA': 7});

        // Existing item already has one covered clock from previous merge
        const oldMessage = SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: '/entries/test.json',
          vectorClock: vc6,
          status: SyncEntryStatus.update,
          coveredVectorClocks: [vc5], // Already covered VC5
        );

        final existingItem = OutboxItem(
          id: 1,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          status: OutboxStatus.pending.index,
          retries: 0,
          message: jsonEncode(oldMessage.toJson()),
          subject: 'hhash:6',
          filePath: null,
          outboxEntryId: 'entry-id',
          priority: OutboxPriority.low.index,
        );

        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);

        String? capturedMessage;
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((invocation) async {
          capturedMessage = invocation.namedArguments[#newMessage] as String?;
          return 1;
        });

        final testService = buildService();

        final metadata = Metadata(
          id: 'entry-id',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: vc7,
        );
        final journalEntity = JournalEntity.journalEntry(
          meta: metadata,
          entryText: const EntryText(plainText: 'Third update'),
        );

        const jsonPath = '/entries/test.json';
        File('${documentsDirectory.path}$jsonPath')
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

        await testService.enqueueMessage(
          const SyncMessage.journalEntity(
            id: 'entry-id',
            jsonPath: jsonPath,
            vectorClock: vc7,
            status: SyncEntryStatus.update,
          ),
        );

        // Verify coveredVectorClocks accumulated both VC5 and VC6
        expect(capturedMessage, isNotNull);
        final decodedMessage = SyncMessage.fromJson(
          jsonDecode(capturedMessage!) as Map<String, dynamic>,
        );
        final journalMsg = decodedMessage as SyncJournalEntity;
        final coveredCounters = journalMsg.coveredVectorClocks!
            .map((vc) => vc.vclock['hostA'])
            .whereType<int>()
            .toSet();
        expect(coveredCounters, containsAll([5, 6, 7]));
        expect(coveredCounters, hasLength(3));
      },
    );

    test(
      'captures intermediate VC when DB has newer version than enqueue call',
      () async {
        // This tests the race condition scenario:
        // 1. Entry created with VC {A:5}, enqueue#1 called
        // 2. Entry updated to VC {A:6}, enqueue#2 called
        // 3. Entry updated to VC {A:7} (before enqueue#2 runs)
        // 4. enqueue#1 runs: creates outbox item with VC {A:5}
        // 5. enqueue#2 runs: journalEntityMsg.VC={A:6}, DB has VC={A:7}
        //    -> coveredClocks should be [{A:5}, {A:6}, {A:7}],
        //       final VC is {A:7}
        final sampleDate = DateTime.utc(2024);
        const oldVc = VectorClock({'hostA': 5}); // VC in existing outbox item
        const intermediateVc = VectorClock({
          'hostA': 6,
        }); // VC from enqueue call
        const latestVc = VectorClock({'hostA': 7}); // VC now in DB

        // Existing item has VC 5 (from enqueue#1)
        const oldMessage = SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: '/entries/test.json',
          vectorClock: oldVc,
          status: SyncEntryStatus.update,
        );

        final existingItem = OutboxItem(
          id: 1,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          status: OutboxStatus.pending.index,
          retries: 0,
          message: jsonEncode(oldMessage.toJson()),
          subject: 'hhash:5',
          filePath: null,
          outboxEntryId: 'entry-id',
          priority: OutboxPriority.low.index,
        );

        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);

        String? capturedMessage;
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((invocation) async {
          capturedMessage = invocation.namedArguments[#newMessage] as String?;
          return 1;
        });

        final testService = buildService();

        // Setup: DB returns entry with latest VC (7)
        final metadata = Metadata(
          id: 'entry-id',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: latestVc,
        );
        final journalEntity = JournalEntity.journalEntry(
          meta: metadata,
          entryText: const EntryText(plainText: 'Updated'),
        );

        when(
          () => journalDb.journalEntityById('entry-id'),
        ).thenAnswer((_) async => journalEntity);

        final jsonPath = '${documentsDirectory.path}/entries/test.json';
        File(jsonPath)
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

        // Call enqueue with INTERMEDIATE VC (6) - simulating a call that was
        // delayed and the DB was updated in the meantime
        await testService.enqueueMessage(
          const SyncMessage.journalEntity(
            id: 'entry-id',
            jsonPath: '/entries/test.json',
            vectorClock: intermediateVc, // VC from when enqueue was called
            status: SyncEntryStatus.update,
          ),
        );

        // Verify the merge captured both the old VC and the intermediate VC
        expect(capturedMessage, isNotNull);
        final decodedMessage = SyncMessage.fromJson(
          jsonDecode(capturedMessage!) as Map<String, dynamic>,
        );
        expect(decodedMessage, isA<SyncJournalEntity>());
        final journalMsg = decodedMessage as SyncJournalEntity;

        // Final VC should be from DB (latest)
        expect(journalMsg.vectorClock?.vclock['hostA'], 7);

        // coveredVectorClocks should contain old VC (5), intermediate (6),
        // and current (7)
        expect(journalMsg.coveredVectorClocks, isNotNull);
        final coveredCounters = journalMsg.coveredVectorClocks!
            .map((vc) => vc.vclock['hostA'])
            .whereType<int>()
            .toSet();
        expect(coveredCounters, containsAll([5, 6, 7]));
        expect(coveredCounters, hasLength(3));
      },
    );

    test('merges entry link updates with coveredVectorClocks', () async {
      final sampleDate = DateTime.utc(2024);
      const oldVc = VectorClock({'hostA': 3});
      const newVc = VectorClock({'hostA': 5});

      final oldLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        vectorClock: oldVc,
      );

      final oldMessage = SyncMessage.entryLink(
        entryLink: oldLink,
        status: SyncEntryStatus.update,
      );

      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: jsonEncode(oldMessage.toJson()),
        subject: 'hhash:link:3',
        filePath: null,
        outboxEntryId: 'link-id',
        priority: OutboxPriority.low.index,
      );

      when(
        () => syncDatabase.findPendingByEntryId('link-id'),
      ).thenAnswer((_) async => existingItem);

      String? capturedMessage;
      String? capturedSubject;
      int? capturedPayloadSize;
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((invocation) async {
        capturedMessage = invocation.namedArguments[#newMessage] as String?;
        capturedSubject = invocation.namedArguments[#newSubject] as String?;
        capturedPayloadSize = invocation.namedArguments[#payloadSize] as int?;
        return 1;
      });

      final testService = buildService();

      final newLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        vectorClock: newVc,
      );

      await testService.enqueueMessage(
        SyncMessage.entryLink(
          entryLink: newLink,
          status: SyncEntryStatus.update,
        ),
      );

      // Verify updateOutboxMessage was called instead of addOutboxItem
      verify(
        () => syncDatabase.updateOutboxMessage(
          itemId: 1,
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
      verifyNever(() => syncDatabase.addOutboxItem(any()));

      // Verify the merged message contains coveredVectorClocks
      expect(capturedMessage, isNotNull);
      final decodedMessage = SyncMessage.fromJson(
        jsonDecode(capturedMessage!) as Map<String, dynamic>,
      );
      expect(decodedMessage, isA<SyncEntryLink>());
      final linkMsg = decodedMessage as SyncEntryLink;
      expect(linkMsg.coveredVectorClocks, isNotNull);
      final coveredCounters = linkMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['hostA'])
          .whereType<int>()
          .toSet();
      expect(coveredCounters, containsAll([3, 5]));
      expect(coveredCounters, hasLength(2));
      expect(capturedSubject, 'hhash:link:5');

      // Verify merged payloadSize = utf8 byte length of merged JSON
      expect(capturedPayloadSize, isNotNull);
      expect(capturedPayloadSize, utf8.encode(capturedMessage!).length);
    });

    test('records sequence log entry during journal entity merge', () async {
      final sampleDate = DateTime.utc(2024);
      const oldVc = VectorClock({'hostA': 5});
      const newVc = VectorClock({'hostA': 7});

      const oldMessage = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entries/test.json',
        vectorClock: oldVc,
        status: SyncEntryStatus.update,
      );

      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: jsonEncode(oldMessage.toJson()),
        subject: 'hhash:5',
        filePath: null,
        outboxEntryId: 'entry-id',
        priority: OutboxPriority.low.index,
      );

      when(
        () => syncDatabase.findPendingByEntryId('entry-id'),
      ).thenAnswer((_) async => existingItem);
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((_) async => 1);

      final mockSequenceService = MockSyncSequenceLogService();
      when(
        () => mockSequenceService.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenAnswer((_) async {});

      final testService = buildService(sequenceLogService: mockSequenceService);

      final metadata = Metadata(
        id: 'entry-id',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        dateFrom: sampleDate,
        dateTo: sampleDate,
        vectorClock: newVc,
      );
      final journalEntity = JournalEntity.journalEntry(
        meta: metadata,
        entryText: const EntryText(plainText: 'Updated text'),
      );

      const jsonPath = '/entries/test.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      await testService.enqueueMessage(
        const SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: jsonPath,
          vectorClock: newVc,
          status: SyncEntryStatus.update,
        ),
      );

      // Verify sequence log was recorded during merge
      verify(
        () => mockSequenceService.recordSentEntry(
          entryId: 'entry-id',
          vectorClock: newVc,
        ),
      ).called(1);
    });

    test('records sequence log entry during entry link merge', () async {
      final sampleDate = DateTime.utc(2024);
      const oldVc = VectorClock({'hostA': 3});
      const newVc = VectorClock({'hostA': 5});

      final oldLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        vectorClock: oldVc,
      );

      final oldMessage = SyncMessage.entryLink(
        entryLink: oldLink,
        status: SyncEntryStatus.update,
      );

      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: jsonEncode(oldMessage.toJson()),
        subject: 'hhash:link:3',
        filePath: null,
        outboxEntryId: 'link-id',
        priority: OutboxPriority.low.index,
      );

      when(
        () => syncDatabase.findPendingByEntryId('link-id'),
      ).thenAnswer((_) async => existingItem);
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((_) async => 1);

      final mockSequenceService = MockSyncSequenceLogService();
      when(
        () => mockSequenceService.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenAnswer((_) async {});

      final testService = buildService(sequenceLogService: mockSequenceService);

      final newLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-entry',
        toId: 'to-entry',
        createdAt: sampleDate,
        updatedAt: sampleDate,
        vectorClock: newVc,
      );

      await testService.enqueueMessage(
        SyncMessage.entryLink(
          entryLink: newLink,
          status: SyncEntryStatus.update,
        ),
      );

      // Verify sequence log was recorded during merge
      verify(
        () => mockSequenceService.recordSentEntryLink(
          linkId: 'link-id',
          vectorClock: newVc,
        ),
      ).called(1);
    });

    test(
      'falls through to create new item when merge message decode fails',
      () async {
        final sampleDate = DateTime.utc(2024);
        const newVc = VectorClock({'hostA': 7});

        // Existing item with invalid JSON message
        final existingItem = OutboxItem(
          id: 1,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          status: OutboxStatus.pending.index,
          retries: 0,
          message: 'invalid-json{{{',
          subject: 'hhash:5',
          filePath: null,
          outboxEntryId: 'entry-id',
          priority: OutboxPriority.low.index,
        );

        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);
        when(
          () => syncDatabase.addOutboxItem(any()),
        ).thenAnswer((_) async => 2);

        final testService = buildService();

        final metadata = Metadata(
          id: 'entry-id',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: newVc,
        );
        final journalEntity = JournalEntity.journalEntry(
          meta: metadata,
          entryText: const EntryText(plainText: 'New text'),
        );

        const jsonPath = '/entries/test.json';
        File('${documentsDirectory.path}$jsonPath')
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

        await testService.enqueueMessage(
          const SyncMessage.journalEntity(
            id: 'entry-id',
            jsonPath: jsonPath,
            vectorClock: newVc,
            status: SyncEntryStatus.update,
          ),
        );

        // Should fall through to create new item since merge decode failed
        verify(() => syncDatabase.addOutboxItem(any())).called(1);
        verifyNever(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        );
      },
    );

    test(
      'journal merge whose update affects zero rows (row no longer pending) '
      'logs MERGE-MISS and inserts a fresh row with the merged data',
      () async {
        final sampleDate = DateTime.utc(2024);
        const oldVc = VectorClock({'hostA': 5});
        const newVc = VectorClock({'hostA': 7});

        const oldMessage = SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: '/entries/test.json',
          vectorClock: oldVc,
          status: SyncEntryStatus.update,
        );
        final existingItem = OutboxItem(
          id: 1,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          status: OutboxStatus.pending.index,
          retries: 0,
          message: jsonEncode(oldMessage.toJson()),
          subject: 'hhash:5',
          filePath: null,
          outboxEntryId: 'entry-id',
          priority: OutboxPriority.low.index,
        );
        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => existingItem);
        // Row was sent out from under us between the SELECT and UPDATE.
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => 0);
        OutboxCompanion? insertedCompanion;
        when(() => syncDatabase.addOutboxItem(any())).thenAnswer((invocation) {
          insertedCompanion =
              invocation.positionalArguments.single as OutboxCompanion;
          return Future<int>.value(2);
        });

        final testService = buildService();

        final journalEntity = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'entry-id',
            createdAt: sampleDate,
            updatedAt: sampleDate,
            dateFrom: sampleDate,
            dateTo: sampleDate,
            vectorClock: newVc,
          ),
          entryText: const EntryText(plainText: 'Updated text'),
        );
        const jsonPath = '/entries/test.json';
        File('${documentsDirectory.path}$jsonPath')
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

        await testService.enqueueMessage(
          const SyncMessage.journalEntity(
            id: 'entry-id',
            jsonPath: jsonPath,
            vectorClock: newVc,
            status: SyncEntryStatus.update,
          ),
        );

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: allOf([
                contains('MERGE-MISS'),
                contains('type=SyncJournalEntity'),
                contains('id=entry-id'),
              ]),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
        // Fresh row carries the merged subject + the original entry id.
        expect(insertedCompanion, isNotNull);
        expect(insertedCompanion!.subject.value, 'hhash:7');
        expect(insertedCompanion!.outboxEntryId.value, 'entry-id');
      },
    );

    test('a throw from recordSentEntry during a journal MERGE is caught and '
        'logged under recordSent so a broken sequence log never breaks the '
        'merge, and the merge still completes', () async {
      final sampleDate = DateTime.utc(2024);
      const oldVc = VectorClock({'hostA': 5});
      const newVc = VectorClock({'hostA': 7});

      const oldMessage = SyncMessage.journalEntity(
        id: 'entry-id',
        jsonPath: '/entries/test.json',
        vectorClock: oldVc,
        status: SyncEntryStatus.update,
      );
      final existingItem = OutboxItem(
        id: 1,
        createdAt: sampleDate,
        updatedAt: sampleDate,
        status: OutboxStatus.pending.index,
        retries: 0,
        message: jsonEncode(oldMessage.toJson()),
        subject: 'hhash:5',
        filePath: null,
        outboxEntryId: 'entry-id',
        priority: OutboxPriority.low.index,
      );
      when(
        () => syncDatabase.findPendingByEntryId('entry-id'),
      ).thenAnswer((_) async => existingItem);
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((_) async => 1);

      final sequenceLog = MockSyncSequenceLogService();
      when(
        () => sequenceLog.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenThrow(StateError('sequence log gone'));

      final testService = buildService(sequenceLogService: sequenceLog);

      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-id',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          dateFrom: sampleDate,
          dateTo: sampleDate,
          vectorClock: newVc,
        ),
        entryText: const EntryText(plainText: 'Updated text'),
      );
      const jsonPath = '/entries/test.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      await testService.enqueueMessage(
        const SyncMessage.journalEntity(
          id: 'entry-id',
          jsonPath: jsonPath,
          vectorClock: newVc,
          status: SyncEntryStatus.update,
        ),
      );

      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'recordSent',
        ),
      ).called(1);
      // The merge still completed despite the sequence-log failure.
      verify(
        () => syncDatabase.updateOutboxMessage(
          itemId: 1,
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
    });

    test(
      'a throw from recordSentEntry on the non-merge journal path is caught '
      'and logged under recordSent so the fresh enqueue still succeeds',
      () async {
        final sampleDate = DateTime.utc(2024);
        const newVc = VectorClock({'hostA': 7});

        // No existing pending item → fresh-insert path (not a merge).
        when(
          () => syncDatabase.findPendingByEntryId('entry-id'),
        ).thenAnswer((_) async => null);

        final sequenceLog = MockSyncSequenceLogService();
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenThrow(StateError('sequence log gone'));

        final testService = buildService(sequenceLogService: sequenceLog);

        final journalEntity = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'entry-id',
            createdAt: sampleDate,
            updatedAt: sampleDate,
            dateFrom: sampleDate,
            dateTo: sampleDate,
            vectorClock: newVc,
          ),
          entryText: const EntryText(plainText: 'Fresh text'),
        );
        const jsonPath = '/entries/test.json';
        File('${documentsDirectory.path}$jsonPath')
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

        await testService.enqueueMessage(
          const SyncMessage.journalEntity(
            id: 'entry-id',
            jsonPath: jsonPath,
            vectorClock: newVc,
            status: SyncEntryStatus.update,
          ),
        );

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordSent',
          ),
        ).called(1);
        // The fresh outbox row was still inserted.
        verify(() => syncDatabase.addOutboxItem(any())).called(1);
      },
    );

    test(
      'entry-link merge whose update affects zero rows logs MERGE-MISS and '
      'inserts a fresh row carrying the merged subject and link id',
      () async {
        final sampleDate = DateTime.utc(2024);
        const oldVc = VectorClock({'hostA': 3});
        const newVc = VectorClock({'hostA': 5});

        final oldLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-entry',
          toId: 'to-entry',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          vectorClock: oldVc,
        );
        final oldMessage = SyncMessage.entryLink(
          entryLink: oldLink,
          status: SyncEntryStatus.update,
        );
        final existingItem = OutboxItem(
          id: 1,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          status: OutboxStatus.pending.index,
          retries: 0,
          message: jsonEncode(oldMessage.toJson()),
          subject: 'hhash:link:3',
          filePath: null,
          outboxEntryId: 'link-id',
          priority: OutboxPriority.low.index,
        );
        when(
          () => syncDatabase.findPendingByEntryId('link-id'),
        ).thenAnswer((_) async => existingItem);
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => 0);
        OutboxCompanion? insertedCompanion;
        when(() => syncDatabase.addOutboxItem(any())).thenAnswer((invocation) {
          insertedCompanion =
              invocation.positionalArguments.single as OutboxCompanion;
          return Future<int>.value(2);
        });

        final testService = buildService();

        final newLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-entry',
          toId: 'to-entry',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          vectorClock: newVc,
        );

        await testService.enqueueMessage(
          SyncMessage.entryLink(
            entryLink: newLink,
            status: SyncEntryStatus.update,
          ),
        );

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: allOf([
                contains('MERGE-MISS'),
                contains('type=SyncEntryLink'),
                contains('id=link-id'),
              ]),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
        expect(insertedCompanion, isNotNull);
        expect(insertedCompanion!.subject.value, 'hhash:link:5');
        expect(insertedCompanion!.outboxEntryId.value, 'link-id');
      },
    );

    test(
      'a throw from recordSentEntryLink during an entry-link MERGE is caught '
      'and logged under recordSent without breaking the merge',
      () async {
        final sampleDate = DateTime.utc(2024);
        const oldVc = VectorClock({'hostA': 3});
        const newVc = VectorClock({'hostA': 5});

        final oldLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-entry',
          toId: 'to-entry',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          vectorClock: oldVc,
        );
        final oldMessage = SyncMessage.entryLink(
          entryLink: oldLink,
          status: SyncEntryStatus.update,
        );
        final existingItem = OutboxItem(
          id: 1,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          status: OutboxStatus.pending.index,
          retries: 0,
          message: jsonEncode(oldMessage.toJson()),
          subject: 'hhash:link:3',
          filePath: null,
          outboxEntryId: 'link-id',
          priority: OutboxPriority.low.index,
        );
        when(
          () => syncDatabase.findPendingByEntryId('link-id'),
        ).thenAnswer((_) async => existingItem);
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => 1);

        final sequenceLog = MockSyncSequenceLogService();
        when(
          () => sequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenThrow(StateError('sequence log gone'));

        final testService = buildService(sequenceLogService: sequenceLog);

        final newLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-entry',
          toId: 'to-entry',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          vectorClock: newVc,
        );

        await testService.enqueueMessage(
          SyncMessage.entryLink(
            entryLink: newLink,
            status: SyncEntryStatus.update,
          ),
        );

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordSent',
          ),
        ).called(1);
        verify(
          () => syncDatabase.updateOutboxMessage(
            itemId: 1,
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).called(1);
      },
    );

    test(
      'an entry-link merge whose existing row holds undecodable JSON is '
      'caught under enqueueMessage.merge and falls through to a fresh insert',
      () async {
        final sampleDate = DateTime.utc(2024);
        const newVc = VectorClock({'hostA': 5});

        // Existing pending link row with a corrupt message body so the
        // merge `SyncMessage.fromJson` throws inside the link merge try.
        final existingItem = OutboxItem(
          id: 1,
          createdAt: sampleDate,
          updatedAt: sampleDate,
          status: OutboxStatus.pending.index,
          retries: 0,
          message: 'not-valid-json{{{',
          subject: 'hhash:link:3',
          filePath: null,
          outboxEntryId: 'link-id',
          priority: OutboxPriority.low.index,
        );
        when(
          () => syncDatabase.findPendingByEntryId('link-id'),
        ).thenAnswer((_) async => existingItem);
        when(
          () => syncDatabase.addOutboxItem(any()),
        ).thenAnswer((_) async => 2);

        final testService = buildService();

        final newLink = EntryLink.basic(
          id: 'link-id',
          fromId: 'from-entry',
          toId: 'to-entry',
          createdAt: sampleDate,
          updatedAt: sampleDate,
          vectorClock: newVc,
        );

        await testService.enqueueMessage(
          SyncMessage.entryLink(
            entryLink: newLink,
            status: SyncEntryStatus.update,
          ),
        );

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'enqueueMessage.merge',
          ),
        ).called(1);
        // The corrupt-merge fall-through still enqueues the link fresh.
        verify(() => syncDatabase.addOutboxItem(any())).called(1);
        verifyNever(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        );
      },
    );
  });

  group('SyncDailyOsUserName', () {
    test('enqueues the Daily OS name message with correct subject', () async {
      final message = SyncMessage.dailyOsUserName(
        userName: 'Sam',
        updatedAt: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'dailyOsUserName');
    });
  });

  group('SyncThemingSelection', () {
    test('enqueues theming message with correct subject', () async {
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'themingSelection');
    });

    test('logs theming message details', () async {
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncThemingSelection'),
              contains('light=Indigo'),
              contains('dark=Shark'),
              contains('mode=dark'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });
  });

  group('SyncConfigFlag', () {
    test('enqueues config flag message with flag-specific subject', () async {
      const message = SyncMessage.configFlag(
        name: 'enableDailyOs',
        description: 'Enable DailyOS Page?',
        status: true,
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'configFlag:enableDailyOs');
      expect(companion.outboxEntryId.value, 'configFlag:enableDailyOs');

      final queued =
          SyncMessage.fromJson(
                jsonDecode(companion.message.value) as Map<String, dynamic>,
              )
              as SyncConfigFlag;
      expect(queued.status, isTrue);
      expect(queued.originatingHostId, 'hostA');
    });

    test('merges pending config flag message to the latest status', () async {
      const oldMessage = SyncMessage.configFlag(
        name: 'enableDailyOs',
        description: 'Enable DailyOS Page?',
        status: false,
      );
      const newMessage = SyncMessage.configFlag(
        name: 'enableDailyOs',
        description: 'Enable DailyOS Page?',
        status: true,
      );

      when(
        () => syncDatabase.findPendingByEntryId('configFlag:enableDailyOs'),
      ).thenAnswer(
        (_) async => OutboxItem(
          id: 42,
          message: jsonEncode(oldMessage.toJson()),
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          subject: 'configFlag:enableDailyOs',
          outboxEntryId: 'configFlag:enableDailyOs',
          priority: OutboxPriority.normal.index,
        ),
      );
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((_) async => 1);

      await service.enqueueMessage(newMessage);

      final captured =
          verify(
                () => syncDatabase.updateOutboxMessage(
                  itemId: 42,
                  newMessage: captureAny(named: 'newMessage'),
                  newSubject: 'configFlag:enableDailyOs',
                  payloadSize: any(named: 'payloadSize'),
                  priority: any(named: 'priority'),
                ),
              ).captured.single
              as String;
      final merged =
          SyncMessage.fromJson(jsonDecode(captured) as Map<String, dynamic>)
              as SyncConfigFlag;
      expect(merged.status, isTrue);
      expect(merged.originatingHostId, 'hostA');
      verifyNever(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()));
    });
  });

  group('SyncSyncNodeProfile', () {
    test('enqueues sync-node-profile message with correct subject', () async {
      final message = SyncMessage.syncNodeProfile(
        profile: SyncNodeProfile(
          hostId: 'host-uuid-abc',
          displayName: 'Studio Mac',
          platform: 'macos',
          capabilities: const [
            NodeCapability.mlxAudio,
            NodeCapability.ollamaLlm,
          ],
          updatedAt: DateTime.utc(2026, 3, 15, 12),
        ),
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'syncNodeProfile');
      // Presence broadcasts ride at low priority so they never queue-jump
      // journal writes.
      expect(companion.priority.value, OutboxPriority.low.index);
    });

    test(
      'logs sync-node-profile message details — hostId, name, and capability '
      'count appear in the structured event for log triage',
      () async {
        final message = SyncMessage.syncNodeProfile(
          profile: SyncNodeProfile(
            hostId: 'host-uuid-xyz',
            displayName: 'Linux Box',
            platform: 'linux',
            capabilities: const [NodeCapability.ollamaLlm],
            updatedAt: DateTime.utc(2026, 3, 15, 12),
          ),
        );

        await service.enqueueMessage(message);

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: allOf([
                contains('type=SyncSyncNodeProfile'),
                contains('hostId=host-uuid-xyz'),
                contains('name=Linux Box'),
                contains('caps=1'),
              ]),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
      },
    );
  });

  group('Simple message handler edge cases', () {
    test('onboarding controls use stable per-round subjects', () async {
      const controls = <SyncMessage>[
        SyncMessage.onboardingSnapshotBegin(
          protocolVersion: 1,
          roundId: 'round-1',
          senderHostId: 'sender-host',
          senderUserId: 'sender-user',
          senderDeviceId: 'sender-device',
          recipientUserId: 'recipient-user',
          recipientDeviceId: 'recipient-device',
          coverageUpperBounds: {'sender-host': 42},
          leaseSeconds: 3600,
        ),
        SyncMessage.onboardingSnapshotAccepted(
          protocolVersion: 1,
          roundId: 'round-1',
          senderHostId: 'sender-host',
          senderUserId: 'sender-user',
          senderDeviceId: 'sender-device',
          recipientHostId: 'recipient-host',
          recipientDeviceId: 'recipient-device',
        ),
        SyncMessage.onboardingTerminalCounters(
          protocolVersion: 1,
          roundId: 'round-1',
          senderHostId: 'sender-host',
          recipientUserId: 'recipient-user',
          recipientDeviceId: 'recipient-device',
          ranges: [SyncCounterRange(start: 1, end: 2)],
        ),
        SyncMessage.onboardingSnapshotEnd(
          protocolVersion: 1,
          roundId: 'round-1',
          senderHostId: 'sender-host',
          recipientUserId: 'recipient-user',
          recipientDeviceId: 'recipient-device',
          reason: OnboardingSyncEndReason.complete,
        ),
      ];

      for (final control in controls) {
        await service.enqueueMessage(control);
      }

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured.cast<OutboxCompanion>();
      expect(captured.map((companion) => companion.subject.value), [
        'onboarding:round-1:begin',
        'onboarding:round-1:accepted',
        'onboarding:round-1:terminal',
        'onboarding:round-1:end',
      ]);
      expect(
        captured.map(
          (companion) => SyncMessage.fromJson(
            jsonDecode(companion.message.value) as Map<String, dynamic>,
          ),
        ),
        controls,
      );
    });

    test(
      'SyncEntityDefinition with null vectorClock uses null in subject',
      () async {
        final entityDef = HabitDefinition(
          id: 'habit-no-vc',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          vectorClock: null, // Null vector clock
          name: 'Test Habit',
          description: 'A habit without vector clock',
          private: false,
          active: true,
          habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
        );

        final message = SyncMessage.entityDefinition(
          entityDefinition: entityDef,
          status: SyncEntryStatus.initial,
        );

        await service.enqueueMessage(message);

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured.length, 1);

        final companion = captured.first as OutboxCompanion;
        // Subject should contain null for the counter part (hhash is the mock value)
        expect(companion.subject.value, 'hhash:null');
      },
    );

    test('SyncMediaRequest rides the inline enqueue path', () async {
      const message = SyncMessage.mediaRequest(
        entryIds: ['entry-1', 'entry-2'],
        requesterId: 'requester-device',
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'mediaRequest:batch:2');
      // A repair request carries no payload file of its own; it must never be
      // mistaken for a media row and pulled out of the bundler.
      expect(companion.filePath.value, isNull);
      // Round-trips intact, so the responder sees the ids it must answer for.
      final decoded =
          SyncMessage.fromJson(
                jsonDecode(companion.message.value) as Map<String, dynamic>,
              )
              as SyncMediaRequest;
      expect(decoded.entryIds, ['entry-1', 'entry-2']);
      expect(decoded.requesterId, 'requester-device');
    });

    test('SyncBackfillRequest with empty entries list', () async {
      const message = SyncMessage.backfillRequest(
        requesterId: 'requester-device',
        entries: [], // Empty list
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'backfillRequest:batch:0');

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('entries=0')),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('SyncBackfillRequest with multiple entries', () async {
      const message = SyncMessage.backfillRequest(
        requesterId: 'requester-device',
        entries: [
          BackfillRequestEntry(hostId: 'host1', counter: 1),
          BackfillRequestEntry(hostId: 'host1', counter: 2),
          BackfillRequestEntry(hostId: 'host2', counter: 1),
        ],
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'backfillRequest:batch:3');
    });

    test('SyncBackfillResponse with deleted=true', () async {
      const message = SyncMessage.backfillResponse(
        hostId: 'host-abc',
        counter: 42,
        deleted: true,
      );

      await service.enqueueMessage(message);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncBackfillResponse'),
              contains('hostId=host-abc'),
              contains('counter=42'),
              contains('deleted=true'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('SyncBackfillResponse with deleted=false and entryId', () async {
      const message = SyncMessage.backfillResponse(
        hostId: 'host-abc',
        counter: 42,
        deleted: false,
        entryId: 'entry-123',
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'backfillResponse:host-abc:42');

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('deleted=false')),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('SyncAiConfig logs config id correctly', () async {
      final config = AiConfig.inferenceProvider(
        id: 'config-xyz-789',
        name: 'Test Config',
        apiKey: 'sk-test',
        baseUrl: 'https://api.openai.com/v1',
        createdAt: DateTime(2025, 1, 1),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      final message = SyncMessage.aiConfig(
        aiConfig: config,
        status: SyncEntryStatus.initial,
      );

      await service.enqueueMessage(message);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncAiConfig'),
              contains('id=config-xyz-789'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('SyncAiConfigDelete logs deleted config id', () async {
      const message = SyncMessage.aiConfigDelete(id: 'config-to-delete-456');

      await service.enqueueMessage(message);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncAiConfigDelete'),
              contains('id=config-to-delete-456'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('enqueueMessage handles addOutboxItem error gracefully', () async {
      when(
        () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
      ).thenThrow(Exception('DB write failed'));

      final message = SyncMessage.themingSelection(
        lightThemeName: 'Light',
        darkThemeName: 'Dark',
        themeMode: 'system',
        updatedAt: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      // Should not throw - error is caught and logged
      await service.enqueueMessage(message);

      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test(
      'SyncEntityDefinition with null host uses null in counter lookup',
      () async {
        // Create a vectorClockService that returns null host
        final nullHostVcs = MockVectorClockService();
        when(() => nullHostVcs.getHost()).thenAnswer((_) async => null);
        when(
          () => nullHostVcs.getHostHash(),
        ).thenAnswer((_) async => 'hash123');

        final serviceWithNullHost = MatrixOutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: nullHostVcs,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: createGate(),
        );

        final entityDef = HabitDefinition(
          id: 'habit-1',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'someHost': 5}),
          name: 'Test Habit',
          description: 'A habit with VC but null host lookup',
          private: false,
          active: true,
          habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
        );

        final message = SyncMessage.entityDefinition(
          entityDefinition: entityDef,
          status: SyncEntryStatus.initial,
        );

        await serviceWithNullHost.enqueueMessage(message);

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured.length, 1);

        final companion = captured.first as OutboxCompanion;
        // With null host, the vclock lookup returns null
        expect(companion.subject.value, 'hash123:null');

        await serviceWithNullHost.dispose();
      },
    );
  });

  group('enqueueNotification originatingHostId fallback -', () {
    test(
      'uses entity.meta.originatingHostId when caller omits the override',
      () async {
        final notification = _testNotification(
          id: 'notif-no-override',
          vectorClock: const VectorClock({'hostA': 7}),
        );
        // entity.meta.originatingHostId is 'hostA' (set in _testNotification)

        await service.enqueueNotification(notification);
        // No originatingHostId override — should fall back to meta value.

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured, hasLength(1));
        final companion = captured.single as OutboxCompanion;
        final queued = SyncMessage.fromJson(
          jsonDecode(companion.message.value) as Map<String, dynamic>,
        );
        expect(queued, isA<SyncNotification>());
        final syncNotification = queued as SyncNotification;
        // Should pick up originatingHostId from entity.meta (= 'hostA')
        expect(syncNotification.originatingHostId, 'hostA');
      },
    );
  });
}

NotificationEntity _testNotification({
  required String id,
  required VectorClock vectorClock,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 10);
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: vectorClock,
      originatingHostId: 'hostA',
    ),
    linkedTaskId: 'task-$id',
    suggestionCount: 2,
    title: 'Review suggestions',
    body: 'Two tasks need review',
  );
}
