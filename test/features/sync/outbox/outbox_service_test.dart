// ignore_for_file: avoid_redundant_argument_values, unnecessary_lambdas, cascade_invocations

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
    await harness.tearDown();
  });

  test('dispose closes owned activity gate', () async {
    final ownedGate = MockUserActivityGate();
    when(ownedGate.waitUntilIdle).thenAnswer((_) async {});
    when(ownedGate.dispose).thenAnswer((_) async {});

    final serviceOwned = MatrixOutboxService(
      syncDatabase: syncDatabase,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      repository: repository,
      messageSender: messageSender,
      processor: processor,
      activityGate: ownedGate,
      ownsActivityGate: true,
    );

    await serviceOwned.dispose();

    verify(ownedGate.dispose).called(1);
  });

  test('dispose does not close externally provided activity gate', () async {
    final externalGate = MockUserActivityGate();
    when(externalGate.waitUntilIdle).thenAnswer((_) async {});
    when(externalGate.dispose).thenAnswer((_) async {});

    final serviceExternal = MatrixOutboxService(
      syncDatabase: syncDatabase,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      repository: repository,
      messageSender: messageSender,
      processor: processor,
      activityGate: externalGate,
    );

    await serviceExternal.dispose();

    verifyNever(externalGate.dispose);
  });

  test('throws when neither matrix service nor message sender provided', () {
    expect(
      () => MatrixOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
      ),
      throwsArgumentError,
    );
  });

  test('constructs with matrixService fallback sender', () async {
    final matrixService = stubMatrixService();

    final serviceWithMatrix = MatrixOutboxService(
      syncDatabase: syncDatabase,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      matrixService: matrixService,
    );

    await serviceWithMatrix.dispose();
  });

  test('MatrixOutboxMessageSender delegates to MatrixService', () async {
    final matrixService = MockMatrixService();
    const message = SyncMessage.aiConfigDelete(id: 'abc');
    when(
      () => matrixService.sendMatrixMsg(message),
    ).thenAnswer((_) async => true);

    final sender = MatrixOutboxMessageSender(matrixService);

    final result = await sender.send(message);

    expect(result, isTrue);
    verify(() => matrixService.sendMatrixMsg(message)).called(1);
  });

  group('dbNudge', () {
    test('enqueues when count increases (>0)', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        final svc = MatrixOutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
        );

        countController.add(5);
        // Debounce delay is 50ms
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();
        verify(
          () => loggingService.log(
            LogDomain.sync,
            'dbNudge count=5 → enqueue',
            subDomain: 'dbNudge',
          ),
        ).called(1);
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('coalesces repeat counts within the quiet window: logs once per '
        'magnitude-bucket transition, not once per stream event', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        final svc = MatrixOutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
        );

        // First tick at count=1 crosses the "first-seen" / count=1 bucket.
        countController.add(1);
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();
        // Same-bucket tick shortly after: must not log again.
        countController.add(2);
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();
        countController.add(3);
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();
        // Crossing into the >=10 bucket: must log.
        countController.add(12);
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();

        final logged = verify(
          () => loggingService.log(
            LogDomain.sync,
            captureAny<String>(that: startsWith('dbNudge count=')),
            subDomain: 'dbNudge',
          ),
        ).captured;
        expect(
          logged,
          equals(<String>[
            'dbNudge count=1 → enqueue',
            'dbNudge count=12 → enqueue',
          ]),
          reason:
              'Only bucket transitions (first-seen, crossing >=10) '
              'should log within the coalesce window',
        );

        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('ignores count <= 0', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        final svc = MatrixOutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
        );

        countController.add(0);
        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();
        verifyNever(
          () => loggingService.log(
            any<LogDomain>(),
            any<String>(that: startsWith('dbNudge')),
            subDomain: any(named: 'subDomain'),
          ),
        );
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('stops after dispose', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        final svc = MatrixOutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
        );
        unawaited(svc.dispose());
        countController.add(2);
        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();
        verifyNever(
          () => loggingService.log(
            any<LogDomain>(),
            any<String>(that: startsWith('dbNudge')),
            subDomain: any(named: 'subDomain'),
          ),
        );
      });
    });

    test('handles stream errors without crashing the test', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

      fakeAsync((async) {
        Object? capturedError;
        StackTrace? capturedSt;
        OutboxService? svc;
        runZonedGuarded(
          () {
            svc = MatrixOutboxService(
              syncDatabase: syncDatabase,
              loggingService: loggingService,
              vectorClockService: vectorClockService,
              journalDb: journalDb,
              documentsDirectory: documentsDirectory,
              userActivityService: userActivityService,
              repository: repository,
              messageSender: messageSender,
              processor: processor,
              activityGate: gate,
              ownsActivityGate: false,
            );
            countController.addError(Exception('stream error'));
          },
          (e, st) {
            capturedError = e;
            capturedSt = st;
          },
        );
        // Allow the stream error to propagate
        async.flushMicrotasks();
        expect(capturedError, isNotNull);
        expect(capturedSt, isNotNull);
        unawaited(svc!.dispose());
        async.flushMicrotasks();
      });
    });
  });

  group('integration: triggers interplay', () {
    test('watchdog does not duplicate work when dbNudge already active', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      // One pending item in repository
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          OutboxItem(
            id: 42,
            message: '{}',
            subject: 's',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            filePath: null,
            priority: OutboxPriority.low.index,
          ),
        ],
      );

      // Gate delays long enough so watchdog fires while runner is active
      final gate = createGate();
      late Completer<void> gateReleased;
      when(gate.waitUntilIdle).thenAnswer((_) => gateReleased.future);

      final matrixService = stubMatrixService(loginState: LoginState.loggedIn);
      when(() => matrixService.isLoggedIn()).thenReturn(true);

      // Track db count stream
      final countController = StreamController<int>.broadcast();
      addTearDown(countController.close);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => countController.stream);

      // Processor returns none for each drain (sendNext runs two drains per invocation)
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      fakeAsync((async) {
        gateReleased = Completer<void>();
        final svc = MatrixOutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          repository: repository,
          messageSender: messageSender,
          processor: processor,
          activityGate: gate,
          ownsActivityGate: false,
          matrixService: matrixService,
          postDrainSettle: Duration.zero,
        );

        // T=0: DB nudge fires → schedules enqueue after 50ms
        countController.add(1);
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();

        // T=10s: Watchdog fires while runner is still blocked in waitUntilIdle
        async.elapse(watchdogInterval);

        // Let the runner finish and the second drain occur after settle
        gateReleased.complete();
        async
          ..flushMicrotasks()
          ..elapse(Duration.zero)
          ..flushMicrotasks();

        // Exactly one runner invocation → two drains
        verify(() => processor.processQueue()).called(2);
        // Watchdog must not enqueue when queue active → no watchdog enqueue log
        verifyNever(
          () => loggingService.log(
            LogDomain.sync,
            'watchdog: pending+loggedIn idleQueue → enqueue',
            subDomain: 'watchdog',
          ),
        );

        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test(
      'connectivity + login + watchdog dont cause triple processing',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        when(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => [
            OutboxItem(
              id: 1,
              message: '{}',
              subject: 's',
              status: OutboxStatus.pending.index,
              retries: 0,
              createdAt: DateTime(2024, 3, 15, 10, 30),
              updatedAt: DateTime(2024, 3, 15, 10, 30),
              filePath: null,
              priority: OutboxPriority.low.index,
            ),
          ],
        );
        when(
          () => processor.processQueue(),
        ).thenAnswer((_) async => OutboxProcessingResult.none);

        // Long wait to keep the queue active till after watchdog
        final gate = createGate();
        late Completer<void> gateReleased;
        when(gate.waitUntilIdle).thenAnswer((_) => gateReleased.future);

        final matrixService = MockMatrixService();
        final client = MockMatrixClient();
        final loginController = StreamController<LoginState>.broadcast();
        addTearDown(loginController.close);
        when(() => matrixService.client).thenReturn(client);
        final cached = MockCachedLoginController();
        when(() => cached.stream).thenAnswer((_) => loginController.stream);
        when(() => cached.value).thenReturn(LoginState.loggedOut);
        when(() => client.onLoginStateChanged).thenReturn(cached);
        when(() => matrixService.isLoggedIn()).thenReturn(false);

        final connectivityController =
            StreamController<List<ConnectivityResult>>.broadcast();
        addTearDown(connectivityController.close);

        // DB count stream inert for this test
        when(
          () => syncDatabase.watchOutboxCount(),
        ).thenAnswer((_) => const Stream<int>.empty());

        fakeAsync((async) {
          gateReleased = Completer<void>();
          final svc = MatrixOutboxService(
            syncDatabase: syncDatabase,
            loggingService: loggingService,
            vectorClockService: vectorClockService,
            journalDb: journalDb,
            documentsDirectory: documentsDirectory,
            userActivityService: userActivityService,
            repository: repository,
            messageSender: messageSender,
            processor: processor,
            activityGate: gate,
            ownsActivityGate: false,
            matrixService: matrixService,
            connectivityStream: connectivityController.stream,
          );

          // T=0: Connectivity regain → enqueue
          connectivityController.add([ConnectivityResult.wifi]);
          async.flushMicrotasks();

          // T=10ms: Login completes → enqueue
          when(() => matrixService.isLoggedIn()).thenReturn(true);
          loginController.add(LoginState.loggedIn);
          async.flushMicrotasks();

          // T=10s: Watchdog fires while queue active → should not enqueue
          async.elapse(watchdogInterval);

          // Allow runner completion and second drains
          gateReleased.complete();
          async
            ..flushMicrotasks()
            ..elapse(Duration.zero)
            ..flushMicrotasks();

          // Upper bound: two drains per runner invocation, at most two runner
          // callbacks (connectivity + login) = 4 drains total. Not 6+.
          verify(() => processor.processQueue()).called(lessThanOrEqualTo(4));
          verifyNever(
            () => loggingService.log(
              LogDomain.sync,
              'watchdog: pending+loggedIn idleQueue → enqueue',
              subDomain: 'watchdog',
            ),
          );

          unawaited(svc.dispose());
          async.flushMicrotasks();
        });
      },
    );

    test(
      'dbNudge during watchdog fetchPending does not duplicate excessively',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        when(
          () => processor.processQueue(),
        ).thenAnswer((_) async => OutboxProcessingResult.none);
        // Slow fetchPending simulates overlap window with dbNudge
        late Completer<List<OutboxItem>> fetchPending;
        when(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) => fetchPending.future);
        final pendingItems = [
          OutboxItem(
            id: 7,
            message: '{}',
            subject: 's',
            status: OutboxStatus.pending.index,
            retries: 0,
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            filePath: null,
            priority: OutboxPriority.low.index,
          ),
        ];

        // Gate immediate
        final gate = createGate();

        final matrixService = stubMatrixService(
          loginState: LoginState.loggedIn,
        );
        when(() => matrixService.isLoggedIn()).thenReturn(true);

        // DB count stream for nudge
        final countController = StreamController<int>.broadcast();
        addTearDown(countController.close);
        when(
          () => syncDatabase.watchOutboxCount(),
        ).thenAnswer((_) => countController.stream);

        fakeAsync((async) {
          fetchPending = Completer<List<OutboxItem>>();
          final svc = MatrixOutboxService(
            syncDatabase: syncDatabase,
            loggingService: loggingService,
            vectorClockService: vectorClockService,
            journalDb: journalDb,
            documentsDirectory: documentsDirectory,
            userActivityService: userActivityService,
            repository: repository,
            messageSender: messageSender,
            processor: processor,
            activityGate: gate,
            ownsActivityGate: false,
            matrixService: matrixService,
          );

          // T=10s: Watchdog fires and begins slow fetchPending
          async.elapse(watchdogInterval);
          // T=10s+20ms: DB nudge enqueues while watchdog is in-flight
          async.elapse(const Duration(milliseconds: 20));
          countController.add(1);
          // Let debounce (50ms) + remaining watchdog (30ms) pass
          async.elapse(const Duration(milliseconds: 80));
          async.flushMicrotasks();

          // Allow drains to complete
          fetchPending.complete(pendingItems);
          async.flushMicrotasks();

          // Should not explode in duplicate processing; 4 drains is an upper bound here
          verify(() => processor.processQueue()).called(lessThanOrEqualTo(4));
          unawaited(svc.dispose());
          async.flushMicrotasks();
        });
      },
    );
  });

  group('notLoggedInGateStream -', () {
    test(
      'notLoggedInGateStream getter is accessible on the service and returns '
      'a broadcast stream',
      () async {
        final stream = service.notLoggedInGateStream;
        expect(stream.isBroadcast, isTrue);

        final first = stream.listen((_) {});
        final second = stream.listen((_) {});
        await first.cancel();
        await second.cancel();
      },
    );

    test('notLoggedInGateStream does not emit inside startup grace window even '
        'when not logged in and pending items exist', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);

      final pendingItem = OutboxItem(
        id: 2,
        message: '{}',
        subject: 's',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        filePath: null,
        priority: OutboxPriority.low.index,
      );
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer((_) async => [pendingItem]);

      final matrixService = stubMatrixService();
      when(matrixService.isLoggedIn).thenReturn(false);

      final svc = MatrixOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        processor: processor,
        activityGate: createGate(),
        ownsActivityGate: false,
        matrixService: matrixService,
        postDrainSettle: Duration.zero,
      );

      final events = <void>[];
      final sub = svc.notLoggedInGateStream.listen(events.add);

      // Within grace window (service just created) — no emission.
      await svc.sendNext();

      expect(events, isEmpty);

      await sub.cancel();
      await svc.dispose();
    });

    test('notLoggedInGateStream DOES emit once the startup grace elapsed and '
        'pending items exist', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);

      final pendingItem = OutboxItem(
        id: 2,
        message: '{}',
        subject: 's',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        filePath: null,
        priority: OutboxPriority.low.index,
      );
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer((_) async => [pendingItem]);

      final matrixService = stubMatrixService();
      when(matrixService.isLoggedIn).thenReturn(false);

      // Drive the grace window with a controllable clock: construct the
      // service at t0, then call sendNext after the 5 s grace elapsed.
      var now = DateTime(2026, 3, 15, 10);
      await withClock(Clock(() => now), () async {
        final svc = MatrixOutboxService(
          syncDatabase: syncDatabase,
          loggingService: loggingService,
          vectorClockService: vectorClockService,
          journalDb: journalDb,
          documentsDirectory: documentsDirectory,
          userActivityService: userActivityService,
          processor: processor,
          activityGate: createGate(),
          ownsActivityGate: false,
          matrixService: matrixService,
          // Past the grace window the gate path queries pending items
          // through the repository before emitting.
          repository: repository,
          postDrainSettle: Duration.zero,
        );

        final events = <void>[];
        final sub = svc.notLoggedInGateStream.listen(events.add);

        now = now.add(const Duration(seconds: 6));
        await svc.sendNext();
        // Let the broadcast stream deliver.
        await Future<void>.value();

        expect(events, hasLength(1));

        await sub.cancel();
        await svc.dispose();
      });
    });
  });

  group('outbox bundling wiring', () {
    test(
      'enqueueMessage(SyncOutboxBundle) throws StateError to the caller — '
      'the early guard rejects the invariant breach instead of swallowing '
      'it inside the routine enqueue try/catch, so a buggy caller fails '
      'loudly in tests/CI rather than producing a silent drop in prod',
      () async {
        await expectLater(
          service.enqueueMessage(const SyncMessage.outboxBundle(children: [])),
          throwsStateError,
        );
        verifyNever(() => syncDatabase.addOutboxItem(any()));
      },
    );
  });
}
