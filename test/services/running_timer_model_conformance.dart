part of 'time_service_test.dart';

// Model conformance with specs/tla/RunningTimer.tla: the running timer on
// one device, under fake time — the app's TimeService as it is wired
// (buildPersistingTimeService: persistRunningTimerEnd on autosave, replace
// and stop), the real PersistenceLogic over an in-memory JournalDb, and the
// task agent's real TimeEntryHandler.
//
// The user starts a timer (UserStart: the entry is created and the timer
// started, as EntryCreationService does) and stops it from the entry page
// (EntryController.save writes the end, then the timer stops without
// writing it again), from the sidebar or by switching profiles (stop), or by
// quitting the app (ServiceDisposer's first step: stop). Time passes in
// minutes, across the autosave cadence (Tick, Autosave). The app can die
// (Crash): its timer is gone with nothing written, and it restarts with a
// fresh TimeService. The agent's tool starts a timer (AgentStart), or does
// while the user starts one between the tool's check and its start
// (agentRace: the user's start lands on the tool's read of the task).
//
// After every step the trace checks what the model does:
//   NoLostTime        every timer stopped has its entry end when it stopped
//   CrashLossBounded  a timer lost to a crash ends within one autosave
//                     interval of the crash
//   NoStolenTimer     the agent's tool never replaces the user's timer

enum _TimerOp {
  userStart,
  wait,
  stopEntry,
  stopSidebar,
  close,
  crash,
  agentStart,
  agentRace,
}

class _TimerStep {
  const _TimerStep(this.op, this.arg);

  factory _TimerStep.decode(int code) => _TimerStep(
    _TimerOp.values[code % _TimerOp.values.length],
    code ~/ _TimerOp.values.length,
  );

  final _TimerOp op;

  /// How long a wait lasts.
  final int arg;

  @override
  String toString() => '${op.name}($arg)';
}

extension _AnyTimerTrace on glados.Any {
  glados.Generator<List<_TimerStep>> get timerTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        12,
        glados.IntAnys(this).intInRange(0, _TimerOp.values.length * 8),
      )
      .map((codes) => [for (final code in codes) _TimerStep.decode(code)]);
}

/// A [JournalDb] that runs an action right after the next read of one row —
/// the agent's tool reading the task, between its check and its start.
class _RacingJournalDb extends JournalDb {
  _RacingJournalDb() : super(inMemoryDatabase: true, background: false);

  ({String id, Future<void> Function() action})? _armed;

  void arm(String id, Future<void> Function() action) =>
      _armed = (id: id, action: action);

  void disarm() => _armed = null;

  /// The stored row, read without running anything.
  Future<JournalEntity?> peek(String id) => super.journalEntityById(id);

  @override
  Future<JournalEntity?> journalEntityById(String id) async {
    final read = await super.journalEntityById(id);
    final armed = _armed;
    if (armed != null && armed.id == id) {
      _armed = null;
      await armed.action();
    }
    return read;
  }
}

class _TimerBench {
  _TimerBench(this.async, this.db);

  final FakeAsync async;
  final _RacingJournalDb db;
  final PersistenceLogic persistence = getIt<PersistenceLogic>();
  late TimeService timeService;
  late TimeEntryHandler handler;
  late Task source;

  /// Ghosts: when each timer stopped, and when each was lost to a crash.
  final stoppedAt = <String, DateTime>{};
  final crashedAt = <String, DateTime>{};

  /// Ghost: the agent's tool replaced the user's timer.
  bool stolen = false;
  var _made = 0;

  /// Waits for [future] in fake time, without moving the clock.
  T settle<T>(Future<T> future) {
    var done = false;
    late T value;
    Object? error;
    StackTrace? trace;
    future.then(
      (v) {
        value = v;
        done = true;
      },
      onError: (Object e, StackTrace s) {
        error = e;
        trace = s;
        done = true;
      },
    );
    for (var i = 0; i < 200 && !done; i++) {
      async
        ..flushMicrotasks()
        ..elapse(Duration.zero);
    }
    if (error case final Object e) Error.throwWithStackTrace(e, trace!);
    expect(done, isTrue, reason: 'the step completes');
    return value;
  }

  void setUp() {
    _boot();
    final meta = settle(persistence.createMetadata());
    source = testTask.copyWith(meta: meta);
    expect(settle(persistence.createDbEntity(source)), isTrue);
  }

  /// A fresh process: the app's TimeService and the agent's tool over it.
  void _boot() {
    timeService = buildPersistingTimeService();
    handler = TimeEntryHandler(
      persistenceLogic: persistence,
      journalDb: db,
      timeService: timeService,
    );
  }

  String? get _running => timeService.getCurrent()?.id;

  void _stopped(String? id) {
    if (id != null) stoppedAt[id] = clock.now();
  }

  /// EntryCreationService's timer: a new entry, linked to the task, then
  /// the timer — which stops a running one first, writing its end.
  Future<void> _userStart() async {
    final running = _running;
    final entry = JournalEntity.journalEntry(
      meta: await persistence.createMetadata(),
      entryText: EntryText(plainText: 'session ${++_made}'),
    );
    expect(
      await persistence.createDbEntity(entry, linkedId: source.id),
      isTrue,
    );
    await timeService.start(entry, source);
    _stopped(running);
  }

  String _localNow() {
    final now = clock.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}T'
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  Future<ToolExecutionResult> _agentStart() => handler.handle(source.id, {
    'startTime': _localNow(),
    'summary': 'Agent session ${++_made}',
  });

  void run(_TimerStep step) {
    switch (step.op) {
      case _TimerOp.userStart:
        settle(_userStart());
      case _TimerOp.wait:
        async.elapse(Duration(minutes: 1 + step.arg % 7));
      case _TimerOp.stopEntry:
        // EntryController.save(stopRecording: true): the end and the
        // editor's text written, then the timer stopped.
        final running = _running;
        if (running == null) return;
        settle(
          persistence.updateJournalEntityText(
            running,
            const EntryText(plainText: 'stopped from its page'),
            clock.now(),
          ),
        );
        settle(timeService.stop(persistEnd: false));
        _stopped(running);
      case _TimerOp.stopSidebar || _TimerOp.close:
        // The sidebar's stop, a profile switch and the app's shutdown all
        // stop the timer through TimeService.stop.
        final running = _running;
        settle(timeService.stop());
        _stopped(running);
      case _TimerOp.crash:
        // The process dies: its timer and their timers go, nothing written.
        final running = _running;
        settle(timeService.stop(persistEnd: false));
        if (running != null) crashedAt[running] = clock.now();
        _boot();
      case _TimerOp.agentStart:
        final running = _running;
        final result = settle(_agentStart());
        if (running != null) {
          expect(result.success, isFalse, reason: 'a timer runs already');
          expect(_running, running);
        }
      case _TimerOp.agentRace:
        // The user starts a timer between the tool's check and its start.
        if (_running != null) return;
        String? users;
        db.arm(source.id, () async {
          await _userStart();
          users = _running;
        });
        settle(_agentStart());
        db.disarm();
        if (users != null && _running != users) {
          stolen = true;
          _stopped(users);
        }
    }
  }

  void check(List<_TimerStep> trace) {
    for (final MapEntry(key: id, value: at) in stoppedAt.entries) {
      final stored = settle(db.peek(id))!;
      expect(
        stored.meta.dateTo,
        at,
        reason: 'NoLostTime ($id stopped at $at): $trace',
      );
    }
    for (final MapEntry(key: id, value: at) in crashedAt.entries) {
      final stored = settle(db.peek(id))!;
      expect(
        at.difference(stored.meta.dateTo),
        lessThanOrEqualTo(runningTimerAutosaveInterval),
        reason: 'CrashLossBounded ($id crashed at $at): $trace',
      );
    }
    expect(stolen, isFalse, reason: 'NoStolenTimer: $trace');
  }
}

void _registerRunningTimerConformance() {
  group('RunningTimer model conformance', () {
    setUpAll(registerAllFallbackValues);

    void replay(List<_TimerStep> trace) {
      fakeAsync((async) {
        final db = _RacingJournalDb();
        final settingsDb = SettingsDb(inMemoryDatabase: true);
        final editorState = MockEditorStateService();
        when(() => editorState.draftOn(any(), any())).thenReturn(null);
        when(
          () => editorState.rebaseDraft(
            id: any(named: 'id'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        ).thenAnswer((_) async {});
        final updateNotifications = MockUpdateNotifications();
        when(
          () => updateNotifications.updateStream,
        ).thenAnswer((_) => const Stream<Set<String>>.empty());
        final fts5Db = MockFts5Db();
        when(
          () => fts5Db.insertText(any(), removePrevious: true),
        ).thenAnswer((_) async {});
        final outbox = MockOutboxService();
        when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
        final notifications = MockNotificationService();
        when(notifications.updateBadge).thenAnswer((_) async {});

        void put<T extends Object>(T instance) {
          if (getIt.isRegistered<T>()) getIt.unregister<T>();
          getIt.registerSingleton<T>(instance);
        }

        put<JournalDb>(db);
        put<SettingsDb>(settingsDb);
        put<UpdateNotifications>(updateNotifications);
        put<Fts5Db>(fts5Db);
        put<OutboxService>(outbox);
        put<NotificationService>(notifications);
        put<EditorStateService>(editorState);
        put<VectorClockService>(VectorClockService(settingsDb: settingsDb));
        put<MetadataService>(
          MetadataService(vectorClockService: getIt<VectorClockService>()),
        );
        put<GeolocationService>(MockGeolocationService());
        put<PersistenceLogic>(buildPersistenceLogic());

        final bench = _TimerBench(async, db)..setUp();
        try {
          bench.check(trace);
          for (final step in trace) {
            bench
              ..run(step)
              ..check(trace);
          }
        } finally {
          bench
            ..settle(bench.timeService.stop(persistEnd: false))
            ..settle(db.close())
            ..settle(settingsDb.close());
        }
      }, initialTime: DateTime(2026, 9, 28, 9));
    }

    // The shortest traces the three fixes answer, as the model finds them.
    test('a timer stopped from the sidebar keeps its time (StopPersists)', () {
      replay(const [
        _TimerStep(_TimerOp.userStart, 0),
        _TimerStep(_TimerOp.wait, 2),
        _TimerStep(_TimerOp.stopSidebar, 0),
      ]);
    });

    test('a timer running when the app quits keeps its time '
        '(ShutdownPersists)', () {
      replay(const [
        _TimerStep(_TimerOp.userStart, 0),
        _TimerStep(_TimerOp.wait, 6),
        _TimerStep(_TimerOp.close, 0),
      ]);
    });

    test('the agent never replaces a timer the user started after its '
        'check (NoStolenTimer)', () {
      replay(const [_TimerStep(_TimerOp.agentRace, 0)]);
    });

    glados.Glados(
      glados.any.timerTrace,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'the user, the agent, quitting and crashing never lose tracked time '
      'beyond one autosave interval, and the agent never replaces the '
      "user's timer",
      replay,
      tags: 'glados',
    );
  });
}
