part of 'relationship_agent_phase_a_test.dart';

// Model conformance with `specs/tla/RelationshipCadence.tla` and
// `specs/tla/AgentWakeOutcome.tla`: one tracked person's check-in cadence,
// and the outcomes of the wakes it runs, on two devices in different zones,
// Berlin (UTC+2) and Tokyo (UTC+9). Each device runs the real deterministic tick,
// `RelationshipAgentPhaseA`, over the real agent stack — an in-memory agent
// database behind the real `AgentRepository` and `AgentSyncService`, every
// write exchanged through the real receive decision (`ReplicaNetwork`) —
// and stamps its check-ins through the real `MetadataService`. The journal
// side is a small store per device holding the check-in versions it has
// received. What the trace supplies is the zone: a device's clock is a
// `TZDateTime` in its location, so `clock.now()` carries that device's wall
// clock and offset, and every stamp a device receives — a check-in's
// `dateFrom` and `updatedAt`, an agent entity's local stamps — is read the
// way `DateTime.parse` reads a value serialized without an offset: the
// writer's components in the reader's zone (`_readIn`). A UTC stamp is read
// as it is. A single process has one zone and CI's is UTC, where a local
// stamp cannot disagree with itself; `TZDateTime` is what lets two zones
// exist here at once.
//
// Model actions and trace operations:
//
//   Save(r)         a check-in saved on device r (`createMetadata`)
//   Touch(r, i)     `touchCheckIn` on device r: `updateMetadata` over the
//                   version it holds, once every device holds the latest
//   Tick(r)         `RelationshipAgentPhaseA.execute` on device r
//   Run(r, e)       the elected run of a due escalation record on device r:
//                   the record consumed as the manager fires it, then the
//                   real derivation and the real stand-down gate
//                   (`relationshipEscalationStandsDown`); a run that briefs
//                   stays in flight on r (AgentWakeOutcome's Start)
//   Finish(r)       the run in flight on r ends: the briefing stamped by
//                   `relationshipBriefingCreatedAt` with the run's start,
//                   the head, and the outcome stamped with the finish
//                   (`relationshipWakeOutcome` through `updateAgentState`,
//                   AgentWakeOutcome's End(ok))
//   Fail(r)         a wake on r — a chat, a Brief me — fails now: the
//                   outcome stamped as a failure (End(~ok))
//   TouchState(r)   another writer of the state row moves `updatedAt`
//                   (AgentWakeOutcome's Touch)
//   SyncJournal(r)  every check-in version device r is missing lands
//   SyncAgent(r)    every agent write device r is missing lands
//   Advance         the clock moves six hours
//
// Every run, finish, failure and touch moves the clock a minute first, so
// no two stamps coincide, as the model's logical clock does.
//
// After every step the trace checks DueDayAgreed and
// EscalationKeyIsTheDueDay. Once everything has arrived (the model's
// Quiescent) it checks StalenessAgreed and BriefedOnNewEvidence, then ticks
// every device until a round writes no register — RegisterStable — and
// checks FailedFaceAgreed (the card's failed face on every device is
// whether the wake that ended last failed) and Converged.

enum _CadenceOp {
  save,
  touch,
  tick,
  run,
  finish,
  fail,
  touchState,
  syncJournal,
  syncAgent,
  advance,
}

class _CadenceStep {
  const _CadenceStep(this.op, this.device, [this.arg = 0]);

  factory _CadenceStep.decode(int code) => _CadenceStep(
    _CadenceOp.values[code % _CadenceOp.values.length],
    (code ~/ _CadenceOp.values.length) % 2,
    code ~/ (_CadenceOp.values.length * 2),
  );

  final _CadenceOp op;
  final int device;

  /// Picks the check-in to touch or the record to run.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnyCadenceTrace on glados.Any {
  glados.Generator<List<_CadenceStep>> get cadenceTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        20,
        glados.IntAnys(this).intInRange(0, _CadenceOp.values.length * 2 * 3),
      )
      .map(
        (codes) => [for (final code in codes) _CadenceStep.decode(code)],
      );
}

const _cadencePersonId = 'person-1';
final String _cadenceAgentId = relationshipAgentIdFor(_cadencePersonId);
const _cadenceDays = 1;

/// The model's clock: a day in, six hours at a time, over two days.
final DateTime _cadenceT0 = DateTime.utc(2026, 8, 17);
const _cadenceStep = Duration(hours: 6);
const _cadenceMaxHours = 48;

/// The model's bounds.
const _cadenceMaxCheckIns = 2;
const _cadenceMaxTouches = 2;
const _cadenceMaxTicks = 6;
const _cadenceMaxRuns = 2;
const _cadenceMaxFailures = 2;
const _cadenceMaxStateTouches = 1;

/// [stamp] as a device in [zone] reads it: a local stamp was serialized
/// as the writer's wall-clock components without an offset, and is parsed
/// as those components in the reader's zone; a UTC stamp names its instant.
DateTime _readIn(tz.Location zone, DateTime stamp) => stamp.isUtc
    ? stamp
    : tz.TZDateTime(
        zone,
        stamp.year,
        stamp.month,
        stamp.day,
        stamp.hour,
        stamp.minute,
        stamp.second,
        stamp.millisecond,
        stamp.microsecond,
      );

DateTime? _readInOrNull(tz.Location zone, DateTime? stamp) =>
    stamp == null ? null : _readIn(zone, stamp);

CheckInEntry _checkInReadIn(tz.Location zone, CheckInEntry entry) =>
    entry.copyWith(
      meta: entry.meta.copyWith(
        createdAt: _readIn(zone, entry.meta.createdAt),
        updatedAt: _readIn(zone, entry.meta.updatedAt),
        dateFrom: _readIn(zone, entry.meta.dateFrom),
        dateTo: _readIn(zone, entry.meta.dateTo),
      ),
    );

/// The serialization boundary for the agent entities the cadence writes.
/// Every kind the trace can receive is named, so a new stamp cannot slip
/// through unread.
AgentDomainEntity _agentEntityReadIn(
  tz.Location zone,
  AgentDomainEntity entity,
) => switch (entity) {
  final RelationshipHealthEntity e => e.copyWith(
    referenceAt: _readIn(zone, e.referenceAt),
    dueAt: _readIn(zone, e.dueAt),
    lastCheckInAt: _readInOrNull(zone, e.lastCheckInAt),
    createdAt: _readIn(zone, e.createdAt),
    updatedAt: _readIn(zone, e.updatedAt),
  ),
  final ScheduledWakeEntity e => e.copyWith(
    scheduledAt: _readIn(zone, e.scheduledAt),
    updatedAt: _readIn(zone, e.updatedAt),
    consumedAt: _readInOrNull(zone, e.consumedAt),
    leaseUntil: _readInOrNull(zone, e.leaseUntil),
  ),
  final AgentReportEntity e => e.copyWith(
    createdAt: _readIn(zone, e.createdAt),
  ),
  final AgentReportHeadEntity e => e.copyWith(
    updatedAt: _readIn(zone, e.updatedAt),
  ),
  final AgentIdentityEntity e => e.copyWith(
    createdAt: _readIn(zone, e.createdAt),
    updatedAt: _readIn(zone, e.updatedAt),
  ),
  final AgentStateEntity e => e.copyWith(
    updatedAt: _readIn(zone, e.updatedAt),
    lastWakeAt: _readInOrNull(zone, e.lastWakeAt),
    lastWakeFailedAt: _readInOrNull(zone, e.lastWakeFailedAt),
    reportStaleAt: _readInOrNull(zone, e.reportStaleAt),
    reportFreshAt: _readInOrNull(zone, e.reportFreshAt),
    nextWakeAt: _readInOrNull(zone, e.nextWakeAt),
    sleepUntil: _readInOrNull(zone, e.sleepUntil),
    scheduledWakeAt: _readInOrNull(zone, e.scheduledWakeAt),
  ),
  _ => throw StateError('the cadence trace received a ${entity.runtimeType}'),
};

/// One version of a check-in as its writer stored it, with the instant the
/// writer meant — the truth the model's properties are checked against.
class _CheckInVersion {
  const _CheckInVersion(this.entry, this.version, this.trueUpdatedAt);

  final CheckInEntry entry;
  final int version;
  final DateTime trueUpdatedAt;
}

class _CadenceDevice {
  _CadenceDevice(ReplicaNetwork network, this.host, this.zone, this.world) {
    replica = network.join(
      host,
      reads: (entity) => _agentEntityReadIn(zone, entity),
    );
    metadata = MetadataService(vectorClockService: replica.device.clocks);
    phaseA = RelationshipAgentPhaseA(
      repository: replica.repository,
      syncService: replica.syncService,
      relationshipRepository: people,
    );
    when(
      () => people.getRelationshipByIdUnfiltered(_cadencePersonId),
    ).thenAnswer((_) async => person);
    when(
      () => people.getAllCheckInsForRelationship(_cadencePersonId),
    ).thenAnswer((_) async => heldCheckIns);
    when(
      () => people.getAllEntriesForCheckIns(any()),
    ).thenAnswer((_) async => const {});
  }

  final String host;
  final tz.Location zone;
  final _CadenceWorld world;
  late final AgentReplica replica;
  late final MetadataService metadata;
  late final RelationshipAgentPhaseA phaseA;
  final MockRelationshipRepository people = MockRelationshipRepository();

  /// The check-in versions this device holds, by id.
  final held = <String, int>{};

  /// The run in flight on this device: the facts it derived and when it
  /// began, until `finish` ends it.
  ({RelationshipCadenceDerivation derivation, DateTime startedAt})? inFlight;

  /// The device's wall clock at the world's instant.
  DateTime get now => tz.TZDateTime.from(world.t, zone);

  RelationshipEntry get person => world.person.copyWith(
    meta: world.person.meta.copyWith(
      createdAt: _readIn(zone, world.person.meta.createdAt),
      updatedAt: _readIn(zone, world.person.meta.updatedAt),
      dateFrom: _readIn(zone, world.person.meta.dateFrom),
      dateTo: _readIn(zone, world.person.meta.dateTo),
    ),
  );

  List<CheckInEntry> get heldCheckIns => [
    for (final id in world.checkInIds)
      if (held[id] case final version?)
        _checkInReadIn(zone, world.versions[id]![version - 1].entry),
  ];

  /// The newest check-in this device holds, by stored components — the one
  /// `deriveCadenceFacts` counts from.
  String? get newestCheckInId {
    String? newest;
    DateTime? newestAt;
    for (final entry in heldCheckIns) {
      final at = relationshipStoredInstant(entry.meta.dateFrom, 0);
      if (newestAt == null || at.isAfter(newestAt)) {
        newest = entry.id;
        newestAt = at;
      }
    }
    return newest;
  }

  Future<T> at<T>(Future<T> Function() body) =>
      withClock(Clock.fixed(now), body);

  Future<RelationshipCadenceDerivation> derive() => at(
    () => phaseA.deriveCadenceFacts(
      agentId: _cadenceAgentId,
      relationship: person,
      now: now,
    ),
  );

  Future<AgentReportEntity?> latestReport() =>
      replica.repository.getLatestReport(
        _cadenceAgentId,
        AgentReportScopes.current,
      );

  Future<AgentStateEntity?> state() =>
      replica.repository.getAgentState(_cadenceAgentId);

  Future<RelationshipHealthEntity?> register() async {
    final entity = await replica.repository.getEntity(
      relationshipHealthId(_cadenceAgentId),
    );
    return entity is RelationshipHealthEntity ? entity : null;
  }

  /// Every scheduled-wake record of the agent: the cadence tick and the
  /// escalations.
  Future<List<ScheduledWakeEntity>> records() async =>
      (await replica.repository.getEntitiesByAgentId(
        _cadenceAgentId,
        type: AgentEntityTypes.scheduledWake,
      )).whereType<ScheduledWakeEntity>().toList();

  Future<List<ScheduledWakeEntity>> escalations() async => [
    for (final record in await records())
      if (isRelationshipEscalationWorkspace(record.workspaceKey)) record,
  ];
}

class _CadenceWorld {
  _CadenceWorld() {
    devices = [
      _CadenceDevice(network, 'hBerlin', tz.getLocation('Europe/Berlin'), this),
      _CadenceDevice(network, 'hTokyo', tz.getLocation('Asia/Tokyo'), this),
    ];
  }

  final network = ReplicaNetwork();
  late final List<_CadenceDevice> devices;

  /// UTC.
  DateTime t = _cadenceT0;

  /// The person, created at noon the day before the clock starts on the
  /// Berlin device, so the counterexamples show the check-in.
  late final RelationshipEntry person = RelationshipEntry(
    meta: Metadata(
      id: _cadencePersonId,
      createdAt: tz.TZDateTime(devices.first.zone, 2026, 8, 16, 12),
      updatedAt: tz.TZDateTime(devices.first.zone, 2026, 8, 16, 12),
      dateFrom: tz.TZDateTime(devices.first.zone, 2026, 8, 16, 12),
      dateTo: tz.TZDateTime(devices.first.zone, 2026, 8, 16, 12),
      utcOffset: 120,
    ),
    data: RelationshipData(
      title: 'Anna',
      important: true,
      importantSince: DateTime.utc(2026, 8, 16, 10),
      checkInCadenceDays: _cadenceDays,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: DateTime.utc(2026, 8, 16, 10),
        utcOffset: 0,
      ),
    ),
  );

  /// Every check-in version written, by id, in order.
  final versions = <String, List<_CheckInVersion>>{};
  final checkInIds = <String>[];

  /// The instants the briefings were written at, in order.
  final briefings = <DateTime>[];

  /// The escalation workspaces a lease has elected a device to run.
  final ran = <String>{};

  int touches = 0;
  int ticks = 0;
  int runs = 0;
  int failures = 0;
  int stateTouches = 0;

  /// The outcome of the wake that ended last, or null before any did.
  bool? lastWakeOk;

  AgentIdentityEntity get identity => makeTestIdentity(
    id: _cadenceAgentId,
    agentId: _cadenceAgentId,
    kind: AgentKinds.relationshipAgent,
    displayName: 'Anna',
    currentStateId: '$_cadenceAgentId:state',
    createdAt: DateTime.utc(2026, 8, 16, 10),
    updatedAt: DateTime.utc(2026, 8, 16, 10),
  );

  /// The agent, its state row and its link exist on both devices before
  /// the clock starts.
  Future<void> setUp() async {
    final first = devices.first;
    await first.at(() async {
      await first.replica.syncService.upsertEntity(identity);
      await first.replica.syncService.upsertEntity(
        makeTestState(
          id: '$_cadenceAgentId:state',
          agentId: _cadenceAgentId,
          updatedAt: DateTime.utc(2026, 8, 16, 10),
        ),
      );
      await first.replica.syncService.upsertLink(
        AgentLink.agentRelationship(
          id: relationshipAgentLinkId(_cadenceAgentId),
          fromId: _cadenceAgentId,
          toId: _cadencePersonId,
          createdAt: DateTime.utc(2026, 8, 16, 10),
          updatedAt: DateTime.utc(2026, 8, 16, 10),
          vectorClock: null,
        ),
      );
    });
    await network.deliverAll();
  }

  Future<void> run(_CadenceStep step, Object trace) async {
    final device = devices[step.device];
    switch (step.op) {
      case _CadenceOp.save:
        if (checkInIds.length >= _cadenceMaxCheckIns) return;
        final id = 'check-in-${checkInIds.length + 1}';
        final meta = await device.at(
          () => device.metadata.createMetadata(id: id),
        );
        final entry = CheckInEntry(
          meta: meta,
          data: const CheckInData(
            relationshipId: _cadencePersonId,
            interactionType: CheckInInteractionType.call,
          ),
        );
        versions[id] = [_CheckInVersion(entry, 1, t)];
        checkInIds.add(id);
        device.held[id] = 1;
      case _CadenceOp.touch:
        if (touches >= _cadenceMaxTouches || checkInIds.isEmpty) return;
        final id = checkInIds[step.arg % checkInIds.length];
        final latest = versions[id]!.last;
        // One writer at a time: a touch on a device that holds the latest
        // version, once every device does.
        if (devices.any((d) => d.held[id] != latest.version)) return;
        final mine = _checkInReadIn(device.zone, latest.entry);
        final meta = await device.at(
          () => device.metadata.updateMetadata(mine.meta),
        );
        versions[id]!.add(
          _CheckInVersion(mine.copyWith(meta: meta), latest.version + 1, t),
        );
        device.held[id] = latest.version + 1;
        touches++;
      case _CadenceOp.tick:
        if (ticks >= _cadenceMaxTicks) return;
        ticks++;
        await _tick(device);
      case _CadenceOp.run:
        if (runs >= _cadenceMaxRuns || device.inFlight != null) return;
        final due = [
          for (final record in await device.escalations())
            if (record.status == ScheduledWakeStatus.pending &&
                !record.scheduledAt.isAfter(t) &&
                !ran.contains(record.workspaceKey))
              record,
        ];
        if (due.isEmpty) return;
        final record = due[step.arg % due.length];
        ran.add(record.workspaceKey!);
        runs++;
        _minute();
        await _runEscalation(device, record);
      case _CadenceOp.finish:
        if (device.inFlight == null) return;
        _minute();
        await _finishRun(device);
      case _CadenceOp.fail:
        if (failures >= _cadenceMaxFailures || device.inFlight != null) {
          return;
        }
        failures++;
        _minute();
        await _stampOutcome(device, succeeded: false);
      case _CadenceOp.touchState:
        if (stateTouches >= _cadenceMaxStateTouches) return;
        stateTouches++;
        _minute();
        await device.at(() async {
          final now = clock.now();
          await device.replica.syncService.updateAgentState(
            _cadenceAgentId,
            (current) => current.copyWith(
              updatedAt: now,
              reportStaleAt: now.toUtc(),
            ),
          );
        });
      case _CadenceOp.syncJournal:
        for (final id in checkInIds) {
          device.held[id] = versions[id]!.last.version;
        }
      case _CadenceOp.syncAgent:
        for (final index in network.pendingFor(device.replica)) {
          await device.replica.receive(index);
        }
      case _CadenceOp.advance:
        final next = t.add(_cadenceStep);
        if (next.isAfter(
          _cadenceT0.add(const Duration(hours: _cadenceMaxHours)),
        )) {
          return;
        }
        t = next;
    }
  }

  /// The clock moves a minute: every stamp is distinct, as in the model.
  void _minute() => t = t.add(const Duration(minutes: 1));

  /// A wake's outcome, stamped the way the workflow stamps it.
  Future<void> _stampOutcome(
    _CadenceDevice device, {
    required bool succeeded,
  }) async {
    await device.at(
      () => device.replica.syncService.updateAgentState(
        _cadenceAgentId,
        (current) => relationshipWakeOutcome(
          current,
          now: clock.now(),
          succeeded: succeeded,
        ),
      ),
    );
    lastWakeOk = succeeded;
  }

  Future<void> _tick(_CadenceDevice device) => device.at(
    () => device.phaseA.execute(
      agentIdentity: identity,
      runKey: 'run-${ticks + runs}',
      triggerTokens: const {},
      threadId: 'thread-1',
    ),
  );

  /// The elected run: the record consumed, the facts derived again, and
  /// the run stood down — or left in flight, to brief when it finishes.
  Future<void> _runEscalation(
    _CadenceDevice device,
    ScheduledWakeEntity record,
  ) => device.at(() async {
    final now = clock.now();
    await device.replica.syncService.upsertEntity(
      record.copyWith(
        status: ScheduledWakeStatus.consumed,
        consumedAt: now,
        updatedAt: now,
      ),
    );
    final derivation = await device.phaseA.deriveCadenceFacts(
      agentId: _cadenceAgentId,
      relationship: device.person,
      now: now,
    );
    final previous = await device.latestReport();
    if (relationshipEscalationStandsDown(
      derivation: derivation,
      previousReport: previous,
      escalationKey: relationshipEscalationDueDayFromTriggerTokens(
        record.triggerTokens.toSet(),
      ),
      eligible: true,
    )) {
      return;
    }
    device.inFlight = (derivation: derivation, startedAt: now);
  });

  /// The run in flight ends: the briefing stamped with the run's start, the
  /// standing head advanced the way the workflow advances it — never back
  /// to an older due day, stamped by the due day, carrying the head it
  /// replaces — and the outcome stamped with the finish.
  Future<void> _finishRun(_CadenceDevice device) async {
    final (:derivation, :startedAt) = device.inFlight!;
    device.inFlight = null;
    await device.at(() async {
      final reportId = 'briefing-${briefings.length + 1}';
      await device.replica.syncService.upsertEntity(
        AgentDomainEntity.agentReport(
          id: reportId,
          agentId: _cadenceAgentId,
          scope: AgentReportScopes.current,
          createdAt: relationshipBriefingCreatedAt(startedAt),
          vectorClock: null,
          content: 'briefing ${briefings.length + 1}',
          provenance: {'dueDayKey': derivation.dueDayKey},
        ),
      );
      final existingHead = await device.replica.repository.getReportHead(
        _cadenceAgentId,
        AgentReportScopes.current,
      );
      final published = existingHead == null
          ? null
          : await device.replica.repository.getEntity(existingHead.reportId);
      final publishedDueDay = published is AgentReportEntity
          ? published.provenance['dueDayKey']
          : null;
      if (publishedDueDay is! String ||
          derivation.dueDayKey.compareTo(publishedDueDay) >= 0) {
        await device.replica.syncService.upsertEntity(
          AgentDomainEntity.agentReportHead(
            id: existingHead?.id ?? 'head-$reportId',
            agentId: _cadenceAgentId,
            scope: AgentReportScopes.current,
            reportId: reportId,
            updatedAt: relationshipReportHeadUpdatedAt(
              derivation.dueDayUtc,
              startedAt,
            ),
            vectorClock: existingHead?.vectorClock,
          ),
        );
      }
      briefings.add(startedAt.toUtc());
    });
    await _stampOutcome(device, succeeded: true);
  }

  /// Every agent entity any device has sent, in order.
  Iterable<AgentDomainEntity> get sentEntities =>
      devices.expand((d) => d.replica.device.sentEntities);

  /// The lapse escalations written so far, by the due day each names.
  Iterable<String> get lapseDayKeys => [
    for (final entity in sentEntities)
      if (entity case ScheduledWakeEntity(:final workspaceKey?))
        if (isRelationshipEscalationWorkspace(workspaceKey) &&
            !workspaceKey.contains(':refresh-'))
          workspaceKey.substring(
            relationshipEscalationWorkspacePrefix.length + 1,
          ),
  ];

  /// The due days some check-in, or the tracking start, names on the
  /// writer's calendar.
  Set<String> get dueDaysNamed => {
    for (final id in checkInIds)
      for (final version in versions[id]!)
        const GoalWindow.day().periodKey(
          relationshipDueDay(version.entry.meta.dateFrom, _cadenceDays),
        ),
    const GoalWindow.day().periodKey(
      relationshipDueDay(person.meta.dateFrom, _cadenceDays),
    ),
  };

  /// DueDayAgreed and EscalationKeyIsTheDueDay, after every step.
  Future<void> check(Object trace) async {
    final derivations = [for (final d in devices) await d.derive()];
    final newest = [for (final d in devices) d.newestCheckInId];
    if (newest.first == newest.last) {
      expect(
        derivations.first.dueDayKey,
        derivations.last.dueDayKey,
        reason: 'DueDayAgreed (newest ${newest.first}): $trace',
      );
    }
    final named = dueDaysNamed;
    for (final key in lapseDayKeys) {
      expect(
        named,
        contains(key),
        reason: 'EscalationKeyIsTheDueDay ($key): $trace',
      );
    }
  }

  /// The truth: the newest change to any check-in is newer than every
  /// briefing, or there is a check-in and no briefing.
  bool get truthStale {
    DateTime? newest;
    for (final id in checkInIds) {
      for (final version in versions[id]!) {
        if (newest == null || version.trueUpdatedAt.isAfter(newest)) {
          newest = version.trueUpdatedAt;
        }
      }
    }
    if (newest == null) return false;
    return briefings.every((at) => newest!.isAfter(at));
  }

  int get registerWrites =>
      sentEntities.whereType<RelationshipHealthEntity>().length;

  /// Everything arrives, then the quiescent properties.
  Future<void> settleAndCheck(Object trace) async {
    for (final device in devices) {
      if (device.inFlight != null) {
        _minute();
        await _finishRun(device);
      }
      for (final id in checkInIds) {
        device.held[id] = versions[id]!.last.version;
      }
    }
    await network.deliverAll();

    final stale = <bool>[];
    for (final device in devices) {
      final derivation = await device.derive();
      stale.add(
        relationshipEvidenceNewerThan(derivation, await device.latestReport()),
      );
    }
    final truth = truthStale;
    for (final (i, device) in devices.indexed) {
      expect(
        stale[i],
        truth,
        reason: 'StalenessAgreed on ${device.host}: $trace',
      );
    }
    if (truth) {
      expect(stale, contains(true), reason: 'BriefedOnNewEvidence: $trace');
    }

    // RegisterStable: a tick on every device, everything delivered, until a
    // round writes no register. Two zones disagreeing rewrite it forever.
    var stable = false;
    for (var round = 0; round < 4 && !stable; round++) {
      final before = registerWrites;
      for (final device in devices) {
        await _tick(device);
      }
      await network.deliverAll();
      stable = registerWrites == before;
    }
    expect(stable, isTrue, reason: 'RegisterStable: $trace');

    String describe(RelationshipHealthEntity? row) => row == null
        ? 'none'
        : '${row.status.name} due ${row.dueAt.toUtc().toIso8601String()} '
              'ref ${row.referenceAt.toUtc().toIso8601String()} '
              'last ${row.lastCheckInAt?.toUtc().toIso8601String()} '
              'every ${row.cadenceDays}';
    final registers = [
      for (final device in devices) describe(await device.register()),
    ];
    final reports = [
      for (final device in devices) (await device.latestReport())?.id,
    ];
    // FailedFaceAgreed: the card's failed face on every device is whether
    // the wake that ended last failed.
    if (lastWakeOk case final ok?) {
      for (final device in devices) {
        final face = relationshipAgentCardStateOf(
          enrolled: true,
          isRunning: false,
          report: await device.latestReport(),
          state: await device.state(),
        );
        expect(
          face == RelationshipAgentCardState.failed,
          !ok,
          reason: 'FailedFaceAgreed on ${device.host} ($face): $trace',
        );
      }
    }
    final outcomes = [
      for (final device in devices)
        if (await device.state() case final row?)
          'done ${row.lastWakeAt?.toUtc().toIso8601String()} '
              'failed ${row.lastWakeFailedAt?.toUtc().toIso8601String()}'
        else
          'none',
    ];
    String describeRecord(ScheduledWakeEntity record) =>
        '${record.workspaceKey} ${record.status.name} '
        '${record.scheduledAt.toUtc().toIso8601String()}';
    // The escalations and the cadence tick: one shared record each, which
    // a deadline written in local time made a different instant per zone.
    final records = [
      for (final device in devices)
        {
          for (final record in await device.records()) describeRecord(record),
        },
    ];
    expect(
      registers.toSet(),
      hasLength(1),
      reason: 'Converged (register): $trace',
    );
    expect(
      reports.toSet(),
      hasLength(1),
      reason: 'Converged (briefing): $trace',
    );
    expect(records.first, records.last, reason: 'Converged (records): $trace');
    expect(
      outcomes.toSet(),
      hasLength(1),
      reason: 'Converged (outcome): $trace',
    );
  }

  Future<void> close() => network.close();
}

Future<void> _playCadenceTrace(List<_CadenceStep> trace) async {
  final world = _CadenceWorld();
  try {
    await world.setUp();
    for (final step in trace) {
      await world.run(step, trace);
      await world.check(trace);
    }
    await world.settleAndCheck(trace);
  } finally {
    await world.close();
  }
}

void _registerRelationshipCadenceConformance() {
  group('model conformance with specs/tla/RelationshipCadence.tla', () {
    setUpAll(tz_data.initializeTimeZones);

    glados.Glados(
      glados.any.cadenceTrace,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated saves, touches, ticks, runs, deliveries and hours leave two '
      'zones agreeing on the due day, one escalation per lapse, a still '
      'register, and the same view of what the briefing covers',
      _playCadenceTrace,
      tags: 'glados',
    );

    const berlin = 0;
    const tokyo = 1;

    test(
      'Berlin saves a check-in at 02:00; Tokyo reads the same components a '
      'day earlier in UTC, and must still derive the same due day '
      '(DueDayAgreed)',
      () => _playCadenceTrace(const [
        _CadenceStep(_CadenceOp.save, berlin),
        _CadenceStep(_CadenceOp.syncJournal, tokyo),
      ]),
    );

    test(
      "Berlin's tick writes its due day and Tokyo receives the row and the "
      'check-in: the register must not be rewritten at each other '
      '(RegisterStable)',
      () => _playCadenceTrace(const [
        _CadenceStep(_CadenceOp.save, berlin),
        _CadenceStep(_CadenceOp.tick, berlin),
        _CadenceStep(_CadenceOp.syncJournal, tokyo),
        _CadenceStep(_CadenceOp.syncAgent, tokyo),
        _CadenceStep(_CadenceOp.tick, tokyo),
      ]),
    );

    test(
      'Tokyo saves a check-in at 03:00 and ticks a day later: the lapse '
      'escalation it arms is keyed by a day that check-in names on its '
      "writer's calendar (EscalationKeyIsTheDueDay)",
      () => _playCadenceTrace(const [
        _CadenceStep(_CadenceOp.advance, berlin),
        _CadenceStep(_CadenceOp.advance, berlin),
        _CadenceStep(_CadenceOp.advance, berlin),
        _CadenceStep(_CadenceOp.save, tokyo),
        _CadenceStep(_CadenceOp.advance, berlin),
        _CadenceStep(_CadenceOp.tick, tokyo),
      ]),
    );

    test(
      'Tokyo saves a check-in and Berlin briefs on it; Berlin then touches '
      'it, and the touch must be read as evidence newer than the briefing '
      'on some device (BriefedOnNewEvidence)',
      () => _playCadenceTrace(const [
        _CadenceStep(_CadenceOp.save, tokyo),
        _CadenceStep(_CadenceOp.syncJournal, berlin),
        _CadenceStep(_CadenceOp.tick, berlin),
        _CadenceStep(_CadenceOp.advance, berlin),
        _CadenceStep(_CadenceOp.run, berlin),
        _CadenceStep(_CadenceOp.advance, berlin),
        _CadenceStep(_CadenceOp.touch, berlin),
      ]),
    );

    test(
      'a short failure in Tokyo that began after a long success in Berlin '
      'began does not outrank it: the outcome is stamped when the wake ends '
      '(FailedFaceAgreed, AgentWakeOutcome StampAtEnd)',
      () => _playCadenceTrace(const [
        _CadenceStep(_CadenceOp.save, berlin),
        _CadenceStep(_CadenceOp.tick, berlin),
        _CadenceStep(_CadenceOp.advance, berlin),
        _CadenceStep(_CadenceOp.run, berlin),
        _CadenceStep(_CadenceOp.fail, tokyo),
        _CadenceStep(_CadenceOp.finish, berlin),
      ]),
    );

    test(
      'a later unrelated write of the state row on the device that failed '
      "does not carry its failure over Berlin's newer success: the outcome "
      'watermarks are joined, never last-writer-wins (FailedFaceAgreed, '
      'AgentWakeOutcome OutcomeWatermarks)',
      () => _playCadenceTrace(const [
        _CadenceStep(_CadenceOp.fail, tokyo),
        _CadenceStep(_CadenceOp.save, berlin),
        _CadenceStep(_CadenceOp.tick, berlin),
        _CadenceStep(_CadenceOp.advance, berlin),
        _CadenceStep(_CadenceOp.run, berlin),
        _CadenceStep(_CadenceOp.finish, berlin),
        _CadenceStep(_CadenceOp.touchState, tokyo),
      ]),
    );

    test(
      'Berlin briefs on its own check-in; Tokyo must read the briefing as '
      'covering that evidence, not as hours behind it (StalenessAgreed)',
      () => _playCadenceTrace(const [
        _CadenceStep(_CadenceOp.save, berlin),
        _CadenceStep(_CadenceOp.tick, berlin),
        _CadenceStep(_CadenceOp.advance, berlin),
        _CadenceStep(_CadenceOp.run, berlin),
        _CadenceStep(_CadenceOp.syncJournal, tokyo),
        _CadenceStep(_CadenceOp.syncAgent, tokyo),
      ]),
    );
  });
}
