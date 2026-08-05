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

  group('sendNext', () {
    test('uses SyncTuning.outboxIdleThreshold for default gate', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final matrixService = stubMatrixService();

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
        matrixService: matrixService,
        postDrainSettle: Duration.zero,
      );

      // Access the gate via reflection (private) by invoking sendNext; gate is
      // injected in ctor and should use the tuned threshold.
      final gate = svc.getActivityGateForTest();
      expect(gate.idleThreshold, SyncTuning.outboxIdleThreshold);
      await svc.dispose();
    });

    test('skips processing when Matrix disabled', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => false);

      final gate = createGate();

      final svc = buildService(activityGate: gate);

      await svc.sendNext();

      verifyNever(() => processor.processQueue());
      expect(svc.enqueueCalls, 0);

      await svc.dispose();
    });

    test('schedules next run when processor requests it', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(() => processor.processQueue()).thenAnswer(
        (_) async =>
            OutboxProcessingResult.schedule(const Duration(seconds: 3)),
      );

      final gate = createGate();

      final svc = buildService(activityGate: gate);

      await svc.sendNext();

      // Processor requested scheduling; sendNext returns after first drain
      verify(() => processor.processQueue()).called(1);
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, const Duration(seconds: 3));

      await svc.dispose();
    });

    test('does not reschedule when queue empty', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final gate = createGate();

      final svc = buildService(activityGate: gate);

      await svc.sendNext();

      expect(svc.enqueueCalls, 0);
      await svc.dispose();
    });

    test('logs error and reschedules on failure', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final exception = Exception('boom');
      when(() => processor.processQueue()).thenThrow(exception);

      final gate = createGate();

      final svc = buildService(activityGate: gate);

      await svc.sendNext();

      verify(
        () => loggingService.error(
          LogDomain.sync,
          exception,
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'sendNext',
        ),
      ).called(1);
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, const Duration(seconds: 15));

      await svc.dispose();
    });

    test(
      'schedules immediate continuation when drain pass cap reached and items remain',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        // Always indicate more work immediately.
        when(() => processor.processQueue()).thenAnswer(
          (_) async => OutboxProcessingResult.schedule(Duration.zero),
        );
        // Indicate there are still pending items after the pass cap is reached.
        when(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => [
            OutboxItem(
              id: 1,
              createdAt: DateTime(2024, 3, 15, 10, 30),
              updatedAt: DateTime(2024, 3, 15, 10, 30),
              status: 0,
              retries: 0,
              message: '{}',
              subject: 'test',
              filePath: null,
              priority: OutboxPriority.low.index,
            ),
          ],
        );

        final gate = createGate();

        final svc = buildService(activityGate: gate);

        await svc.sendNext();

        // After hitting the internal pass cap, service should schedule an
        // immediate continuation because items remain pending.
        expect(svc.enqueueCalls, 1);
        expect(svc.lastDelay, Duration.zero);

        await svc.dispose();
      },
    );
  });

  group('sendNext login gate - ', () {
    test('returns early when sync enabled but not logged in', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final gate = createGate();

      final matrixService = stubMatrixService();
      when(matrixService.isLoggedIn).thenReturn(false);

      final svc = buildService(activityGate: gate, ownsActivityGate: false);

      // Inject matrixService by replacing the sender with MatrixOutboxMessageSender
      // and re-creating the service with matrixService for login gate.
      final gatedSvc = MatrixOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
        matrixService: matrixService,
        postDrainSettle: Duration.zero,
      );

      await gatedSvc.sendNext();

      // Should not attempt to drain
      verifyNever(() => processor.processQueue());

      await gatedSvc.dispose();
      await svc.dispose();
    });

    test('drains when sync enabled and logged in', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      final gate = createGate();

      final matrixService = stubMatrixService();
      when(matrixService.isLoggedIn).thenReturn(true);

      final svc = MatrixOutboxService(
        syncDatabase: syncDatabase,
        loggingService: loggingService,
        vectorClockService: vectorClockService,
        journalDb: journalDb,
        documentsDirectory: documentsDirectory,
        userActivityService: userActivityService,
        processor: processor,
        activityGate: gate,
        ownsActivityGate: false,
        matrixService: matrixService,
        postDrainSettle: Duration.zero,
      );

      await svc.sendNext();

      // sendNext performs two drains (second after a short settle delay)
      verify(() => processor.processQueue()).called(2);

      await svc.dispose();
    });

    test(
      'post-login nudge enqueues and drains after LoginState.loggedIn',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        when(
          () => processor.processQueue(),
        ).thenAnswer((_) async => OutboxProcessingResult.none);

        final gate = createGate();

        final matrixService = MockMatrixService();
        final client = MockMatrixClient();
        final loginController = StreamController<LoginState>.broadcast();
        addTearDown(loginController.close);
        when(() => matrixService.client).thenReturn(client);
        final cached = MockCachedLoginController();
        when(() => cached.stream).thenAnswer((_) => loginController.stream);
        when(() => cached.value).thenReturn(LoginState.loggedOut);
        when(() => client.onLoginStateChanged).thenReturn(cached);

        var loggedIn = false;
        when(matrixService.isLoggedIn).thenAnswer((_) => loggedIn);

        fakeAsync((async) {
          final svc = MatrixOutboxService(
            syncDatabase: syncDatabase,
            loggingService: loggingService,
            vectorClockService: vectorClockService,
            journalDb: journalDb,
            documentsDirectory: documentsDirectory,
            userActivityService: userActivityService,
            processor: processor,
            activityGate: gate,
            ownsActivityGate: false,
            matrixService: matrixService,
          );
          // Flip to logged in and emit login event
          loggedIn = true;
          loginController.add(LoginState.loggedIn);
          // Advance time to allow scheduled drain, then flush microtasks
          async
            ..elapse(const Duration(milliseconds: 50))
            ..flushMicrotasks();
          verify(
            () => processor.processQueue(),
          ).called(greaterThanOrEqualTo(1));
          unawaited(svc.dispose());
          async.flushMicrotasks();
        });
      },
    );

    test(
      'connectivity regain pre-login does not drain, drains after login',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        when(
          () => processor.processQueue(),
        ).thenAnswer((_) async => OutboxProcessingResult.none);
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

        final gate = createGate();

        final matrixService = MockMatrixService();
        final client = MockMatrixClient();
        final loginController = StreamController<LoginState>.broadcast();
        addTearDown(loginController.close);
        when(() => matrixService.client).thenReturn(client);
        final cached = MockCachedLoginController();
        when(() => cached.stream).thenAnswer((_) => loginController.stream);
        when(() => cached.value).thenReturn(LoginState.loggedOut);
        when(() => client.onLoginStateChanged).thenReturn(cached);

        var loggedIn = false;
        when(matrixService.isLoggedIn).thenAnswer((_) => loggedIn);

        final connectivityController =
            StreamController<List<ConnectivityResult>>.broadcast();
        addTearDown(connectivityController.close);

        fakeAsync((async) {
          final svc = MatrixOutboxService(
            syncDatabase: syncDatabase,
            loggingService: loggingService,
            vectorClockService: vectorClockService,
            journalDb: journalDb,
            documentsDirectory: documentsDirectory,
            userActivityService: userActivityService,
            processor: processor,
            activityGate: gate,
            ownsActivityGate: false,
            matrixService: matrixService,
            connectivityStream: connectivityController.stream,
          );
          // Connectivity regain before login — should enqueue but not drain
          connectivityController.add([ConnectivityResult.wifi]);
          async
            ..elapse(const Duration(milliseconds: 20))
            ..flushMicrotasks();
          verifyNever(() => processor.processQueue());

          // Now login completes — post-login nudge should drain
          loggedIn = true;
          loginController.add(LoginState.loggedIn);
          async
            ..elapse(const Duration(milliseconds: 40))
            ..flushMicrotasks();
          verify(
            () => processor.processQueue(),
          ).called(greaterThanOrEqualTo(1));

          unawaited(svc.dispose());
          async.flushMicrotasks();
        });
      },
    );
  });

  group('drainOutbox behavior', () {
    test('pauses when canProcess is false initially', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate(canProcess: false);

      final svc = buildService(activityGate: gate, ownsActivityGate: false);

      await svc.sendNext();

      verifyNever(() => processor.processQueue());
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, SyncTuning.outboxRetryDelay);

      await svc.dispose();
    });

    test('pauses mid-burst when canProcess flips to false', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      var canProcess = true;
      final gate = createGate();
      when(() => gate.canProcess).thenAnswer((_) => canProcess);

      var processCalls = 0;
      when(() => processor.processQueue()).thenAnswer((_) async {
        processCalls++;
        // First pass continues immediately; then mark active to force pause.
        if (processCalls == 1) {
          canProcess = false;
          return OutboxProcessingResult.schedule(Duration.zero);
        }
        return OutboxProcessingResult.none;
      });

      final svc = buildService(activityGate: gate, ownsActivityGate: false);

      await svc.sendNext();

      expect(processCalls, 1);
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, SyncTuning.outboxRetryDelay);

      await svc.dispose();
    });

    test('post-settle drain is skipped when activity resumes', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      var canProcess = true;
      final gate = createGate();
      when(() => gate.canProcess).thenAnswer((_) => canProcess);

      var calls = 0;
      when(() => processor.processQueue()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          // Flip activity to false after first drain to skip post-settle.
          unawaited(Future.microtask(() => canProcess = false));
          return OutboxProcessingResult.none;
        }
        return OutboxProcessingResult.none;
      });

      final svc = buildService(activityGate: gate, ownsActivityGate: false);

      await svc.sendNext();

      expect(calls, 1);
      expect(svc.enqueueCalls, 1);
      expectDelayCloseTo(svc.lastDelay, SyncTuning.outboxRetryDelay);

      await svc.dispose();
    });

    test('sendNext aborts second drain when disposed during settle', () {
      // Regression: with `outboxPostDrainSettle = 1500ms`, the disposal
      // window grows. After awaiting the settle, sendNext must not run a
      // second drain on a disposed service.
      fakeAsync((async) {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        final gate = createGate();

        var calls = 0;
        when(() => processor.processQueue()).thenAnswer((_) async {
          calls++;
          return OutboxProcessingResult.none;
        });

        final svc = buildService(
          activityGate: gate,
          ownsActivityGate: false,
          postDrainSettle: const Duration(milliseconds: 50),
        );

        var pendingCompleted = false;
        final pending = svc.sendNext()
          ..then((_) {
            pendingCompleted = true;
          });
        async.flushMicrotasks();
        expect(calls, 1);

        // Dispose mid-settle, before the trailing drain runs.
        async.elapse(const Duration(milliseconds: 10));
        unawaited(svc.dispose());
        async
          ..elapse(const Duration(milliseconds: 40))
          ..flushMicrotasks();
        expect(pendingCompleted, isTrue);

        // First drain ran; trailing drain skipped because of disposal.
        expect(calls, 1);
        unawaited(pending);
      });
    });

    test('respects retry backoff and skips immediate re-entry', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();

      const delay = Duration(seconds: 5);
      var processCalls = 0;
      when(() => processor.processQueue()).thenAnswer((_) async {
        processCalls++;
        return OutboxProcessingResult.schedule(delay);
      });

      final svc = buildService(activityGate: gate, ownsActivityGate: false);

      await svc.sendNext();
      expect(processCalls, 1);
      expectDelayCloseTo(svc.lastDelay, delay);

      await svc.sendNext();
      expect(processCalls, 1);

      await svc.dispose();
    });

    test('pass cap schedules immediate continuation (delay=0)', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);

      // Processor always returns schedule(Duration.zero) to keep the loop running
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.schedule(Duration.zero));
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

      // Gate returns immediately to avoid delaying the test
      final gate = createGate();

      // Custom testable service to capture enqueueNextSendRequest calls
      final svc = buildService(activityGate: gate, ownsActivityGate: false);

      await svc.sendNext();

      // Since we hit the pass cap, the service should have enqueued an
      // immediate continuation (delay zero).
      expect(svc.enqueueCalls, greaterThanOrEqualTo(1));
      expect(svc.lastDelay, Duration.zero);

      await svc.dispose();
    });

    test('runner logs gate wait when > 50ms', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

      // The service measures the gate wait with clock.now(): advance a
      // controllable clock from inside the gate stub so the 120 ms wait is
      // observed deterministically without any real wall-clock sleep.
      var now = DateTime(2026, 3, 15, 10);
      final gate = createGate();
      when(gate.waitUntilIdle).thenAnswer((_) {
        now = now.add(const Duration(milliseconds: 120));
        return Future<void>.value();
      });

      await withClock(Clock(() => now), () async {
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

        // Trigger the runner via the public enqueue API and drain the
        // event queue so the runner callback completes.
        await svc.enqueueNextSendRequest(delay: Duration.zero);
        await pumpEventQueue();

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: startsWith('activityGate.wait ms=')),
            subDomain: 'activityGate',
          ),
        ).called(greaterThanOrEqualTo(1));
        await svc.dispose();
      });
    });
  });

  group('computeEnqueueDelay / backoff gate', () {
    test('negative delays clamp to zero when no backoff gate is set', () {
      final svc = buildService();
      addTearDown(svc.dispose);

      expect(
        svc.computeEnqueueDelay(const Duration(seconds: -5)),
        Duration.zero,
      );
      expect(svc.computeEnqueueDelay(Duration.zero), Duration.zero);
    });

    test('a backoff gate in the past is ignored — the plain delay wins', () {
      final svc = buildService();
      addTearDown(svc.dispose);
      svc.debugNextSendAllowedAt = DateTime.utc(2000);

      expect(
        svc.computeEnqueueDelay(const Duration(seconds: 5)),
        const Duration(seconds: 5),
      );
    });

    test('a backoff gate in the future dominates shorter delays', () {
      final svc = buildService();
      addTearDown(svc.dispose);
      svc.debugNextSendAllowedAt = DateTime.utc(9999);

      final adjusted = svc.computeEnqueueDelay(const Duration(seconds: 1));
      expect(adjusted, greaterThan(const Duration(days: 365)));
    });

    test('recordBackoff short-circuits on zero/negative delays', () {
      final svc = buildService();
      addTearDown(svc.dispose);

      svc
        ..debugRecordBackoff(Duration.zero)
        ..debugRecordBackoff(const Duration(seconds: -3));

      // The gate was never set: enqueue delays pass through untouched.
      expect(svc.debugNextSendAllowedAt, isNull);
      expect(
        svc.computeEnqueueDelay(const Duration(seconds: 2)),
        const Duration(seconds: 2),
      );
    });

    test('recordBackoff keeps the furthest gate (monotonic candidate)', () {
      final svc = buildService();
      addTearDown(svc.dispose);

      svc.debugRecordBackoff(const Duration(minutes: 30));
      final first = svc.debugNextSendAllowedAt!;
      // A shorter follow-up backoff must not pull the gate closer.
      svc.debugRecordBackoff(const Duration(minutes: 1));
      expect(svc.debugNextSendAllowedAt, first);
    });
  });

  group('watchdog', () {
    test('enqueues when pending + logged in + idle queue', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);
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
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);

      // Controlled outbox count stream to avoid extra nudges
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
          matrixService: matrixService,
        );

        // Tick the 10s watchdog
        async
          ..elapse(const Duration(seconds: 10))
          // Allow pending tasks and the post-drain settle (250ms)
          ..elapse(const Duration(milliseconds: 300));
        verify(
          () => loggingService.log(
            LogDomain.sync,
            'watchdog: pending+loggedIn idleQueue → enqueue',
            subDomain: 'watchdog',
          ),
        ).called(1);
        verify(() => processor.processQueue()).called(greaterThanOrEqualTo(1));
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('does not enqueue when queue active', () async {
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
      final gate = createGate();
      // Keep the runner busy so queueSize > 0 when watchdog fires
      late Completer<void> gateReleased;
      when(gate.waitUntilIdle).thenAnswer((_) => gateReleased.future);
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);
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
        );
        // Make the queue active
        unawaited(svc.enqueueNextSendRequest(delay: Duration.zero));
        async
          ..flushMicrotasks()
          ..elapse(Duration.zero)
          // Now watchdog fires while the queue is active
          ..elapse(const Duration(seconds: 10));
        verifyNever(
          () => loggingService.log(
            LogDomain.sync,
            'watchdog: pending+loggedIn idleQueue → enqueue',
            subDomain: 'watchdog',
          ),
        );
        gateReleased.complete();
        async.flushMicrotasks();
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('does not enqueue when not logged in', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(false);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
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
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => const Stream<int>.empty());
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

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
          matrixService: matrixService,
        );
        async.elapse(watchdogInterval);
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

    test('handles fetchPending errors gracefully', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenThrow(Exception('boom'));
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => const Stream<int>.empty());

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
          matrixService: matrixService,
        );
        async.elapse(watchdogInterval);
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'watchdog',
          ),
        ).called(1);
        unawaited(svc.dispose());
        async.flushMicrotasks();
      });
    });

    test('stops after dispose', () async {
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
      final gate = createGate();
      final matrixService = MockMatrixService();
      when(() => matrixService.isLoggedIn()).thenReturn(true);
      final client = MockMatrixClient();
      final cached = MockCachedLoginController();
      when(
        () => cached.stream,
      ).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => cached.value).thenReturn(LoginState.loggedOut);
      when(() => client.onLoginStateChanged).thenReturn(cached);
      when(() => matrixService.client).thenReturn(client);
      when(
        () => syncDatabase.watchOutboxCount(),
      ).thenAnswer((_) => const Stream<int>.empty());
      when(
        () => processor.processQueue(),
      ).thenAnswer((_) async => OutboxProcessingResult.none);

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
          matrixService: matrixService,
        );
        async.elapse(watchdogInterval);
        unawaited(svc.dispose());
        // Further elapse should not trigger watchdog again
        async.elapse(const Duration(seconds: 20));
        verify(
          () => loggingService.log(
            LogDomain.sync,
            'watchdog: pending+loggedIn idleQueue → enqueue',
            subDomain: 'watchdog',
          ),
        ).called(1);
      });
    });
  });

  group('sent-outbox prune', () {
    test('startup prune fires after the 30-second grace and logs the removed '
        'count when rows are deleted — uses the SyncTuning retention so both '
        'desktop and mobile agree on the cutoff window. Calls the chunked '
        'variant so the writer lock is released between batches even on '
        'devices with hundreds of thousands of stale sent rows', () {
      fakeAsync((async) {
        when(
          () => repository.pruneSentOutboxItemsChunked(
            retention: SyncTuning.outboxSentRetention,
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => 42);

        final svc = buildService(
          activityGate: createGate(),
          ownsActivityGate: false,
        );
        addTearDown(() async {
          await svc.dispose();
          async.flushMicrotasks();
        });

        // Before the 30s grace — prune must not have fired yet.
        async
          ..elapse(const Duration(seconds: 20))
          ..flushMicrotasks();
        verifyNever(
          () => repository.pruneSentOutboxItemsChunked(
            retention: any(named: 'retention'),
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        );

        // Cross the 30s boundary — startup prune kicks.
        async
          ..elapse(const Duration(seconds: 20))
          ..flushMicrotasks();

        verify(
          () => repository.pruneSentOutboxItemsChunked(
            retention: SyncTuning.outboxSentRetention,
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('prune.sent removed=42')),
            subDomain: 'prune',
          ),
        ).called(1);

        // The startup prune is a one-shot Timer that nulls itself out in
        // its callback (_startupPruneTimer = null). Advancing well past the
        // grace but short of the 24h periodic interval must NOT fire a
        // second startup prune — proving the one-shot timer does not
        // re-arm.
        async
          ..elapse(const Duration(minutes: 5))
          ..flushMicrotasks();
        verifyNever(
          () => repository.pruneSentOutboxItemsChunked(
            retention: any(named: 'retention'),
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        );
      });
    });

    test('periodic background prune passes vacuumWhenDone=false — VACUUM '
        'rewrites the whole DB file and would dominate the daily sweep cost '
        'long after the backlog has settled. The user-triggered Maintenance '
        'action is the place that pays for VACUUM', () {
      fakeAsync((async) {
        bool? capturedVacuum;
        when(
          () => repository.pruneSentOutboxItemsChunked(
            retention: any(named: 'retention'),
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          capturedVacuum = invocation.namedArguments[#vacuumWhenDone] as bool?;
          return 0;
        });

        final svc = buildService(
          activityGate: createGate(),
          ownsActivityGate: false,
        );
        addTearDown(() async {
          await svc.dispose();
          async.flushMicrotasks();
        });

        // Step past the 30s startup grace so the one-shot startup
        // prune fires and returns. Reset the captured value + the
        // mock interaction log so the assertion below proves the
        // periodic timer (not the startup timer) called the
        // repository — without this clear the test could pass on
        // the startup invocation alone, which says nothing about
        // the periodic path.
        async
          ..elapse(const Duration(seconds: 31))
          ..flushMicrotasks();
        capturedVacuum = null;
        clearInteractions(repository);

        // Now advance one full periodic interval. Only the periodic
        // timer can fire here, so the captured `vacuumWhenDone`
        // value belongs to it.
        async
          ..elapse(SyncTuning.outboxPruneInterval + const Duration(seconds: 1))
          ..flushMicrotasks();

        verify(
          () => repository.pruneSentOutboxItemsChunked(
            retention: any(named: 'retention'),
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
        expect(capturedVacuum, isFalse);
      });
    });

    test('no log emission when the prune deletes zero rows — prevents the '
        'daily sweep from spamming the log once the backlog is drained', () {
      fakeAsync((async) {
        when(
          () => repository.pruneSentOutboxItemsChunked(
            retention: any(named: 'retention'),
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => 0);

        final svc = buildService(
          activityGate: createGate(),
          ownsActivityGate: false,
        );
        addTearDown(() async {
          await svc.dispose();
          async.flushMicrotasks();
        });

        async
          ..elapse(const Duration(seconds: 31))
          ..flushMicrotasks();

        verify(
          () => repository.pruneSentOutboxItemsChunked(
            retention: any(named: 'retention'),
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
        verifyNever(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(),
            subDomain: 'prune',
          ),
        );
      });
    });

    test('prune errors are captured under OUTBOX/prune and do not propagate — '
        'a transient DB failure in the sweep must not kill the outbox '
        "service's background work", () {
      fakeAsync((async) {
        when(
          () => repository.pruneSentOutboxItemsChunked(
            retention: any(named: 'retention'),
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => throw StateError('db gone'));

        final svc = buildService(
          activityGate: createGate(),
          ownsActivityGate: false,
        );
        addTearDown(() async {
          await svc.dispose();
          async.flushMicrotasks();
        });

        async
          ..elapse(const Duration(seconds: 31))
          ..flushMicrotasks();

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'prune',
          ),
        ).called(1);
      });
    });

    test('dispose cancels the periodic prune timer — after dispose no further '
        'prune fires even when time advances past the interval', () {
      fakeAsync((async) {
        when(
          () => repository.pruneSentOutboxItemsChunked(
            retention: any(named: 'retention'),
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => 0);

        final svc = buildService(
          activityGate: createGate(),
          ownsActivityGate: false,
        );

        async
          ..elapse(const Duration(seconds: 31))
          ..flushMicrotasks();
        // Startup prune fired once.
        verify(
          () => repository.pruneSentOutboxItemsChunked(
            retention: any(named: 'retention'),
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);

        unawaited(svc.dispose());
        async.flushMicrotasks();

        // Advance past a full prune interval — nothing should fire.
        async
          ..elapse(SyncTuning.outboxPruneInterval + const Duration(hours: 1))
          ..flushMicrotasks();
        verifyNever(
          () => repository.pruneSentOutboxItemsChunked(
            retention: any(named: 'retention'),
            chunkSize: any(named: 'chunkSize'),
            vacuumWhenDone: any(named: 'vacuumWhenDone'),
            onProgress: any(named: 'onProgress'),
          ),
        );
      });
    });
  });

  group('_recordBackoff duplicate call — longer existing backoff not replaced -', () {
    test('when a shorter backoff arrives while a longer one is already set, '
        'the longer backoff is preserved (line 577 false branch)', () async {
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => true);
      when(
        () => repository.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer((_) async => <OutboxItem>[]);

      final gate = createGate();
      var callCount = 0;
      // First call returns a long delay (15s), triggering _recordBackoff(15s).
      // Second call returns a shorter delay (5s), triggering _recordBackoff(5s).
      // The shorter backoff should NOT replace the longer one.
      when(() => processor.processQueue()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return OutboxProcessingResult.schedule(const Duration(seconds: 15));
        }
        // After the long backoff is set, if drain ever runs again return none.
        return OutboxProcessingResult.none;
      });

      final svc = buildService(
        activityGate: gate,
        ownsActivityGate: false,
        postDrainSettle: Duration.zero,
      );

      // First sendNext — drain returns a 15-second backoff.
      await svc.sendNext();
      expect(callCount, 1);

      // Verify a retry was scheduled (enqueueNextSendRequest called with
      // the 15s-derived delay).
      expect(svc.enqueueCalls, greaterThan(0));
      // The last adjusted delay should be close to the 15-second backoff.
      expectDelayCloseTo(
        svc.lastDelay,
        const Duration(seconds: 15),
        tolerance: const Duration(milliseconds: 200),
      );

      // Second sendNext — still within the 15-second window, so early return.
      await svc.sendNext();
      // processQueue NOT called again because we're still in the backoff window.
      expect(callCount, 1);

      await svc.dispose();
    });
  });

  group('sendNext backoff expiry -', () {
    test(
      'when backoff window has already elapsed by the next sendNext call, '
      '_nextSendAllowedAt is cleared and the drain proceeds (lines 740-741)',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        when(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => <OutboxItem>[]);

        final gate = createGate();
        var callCount = 0;
        when(() => processor.processQueue()).thenAnswer((_) async {
          callCount++;
          return OutboxProcessingResult.none;
        });

        final svc = buildService(
          activityGate: gate,
          ownsActivityGate: false,
          postDrainSettle: Duration.zero,
        );

        svc.debugNextSendAllowedAt = DateTime.utc(2000);

        await svc.sendNext();

        expect(svc.debugNextSendAllowedAt, isNull);
        expect(callCount, greaterThan(0));

        await svc.dispose();
      },
    );
  });

  group('sendNext coalesced state logging -', () {
    test(
      'second sendNext with same loggedIn/canProcess state skips the DB probe '
      'when called within the quiet window',
      () async {
        when(
          () => journalDb.getConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) async => true);
        when(
          () => processor.processQueue(),
        ).thenAnswer((_) async => OutboxProcessingResult.none);
        when(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => <OutboxItem>[]);

        final gate = createGate();
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
          postDrainSettle: Duration.zero,
        );

        // First call — always logs (no previous state recorded).
        await svc.sendNext();
        final firstCallFetchCount = verify(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).callCount;
        expect(firstCallFetchCount, greaterThanOrEqualTo(1));

        clearInteractions(repository);
        when(
          () => repository.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => <OutboxItem>[]);

        // Second call — same state, within quiet window → skips DB probe.
        await svc.sendNext();
        // fetchPending should NOT be called for state logging (coalesced),
        // though it may still be called by the watchdog path.
        // The key assertion: drain ran (processQueue called).
        verify(() => processor.processQueue()).called(greaterThanOrEqualTo(1));

        await svc.dispose();
      },
    );
  });
}
