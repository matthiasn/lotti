// ignore_for_file: avoid_redundant_argument_values

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
  late MockVectorClockService vectorClockService;
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
    vectorClockService = harness.vectorClockService;
    userActivityService = harness.userActivityService;
    documentsDirectory = harness.documentsDirectory;
    service = harness.service;
  });

  tearDown(() async {
    await harness.tearDown(service);
  });

  group('Embedded Entry Links', () {
    test('embeds entry links when enqueueing journal entity', () async {
      const entryId = 'entry-123';
      final link1 = EntryLink.basic(
        id: 'link-1',
        fromId: entryId,
        toId: 'category-1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );
      final link2 = EntryLink.basic(
        id: 'link-2',
        fromId: 'category-2',
        toId: entryId,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: null,
      );

      // Mock journalDb to return links for this entry (both directions)
      when(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).thenAnswer((_) async => [link1, link2]);

      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'host1': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

      // Create the JSON file so it can be read
      const jsonPath = '/test/path.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      const message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: VectorClock({'host1': 1}),
        status: SyncEntryStatus.initial,
      );

      await service.enqueueMessage(message);

      // Verify links were fetched
      verify(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).called(1);

      // Verify logging shows embedded links count
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: contains(
              'enqueueMessage.attachedLinks id=$entryId count=2 embedded=2 from=1 to=1',
            ),
          ),
          subDomain: 'enqueueMessage.attachLinks',
        ),
      ).called(1);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncJournalEntity'),
              contains('embeddedLinks=2'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);

      // Verify the message was encoded with embedded links
      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      final companion = captured.first as OutboxCompanion;
      final encodedMessage =
          json.decode(companion.message.value) as Map<String, dynamic>;
      expect(encodedMessage['entryLinks'], hasLength(2));
      final entryLinks = encodedMessage['entryLinks'] as List<dynamic>;
      final entryLinkIds = entryLinks
          .map((entry) => (entry as Map<String, dynamic>)['id'])
          .toList();
      expect(entryLinkIds, containsAll([link1.id, link2.id]));
    });

    test('continues without links when linksForEntryIds fails', () async {
      const entryId = 'entry-456';

      // Mock journalDb.linksForEntryIdsBidirectional to throw an error
      when(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).thenThrow(Exception('Database error'));

      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'host1': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

      // Create the JSON file so it can be read
      const jsonPath = '/test/path2.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      const message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: VectorClock({'host1': 1}),
        status: SyncEntryStatus.initial,
      );

      // Should not throw
      await service.enqueueMessage(message);

      // Verify exception was logged
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Exception>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'enqueueMessage.fetchLinks',
        ),
      ).called(1);

      // Verify message was still enqueued (without links)
      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      final companion = captured.first as OutboxCompanion;
      final encodedMessage =
          json.decode(companion.message.value) as Map<String, dynamic>;
      expect(encodedMessage['entryLinks'], isNull);
    });

    test('does not log attachedLinks when no links found', () async {
      const entryId = 'entry-789';

      // Mock journalDb to return empty list
      when(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).thenAnswer((_) async => []);

      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'host1': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

      // Create the JSON file so it can be read
      const jsonPath = '/test/path3.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      const message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: VectorClock({'host1': 1}),
        status: SyncEntryStatus.initial,
      );

      await service.enqueueMessage(message);

      // Verify links were fetched
      verify(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).called(1);

      // Verify attachedLinks log was NOT called (no links to attach)
      verifyNever(
        () => loggingService.log(
          any<LogDomain>(),
          any<String>(that: contains('enqueueMessage.attachedLinks')),
          subDomain: any(named: 'subDomain'),
        ),
      );

      // Verify no-links log was emitted
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('enqueueMessage.noLinks id=$entryId')),
          subDomain: 'enqueueMessage.attachLinks',
        ),
      ).called(1);

      // Verify embeddedLinks=0 in the log
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf([
              contains('type=SyncJournalEntity'),
              contains('embeddedLinks=0'),
            ]),
          ),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });
  });

  group('EntryLink sequence log recording -', () {
    late MockSyncSequenceLogService sequenceLogService;
    late OutboxService serviceWithSequenceLog;

    setUp(() {
      sequenceLogService = MockSyncSequenceLogService();
      registerFallbackValue(const VectorClock({'fallback': 1}));
    });

    tearDown(() async {
      await serviceWithSequenceLog.dispose();
    });

    test(
      'records entry link in sequence log when vectorClock present',
      () async {
        const vc = VectorClock({'host-A': 10});
        final link = SyncMessage.entryLink(
          entryLink: EntryLink.basic(
            id: 'link-seq-1',
            fromId: 'A',
            toId: 'B',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: vc,
          ),
          status: SyncEntryStatus.initial,
        );

        when(
          () => sequenceLogService.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenAnswer((_) async {});

        serviceWithSequenceLog = buildSequenceLogService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          gate: createGate(),
          sequenceLogService: sequenceLogService,
        );

        await serviceWithSequenceLog.enqueueMessage(link);

        verify(
          () => sequenceLogService.recordSentEntryLink(
            linkId: 'link-seq-1',
            vectorClock: vc,
          ),
        ).called(1);
      },
    );

    test('skips sequence log recording when vectorClock is null', () async {
      final link = SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: 'link-no-vc',
          fromId: 'X',
          toId: 'Y',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          vectorClock: null,
        ),
        status: SyncEntryStatus.initial,
      );

      serviceWithSequenceLog = buildSequenceLogService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        gate: createGate(),
        sequenceLogService: sequenceLogService,
      );

      await serviceWithSequenceLog.enqueueMessage(link);

      // Should NOT call recordSentEntryLink
      verifyNever(
        () => sequenceLogService.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      );
    });

    test('handles recordSentEntryLink errors gracefully', () async {
      const vc = VectorClock({'host-B': 5});
      final link = SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: 'link-error',
          fromId: 'P',
          toId: 'Q',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          vectorClock: vc,
        ),
        status: SyncEntryStatus.initial,
      );

      when(
        () => sequenceLogService.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenThrow(Exception('sequence log error'));

      serviceWithSequenceLog = buildSequenceLogService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        gate: createGate(),
        sequenceLogService: sequenceLogService,
      );

      // Should not throw
      await serviceWithSequenceLog.enqueueMessage(link);

      // Verify exception was logged
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'recordSent',
        ),
      ).called(1);
    });

    test('skips recording when sequenceLogService is null', () async {
      const vc = VectorClock({'host-C': 7});
      final link = SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: 'link-no-service',
          fromId: 'M',
          toId: 'N',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          vectorClock: vc,
        ),
        status: SyncEntryStatus.initial,
      );

      // Service without sequenceLogService
      serviceWithSequenceLog = buildSequenceLogService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        gate: createGate(),
        // No sequenceLogService
      );

      // Should not throw and not attempt to record
      await serviceWithSequenceLog.enqueueMessage(link);

      // sequenceLogService is null so this is effectively a no-op test
      // Verify the message was still enqueued (logging event)
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('type=SyncEntryLink')),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });
  });

  group('Agent sequence log recording -', () {
    late MockSyncSequenceLogService sequenceLogService;
    late OutboxService serviceWithSequenceLog;

    setUp(() {
      sequenceLogService = MockSyncSequenceLogService();
      registerFallbackValue(const VectorClock({'fallback': 1}));
      registerFallbackValue(SyncSequencePayloadType.journalEntity);
    });

    tearDown(() async {
      await serviceWithSequenceLog.dispose();
    });

    test(
      'records agent entity in sequence log when vectorClock present',
      () async {
        const vc = VectorClock({'host-A': 10});
        final entity = AgentDomainEntity.agent(
          id: 'agent-seq-1',
          agentId: 'agent-seq-1',
          kind: 'task_agent',
          displayName: 'Test',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );

        when(
          () => sequenceLogService.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async {});

        serviceWithSequenceLog = buildSequenceLogService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          gate: createGate(),
          sequenceLogService: sequenceLogService,
        );

        await serviceWithSequenceLog.enqueueMessage(message);

        verify(
          () => sequenceLogService.recordSentEntry(
            entryId: 'agent-seq-1',
            vectorClock: vc,
            payloadType: SyncSequencePayloadType.agentEntity,
          ),
        ).called(1);
      },
    );

    test(
      'records agent link in sequence log when vectorClock present',
      () async {
        const vc = VectorClock({'host-B': 5});
        final link = AgentLink.basic(
          id: 'link-seq-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
        );

        when(
          () => sequenceLogService.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async {});

        serviceWithSequenceLog = buildSequenceLogService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          gate: createGate(),
          sequenceLogService: sequenceLogService,
        );

        await serviceWithSequenceLog.enqueueMessage(message);

        verify(
          () => sequenceLogService.recordSentEntry(
            entryId: 'link-seq-1',
            vectorClock: vc,
            payloadType: SyncSequencePayloadType.agentLink,
          ),
        ).called(1);
      },
    );

    test('skips agent entity recording when vectorClock is null', () async {
      final entity = AgentDomainEntity.agent(
        id: 'agent-no-vc',
        agentId: 'agent-no-vc',
        kind: 'task_agent',
        displayName: 'No VC',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      serviceWithSequenceLog = buildSequenceLogService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        repository: repository,
        messageSender: messageSender,
        processor: processor,
        gate: createGate(),
        sequenceLogService: sequenceLogService,
      );

      await serviceWithSequenceLog.enqueueMessage(message);

      verifyNever(
        () => sequenceLogService.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      );
    });

    test(
      'handles recordSentEntry errors gracefully for agent entity',
      () async {
        const vc = VectorClock({'host-C': 3});
        final entity = AgentDomainEntity.agent(
          id: 'agent-err',
          agentId: 'agent-err',
          kind: 'task_agent',
          displayName: 'Err',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );

        when(
          () => sequenceLogService.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenThrow(Exception('sequence log error'));

        serviceWithSequenceLog = buildSequenceLogService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          gate: createGate(),
          sequenceLogService: sequenceLogService,
        );

        // Should not throw
        await serviceWithSequenceLog.enqueueMessage(message);

        // Verify exception was logged
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordSent',
          ),
        ).called(1);
      },
    );
  });

  group('Message preparation', () {
    test('prepareJournalEntity adds originatingHostId when null', () async {
      const entryId = 'entry-with-no-host';
      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'hostA': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      // Create JSON file on disk (required by readEntityFromJson)
      final jsonPath = relativeEntityPath(journalEntity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      // Mock journalEntityById to return the entity
      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

      final message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: const VectorClock({'hostA': 1}),
        status: SyncEntryStatus.initial,
        // originatingHostId is null
      );

      await service.enqueueMessage(message);

      // Verify the message was enqueued with originatingHostId set
      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      expect(decodedMessage, isA<SyncJournalEntity>());
      final journalMsg = decodedMessage as SyncJournalEntity;
      // hostA is the mock value returned by vectorClockService.getHost()
      expect(journalMsg.originatingHostId, 'hostA');
    });

    test('prepareJournalEntity preserves existing originatingHostId', () async {
      const entryId = 'entry-with-existing-host';
      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'hostA': 1}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      // Create JSON file on disk
      final jsonPath = relativeEntityPath(journalEntity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

      final message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: const VectorClock({'hostA': 1}),
        status: SyncEntryStatus.initial,
        originatingHostId: 'originalHost', // Already set
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      final journalMsg = decodedMessage as SyncJournalEntity;
      // Should preserve the original value, not overwrite
      expect(journalMsg.originatingHostId, 'originalHost');
    });

    test('prepareJournalEntity merges coveredVectorClocks', () async {
      const entryId = 'entry-for-vc-merge';
      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'hostA': 3}),
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      // Create JSON file on disk
      final jsonPath = relativeEntityPath(journalEntity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

      final message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: const VectorClock({'hostA': 3}),
        status: SyncEntryStatus.update,
        coveredVectorClocks: const [
          VectorClock({'hostA': 1}),
          VectorClock({'hostA': 2}),
        ],
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      final journalMsg = decodedMessage as SyncJournalEntity;
      // Should have all 3 VCs merged (1, 2, and the current 3)
      expect(journalMsg.coveredVectorClocks, isNotNull);
      expect(journalMsg.coveredVectorClocks!.length, 3);
    });

    test('prepareEntryLink adds originatingHostId when null', () async {
      final link = EntryLink.basic(
        id: 'link-no-host',
        fromId: 'entry-A',
        toId: 'entry-B',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: const VectorClock({'hostA': 1}),
      );

      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
        // originatingHostId is null
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      final linkMsg = decodedMessage as SyncEntryLink;
      expect(linkMsg.originatingHostId, 'hostA');
    });

    test('prepareEntryLink merges coveredVectorClocks', () async {
      final link = EntryLink.basic(
        id: 'link-for-vc-merge',
        fromId: 'entry-A',
        toId: 'entry-B',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        vectorClock: const VectorClock({'hostA': 3}),
      );

      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.update,
        coveredVectorClocks: const [
          VectorClock({'hostA': 1}),
          VectorClock({'hostA': 2}),
        ],
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      final linkMsg = decodedMessage as SyncEntryLink;
      expect(linkMsg.coveredVectorClocks, isNotNull);
      expect(linkMsg.coveredVectorClocks!.length, 3);
    });

    test('prepareMessage passes through non-entity messages unchanged', () async {
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Light',
        darkThemeName: 'Dark',
        themeMode: 'system',
        updatedAt: DateTime(2025, 1, 1).millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;

      final companion = captured.first as OutboxCompanion;
      final decodedMessage = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );

      // Should be unchanged (no originatingHostId or coveredVectorClocks added)
      expect(decodedMessage, isA<SyncThemingSelection>());
      final themingMsg = decodedMessage as SyncThemingSelection;
      expect(themingMsg.lightThemeName, 'Light');
      expect(themingMsg.darkThemeName, 'Dark');
    });

    test(
      'SyncAgentEntity enqueues with correct subject and saves JSON',
      () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-xyz',
          agentId: 'agent-xyz',
          kind: 'task_agent',
          displayName: 'Test',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );

        await service.enqueueMessage(message);

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured.length, 1);

        final companion = captured.first as OutboxCompanion;
        expect(companion.subject.value, 'agentEntity:agent-xyz');
        expect(companion.outboxEntryId.value, 'agent-xyz');

        // Verify JSON was saved to disk
        final expectedPath =
            '${documentsDirectory.path}/agent_entities/agent-xyz.json';
        expect(File(expectedPath).existsSync(), isTrue);

        // Verify the enriched message has jsonPath set
        final storedMessage =
            SyncMessage.fromJson(
                  json.decode(companion.message.value) as Map<String, dynamic>,
                )
                as SyncAgentEntity;
        expect(storedMessage.jsonPath, '/agent_entities/agent-xyz.json');

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: allOf([
                contains('type=SyncAgentEntity'),
                contains('subject=agentEntity:agent-xyz'),
              ]),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
      },
    );

    test('SyncAgentEntity merges with existing pending item', () async {
      final entity = AgentDomainEntity.agent(
        id: 'agent-xyz',
        agentId: 'agent-xyz',
        kind: 'task_agent',
        displayName: 'Updated',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      when(() => syncDatabase.findPendingByEntryId('agent-xyz')).thenAnswer(
        (_) async => OutboxItem(
          id: 42,
          message: json.encode(message.toJson()),
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          subject: 'agentEntity:agent-xyz',
          priority: OutboxPriority.low.index,
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

      await service.enqueueMessage(message);

      verify(
        () => syncDatabase.updateOutboxMessage(
          itemId: 42,
          newMessage: any(named: 'newMessage'),
          newSubject: 'agentEntity:agent-xyz',
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
      verifyNever(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()));
    });

    test('SyncAgentEntity merge preserves coveredVectorClocks', () async {
      const oldVc = VectorClock({'hostA': 3});
      const newVc = VectorClock({'hostA': 5});

      final oldEntity = AgentDomainEntity.agent(
        id: 'agent-xyz',
        agentId: 'agent-xyz',
        kind: 'task_agent',
        displayName: 'Old',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: oldVc,
      );

      final oldMessage = SyncMessage.agentEntity(
        agentEntity: oldEntity,
        status: SyncEntryStatus.update,
      );

      when(() => syncDatabase.findPendingByEntryId('agent-xyz')).thenAnswer(
        (_) async => OutboxItem(
          id: 42,
          message: json.encode(oldMessage.toJson()),
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          subject: 'agentEntity:agent-xyz',
          priority: OutboxPriority.low.index,
        ),
      );

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

      final newEntity = AgentDomainEntity.agent(
        id: 'agent-xyz',
        agentId: 'agent-xyz',
        kind: 'task_agent',
        displayName: 'Updated',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-2',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: newVc,
      );

      final newMessage = SyncMessage.agentEntity(
        agentEntity: newEntity,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(newMessage);

      expect(capturedMessage, isNotNull);
      final decoded = SyncMessage.fromJson(
        json.decode(capturedMessage!) as Map<String, dynamic>,
      );
      expect(decoded, isA<SyncAgentEntity>());
      final agentMsg = decoded as SyncAgentEntity;
      expect(agentMsg.coveredVectorClocks, isNotNull);
      final coveredCounters = agentMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['hostA'])
          .whereType<int>()
          .toSet();
      expect(coveredCounters, containsAll([3, 5]));
      expect(coveredCounters, hasLength(2));
    });

    test(
      'SyncAgentEntity merge inserts fresh row when original no longer pending',
      () async {
        const oldVc = VectorClock({'hostA': 3});
        const newVc = VectorClock({'hostA': 5});

        final oldEntity = AgentDomainEntity.agent(
          id: 'agent-xyz',
          agentId: 'agent-xyz',
          kind: 'task_agent',
          displayName: 'Old',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: oldVc,
        );

        final oldMessage = SyncMessage.agentEntity(
          agentEntity: oldEntity,
          status: SyncEntryStatus.update,
        );

        when(() => syncDatabase.findPendingByEntryId('agent-xyz')).thenAnswer(
          (_) async => OutboxItem(
            id: 42,
            message: json.encode(oldMessage.toJson()),
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            subject: 'agentEntity:agent-xyz',
            priority: OutboxPriority.low.index,
          ),
        );

        // Simulate row no longer pending (already sent)
        when(
          () => syncDatabase.updateOutboxMessage(
            itemId: any(named: 'itemId'),
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => 0);

        final newEntity = AgentDomainEntity.agent(
          id: 'agent-xyz',
          agentId: 'agent-xyz',
          kind: 'task_agent',
          displayName: 'Updated',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-2',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: newVc,
        );

        final newMessage = SyncMessage.agentEntity(
          agentEntity: newEntity,
          status: SyncEntryStatus.update,
        );

        await service.enqueueMessage(newMessage);

        // updateOutboxMessage was attempted but returned 0
        verify(
          () => syncDatabase.updateOutboxMessage(
            itemId: 42,
            newMessage: any(named: 'newMessage'),
            newSubject: any(named: 'newSubject'),
            payloadSize: any(named: 'payloadSize'),
            priority: any(named: 'priority'),
          ),
        ).called(1);

        // Fresh row inserted as fallback
        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured, hasLength(1));
        final companion = captured.first as OutboxCompanion;
        expect(companion.outboxEntryId.value, 'agent-xyz');
        expect(companion.subject.value, 'agentEntity:agent-xyz');

        // Verify the inserted message has coveredVectorClocks
        final decoded = SyncMessage.fromJson(
          json.decode(companion.message.value) as Map<String, dynamic>,
        );
        expect(decoded, isA<SyncAgentEntity>());
        final agentMsg = decoded as SyncAgentEntity;
        expect(agentMsg.coveredVectorClocks, isNotNull);
        final coveredCounters = agentMsg.coveredVectorClocks!
            .map((vc) => vc.vclock['hostA'])
            .whereType<int>()
            .toSet();
        expect(coveredCounters, containsAll([3, 5]));
      },
    );

    test('SyncAgentLink merge preserves coveredVectorClocks', () async {
      const oldVc = VectorClock({'hostA': 10});
      const newVc = VectorClock({'hostA': 12});

      final oldLink = AgentLink.agentTask(
        id: 'link-abc',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: oldVc,
      );

      final oldMessage = SyncMessage.agentLink(
        agentLink: oldLink,
        status: SyncEntryStatus.update,
      );

      when(() => syncDatabase.findPendingByEntryId('link-abc')).thenAnswer(
        (_) async => OutboxItem(
          id: 43,
          message: json.encode(oldMessage.toJson()),
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          subject: 'agentLink:link-abc',
          priority: OutboxPriority.low.index,
        ),
      );

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

      final newLink = AgentLink.agentTask(
        id: 'link-abc',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: newVc,
      );

      final newMessage = SyncMessage.agentLink(
        agentLink: newLink,
        status: SyncEntryStatus.update,
      );

      await service.enqueueMessage(newMessage);

      expect(capturedMessage, isNotNull);
      final decoded = SyncMessage.fromJson(
        json.decode(capturedMessage!) as Map<String, dynamic>,
      );
      expect(decoded, isA<SyncAgentLink>());
      final linkMsg = decoded as SyncAgentLink;
      expect(linkMsg.coveredVectorClocks, isNotNull);
      final coveredCounters = linkMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['hostA'])
          .whereType<int>()
          .toSet();
      expect(coveredCounters, containsAll([10, 12]));
      expect(coveredCounters, hasLength(2));
    });

    test(
      'SyncAgentLink enqueues with correct subject and saves JSON',
      () async {
        final link = AgentLink.agentTask(
          id: 'link-abc',
          fromId: 'agent-1',
          toId: 'task-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
        );

        await service.enqueueMessage(message);

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured.length, 1);

        final companion = captured.first as OutboxCompanion;
        expect(companion.subject.value, 'agentLink:link-abc');
        expect(companion.outboxEntryId.value, 'link-abc');

        // Verify JSON was saved to disk
        final expectedPath =
            '${documentsDirectory.path}/agent_links/link-abc.json';
        expect(File(expectedPath).existsSync(), isTrue);

        // Verify the enriched message has jsonPath set
        final storedMessage =
            SyncMessage.fromJson(
                  json.decode(companion.message.value) as Map<String, dynamic>,
                )
                as SyncAgentLink;
        expect(storedMessage.jsonPath, '/agent_links/link-abc.json');

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: allOf([
                contains('type=SyncAgentLink'),
                contains('subject=agentLink:link-abc'),
              ]),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
      },
    );

    test('SyncAgentEntity skips enqueue when entity is null', () async {
      const message = SyncMessage.agentEntity(status: SyncEntryStatus.update);

      await service.enqueueMessage(message);

      verifyNever(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()));
      verify(
        () => loggingService.log(
          LogDomain.sync,
          'enqueue.skip agentEntity is null',
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('SyncAgentLink skips enqueue when link is null', () async {
      const message = SyncMessage.agentLink(status: SyncEntryStatus.update);

      await service.enqueueMessage(message);

      verifyNever(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()));
      verify(
        () => loggingService.log(
          LogDomain.sync,
          'enqueue.skip agentLink is null',
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
    });

    test('SyncAgentLink merges with existing pending item', () async {
      final link = AgentLink.agentTask(
        id: 'link-abc',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      when(() => syncDatabase.findPendingByEntryId('link-abc')).thenAnswer(
        (_) async => OutboxItem(
          id: 43,
          message: json.encode(message.toJson()),
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          subject: 'agentLink:link-abc',
          priority: OutboxPriority.low.index,
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

      await service.enqueueMessage(message);

      verify(
        () => syncDatabase.updateOutboxMessage(
          itemId: 43,
          newMessage: any(named: 'newMessage'),
          newSubject: 'agentLink:link-abc',
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
      verifyNever(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()));
    });

    test('SyncAgentEntity enqueues fallback when saveJson fails', () async {
      final failingService = buildService(
        activityGate: createGate(),
        ownsActivityGate: false,
        saveJsonHandler: (_, _) => Future.error(Exception('disk full')),
      );

      final entity = AgentDomainEntity.agent(
        id: 'fail-agent',
        agentId: 'fail-agent',
        kind: 'task_agent',
        displayName: 'Fail',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      await failingService.enqueueMessage(message);

      // Fallback item still enqueued
      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured.length, 1);

      final companion = captured.first as OutboxCompanion;
      expect(companion.subject.value, 'agentEntity:fail-agent');
      expect(companion.outboxEntryId.value, 'fail-agent');

      // Error was logged
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'enqueueMessage.saveAgentPayload',
        ),
      ).called(1);

      await failingService.dispose();
    });

    test(
      'an agent entity whose id escapes the documents root is skipped and '
      'logged — the unencoded agent path builder makes a traversal id reach '
      'the !isWithin guard, unlike notification paths which are URL-encoded',
      () async {
        // `relativeAgentEntityPath` does NOT URL-encode the id, so an id
        // with `../` segments produces a path that normalizes outside the
        // docs root and trips the `!p.isWithin` guard.
        final entity = AgentDomainEntity.agent(
          id: '../../escape',
          agentId: '../../escape',
          kind: 'task_agent',
          displayName: 'Escape',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        await service.enqueueMessage(
          SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          ),
        );

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: contains('enqueue.skip invalid agent payload path'),
            ),
            subDomain: 'enqueueMessage',
          ),
        ).called(1);
        // Nothing was persisted: the row is never created for an
        // out-of-root payload path.
        verifyNever(() => syncDatabase.addOutboxItem(any<OutboxCompanion>()));
      },
    );

    test('an agent merge whose existing row holds undecodable JSON is caught '
        'under enqueueMessage.agentMerge, logs the (no VC merge) fallback, and '
        'still updates the pending row', () async {
      const newVc = VectorClock({'hostA': 5});

      // Existing pending agent row with a corrupt message body so the
      // VC-merge `SyncMessage.fromJson` throws inside the agent merge try.
      when(() => syncDatabase.findPendingByEntryId('agent-xyz')).thenAnswer(
        (_) async => OutboxItem(
          id: 42,
          message: 'corrupt-agent-json{{{',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          subject: 'agentEntity:agent-xyz',
          priority: OutboxPriority.low.index,
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

      final entity = AgentDomainEntity.agent(
        id: 'agent-xyz',
        agentId: 'agent-xyz',
        kind: 'task_agent',
        displayName: 'Updated',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-2',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: newVc,
      );

      await service.enqueueMessage(
        SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        ),
      );

      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'enqueueMessage.agentMerge',
        ),
      ).called(1);
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('(no VC merge)')),
          subDomain: 'enqueueMessage',
        ),
      ).called(1);
      // The merge still proceeds (without merged covered clocks) and
      // updates the existing pending row rather than inserting fresh.
      verify(
        () => syncDatabase.updateOutboxMessage(
          itemId: 42,
          newMessage: any(named: 'newMessage'),
          newSubject: 'agentEntity:agent-xyz',
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
    });
  });

  group('links capped at maxEmbeddedEntryLinks -', () {
    test('when more than maxEmbeddedEntryLinks links exist, '
        'only the last maxEmbeddedEntryLinks are embedded', () async {
      const entryId = 'entry-many-links';
      final tooManyLinks = [
        for (var i = 0; i < SyncTuning.maxEmbeddedEntryLinks + 5; i++)
          EntryLink.basic(
            id: 'link-$i',
            fromId: entryId,
            toId: 'target-$i',
            createdAt: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
            vectorClock: null,
          ),
      ];

      when(
        () => journalDb.linksForEntryIdsBidirectional(const {entryId}),
      ).thenAnswer((_) async => tooManyLinks);

      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          dateFrom: DateTime(2025, 1, 1),
          dateTo: DateTime(2025, 1, 1),
          vectorClock: const VectorClock({'hostA': 1}),
        ),
        entryText: const EntryText(plainText: 'many links'),
      );

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

      const jsonPath = '/test/many-links.json';
      File('${documentsDirectory.path}$jsonPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      const message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: VectorClock({'hostA': 1}),
        status: SyncEntryStatus.initial,
      );

      await service.enqueueMessage(message);

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured, hasLength(1));
      final companion = captured.single as OutboxCompanion;
      final decoded =
          json.decode(companion.message.value) as Map<String, dynamic>;
      final entryLinks = decoded['entryLinks'] as List<dynamic>;
      // Capped to maxEmbeddedEntryLinks
      expect(entryLinks, hasLength(SyncTuning.maxEmbeddedEntryLinks));
      // Verify the log message shows the total count and capped count.
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: contains(
              'count=${SyncTuning.maxEmbeddedEntryLinks + 5} '
              'embedded=${SyncTuning.maxEmbeddedEntryLinks}',
            ),
          ),
          subDomain: 'enqueueMessage.attachLinks',
        ),
      ).called(1);
    });
  });

  group('JournalAudio attachment for initial status -', () {
    test(
      'JournalAudio with status=initial sets attachment path from AudioUtils',
      () async {
        const entryId = 'audio-entry-1';
        const audioDir = '/audio/recordings/';
        const audioFile = 'recording.aac';
        final meta = Metadata(
          id: entryId,
          createdAt: DateTime(2024, 3, 15, 10),
          updatedAt: DateTime(2024, 3, 15, 10),
          dateFrom: DateTime(2024, 3, 15, 10),
          dateTo: DateTime(2024, 3, 15, 11),
          vectorClock: const VectorClock({'hostA': 2}),
        );
        final journalAudio = JournalEntity.journalAudio(
          meta: meta,
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10),
            dateTo: DateTime(2024, 3, 15, 11),
            audioFile: audioFile,
            audioDirectory: audioDir,
            duration: const Duration(hours: 1),
          ),
        );

        when(
          () => journalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => journalAudio);

        // relativeEntityPath for JournalAudio = audioDir + audioFile + '.json'
        final jsonPath = relativeEntityPath(journalAudio);
        File('${documentsDirectory.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalAudio.toJson()));

        // Create a dummy audio file so File.length() succeeds.
        final audioFullPath = '${documentsDirectory.path}$audioDir$audioFile';
        File(audioFullPath)
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync([0, 1, 2, 3]);

        // jsonPath must match the file on disk — use relativeEntityPath.
        final message = SyncMessage.journalEntity(
          id: entryId,
          jsonPath: jsonPath,
          vectorClock: const VectorClock({'hostA': 2}),
          status: SyncEntryStatus.initial,
        );

        await service.enqueueMessage(message);

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured, hasLength(1));
        final companion = captured.single as OutboxCompanion;
        // Attachment path should be the relative audio path (non-null)
        expect(companion.filePath.present, isTrue);
        expect(companion.filePath.value, isNotNull);
        expect(companion.filePath.value, contains(audioDir));
        // payloadSize should include the 4-byte audio file
        expect(companion.payloadSize.value, greaterThan(0));
      },
    );

    test(
      'JournalAudio with status=update does NOT set attachment (no re-send)',
      () async {
        const entryId = 'audio-entry-update';
        const audioDir = '/audio/updates/';
        const audioFile = 'recording2.aac';
        final meta = Metadata(
          id: entryId,
          createdAt: DateTime(2024, 3, 15, 10),
          updatedAt: DateTime(2024, 3, 15, 10),
          dateFrom: DateTime(2024, 3, 15, 10),
          dateTo: DateTime(2024, 3, 15, 11),
          vectorClock: const VectorClock({'hostA': 3}),
        );
        final journalAudio = JournalEntity.journalAudio(
          meta: meta,
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10),
            dateTo: DateTime(2024, 3, 15, 11),
            audioFile: audioFile,
            audioDirectory: audioDir,
            duration: const Duration(hours: 1),
          ),
        );

        when(
          () => journalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => journalAudio);

        final jsonPath = relativeEntityPath(journalAudio);
        File('${documentsDirectory.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalAudio.toJson()));

        // Use the correct json path matching the entity on disk.
        final message = SyncMessage.journalEntity(
          id: entryId,
          jsonPath: jsonPath,
          vectorClock: const VectorClock({'hostA': 3}),
          status: SyncEntryStatus.update, // not initial → no attachment
        );

        await service.enqueueMessage(message);

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured, hasLength(1));
        final companion = captured.single as OutboxCompanion;
        // Status=update → no attachment path
        expect(
          companion.filePath.present && companion.filePath.value != null,
          isFalse,
        );
      },
    );
  });

  group('_enrichCoveredVcsFromSequenceLog path -', () {
    test('when getLastSentVectorClockForEntry returns a VC, it is merged into '
        'coveredVectorClocks for a new journal entity enqueue', () async {
      final sequenceLog = MockSyncSequenceLogService();
      const previousVc = VectorClock({'hostA': 1});
      const currentVc = VectorClock({'hostA': 2});

      when(
        () => sequenceLog.getLastSentVectorClockForEntry(any()),
      ).thenAnswer((_) async => previousVc);
      // Sequence log recording is also called; stub it.
      when(
        () => sequenceLog.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      const entryId = 'journal-seq-enrich';
      final journalEntity = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          vectorClock: currentVc,
        ),
        entryText: const EntryText(plainText: 'enriched'),
      );

      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => journalEntity);

      final jsonPath = relativeEntityPath(journalEntity);
      File('${documentsDirectory.path}$jsonPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

      final svc = buildService(
        activityGate: createGate(),
        ownsActivityGate: false,
        sequenceLogService: sequenceLog,
      );

      final message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: jsonPath,
        vectorClock: currentVc,
        status: SyncEntryStatus.initial,
      );

      await svc.enqueueMessage(message);
      await svc.dispose();

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured, hasLength(1));
      final companion = captured.single as OutboxCompanion;
      final decoded = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );
      expect(decoded, isA<SyncJournalEntity>());
      final journalMsg = decoded as SyncJournalEntity;
      // The previous VC from sequence log should appear in coveredVectorClocks.
      expect(journalMsg.coveredVectorClocks, isNotNull);
      final covered = journalMsg.coveredVectorClocks!;
      expect(
        covered.any((vc) => vc.vclock['hostA'] == 1),
        isTrue,
        reason: 'previousVc hostA:1 should be in coveredVectorClocks',
      );
    });

    test(
      'when getLastSentVectorClockForEntry returns null, coveredVectorClocks '
      'is unchanged (no enrichment performed)',
      () async {
        final sequenceLog = MockSyncSequenceLogService();
        const currentVc = VectorClock({'hostA': 5});

        when(
          () => sequenceLog.getLastSentVectorClockForEntry(any()),
        ).thenAnswer((_) async => null);
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async {});

        const entryId = 'journal-seq-no-enrich';
        final journalEntity = JournalEntity.journalEntry(
          meta: Metadata(
            id: entryId,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            vectorClock: currentVc,
          ),
          entryText: const EntryText(plainText: 'no enrich'),
        );

        when(
          () => journalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => journalEntity);

        final jsonPath = relativeEntityPath(journalEntity);
        File('${documentsDirectory.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

        final svc = buildService(
          activityGate: createGate(),
          ownsActivityGate: false,
          sequenceLogService: sequenceLog,
        );

        final message = SyncMessage.journalEntity(
          id: entryId,
          jsonPath: jsonPath,
          vectorClock: currentVc,
          status: SyncEntryStatus.initial,
        );

        await svc.enqueueMessage(message);
        await svc.dispose();

        verify(
          () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
        ).called(1);
      },
    );

    test(
      'enrichCoveredVcsFromSequenceLog error is caught and logged; '
      'original coveredVectorClocks returned unchanged for journal entity',
      () async {
        final sequenceLog = MockSyncSequenceLogService();
        const currentVc = VectorClock({'hostA': 9});

        when(
          () => sequenceLog.getLastSentVectorClockForEntry(any()),
        ).thenThrow(Exception('db read failed'));
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async {});

        const entryId = 'journal-seq-err';
        final journalEntity = JournalEntity.journalEntry(
          meta: Metadata(
            id: entryId,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            vectorClock: currentVc,
          ),
          entryText: const EntryText(plainText: 'err enrich'),
        );

        when(
          () => journalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => journalEntity);

        final jsonPath = relativeEntityPath(journalEntity);
        File('${documentsDirectory.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(journalEntity.toJson()));

        final svc = buildService(
          activityGate: createGate(),
          ownsActivityGate: false,
          sequenceLogService: sequenceLog,
        );

        final message = SyncMessage.journalEntity(
          id: entryId,
          jsonPath: jsonPath,
          vectorClock: currentVc,
          status: SyncEntryStatus.initial,
        );

        // Should not throw.
        await svc.enqueueMessage(message);
        await svc.dispose();

        // Error from getLastSentVectorClockForEntry is logged.
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'enrichCoveredVcs',
          ),
        ).called(1);
        // Item is still added.
        verify(
          () => syncDatabase.addOutboxItem(any<OutboxCompanion>()),
        ).called(1);
      },
    );
  });

  group('_enrichCoveredVcsFromSequenceLog for entry links -', () {
    test(
      'when getLastSentVectorClockForEntry returns a VC, it is merged into '
      'coveredVectorClocks for a new entry link enqueue (line 1374 path)',
      () async {
        final sequenceLog = MockSyncSequenceLogService();
        const previousVc = VectorClock({'hostA': 3});
        const currentVc = VectorClock({'hostA': 4});

        when(
          () => sequenceLog.getLastSentVectorClockForEntry(any()),
        ).thenAnswer((_) async => previousVc);
        when(
          () => sequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenAnswer((_) async {});

        final svc = buildService(
          activityGate: createGate(),
          ownsActivityGate: false,
          sequenceLogService: sequenceLog,
        );

        final link = SyncMessage.entryLink(
          entryLink: EntryLink.basic(
            id: 'link-enrich-1',
            fromId: 'entry-A',
            toId: 'entry-B',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: currentVc,
          ),
          status: SyncEntryStatus.initial,
        );

        await svc.enqueueMessage(link);
        await svc.dispose();

        final captured = verify(
          () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
        ).captured;
        expect(captured, hasLength(1));
        final companion = captured.single as OutboxCompanion;
        final decoded = SyncMessage.fromJson(
          json.decode(companion.message.value) as Map<String, dynamic>,
        );
        expect(decoded, isA<SyncEntryLink>());
        final linkMsg = decoded as SyncEntryLink;
        // The previous VC from sequence log should appear in coveredVectorClocks.
        expect(linkMsg.coveredVectorClocks, isNotNull);
        expect(
          linkMsg.coveredVectorClocks!.any((vc) => vc.vclock['hostA'] == 3),
          isTrue,
          reason: 'previousVc hostA:3 should be in coveredVectorClocks',
        );
      },
    );
  });

  group('agent payload enriched covered VCs from sequence log -', () {
    test('SyncAgentEntity new enqueue: getLastSentVectorClockForEntry merges '
        'into coveredVectorClocks (line 1851 branch)', () async {
      final sequenceLog = MockSyncSequenceLogService();
      const previousVc = VectorClock({'hostA': 7});
      const currentVc = VectorClock({'hostA': 8});

      when(
        () => sequenceLog.getLastSentVectorClockForEntry(any()),
      ).thenAnswer((_) async => previousVc);
      when(
        () => sequenceLog.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      final entity = AgentDomainEntity.agent(
        id: 'agent-enrich-1',
        agentId: 'agent-enrich-1',
        kind: 'task_agent',
        displayName: 'Enrich Test',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: currentVc,
      );

      final svc = buildService(
        activityGate: createGate(),
        ownsActivityGate: false,
        sequenceLogService: sequenceLog,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.initial,
      );

      await svc.enqueueMessage(message);
      await svc.dispose();

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured, hasLength(1));
      final companion = captured.single as OutboxCompanion;
      final decoded = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );
      expect(decoded, isA<SyncAgentEntity>());
      final agentMsg = decoded as SyncAgentEntity;
      // The enriched previous VC should appear in coveredVectorClocks.
      expect(agentMsg.coveredVectorClocks, isNotNull);
      expect(
        agentMsg.coveredVectorClocks!.any((vc) => vc.vclock['hostA'] == 7),
        isTrue,
        reason: 'previousVc hostA:7 should be in coveredVectorClocks',
      );
    });

    test('SyncAgentLink new enqueue: getLastSentVectorClockForEntry merges '
        'into coveredVectorClocks (line 1854 branch)', () async {
      final sequenceLog = MockSyncSequenceLogService();
      const previousVc = VectorClock({'hostA': 11});
      const currentVc = VectorClock({'hostA': 12});

      when(
        () => sequenceLog.getLastSentVectorClockForEntry(any()),
      ).thenAnswer((_) async => previousVc);
      when(
        () => sequenceLog.recordSentEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      final link = AgentLink.basic(
        id: 'agent-link-enrich-1',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: currentVc,
      );

      final svc = buildService(
        activityGate: createGate(),
        ownsActivityGate: false,
        sequenceLogService: sequenceLog,
      );

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.initial,
      );

      await svc.enqueueMessage(message);
      await svc.dispose();

      final captured = verify(
        () => syncDatabase.addOutboxItem(captureAny<OutboxCompanion>()),
      ).captured;
      expect(captured, hasLength(1));
      final companion = captured.single as OutboxCompanion;
      final decoded = SyncMessage.fromJson(
        json.decode(companion.message.value) as Map<String, dynamic>,
      );
      expect(decoded, isA<SyncAgentLink>());
      final linkMsg = decoded as SyncAgentLink;
      // The enriched previous VC should appear in coveredVectorClocks.
      expect(linkMsg.coveredVectorClocks, isNotNull);
      expect(
        linkMsg.coveredVectorClocks!.any((vc) => vc.vclock['hostA'] == 11),
        isTrue,
        reason: 'previousVc hostA:11 should be in coveredVectorClocks',
      );
    });

    test('SyncAgentEntity merge: oldCovered and newCovered both contribute to '
        'merged coveredVectorClocks (line 1728 merge block covered)', () async {
      const oldVc = VectorClock({'hostA': 2});
      const newVc = VectorClock({'hostA': 4});
      const oldCoveredVc = VectorClock({'hostA': 1});
      const newCoveredVc = VectorClock({'hostA': 3});

      final oldEntity = AgentDomainEntity.agent(
        id: 'agent-both-covered',
        agentId: 'agent-both-covered',
        kind: 'task_agent',
        displayName: 'Old',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: oldVc,
      );

      final oldMessage = SyncMessage.agentEntity(
        agentEntity: oldEntity,
        status: SyncEntryStatus.update,
        coveredVectorClocks: const [oldCoveredVc],
      );

      when(
        () => syncDatabase.findPendingByEntryId('agent-both-covered'),
      ).thenAnswer(
        (_) async => OutboxItem(
          id: 77,
          message: json.encode(oldMessage.toJson()),
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          subject: 'agentEntity:agent-both-covered',
          priority: OutboxPriority.normal.index,
        ),
      );

      String? capturedMsg;
      when(
        () => syncDatabase.updateOutboxMessage(
          itemId: any(named: 'itemId'),
          newMessage: any(named: 'newMessage'),
          newSubject: any(named: 'newSubject'),
          payloadSize: any(named: 'payloadSize'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((inv) async {
        capturedMsg = inv.namedArguments[#newMessage] as String?;
        return 1;
      });

      final newEntity = AgentDomainEntity.agent(
        id: 'agent-both-covered',
        agentId: 'agent-both-covered',
        kind: 'task_agent',
        displayName: 'New',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-2',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: newVc,
      );

      final newMessage = SyncMessage.agentEntity(
        agentEntity: newEntity,
        status: SyncEntryStatus.update,
        coveredVectorClocks: const [newCoveredVc],
      );

      await service.enqueueMessage(newMessage);

      expect(capturedMsg, isNotNull);
      final decoded = SyncMessage.fromJson(
        json.decode(capturedMsg!) as Map<String, dynamic>,
      );
      expect(decoded, isA<SyncAgentEntity>());
      final agentMsg = decoded as SyncAgentEntity;
      expect(agentMsg.coveredVectorClocks, isNotNull);
      final counters = agentMsg.coveredVectorClocks!
          .map((vc) => vc.vclock['hostA'])
          .whereType<int>()
          .toSet();
      // Should contain oldVc (2), newVc (4), oldCoveredVc (1), newCoveredVc (3)
      expect(counters, containsAll([1, 2, 3, 4]));
    });
  });
}
