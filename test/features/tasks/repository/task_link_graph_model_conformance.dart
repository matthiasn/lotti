part of 'blocks_cycles_test.dart';

// Model conformance with specs/tla/TaskLinkGraph.tla: three tasks and their
// projects on two devices, each a real in-memory JournalDb and SettingsDb
// behind the real writers -- PersistenceLogic.createLink with a blocks
// link, JournalRepository.updateLinkType turning one around and
// removeTypedLink removing one, ProjectRepository.linkTaskToProject and
// unlinkTaskFromProject -- and a task closed by a new version of it. The
// user and the task agent's link tool write at the same time on one device
// (race, raceFlip), the interleaving the model splits the cycle check from
// the write at. Every link version a device sends, and every task version,
// reaches the other device in a generated order through the real receive,
// JournalDb.upsertEntryLink and updateJournalEntity.
//
// After every step the trace checks NoLocalCycle -- no link a device just
// wrote is on a cycle of the links it holds -- and, on each device, that
// TaskDependencyResolver reports exactly the blockers that are open and
// exactly the ones on a cycle (CycleSurfaced, ReleaseOnClose), and that a
// filing shows on the device that made it (FilingShows). Once everything has
// arrived: every device holds the same links and shows each task in the
// same project, or none (AtMostOneProject), and no device shows a task
// through a link a move or unfile of it had seen (ProjectWriteSticks).

enum _GraphOp {
  create,
  race,
  flip,
  raceFlip,
  remove,
  close,
  file,
  unfile,
  deliver,
}

class _GraphStep {
  const _GraphStep(this.op, this.device, this.arg);

  factory _GraphStep.decode(int code, List<_GraphOp> ops) => _GraphStep(
    ops[code % ops.length],
    (code ~/ ops.length) % 2,
    code ~/ (ops.length * 2),
  );

  final _GraphOp op;
  final int device;

  /// Picks the link or links, the task, the project, or the delivery.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

/// The range of [_GraphStep.arg].
const _maxGraphArg = 36;

/// The blocks-link operations, as the model's `TaskLinkGraph` configuration
/// has them, and the project ones, as `TaskLinkGraphProjects` has them.
const List<_GraphOp> _blocksOps = [
  _GraphOp.create,
  _GraphOp.race,
  _GraphOp.flip,
  _GraphOp.raceFlip,
  _GraphOp.remove,
  _GraphOp.close,
  _GraphOp.deliver,
];
const List<_GraphOp> _projectOps = [
  _GraphOp.file,
  _GraphOp.unfile,
  _GraphOp.deliver,
];

extension _AnyGraphTrace on glados.Any {
  glados.Generator<List<_GraphStep>> graphTrace(List<_GraphOp> ops) =>
      glados.ListAnys(this)
          .listWithLengthInRange(
            1,
            14,
            glados.IntAnys(this).intInRange(0, ops.length * 2 * _maxGraphArg),
          )
          .map(
            (codes) => [
              for (final code in codes) _GraphStep.decode(code, ops),
            ],
          );
}

/// Writes per trace, as the model bounds them (`MaxWrites`), plus two.
const _maxGraphWrites = 6;

const _graphTasks = ['t1', 't2', 't3'];
const _graphCategory = 'graph-category';

/// The task the generated traces file under projects.
const _filedTask = 't1';
final _graphDate = DateTime(2024, 3, 15);

final List<(String, String)> _graphPairs = [
  for (final a in _graphTasks)
    for (final b in _graphTasks)
      if (a != b) (a, b),
];

/// Replaces the registration of [T] with [instance].
void _put<T extends Object>(T instance) {
  if (getIt.isRegistered<T>()) getIt.unregister<T>();
  getIt.registerSingleton<T>(instance);
}

/// One device: its databases, its clock, and the writers over them.
class _GraphDevice {
  _GraphDevice._(this.db, this.settings, this.outbox);

  final JournalDb db;
  final SettingsDb settings;
  final MockOutboxService outbox;
  final journal = JournalRepository();
  late final VectorClockService clocks;
  late final PersistenceLogic persistence;
  late final ProjectRepository projects;

  static Future<_GraphDevice> open({
    required UpdateNotifications notifications,
    required EntitiesCacheService cache,
  }) async {
    final device = _GraphDevice._(
      JournalDb(inMemoryDatabase: true),
      SettingsDb(inMemoryDatabase: true),
      MockOutboxService(),
    );
    // The clock reads its host and counter from the device's settings.
    _put<SettingsDb>(device.settings);
    device.clocks = VectorClockService();
    await device.clocks.initialized;
    device.persistence = PersistenceLogic();
    device.projects = ProjectRepository(
      journalDb: device.db,
      entitiesCacheService: cache,
      persistenceLogic: device.persistence,
      updateNotifications: notifications,
      vectorClockService: device.clocks,
      projectHasActiveAgent: (_) async => false,
    );
    return device;
  }

  /// Makes this device the one the writers' `getIt` lookups resolve to.
  void _activate() {
    _put<JournalDb>(db);
    _put<SettingsDb>(settings);
    _put<OutboxService>(outbox);
    _put<VectorClockService>(clocks);
    _put<MetadataService>(MetadataService(vectorClockService: clocks));
    _put<PersistenceLogic>(persistence);
  }

  Future<void> close() async {
    await db.close();
    await settings.close();
  }
}

class _GraphBench {
  _GraphBench(this.devices, {this.projects = const ['p1', 'p2']}) {
    for (var d = 0; d < devices.length; d++) {
      when(() => devices[d].outbox.enqueueMessage(any())).thenAnswer((
        invocation,
      ) async {
        final message = invocation.positionalArguments.first;
        if (message is SyncEntryLink) {
          _sent.add((from: d, payload: message.entryLink));
        }
      });
    }
  }

  final List<_GraphDevice> devices;
  final List<String> projects;

  /// What the failure messages name: the generated trace, or the test.
  Object? trace;

  /// Every link and task version sent, with its writer.
  final _sent = <({int from, Object payload})>[];
  final _delivered = [<int>{}, <int>{}];

  /// Ghost: per project write, the task and the live links it saw, apart
  /// from the one it filed the task under.
  final _filings = <({String task, Set<String> saw})>[];
  var _writes = 0;
  var _serial = 0;

  Future<void> setUp() async {
    for (final device in devices) {
      await clearAllTables(device.db);
      await initConfigFlags(device.db, inMemoryDatabase: true);
      for (final id in _graphTasks) {
        await device.db.updateJournalEntity(
          TestTaskFactory.create(id: id, title: id, categoryId: _graphCategory),
        );
      }
      for (final id in projects) {
        await device.db.updateJournalEntity(
          TestProjectFactory.create(
            id: id,
            title: id,
            categoryId: _graphCategory,
          ),
        );
      }
    }
  }

  _GraphDevice activate(int d) => devices[d].._activate();

  Future<List<EntryLink>> liveBlocks(int d) => devices[d].db
      .typedLinksForTaskIds(_graphTasks.toSet(), types: const {'BlocksLink'});

  Future<Set<(String, String)>> _liveKeys(int d) async => {
    for (final link in await liveBlocks(d)) (link.fromId, link.toId),
  };

  static String _versionKey(EntryLink link) =>
      '${link.id}|${link.vectorClock?.vclock}';

  Future<void> run(_GraphStep step) async {
    final d = step.device;
    final device = activate(d);
    final canWrite = _writes < _maxGraphWrites;
    switch (step.op) {
      case _GraphOp.create:
        if (!canWrite) return;
        final (from, to) = _graphPairs[step.arg % _graphPairs.length];
        await localWrite(d, [() => createBlocks(d, from, to)]);
      case _GraphOp.race:
        if (!canWrite) return;
        final (a, b) = _graphPairs[step.arg % _graphPairs.length];
        final (c, e) = _graphPairs[(step.arg ~/ 6) % _graphPairs.length];
        await localWrite(d, [
          () => createBlocks(d, a, b),
          () => createBlocks(d, c, e),
        ]);
      case _GraphOp.flip:
        final live = await liveBlocks(d);
        if (!canWrite || live.isEmpty) return;
        final link = live[step.arg % live.length];
        await localWrite(d, [() => flip(d, link)]);
      case _GraphOp.raceFlip:
        final live = await liveBlocks(d);
        if (!canWrite || live.isEmpty) return;
        final (a, b) = _graphPairs[step.arg % _graphPairs.length];
        final link = live[(step.arg ~/ 6) % live.length];
        await localWrite(d, [() => createBlocks(d, a, b), () => flip(d, link)]);
      case _GraphOp.remove:
        final live = await liveBlocks(d);
        if (!canWrite || live.isEmpty) return;
        final link = live[step.arg % live.length];
        _writes++;
        await device.journal.removeTypedLink(
          fromId: link.fromId,
          toId: link.toId,
          linkType: 'BlocksLink',
        );
      case _GraphOp.close:
        if (!canWrite) return;
        await closeTask(d, _graphTasks[step.arg % _graphTasks.length]);
      // Project writes are on one task, as the model's configurations have
      // them: tasks do not share project links.
      case _GraphOp.file:
        if (!canWrite) return;
        await file(d, _filedTask, projects[step.arg % projects.length]);
      case _GraphOp.unfile:
        if (!canWrite) return;
        await unfile(d, _filedTask);
      case _GraphOp.deliver:
        final pending = _pendingFor(d);
        if (pending.isEmpty) return;
        await deliver(d, pending[step.arg % pending.length]);
    }
  }

  Future<bool> createBlocks(int d, String from, String to) =>
      activate(d).persistence.createLink(
        fromId: from,
        toId: to,
        linkType: EntryLinkType.blocks,
      );

  Future<bool> flip(int d, EntryLink link) =>
      activate(d).journal.updateLinkType(
        linkId: link.id,
        newType: EntryLinkType.blocks,
        swapDirection: true,
      );

  /// Runs [writes] on device [d] at once and checks NoLocalCycle: no link
  /// they made live is on a cycle of the links the device holds after.
  Future<void> localWrite(
    int d,
    List<Future<bool> Function()> writes,
  ) async {
    _writes += writes.length;
    final before = await _liveKeys(d);
    await Future.wait([for (final write in writes) write()]);
    final after = await _liveKeys(d);
    for (final (from, to) in after.difference(before)) {
      expect(
        _reaches(after, to, from),
        isFalse,
        reason: 'NoLocalCycle: $from -> $to closed a cycle on d$d: $trace',
      );
    }
  }

  /// A new version of task [t] on device [d], closed as done.
  Future<void> closeTask(int d, String t) async {
    final device = activate(d);
    final stored = await device.db.journalEntityById(t);
    if (stored is! Task || blockerReleases(stored)) return;
    _writes++;
    final serial = ++_serial;
    final version = stored.copyWith(
      meta: stored.meta.copyWith(
        updatedAt: _graphDate.add(Duration(minutes: serial)),
        vectorClock: await device.clocks.getNextVectorClock(
          previous: stored.meta.vectorClock,
        ),
      ),
      data: stored.data.copyWith(
        status: TaskStatus.done(
          id: 'done-$serial',
          createdAt: _graphDate,
          utcOffset: 0,
        ),
      ),
    );
    await device.db.updateJournalEntity(version);
    _sent.add((from: d, payload: version));
  }

  Future<Set<String>> _liveProjectKeys(
    int d,
    String t, {
    String? except,
  }) async => {
    for (final link in await devices[d].db.getLiveProjectLinksForTask(t))
      if (link.fromId != except) _versionKey(link),
  };

  /// Files task [t] under project [p] on device [d] and checks FilingShows.
  Future<void> file(int d, String t, String p) async {
    _writes++;
    _filings.add((task: t, saw: await _liveProjectKeys(d, t, except: p)));
    final filed = await activate(d).projects.linkTaskToProject(
      projectId: p,
      taskId: t,
    );
    expect(filed, isTrue, reason: 'FilingShows: file($t, $p) refused: $trace');
    expect(
      await shownProject(d, t),
      p,
      reason: 'FilingShows: d$d does not show $t in $p: $trace',
    );
  }

  Future<void> unfile(int d, String t) async {
    _writes++;
    _filings.add((task: t, saw: await _liveProjectKeys(d, t)));
    await activate(d).projects.unlinkTaskFromProject(t);
  }

  Future<String?> shownProject(int d, String t) async =>
      (await devices[d].projects.getLinkedProjectForTask(t))?.meta.id;

  List<int> _pendingFor(int d) => [
    for (var i = 0; i < _sent.length; i++)
      if (_sent[i].from != d && !_delivered[d].contains(i)) i,
  ];

  /// The real receive of sent version [index] on device [d].
  Future<void> deliver(int d, int index) async {
    _delivered[d].add(index);
    switch (_sent[index].payload) {
      case final EntryLink link:
        await devices[d].db.upsertEntryLink(link);
      case final JournalEntity entity:
        await devices[d].db.updateJournalEntity(entity);
    }
  }

  Future<void> settle() async {
    for (var round = 0; round < 2; round++) {
      for (var d = 0; d < devices.length; d++) {
        for (final index in _pendingFor(d)) {
          await deliver(d, index);
        }
      }
    }
  }

  static bool _reaches(Set<(String, String)> edges, String from, String to) {
    final reached = <String>{};
    final stack = [from];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      for (final (a, b) in edges) {
        if (a == node && reached.add(b)) stack.add(b);
      }
    }
    return reached.contains(to);
  }

  /// CycleSurfaced and ReleaseOnClose on device [d]: the resolver names as
  /// blockers exactly the tasks that block through a live link and have not
  /// released, and marks as a cycle exactly those the task reaches back.
  Future<void> checkReaders(int d) async {
    final device = activate(d);
    final entities = {
      for (final row in await device.db.entriesForIds(_graphTasks).get())
        row.id: fromDbEntity(row),
    };
    final live = await _liveKeys(d);
    final blocking = {
      for (final (from, to) in live)
        if (!blockerReleases(entities[from])) (from, to),
    };
    final resolved = await TaskDependencyResolver(
      journalRepository: device.journal,
    ).resolveBlockedStatus(_graphTasks.toSet());
    for (final t in _graphTasks) {
      final expected = {
        for (final (from, to) in blocking)
          if (to == t) from: _reaches(blocking, t, from),
      };
      final actual = {
        for (final blocker in resolved[t] ?? const <ResolvedBlocker>[])
          blocker.taskId: blocker.cycle,
      };
      expect(
        actual,
        expected,
        reason: 'CycleSurfaced/ReleaseOnClose: $t on d$d: $trace',
      );
    }
  }

  Future<void> checkStep() async {
    for (var d = 0; d < devices.length; d++) {
      await checkReaders(d);
    }
  }

  Future<void> checkConverged() async {
    final keys = [
      for (var d = 0; d < devices.length; d++) await _liveKeys(d),
    ];
    expect(keys[1], keys[0], reason: 'Converged links: $trace');
    for (final t in _graphTasks) {
      final shown = <String?>[];
      for (var d = 0; d < devices.length; d++) {
        final device = activate(d);
        final project = await shownProject(d, t);
        shown.add(project);
        expect(
          (await device.db.getProjectIdMapForTasks({t}))[t],
          project,
          reason: 'AtMostOneProject: the project id of $t on d$d: $trace',
        );
        final link = await device.db.getProjectLinkForTask(t);
        for (final filing in _filings) {
          if (filing.task != t || link == null) continue;
          expect(
            filing.saw.contains(_versionKey(link)),
            isFalse,
            reason:
                'ProjectWriteSticks: d$d shows $t in ${link.fromId} '
                'through a link a write took it out of: $trace',
          );
        }
      }
      expect(
        shown.toSet(),
        hasLength(1),
        reason: 'AtMostOneProject: $t shows in $shown: $trace',
      );
    }
  }
}

void _registerTaskLinkGraphConformance() {
  group('task link graph (specs/tla/TaskLinkGraph.tla)', () {
    final notifications = MockUpdateNotifications();
    final cache = MockEntitiesCacheService();
    final devices = <_GraphDevice>[];
    late Directory documents;

    setUpAll(() async {
      registerAllFallbackValues();
      when(
        () => notifications.updateStream,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
      documents = Directory.systemTemp.createTempSync('task_link_graph');
      _put<Directory>(documents);
      _put<UpdateNotifications>(notifications);
      _put<DomainLogger>(DomainLogger(loggingService: LoggingService()));
      _put<EntitiesCacheService>(cache);
      for (var d = 0; d < 2; d++) {
        devices.add(
          await _GraphDevice.open(notifications: notifications, cache: cache),
        );
      }
    });

    tearDownAll(() async {
      for (final device in devices) {
        await device.close();
      }
      documents.deleteSync(recursive: true);
      for (final unregister in [
        getIt.unregister<JournalDb>,
        getIt.unregister<SettingsDb>,
        getIt.unregister<OutboxService>,
        getIt.unregister<VectorClockService>,
        getIt.unregister<MetadataService>,
        getIt.unregister<PersistenceLogic>,
        getIt.unregister<UpdateNotifications>,
        getIt.unregister<DomainLogger>,
        getIt.unregister<EntitiesCacheService>,
        getIt.unregister<Directory>,
      ]) {
        unregister();
      }
    });

    Future<_GraphBench> bench({
      List<String> projects = const ['p1', 'p2'],
    }) async {
      final bench = _GraphBench(devices, projects: projects);
      await bench.setUp();
      return bench;
    }

    // The shortest counterexamples TLC found, one per fix (README), on the
    // real writers. Each fails with its fix reverted.

    test('the user and the agent linking two tasks both ways at once on one '
        'device write one link, not a cycle (AtomicCheck)', () async {
      final b = await bench();
      b.activate(0);
      await b.localWrite(0, [
        () => b.createBlocks(0, 't1', 't2'),
        () => b.createBlocks(0, 't2', 't1'),
      ]);
      expect(await b._liveKeys(0), hasLength(1));
    });

    test('a flip and a new link racing on one device close no cycle '
        '(AtomicCheck, updateLinkType)', () async {
      final b = await bench();
      b.activate(0);
      await b.createBlocks(0, 't1', 't2');
      await b.createBlocks(0, 't1', 't3');
      final t1BlocksT3 = (await b.liveBlocks(
        0,
      )).singleWhere((link) => link.toId == 't3');
      // t3 -> t1 and t2 -> t3 each pass their check alone; together with
      // t1 -> t2 they close t1 -> t2 -> t3 -> t1.
      await b.localWrite(0, [
        () => b.flip(0, t1BlocksT3),
        () => b.createBlocks(0, 't2', 't3'),
      ]);
      // One of the two writes lands; the other finds the cycle it would
      // close inside its transaction and writes nothing.
      expect(
        await b._liveKeys(0),
        anyOf(
          {
            ('t1', 't2'),
            ('t1', 't3'),
            ('t2', 't3'),
          },
          {
            ('t1', 't2'),
            ('t3', 't1'),
          },
        ),
      );
    });

    test(
      'links written on two devices that close a cycle are reported as '
      'one on both, by the resolver and the task page (DetectCycle)',
      () async {
        final b = await bench();
        b.activate(0);
        await b.createBlocks(0, 't2', 't1');
        b.activate(1);
        await b.createBlocks(1, 't1', 't2');
        await b.settle();
        for (var d = 0; d < 2; d++) {
          final device = b.activate(d);
          final resolved = await TaskDependencyResolver(
            journalRepository: device.journal,
          ).resolveBlockedStatus({'t1', 't2'});
          expect(resolved['t1']!.single.taskId, 't2');
          expect(resolved['t1']!.single.toJson()['cycle'], isTrue);
          expect(resolved['t2']!.single.toJson()['cycle'], isTrue);
          final container = ProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(device.journal),
            ],
          );
          addTearDown(container.dispose);
          final page = await container.read(
            taskBlockersControllerProvider('t2').future,
          );
          expect(page.inCycle, isTrue);
          expect(page.cycleBlockerIds, {'t1'});
        }
        // Closing either task releases the other, on both devices.
        await b.closeTask(0, 't2');
        await b.settle();
        await b.checkStep();
        for (var d = 0; d < 2; d++) {
          final device = b.activate(d);
          final resolved = await TaskDependencyResolver(
            journalRepository: device.journal,
          ).resolveBlockedStatus({'t1', 't2'});
          expect(resolved.keys, ['t2']);
          expect(resolved['t2']!.single.cycle, isFalse);
        }
      },
    );

    test('a task filed under two projects on two devices and then taken out '
        'of the one it shows in is in none (RetireAll, unfile)', () async {
      final b = await bench();
      b.activate(0);
      await b.file(0, 't1', 'p1');
      b.activate(1);
      await b.file(1, 't1', 'p2');
      await b.deliver(1, 0);
      b.activate(1);
      await b.unfile(1, 't1');
      await b.settle();
      await b.checkConverged();
      expect(await b.shownProject(0, 't1'), isNull);
      expect(await b.shownProject(1, 't1'), isNull);
    });

    test('filing a task under the project of its other live link shows it '
        'there (RetireAll, file)', () async {
      final b = await bench();
      b.activate(0);
      await b.file(0, 't1', 'p1');
      b.activate(1);
      await b.file(1, 't1', 'p2');
      await b.settle();
      final shown = await b.shownProject(0, 't1');
      final other = shown == 'p1' ? 'p2' : 'p1';
      // FilingShows fails here when the move refuses the live link that
      // does not show.
      await b.file(0, 't1', other);
      await b.settle();
      await b.checkConverged();
    });

    test(
      'moving a task shows it in the new project even when a live link '
      'stamped by a clock that runs ahead is still stored (RetireAll, move)',
      () async {
        final b = await bench(projects: const ['p1', 'p2', 'p3']);
        // Two links another device wrote while its clock ran ahead: p2 shows,
        // p1 lies underneath it, both stamped later than this device's now.
        for (final (project, year) in [('p1', 2100), ('p2', 2101)]) {
          await b.devices[0].db.upsertEntryLink(
            EntryLink.project(
              id: 'ahead-$project',
              fromId: project,
              toId: 't1',
              createdAt: DateTime(year),
              updatedAt: DateTime(year),
              vectorClock: VectorClock({'ahead': year}),
            ),
          );
        }
        b.activate(0);
        expect(await b.shownProject(0, 't1'), 'p2');
        await b.file(0, 't1', 'p3');
      },
    );

    Future<void> runTrace(List<_GraphStep> trace) async {
      final b = await bench()
        ..trace = trace;
      for (final step in trace) {
        await b.run(step);
        await b.checkStep();
      }
      await b.settle();
      await b.checkStep();
      await b.checkConverged();
    }

    glados.Glados(
      glados.any.graphTrace(_blocksOps),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'blocks links created, raced, turned and removed and tasks closed on '
      'two devices close no cycle on one device, and every cycle and every '
      'open blocker is reported',
      runTrace,
      timeout: const Timeout(Duration(minutes: 4)),
      tags: 'glados',
    );

    glados.Glados(
      glados.any.graphTrace(_projectOps),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'a task filed, moved and unfiled on two devices shows in the project '
      'it was last put in, the same one everywhere',
      runTrace,
      timeout: const Timeout(Duration(minutes: 4)),
      tags: 'glados',
    );
  });
}
