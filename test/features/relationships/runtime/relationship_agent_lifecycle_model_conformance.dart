part of 'relationship_runtime_maintenance_test.dart';

// Model conformance with `specs/tla/RelationshipAgentLifecycle.tla`: one
// person and their relationship agent on two devices. Each device runs the
// real agent stack — an in-memory agent database behind the real
// `AgentRepository`, `AgentSyncService`, `AgentService`,
// `RelationshipAgentService` and `RelationshipRuntimeMaintenance` — and
// exchanges every agent write through the real receive decision
// (`ReplicaNetwork`). The person is the journal side, which
// `JournalReplication` covers: here a small store per device applies a
// version the way `JournalDb.updateJournalEntity` does (a dominating version
// applies, two concurrent deletions merge, any other concurrent pair is an
// open conflict) and answers the repository reads the maintenance makes.
//
// Model actions and trace operations:
//
//   Mark, Unmark, Edit   the person saved on a device (`importantSince`
//                        stamped on the off→on switch, as the repository
//                        does); Mark and an important Edit queue the
//                        background ensure
//   Delete(page)         the tombstone; from the person page it queues the
//                        teardown (`handleRelationshipDeleted`)
//   Ensure, Teardown     a queued background job runs
//   Crash                a device dies with its queued jobs lost
//   Reap, Reconciles     the maintenance pass (`beforeWakeScan`)
//   Stop, Resume         the agent controls: destroy or pause, resume
//   HardDelete           `deleteAgent` by the user
//   Resolve              the conflict page keeps one side
//   Deliver              one agent write or one person version arrives
//
// After every maintenance pass the trace checks NoReapOfLivePerson; once
// every write has arrived, every job has run and a pass on each device
// writes nothing more, it checks Tracked, Untracked, StopSticks and
// Converged. The clock only moves forward, as in the model.

enum _LifeOp {
  mark,
  unmark,
  edit,
  deletePage,
  deleteJournal,
  ensure,
  crash,
  scan,
  stop,
  pause,
  resume,
  hardDelete,
  resolve,
  deliverAgent,
  deliverPerson,
}

class _LifeStep {
  const _LifeStep(this.op, this.device, [this.arg = 0]);

  factory _LifeStep.decode(int code) => _LifeStep(
    _LifeOp.values[code % _LifeOp.values.length],
    (code ~/ _LifeOp.values.length) % 2,
    code ~/ (_LifeOp.values.length * 2),
  );

  final _LifeOp op;
  final int device;

  /// Picks the job, the conflict, or the write to deliver.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnyLifeTrace on glados.Any {
  glados.Generator<List<_LifeStep>> get lifeTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        20,
        glados.IntAnys(this).intInRange(0, _LifeOp.values.length * 2 * 4),
      )
      .map((codes) => [for (final code in codes) _LifeStep.decode(code)]);
}

const _lifePersonId = 'person-1';
final String _lifeAgentId = relationshipAgentIdFor(_lifePersonId);

/// The model's bounds: two user stops, one crash.
const _lifeMaxStops = 2;
const _lifeMaxCrashes = 1;

/// One person version on the journal side.
@immutable
class _PersonVersion {
  const _PersonVersion({
    required this.clock,
    required this.dead,
    required this.important,
    required this.title,
    this.importantSince,
  });

  final Map<String, int> clock;
  final bool dead;
  final bool important;
  final DateTime? importantSince;
  final String title;

  RelationshipEntry entry(DateTime at) => RelationshipEntry(
    meta: Metadata(
      id: _lifePersonId,
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
      deletedAt: dead ? at : null,
    ),
    data: RelationshipData(
      title: title,
      important: important,
      importantSince: importantSince,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: at,
        utcOffset: 0,
      ),
    ),
  );

  _PersonVersion copyWith({
    required Map<String, int> clock,
    bool? dead,
    bool? important,
    DateTime? importantSince,
    String? title,
  }) => _PersonVersion(
    clock: clock,
    dead: dead ?? this.dead,
    important: important ?? this.important,
    importantSince: importantSince ?? this.importantSince,
    title: title ?? this.title,
  );

  bool sameAs(_PersonVersion other) =>
      mapEquals(clock, other.clock) &&
      dead == other.dead &&
      important == other.important &&
      importantSince == other.importantSince &&
      title == other.title;

  @override
  String toString() => '${dead ? 'dead' : 'live'}${important ? '*' : ''}$clock';
}

bool _covers(Map<String, int> a, Map<String, int> b) =>
    b.entries.every((e) => (a[e.key] ?? 0) >= e.value);

Map<String, int> _join(Map<String, int> a, Map<String, int> b) => {
  for (final host in {...a.keys, ...b.keys})
    host: (a[host] ?? 0) > (b[host] ?? 0) ? a[host]! : b[host] ?? 0,
};

/// One queued background job: the ensure after a save, or the teardown
/// after a delete from the person page.
typedef _LifeJob = ({String kind, RelationshipEntry person});

MockWakeOrchestrator _lifeOrchestrator() {
  final orchestrator = MockWakeOrchestrator();
  when(() => orchestrator.addSubscription(any())).thenReturn(null);
  when(() => orchestrator.removeSubscriptions(any())).thenReturn(null);
  when(() => orchestrator.clearThrottle(any())).thenReturn(null);
  when(
    () => orchestrator.cancelPendingWakes(
      any(),
      allWorkspaces: any(named: 'allWorkspaces'),
    ),
  ).thenReturn(const []);
  when(() => orchestrator.abortRunningWake(any())).thenReturn(false);
  when(
    () => orchestrator.enqueueManualWake(
      agentId: any(named: 'agentId'),
      reason: any(named: 'reason'),
      triggerTokens: any(named: 'triggerTokens'),
      workspaceKey: any(named: 'workspaceKey'),
      supersede: any(named: 'supersede'),
      initiator: any(named: 'initiator'),
    ),
  ).thenReturn('run-key');
  return orchestrator;
}

class _LifeDevice {
  _LifeDevice(this.replica) {
    when(
      () => people.isRelationshipDeleted(_lifePersonId),
    ).thenAnswer((_) async => person?.dead ?? false);
    when(
      () => people.getRelationshipByIdUnfiltered(_lifePersonId),
    ).thenAnswer((_) async {
      final stored = person;
      return stored == null || stored.dead ? null : stored.entry(clock.now());
    });
    when(people.getAllRelationshipsUnfiltered).thenAnswer((_) async {
      final stored = person;
      return stored == null || stored.dead ? [] : [stored.entry(clock.now())];
    });
    when(() => people.openConflictVersions(_lifePersonId)).thenAnswer(
      (_) async => [for (final c in conflicts) c.entry(clock.now())],
    );
    _build();
  }

  final AgentReplica replica;
  final MockWakeOrchestrator orchestrator = _lifeOrchestrator();
  final MockRelationshipRepository people = MockRelationshipRepository();
  late AgentService agents;
  late RelationshipAgentService relationships;
  late RelationshipRuntimeMaintenance maintenance;

  String get host => replica.host;

  /// The journal side: the stored person, and versions held as conflicts.
  _PersonVersion? person;
  final conflicts = <_PersonVersion>[];
  var _counter = 0;

  /// Queued background jobs, lost on a crash.
  final jobs = <_LifeJob>[];

  /// Person versions delivered here, by index into the world's list.
  final receivedPeople = <int>{};

  /// This device deleted the agent.
  bool gone = false;

  void _build() {
    agents = AgentService(
      domainLogger: MockDomainLogger(),
      repository: replica.repository,
      orchestrator: orchestrator,
      syncService: replica.syncService,
    );
    relationships = RelationshipAgentService(
      agentService: agents,
      repository: replica.repository,
      syncService: replica.syncService,
      orchestrator: orchestrator,
      relationshipRepository: people,
    );
    maintenance = RelationshipRuntimeMaintenance(
      agentService: agents,
      repository: replica.repository,
      syncService: replica.syncService,
      relationshipAgentService: relationships,
      relationshipRepository: people,
    );
  }

  /// A process death and restart over the same database.
  void crash() {
    jobs.clear();
    replica.reboot();
    _build();
  }

  Future<AgentIdentityEntity?> identity() async {
    final entity = await replica.repository.getEntity(_lifeAgentId);
    return entity is AgentIdentityEntity ? entity : null;
  }

  /// The model's `Lc`: a device that deleted the agent counts as holding it
  /// destroyed.
  Future<AgentLifecycle?> lifecycle() async =>
      (await identity())?.lifecycle ?? (gone ? AgentLifecycle.destroyed : null);

  /// A local person write over the stored version.
  _PersonVersion write({
    bool? dead,
    bool? important,
    DateTime? importantSince,
    String? title,
  }) {
    final stored = person!;
    final version = stored.copyWith(
      clock: {...stored.clock, host: ++_counter},
      dead: dead,
      important: important,
      importantSince: importantSince,
      title: title,
    );
    apply(version);
    return version;
  }

  /// `JournalDb.updateJournalEntity` for a received or written version.
  void apply(_PersonVersion incoming) {
    final stored = person;
    if (stored == null || _covers(incoming.clock, stored.clock)) {
      if (stored != null && mapEquals(stored.clock, incoming.clock)) return;
      person = incoming;
    } else if (_covers(stored.clock, incoming.clock)) {
      return;
    } else if (stored.dead && incoming.dead) {
      person = stored.copyWith(clock: _join(stored.clock, incoming.clock));
    } else {
      if (!conflicts.any((c) => mapEquals(c.clock, incoming.clock))) {
        conflicts.add(incoming);
      }
      return;
    }
    conflicts.removeWhere((c) => _covers(person!.clock, c.clock));
  }
}

class _LifeWorld {
  _LifeWorld() {
    devices = [
      _LifeDevice(network.join('hA')),
      _LifeDevice(network.join('hB')),
    ];
  }

  final network = ReplicaNetwork();
  late final List<_LifeDevice> devices;

  /// Every person version written, with its writer, in order.
  final people = <({String from, _PersonVersion version})>[];

  var _now = DateTime(2026, 9, 30, 9);

  // Ghosts.
  bool everDeleted = false;
  int stops = 0;
  int crashes = 0;
  DateTime? lastStop;
  DateTime? lastMark;
  DateTime? lastResume;

  /// The person is created on the first device and reaches the second
  /// late, as in the model's initial state.
  void setUp() {
    final first = devices.first;
    first.person = _PersonVersion(
      clock: {first.host: ++first._counter},
      dead: false,
      important: false,
      title: 'Anna',
    );
    people.add((from: first.host, version: first.person!));
  }

  Future<T> _at<T>(Future<T> Function() body) {
    _now = _now.add(const Duration(minutes: 1));
    return withClock(Clock.fixed(_now), body);
  }

  void _personWrite(
    _LifeDevice device, {
    bool? dead,
    bool? important,
    DateTime? importantSince,
    String? title,
  }) {
    final version = device.write(
      dead: dead,
      important: important,
      importantSince: importantSince,
      title: title,
    );
    people.add((from: device.host, version: version));
  }

  List<int> _pendingPeople(_LifeDevice to) => [
    for (var i = 0; i < people.length; i++)
      if (people[i].from != to.host && !to.receivedPeople.contains(i)) i,
  ];

  void _deliverPerson(_LifeDevice device, int index) {
    device
      ..receivedPeople.add(index)
      ..apply(people[index].version);
  }

  Future<void> _runJob(_LifeDevice device, int pick) async {
    if (device.jobs.isEmpty) return;
    final job = device.jobs.removeAt(pick % device.jobs.length);
    await _at(() async {
      if (job.kind == 'teardown') {
        await device.relationships.handleRelationshipDeleted(_lifePersonId);
      } else {
        await device.relationships.ensureAgentForRelationship(job.person);
      }
    });
  }

  /// The maintenance pass, checking NoReapOfLivePerson: a live agent it
  /// destroys was destroyed for a deleted person or for the user's stop.
  Future<void> _scan(_LifeDevice device, Object trace) async {
    final before = await device.identity();
    await _at(device.maintenance.beforeWakeScan);
    final after = await device.identity();
    if (before?.lifecycle == AgentLifecycle.active &&
        after?.lifecycle == AgentLifecycle.destroyed &&
        after?.userStopLifecycle != AgentLifecycle.destroyed) {
      expect(
        everDeleted,
        isTrue,
        reason: 'NoReapOfLivePerson on ${device.host}: $trace',
      );
    }
  }

  Future<void> run(_LifeStep step, Object trace) async {
    final device = devices[step.device];
    final stored = device.person;
    final live = stored != null && !stored.dead;
    switch (step.op) {
      case _LifeOp.mark:
        if (!live || stored.important) return;
        _now = _now.add(const Duration(minutes: 1));
        lastMark = _now;
        _personWrite(device, important: true, importantSince: _now);
        device.jobs.add((kind: 'mark', person: device.person!.entry(_now)));
      case _LifeOp.unmark:
        if (!live || !stored.important) return;
        _personWrite(device, important: false);
      case _LifeOp.edit:
        if (!live) return;
        _personWrite(device, title: 'Anna ${people.length}');
        if (device.person!.important) {
          device.jobs.add((kind: 'save', person: device.person!.entry(_now)));
        }
      case _LifeOp.deletePage || _LifeOp.deleteJournal:
        if (!live) return;
        everDeleted = true;
        _personWrite(device, dead: true);
        if (step.op == _LifeOp.deletePage) {
          device.jobs.add((kind: 'teardown', person: stored.entry(_now)));
        }
      case _LifeOp.ensure:
        await _runJob(device, step.arg);
      case _LifeOp.crash:
        if (crashes >= _lifeMaxCrashes || device.jobs.isEmpty) return;
        crashes++;
        device.crash();
      case _LifeOp.scan:
        await _scan(device, trace);
      case _LifeOp.stop || _LifeOp.pause:
        final lifecycle = (await device.identity())?.lifecycle;
        final pausing = step.op == _LifeOp.pause;
        if (stops >= _lifeMaxStops ||
            lifecycle == null ||
            lifecycle == AgentLifecycle.destroyed ||
            (pausing && lifecycle != AgentLifecycle.active)) {
          return;
        }
        stops++;
        await _at(
          () => pausing
              ? device.agents.pauseAgent(_lifeAgentId, byUser: true)
              : device.agents.destroyAgent(_lifeAgentId, byUser: true),
        );
        lastStop = _now;
      case _LifeOp.resume:
        if ((await device.identity())?.lifecycle != AgentLifecycle.dormant) {
          return;
        }
        await _at(() => device.agents.resumeAgent(_lifeAgentId, byUser: true));
        lastMark = lastResume = _now;
      case _LifeOp.hardDelete:
        if (stops >= _lifeMaxStops ||
            (await device.identity())?.lifecycle != AgentLifecycle.destroyed) {
          return;
        }
        stops++;
        await _at(() => device.agents.deleteAgent(_lifeAgentId, byUser: true));
        lastStop = _now;
        device.gone = true;
      case _LifeOp.resolve:
        if (device.conflicts.isEmpty || stored == null) return;
        final conflict = device.conflicts[step.arg % device.conflicts.length];
        final kept = step.arg.isEven ? stored : conflict;
        device.conflicts.remove(conflict);
        final version = kept.copyWith(
          clock: {
            ..._join(stored.clock, conflict.clock),
            device.host: ++device._counter,
          },
        );
        device.apply(version);
        people.add((from: device.host, version: version));
      case _LifeOp.deliverAgent:
        final pending = network.pendingFor(device.replica);
        if (pending.isEmpty) return;
        await device.replica.receive(pending[step.arg % pending.length]);
      case _LifeOp.deliverPerson:
        final pending = _pendingPeople(device);
        if (pending.isEmpty) return;
        _deliverPerson(device, pending[step.arg % pending.length]);
    }
  }

  /// Every write arrives, every job runs, and passes run until none of them
  /// writes anything: the model's `Quiescent`.
  Future<void> settle(Object trace) async {
    for (var round = 0; round < 12; round++) {
      final writes = network.sent.length + people.length;
      for (final (d, device) in devices.indexed) {
        final pending = network.pendingFor(device.replica);
        for (final index in d.isOdd ? pending.reversed : pending) {
          await device.replica.receive(index);
        }
        for (final index in _pendingPeople(device)) {
          _deliverPerson(device, index);
        }
        while (device.jobs.isNotEmpty) {
          await _runJob(device, 0);
        }
      }
      for (final device in devices) {
        await _scan(device, trace);
      }
      final quiet =
          network.quiescent &&
          devices.every((d) => _pendingPeople(d).isEmpty) &&
          network.sent.length + people.length == writes;
      if (quiet) return;
    }
    fail('the maintenance passes never settled: $trace');
  }

  Future<void> checkQuiescent(Object trace) async {
    final lifecycles = [for (final d in devices) await d.lifecycle()];
    final first = devices.first.person;
    final agreed =
        first != null &&
        devices.every(
          (d) => d.conflicts.isEmpty && d.person!.sameAs(first),
        );
    final active = lifecycles.map((l) => l == AgentLifecycle.active);
    final state = '$lifecycles person ${[for (final d in devices) d.person]}';

    if (agreed && !first.dead && first.important) {
      final asked =
          [
            first.importantSince,
            lastResume,
          ].whereType<DateTime>().fold<DateTime?>(
            null,
            (a, b) => a == null || b.isAfter(a) ? b : a,
          );
      final stopped = lastStop;
      if (stopped == null || (asked != null && stopped.isBefore(asked))) {
        expect(active, everyElement(isTrue), reason: 'Tracked $state: $trace');
      }
    }
    if (agreed && first.dead) {
      expect(active, everyElement(isFalse), reason: 'Untracked $state: $trace');
    }
    final stopped = lastStop;
    final marked = lastMark;
    if (stopped != null && (marked == null || stopped.isAfter(marked))) {
      expect(
        active,
        everyElement(isFalse),
        reason: 'StopSticks $state: $trace',
      );
    }
    if (agreed) {
      expect(
        lifecycles.toSet(),
        hasLength(1),
        reason: 'Converged $state: $trace',
      );
    }
  }

  Future<void> close() => network.close();
}

Future<void> _playLifeTrace(List<_LifeStep> trace) async {
  final world = _LifeWorld()..setUp();
  try {
    for (final step in trace) {
      await world.run(step, trace);
    }
    await world.settle(trace);
    await world.checkQuiescent(trace);
  } finally {
    await world.close();
  }
}

Future<void> _playPinned(
  List<_LifeStep> trace, {
  Future<void> Function(_LifeWorld world)? then,
}) async {
  final world = _LifeWorld()..setUp();
  try {
    for (final step in trace) {
      await world.run(step, trace);
    }
    await then?.call(world);
    await world.settle(trace);
    await world.checkQuiescent(trace);
  } finally {
    await world.close();
  }
}

void _registerRelationshipAgentLifecycleConformance() {
  group('model conformance with specs/tla/RelationshipAgentLifecycle.tla', () {
    glados.Glados(
      glados.any.lifeTrace,
      glados.ExploreConfig(),
    ).test(
      'generated marks, edits, deletes, stops, resumes, hard deletes, '
      'conflicts, crashes, passes and arrival orders leave the agent where '
      "the user's latest word puts it, the same on every device",
      _playLifeTrace,
      tags: 'glados',
    );

    const a = 0;
    const b = 1;

    test(
      'NoReapOfLivePerson: B holds the agent and its link before the person, '
      'and its pass leaves the agent alone',
      () async {
        await _playPinned(
          const [
            _LifeStep(_LifeOp.mark, a),
            _LifeStep(_LifeOp.ensure, a),
          ],
          then: (world) async {
            final device = world.devices[b];
            // Every agent write, and none of the person's, reaches B.
            for (final index in world.network.pendingFor(device.replica)) {
              await device.replica.receive(index);
            }
            expect(device.person, isNull);
            await world._scan(device, 'pinned');
            expect(
              (await device.identity())?.lifecycle,
              AgentLifecycle.active,
            );
          },
        );
      },
    );

    test('Tracked: a crash that loses the ensure after a mark still ends '
        'with the agent on both devices', () async {
      await _playPinned(const [
        _LifeStep(_LifeOp.mark, a),
        _LifeStep(_LifeOp.crash, a),
      ]);
    });

    test("StopSticks: a rename racing the user's destroy does not revive the "
        'agent', () async {
      await _playPinned(
        const [
          _LifeStep(_LifeOp.mark, a),
          _LifeStep(_LifeOp.ensure, a),
        ],
        then: (world) async {
          await world.settle('pinned');
          await world.run(const _LifeStep(_LifeOp.stop, b), 'pinned');
          // A renames the person before B's destroy reaches it.
          await world.run(const _LifeStep(_LifeOp.edit, a), 'pinned');
          await world.run(const _LifeStep(_LifeOp.ensure, a), 'pinned');
          await world.settle('pinned');
          for (final device in world.devices) {
            expect(await device.lifecycle(), AgentLifecycle.destroyed);
          }
        },
      );
    });

    test(
      "StopSticks: the user's hard delete reaches the other device",
      () async {
        await _playPinned(
          const [
            _LifeStep(_LifeOp.mark, a),
            _LifeStep(_LifeOp.ensure, a),
          ],
          then: (world) async {
            await world.settle('pinned');
            await world.run(const _LifeStep(_LifeOp.stop, a), 'pinned');
            await world.run(const _LifeStep(_LifeOp.hardDelete, a), 'pinned');
            await world.settle('pinned');
            expect(
              await world.devices[b].lifecycle(),
              AgentLifecycle.destroyed,
            );
          },
        );
      },
    );

    test("StopSticks: the user's hard delete of an agent the system destroyed "
        'reaches a device that still holds the person live', () async {
      await _playPinned(
        const [
          _LifeStep(_LifeOp.mark, a),
          _LifeStep(_LifeOp.ensure, a),
        ],
        then: (world) async {
          await world.settle('pinned');
          // A deletes the person while B edits it: a conflict to come.
          await world.run(const _LifeStep(_LifeOp.deleteJournal, a), 'pinned');
          await world.run(const _LifeStep(_LifeOp.edit, b), 'pinned');
          // A reaps the agent, and the user deletes it there.
          await world.run(const _LifeStep(_LifeOp.scan, a), 'pinned');
          await world.run(const _LifeStep(_LifeOp.hardDelete, a), 'pinned');
          // B hears about the agent before it hears about the person.
          final device = world.devices[b];
          for (final index in world.network.pendingFor(device.replica)) {
            await device.replica.receive(index);
          }
          await world.run(const _LifeStep(_LifeOp.scan, b), 'pinned');
          expect(await device.lifecycle(), AgentLifecycle.destroyed);
        },
      );
    });

    test('StopSticks: an ensure queued before the user deleted the agent '
        'does not create it again', () async {
      await _playPinned(
        const [
          // A marks; its ensure stays queued. B creates the agent instead.
          _LifeStep(_LifeOp.mark, a),
          _LifeStep(_LifeOp.deliverPerson, b),
          _LifeStep(_LifeOp.deliverPerson, b),
          _LifeStep(_LifeOp.scan, b),
        ],
        then: (world) async {
          final device = world.devices[a];
          for (final index in world.network.pendingFor(device.replica)) {
            await device.replica.receive(index);
          }
          await world.run(const _LifeStep(_LifeOp.stop, a), 'pinned');
          await world.run(const _LifeStep(_LifeOp.hardDelete, a), 'pinned');
          expect(device.jobs, hasLength(1));
          await world.run(const _LifeStep(_LifeOp.ensure, a), 'pinned');
          expect(await device.identity(), isNull);
        },
      );
    });

    test('Untracked: a person deleted from the page on the other device '
        'leaves no active agent', () async {
      await _playPinned(
        const [
          _LifeStep(_LifeOp.mark, a),
          _LifeStep(_LifeOp.ensure, a),
        ],
        then: (world) async {
          await world.settle('pinned');
          await world.run(const _LifeStep(_LifeOp.deletePage, b), 'pinned');
        },
      );
    });

    test('marking again after the user destroyed the agent brings it back '
        'on both devices', () async {
      await _playPinned(
        const [
          _LifeStep(_LifeOp.mark, a),
          _LifeStep(_LifeOp.ensure, a),
        ],
        then: (world) async {
          await world.settle('pinned');
          await world.run(const _LifeStep(_LifeOp.stop, a), 'pinned');
          await world.run(const _LifeStep(_LifeOp.unmark, a), 'pinned');
          await world.run(const _LifeStep(_LifeOp.mark, a), 'pinned');
          await world.settle('pinned');
          for (final device in world.devices) {
            expect(await device.lifecycle(), AgentLifecycle.active);
          }
        },
      );
    });
  });
}
