import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'relationship_agent:person-1';
  const relationshipId = 'person-1';
  final testDate = DateTime(2026, 8, 1, 9);
  final now = DateTime(2026, 8, 16, 12);

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockRelationshipRepository relationshipRepository;
  late List<AgentDomainEntity> upserts;
  late int escalationCallbacks;
  late _RecordingReminderSink reminders;

  /// Every agent write and every reminder call, in the order they happened.
  /// The reminder projection must land *after* the transaction commits — it
  /// writes to a different database behind its own vector-clock scope.
  late List<String> events;
  late RelationshipAgentPhaseA phaseA;

  AgentIdentityEntity identity() =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.relationshipAgent,
            displayName: 'Anna',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: const AgentConfig(),
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          )
          as AgentIdentityEntity;

  Metadata meta(String id, {DateTime? dateFrom, DateTime? deletedAt}) =>
      Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: dateFrom ?? testDate,
        dateTo: dateFrom ?? testDate,
        deletedAt: deletedAt,
      );

  RelationshipEntry relationship({
    bool important = true,
    int? cadenceDays = 7,
    RelationshipStatus? status,
    DateTime? trackingStart,
    DateTime? deletedAt,
  }) => RelationshipEntry(
    meta: meta(relationshipId, dateFrom: trackingStart, deletedAt: deletedAt),
    data: RelationshipData(
      title: 'Anna',
      important: important,
      checkInCadenceDays: cadenceDays,
      status:
          status ??
          RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
    ),
  );

  CheckInEntry checkIn(String id, DateTime at) => CheckInEntry(
    meta: meta(id, dateFrom: at),
    data: const CheckInData(
      relationshipId: relationshipId,
      interactionType: CheckInInteractionType.call,
    ),
  );

  Future<WakeResult> run() async => phaseA.execute(
    agentIdentity: identity(),
    runKey: 'run-1',
    triggerTokens: const {},
    threadId: 'thread-1',
  );

  setUp(() {
    repository = MockAgentRepository();
    upserts = [];
    escalationCallbacks = 0;
    events = [];
    syncService = _TransactionRecordingSyncService(events);
    relationshipRepository = MockRelationshipRepository();
    reminders = _RecordingReminderSink(events);
    phaseA = RelationshipAgentPhaseA(
      repository: repository,
      syncService: syncService,
      relationshipRepository: relationshipRepository,
      onEscalationArmed: () => escalationCallbacks++,
      reminders: reminders,
    );
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => repository.getLatestReport(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getEntitiesByAgentId(any(), type: any(named: 'type')),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getLinksFrom(
        agentId,
        type: AgentLinkTypes.agentRelationship,
      ),
    ).thenAnswer(
      (_) async => [
        AgentLink.agentRelationship(
          id: relationshipAgentLinkId(agentId),
          fromId: agentId,
          toId: relationshipId,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      ],
    );
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
      upserts.add(entity);
      events.add('upsert:${entity.runtimeType}');
    });
    when(
      () =>
          relationshipRepository.getRelationshipByIdUnfiltered(relationshipId),
    ).thenAnswer((_) async => relationship());
    when(
      () => relationshipRepository.getAllCheckInsForRelationship(
        relationshipId,
      ),
    ).thenAnswer((_) async => []);
  });

  AgentReportEntity freshReport(DateTime createdAt) =>
      AgentDomainEntity.agentReport(
            id: 'report-1',
            agentId: agentId,
            scope: AgentReportScopes.current,
            createdAt: createdAt,
            vectorClock: null,
            content: 'briefing',
            tldr: 'briefing',
          )
          as AgentReportEntity;

  RelationshipHealthEntity? writtenRegister() =>
      upserts.whereType<RelationshipHealthEntity>().singleOrNull;
  List<ScheduledWakeEntity> writtenWakes() =>
      upserts.whereType<ScheduledWakeEntity>().toList();

  test('no agent link: succeeds and writes nothing', () async {
    when(
      () => repository.getLinksFrom(
        agentId,
        type: AgentLinkTypes.agentRelationship,
      ),
    ).thenAnswer((_) async => []);
    final result = await withClock(Clock.fixed(now), run);
    expect(result.success, isTrue);
    expect(upserts, isEmpty);
  });

  test('ineligible relationships re-arm the cadence but never produce a '
      'register — important is the single consent switch (ADR 0039), and '
      'flipping it back on must need no re-wiring', () async {
    final ineligible = [
      relationship(important: false),
      relationship(
        status: RelationshipStatus.dormant(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
    ];
    for (final entry in ineligible) {
      upserts.clear();
      when(
        () => relationshipRepository.getRelationshipByIdUnfiltered(
          relationshipId,
        ),
      ).thenAnswer((_) async => entry);
      final result = await withClock(Clock.fixed(now), run);
      expect(result.success, isTrue);
      expect(writtenRegister(), isNull, reason: '${entry.data.status}');
      expect(
        writtenWakes().single.workspaceKey,
        relationshipCadenceWorkspaceKey,
      );
    }
  });

  test(
    'a deleted person stops the agent for good: NOTHING is written, the '
    'cadence tick included — re-arming here is what kept an orphaned '
    'agent (deleted through the generic journal path) waking forever',
    () async {
      for (final gone in <RelationshipEntry?>[
        relationship(deletedAt: testDate),
        null,
      ]) {
        upserts.clear();
        when(
          () => relationshipRepository.getRelationshipByIdUnfiltered(
            relationshipId,
          ),
        ).thenAnswer((_) async => gone);
        final result = await withClock(Clock.fixed(now), run);
        expect(result.success, isTrue);
        expect(upserts, isEmpty, reason: 'gone: ${gone?.meta.deletedAt}');
      }
    },
  );

  test('the relationship read is UNFILTERED — a private person must derive '
      'the same register on a device that hides private entries as on one '
      'that shows them', () async {
    await withClock(Clock.fixed(now), run);
    verify(
      () => relationshipRepository.getRelationshipByIdUnfiltered(
        relationshipId,
      ),
    ).called(1);
    verifyNever(() => relationshipRepository.getRelationshipById(any()));
  });

  test('inside the cadence: register says ok with the check-in as the '
      'reference; no escalation, no callback', () async {
    final lastCheckIn = DateTime(2026, 8, 14, 20);
    // The briefing already covers the newest check-in — nothing is stale.
    when(
      () => repository.getLatestReport(any(), any()),
    ).thenAnswer((_) async => freshReport(DateTime(2026, 8, 15)));
    when(
      () => relationshipRepository.getAllCheckInsForRelationship(
        relationshipId,
      ),
    ).thenAnswer(
      (_) async => [
        checkIn('c-old', DateTime(2026, 8, 2, 18)),
        checkIn('c-new', lastCheckIn),
      ],
    );
    await withClock(Clock.fixed(now), run);

    final register = writtenRegister()!;
    expect(register.id, relationshipHealthId(agentId));
    expect(register.status, RelationshipCadenceStatus.ok);
    expect(register.relationshipId, relationshipId);
    expect(register.cadenceDays, 7);
    expect(register.referenceAt, lastCheckIn.toUtc());
    expect(register.lastCheckInAt, lastCheckIn.toUtc());
    // 2026-08-14 + 7 days, as a UTC day key.
    expect(register.dueAt, DateTime.utc(2026, 8, 21));
    expect(
      writtenWakes().map((w) => w.workspaceKey),
      [relationshipCadenceWorkspaceKey],
      reason: 'an ok cadence must not spend an escalation',
    );
    expect(escalationCallbacks, 0);
  });

  test('the newest check-in wins regardless of list order', () async {
    when(
      () => relationshipRepository.getAllCheckInsForRelationship(
        relationshipId,
      ),
    ).thenAnswer(
      (_) async => [
        checkIn('c-mid', DateTime(2026, 8, 10)),
        checkIn('c-newest', DateTime(2026, 8, 15)),
        checkIn('c-oldest', DateTime(2026, 8, 2)),
      ],
    );
    await withClock(Clock.fixed(now), run);
    expect(writtenRegister()!.referenceAt, DateTime(2026, 8, 15).toUtc());
  });

  test('no check-ins yet: the baseline is tracking start and the default '
      'cadence applies — the first reminder is never suppressed', () async {
    when(
      () =>
          relationshipRepository.getRelationshipByIdUnfiltered(relationshipId),
    ).thenAnswer(
      (_) async => relationship(
        cadenceDays: null,
        trackingStart: DateTime(2026, 8, 10, 15),
      ),
    );
    await withClock(Clock.fixed(now), run);

    final register = writtenRegister()!;
    expect(register.lastCheckInAt, isNull);
    expect(register.referenceAt, DateTime(2026, 8, 10, 15).toUtc());
    expect(register.cadenceDays, relationshipDefaultCadenceDays);
    expect(register.dueAt, DateTime.utc(2026, 9, 9));
    expect(register.status, RelationshipCadenceStatus.ok);
  });

  group('the episode key is zone-free', () {
    // The due day IS the episode key: `_upsertRegister` compares `dueAt` and
    // `relationshipEscalationWake` mints its workspace key from `dueDayKey`.
    // Deriving either through the device's local calendar makes two devices
    // in different timezones disagree about the same check-in — they then
    // rewrite the register at each other forever, and pay for the same lapse
    // twice.
    //
    // A single process cannot hold two timezones, so these assert the UTC
    // contract directly. They are CORRECT on every machine; the first one is
    // only DISCRIMINATING off UTC, where the reference instant's local
    // calendar day differs from its UTC one.
    test("the reference instant's UTC day drives the due day, not the "
        "device's local calendar day", () async {
      // 23:30Z — a later local day everywhere east of Greenwich, an earlier
      // one everywhere west. UTC day 10, plus the fixture's 7-day cadence.
      final reference = DateTime.utc(2026, 8, 10, 23, 30);
      when(
        () => relationshipRepository.getRelationshipByIdUnfiltered(
          relationshipId,
        ),
      ).thenAnswer((_) async => relationship(trackingStart: reference));

      await withClock(Clock.fixed(now), run);

      final register = writtenRegister()!;
      expect(register.referenceAt, reference);
      expect(register.cadenceDays, 7);
      expect(register.dueAt, DateTime.utc(2026, 8, 17));
      expect(register.dueAt.isUtc, isTrue);
    });

    test('the escalation workspace key and its deadline are minted from the '
        'same UTC day, across a month boundary', () async {
      final reference = DateTime.utc(2026, 8, 28, 22);
      when(
        () => relationshipRepository.getRelationshipByIdUnfiltered(
          relationshipId,
        ),
      ).thenAnswer(
        (_) async => relationship(cadenceDays: 5, trackingStart: reference),
      );

      // Well past 2026-09-02, so the cadence has lapsed and an episode arms.
      await withClock(Clock.fixed(DateTime.utc(2026, 9, 20, 12)), run);

      final escalation = writtenWakes().singleWhere(
        (w) => isRelationshipEscalationWorkspace(w.workspaceKey),
      );
      expect(
        escalation.workspaceKey,
        relationshipEscalationWorkspaceKey('2026-09-02'),
      );
      expect(escalation.scheduledAt, DateTime.utc(2026, 9, 2));
      expect(writtenRegister()!.dueAt, DateTime.utc(2026, 9, 2));
    });

    test('the register row round-trips through JSON persistence intact — '
        'referenceAt and lastCheckInAt are UTC, so they serialize '
        'zone-suffixed and a peer in any timezone parses the same instants '
        '(a LOCAL instant serializes without an offset and would shift, '
        'failing the unchanged-check and rewriting the register on every '
        'sync)', () async {
      final lastCheckIn = DateTime(2026, 8, 14, 20);
      when(
        () => relationshipRepository.getAllCheckInsForRelationship(
          relationshipId,
        ),
      ).thenAnswer((_) async => [checkIn('c-1', lastCheckIn)]);
      when(
        () => repository.getLatestReport(any(), any()),
      ).thenAnswer((_) async => freshReport(DateTime(2026, 8, 15)));
      await withClock(Clock.fixed(now), run);

      final register = writtenRegister()!;
      expect(register.referenceAt.isUtc, isTrue);
      expect(register.lastCheckInAt!.isUtc, isTrue);
      expect(register.dueAt.isUtc, isTrue);

      final decoded =
          AgentDomainEntity.fromJson(
                jsonDecode(jsonEncode(register.toJson()))
                    as Map<String, dynamic>,
              )
              as RelationshipHealthEntity;
      expect(decoded.referenceAt, register.referenceAt);
      expect(decoded.referenceAt.isUtc, isTrue);
      expect(decoded.lastCheckInAt, register.lastCheckInAt);
      expect(decoded.lastCheckInAt!.isUtc, isTrue);
      expect(decoded.dueAt, register.dueAt);
    });
  });

  group('a lapsed cadence', () {
    setUp(() {
      // Last check-in 2026-08-01, cadence 7 → due day 2026-08-08, now the
      // 16th: overdue.
      when(
        () => relationshipRepository.getAllCheckInsForRelationship(
          relationshipId,
        ),
      ).thenAnswer((_) async => [checkIn('c-1', DateTime(2026, 8, 1, 18))]);
    });

    test('with a previous ok register arms EXACTLY one lease-elected '
        'escalation carrying the baseline token', () async {
      when(
        () => repository.getEntity(relationshipHealthId(agentId)),
      ).thenAnswer(
        (_) async => AgentDomainEntity.relationshipHealth(
          id: relationshipHealthId(agentId),
          agentId: agentId,
          relationshipId: relationshipId,
          status: RelationshipCadenceStatus.ok,
          cadenceDays: 7,
          referenceAt: DateTime(2026, 8, 1, 18),
          dueAt: DateTime.utc(2026, 8, 8),
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          lastCheckInAt: DateTime(2026, 8, 1, 18),
        ),
      );
      await withClock(Clock.fixed(now), run);

      expect(writtenRegister()!.status, RelationshipCadenceStatus.due);
      final escalation = writtenWakes().singleWhere(
        (w) => isRelationshipEscalationWorkspace(w.workspaceKey),
      );
      expect(
        escalation.workspaceKey,
        relationshipEscalationWorkspaceKey('2026-08-08'),
      );
      expect(escalation.scheduledAt, DateTime.utc(2026, 8, 8));
      expect(
        escalation.triggerTokens,
        containsAll([
          relationshipEscalationWorkspaceKey('2026-08-08'),
          relationshipEscalationBaselineToken('ok'),
        ]),
      );
      expect(escalationCallbacks, 1);
    });

    test('with no previous register the escalation carries no baseline '
        'token — a first evaluation has no pre-transition state', () async {
      await withClock(Clock.fixed(now), run);
      final escalation = writtenWakes().singleWhere(
        (w) => isRelationshipEscalationWorkspace(w.workspaceKey),
      );
      expect(
        escalation.triggerTokens.where(
          (t) => t.startsWith(relationshipEscalationBaselinePrefix),
        ),
        isEmpty,
      );
    });

    test('still due (previous register already says due): no second '
        'escalation, no callback', () async {
      // The briefing already covers the newest check-in — a still-due day
      // with nothing new must stay quiet (only NEWLY due or fresh
      // evidence spends the LLM tier).
      when(
        () => repository.getLatestReport(any(), any()),
      ).thenAnswer((_) async => freshReport(DateTime(2026, 8, 2)));
      when(
        () => repository.getEntity(relationshipHealthId(agentId)),
      ).thenAnswer(
        (_) async => AgentDomainEntity.relationshipHealth(
          id: relationshipHealthId(agentId),
          agentId: agentId,
          relationshipId: relationshipId,
          status: RelationshipCadenceStatus.due,
          cadenceDays: 7,
          referenceAt: DateTime(2026, 8, 1, 18),
          dueAt: DateTime.utc(2026, 8, 8),
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          lastCheckInAt: DateTime(2026, 8, 1, 18),
        ),
      );
      await withClock(Clock.fixed(now), run);
      expect(
        writtenWakes().where(
          (w) => isRelationshipEscalationWorkspace(w.workspaceKey),
        ),
        isEmpty,
      );
      expect(escalationCallbacks, 0);
    });

    test(
      'an episode already armed (synced from a peer, whatever its '
      'status) is never re-armed — arming is idempotent per due day',
      () async {
        when(
          () => repository.getEntity(
            scheduledWakeRecordId(
              agentId,
              workspaceKey: relationshipEscalationWorkspaceKey('2026-08-08'),
            ),
          ),
        ).thenAnswer(
          (_) async => AgentDomainEntity.scheduledWake(
            id: scheduledWakeRecordId(
              agentId,
              workspaceKey: relationshipEscalationWorkspaceKey('2026-08-08'),
            ),
            agentId: agentId,
            scheduledAt: DateTime.utc(2026, 8, 8),
            status: ScheduledWakeStatus.consumed,
            reason: WakeReason.scheduled.name,
            updatedAt: testDate,
            vectorClock: null,
            workspaceKey: relationshipEscalationWorkspaceKey('2026-08-08'),
          ),
        );
        await withClock(Clock.fixed(now), run);
        expect(
          writtenWakes().where(
            (w) => isRelationshipEscalationWorkspace(w.workspaceKey),
          ),
          isEmpty,
        );
        expect(escalationCallbacks, 0);
      },
    );
  });

  test('an unchanged derivation writes NOTHING — the €0 no-op the plan '
      'demands', () async {
    when(
      () => relationshipRepository.getAllCheckInsForRelationship(
        relationshipId,
      ),
    ).thenAnswer((_) async => [checkIn('c-1', DateTime(2026, 8, 14, 20))]);
    when(
      () => repository.getLatestReport(any(), any()),
    ).thenAnswer((_) async => freshReport(DateTime(2026, 8, 15)));

    await withClock(Clock.fixed(now), run);
    final firstRegister = writtenRegister()!;
    final firstWake = writtenWakes().single;

    // Second tick: everything Phase A wrote is now what it reads back.
    when(
      () => repository.getEntity(relationshipHealthId(agentId)),
    ).thenAnswer((_) async => firstRegister);
    when(
      () => repository.getEntity(firstWake.id),
    ).thenAnswer((_) async => firstWake);
    upserts.clear();

    await withClock(Clock.fixed(now), run);
    expect(upserts, isEmpty);
  });

  test('two devices deriving the same facts write identical register '
      'content — recompute-never-accumulate convergence', () async {
    when(
      () => relationshipRepository.getAllCheckInsForRelationship(
        relationshipId,
      ),
    ).thenAnswer((_) async => [checkIn('c-1', DateTime(2026, 8, 1, 18))]);

    await withClock(Clock.fixed(now), run);
    final deviceA = writtenRegister()!;

    upserts.clear();
    escalationCallbacks = 0;
    await withClock(Clock.fixed(now), run);
    final deviceB = writtenRegister()!;

    expect(deviceB, deviceA);
    final wakesA = writtenWakes();
    expect(
      wakesA.map((w) => w.id).toSet(),
      hasLength(wakesA.length),
      reason: 'per-episode ids: both devices write the SAME records',
    );
  });

  test('a check-in newer than the briefing arms a report-refresh escalation '
      'even inside the cadence — "check-in saved since last report" is a '
      'spend-worthy fact (ADR 0059), and it must be due IMMEDIATELY, not on '
      'the next due day', () async {
    final checkInAt = DateTime(2026, 8, 14, 20);
    when(
      () => relationshipRepository.getAllCheckInsForRelationship(
        relationshipId,
      ),
    ).thenAnswer((_) async => [checkIn('c-1', checkInAt)]);
    when(
      () => repository.getLatestReport(any(), any()),
    ).thenAnswer((_) async => freshReport(DateTime(2026, 8, 10)));
    await withClock(Clock.fixed(now), run);

    final escalation = writtenWakes().singleWhere(
      (w) => isRelationshipEscalationWorkspace(w.workspaceKey),
    );
    // Its OWN episode family, keyed to the check-in's UTC day — consuming
    // the lapse episode's key (2026-08-21) early would suppress the real
    // lapse escalation when that day arrives.
    final utc = checkInAt.toUtc();
    final utcDay =
        '${utc.year}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
    expect(
      escalation.workspaceKey,
      relationshipReportRefreshEscalationWorkspaceKey(utcDay),
    );
    // The deadline is the check-in's own instant: deterministic across
    // devices AND already past, so the briefing refresh fires now instead
    // of waiting out the rest of the cadence.
    expect(escalation.scheduledAt, checkInAt.toUtc());
    expect(escalation.scheduledAt.isBefore(now.toUtc()), isTrue);
    expect(escalationCallbacks, 1);
    // No previous register on a first evaluation, so no baseline token.
    expect(
      escalation.triggerTokens.where(
        (t) => t.startsWith(relationshipEscalationBaselinePrefix),
      ),
      isEmpty,
    );
  });

  test('a report-refresh escalation carries the baseline token when a '
      'register already exists — Phase B tells "newly ok" from "still ok" '
      'from the token, never from storage', () async {
    final checkInAt = DateTime(2026, 8, 14, 20);
    when(
      () => relationshipRepository.getAllCheckInsForRelationship(
        relationshipId,
      ),
    ).thenAnswer((_) async => [checkIn('c-1', checkInAt)]);
    when(
      () => repository.getLatestReport(any(), any()),
    ).thenAnswer((_) async => freshReport(DateTime(2026, 8, 10)));
    // A previous register — the case the first-evaluation test above cannot
    // reach, because Phase A's own register write hides the pre-transition
    // status from any later re-derivation.
    when(() => repository.getEntity(relationshipHealthId(agentId))).thenAnswer(
      (_) async =>
          AgentDomainEntity.relationshipHealth(
                id: relationshipHealthId(agentId),
                agentId: agentId,
                relationshipId: relationshipId,
                status: RelationshipCadenceStatus.due,
                cadenceDays: 7,
                referenceAt: testDate,
                dueAt: DateTime.utc(2026, 8, 8),
                createdAt: testDate,
                updatedAt: testDate,
                vectorClock: null,
              )
              as RelationshipHealthEntity,
    );

    await withClock(Clock.fixed(now), run);

    final escalation = writtenWakes().singleWhere(
      (w) => isRelationshipEscalationWorkspace(w.workspaceKey),
    );
    expect(
      relationshipEscalationBaselineFromTriggerTokens(
        escalation.triggerTokens.toSet(),
      ),
      RelationshipCadenceStatus.due.name,
    );
  });

  test('when the cadence newly lapses AND the briefing is stale, only the '
      'lapse episode arms — its run regenerates the briefing anyway', () async {
    // Check-in on 8/1 with a 7-day cadence → due day 8/8, well past `now`
    // (8/16) and newly due (no previous register); the briefing predates
    // the check-in, so both facts hold at once.
    when(
      () => relationshipRepository.getAllCheckInsForRelationship(
        relationshipId,
      ),
    ).thenAnswer((_) async => [checkIn('c-1', DateTime(2026, 8, 1, 18))]);
    when(
      () => repository.getLatestReport(any(), any()),
    ).thenAnswer((_) async => freshReport(DateTime(2026, 7, 30)));
    await withClock(Clock.fixed(now), run);

    final escalations = writtenWakes()
        .where((w) => isRelationshipEscalationWorkspace(w.workspaceKey))
        .toList();
    expect(escalations, hasLength(1));
    expect(
      escalations.single.workspaceKey,
      relationshipEscalationWorkspaceKey('2026-08-08'),
    );
    expect(escalations.single.workspaceKey, isNot(contains('refresh')));
  });

  group('the deterministic nudge sweep', () {
    RelationshipNudgeEntity nudge({
      required String id,
      DateTime? staleAt,
    }) =>
        AgentDomainEntity.relationshipNudge(
              id: id,
              agentId: agentId,
              status: NudgeStatus.active,
              brief: const NudgeBrief(
                headline: 'Check in with Anna.',
                tone: NudgeTone.nudge,
                animation: NudgeBannerAnimation.steady,
              ),
              briefDigest: id,
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
              staleAt: staleAt,
            )
            as RelationshipNudgeEntity;

    // `important` is the consent switch (ADR 0037/0039). Withdrawing it has
    // to reach the banner already on the dock: the render side filters on
    // the agent and the person existing, not on eligibility, so before this
    // an un-marked person kept nudging until the banner's own staleAt.
    test('withdrawing eligibility RETIRES the live banner', () async {
      final ineligible = [
        relationship(important: false),
        relationship(
          status: RelationshipStatus.dormant(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      ];

      for (final entry in ineligible) {
        upserts.clear();
        when(
          () => relationshipRepository.getRelationshipByIdUnfiltered(
            relationshipId,
          ),
        ).thenAnswer((_) async => entry);
        when(
          () =>
              repository.getEntitiesByAgentId(any(), type: any(named: 'type')),
        ).thenAnswer((_) async => [nudge(id: 'ad-live')]);

        await withClock(Clock.fixed(now), run);

        final retired = upserts.whereType<RelationshipNudgeEntity>().single;
        expect(retired.status, NudgeStatus.retired, reason: '$entry');
        expect(retired.retiredAt, now.toUtc());
      }
    });

    test('an ineligible person with no live banner writes nothing', () async {
      when(
        () => relationshipRepository.getRelationshipByIdUnfiltered(
          relationshipId,
        ),
      ).thenAnswer((_) async => relationship(important: false));
      when(
        () => repository.getEntitiesByAgentId(any(), type: any(named: 'type')),
      ).thenAnswer((_) async => []);

      await withClock(Clock.fixed(now), run);

      expect(upserts.whereType<RelationshipNudgeEntity>(), isEmpty);
    });

    test('an active banner past its deadline is terminally EXPIRED with '
        'the deterministic deadline timestamp', () async {
      when(
        () => relationshipRepository.getAllCheckInsForRelationship(
          relationshipId,
        ),
      ).thenAnswer((_) async => [checkIn('c-1', DateTime(2026, 8, 1, 18))]);
      when(
        () => repository.getEntitiesByAgentId(any(), type: any(named: 'type')),
      ).thenAnswer(
        (_) async => [nudge(id: 'ad-old', staleAt: DateTime.utc(2026, 8, 10))],
      );
      await withClock(Clock.fixed(now), run);

      final swept = upserts.whereType<RelationshipNudgeEntity>().single;
      expect(swept.status, NudgeStatus.expired);
      expect(swept.expiredAt, DateTime.utc(2026, 8, 10));
    });

    test(
      'a satisfied cadence RETIRES the still-active banner — the agent '
      'takes back an obsolete chide instead of running out its clock',
      () async {
        when(
          () => relationshipRepository.getAllCheckInsForRelationship(
            relationshipId,
          ),
        ).thenAnswer((_) async => [checkIn('c-1', DateTime(2026, 8, 14, 20))]);
        when(
          () => repository.getLatestReport(any(), any()),
        ).thenAnswer((_) async => freshReport(DateTime(2026, 8, 15)));
        when(
          () =>
              repository.getEntitiesByAgentId(any(), type: any(named: 'type')),
        ).thenAnswer(
          (_) async => [
            nudge(id: 'ad-live', staleAt: DateTime.utc(2026, 8, 20)),
          ],
        );
        await withClock(Clock.fixed(now), run);

        final swept = upserts.whereType<RelationshipNudgeEntity>().single;
        expect(swept.status, NudgeStatus.retired);
        expect(swept.retiredAt, now.toUtc());
      },
    );

    test('a due cadence leaves the active banner alone — it is still the '
        'right message', () async {
      when(
        () => relationshipRepository.getAllCheckInsForRelationship(
          relationshipId,
        ),
      ).thenAnswer((_) async => [checkIn('c-1', DateTime(2026, 8, 1, 18))]);
      when(
        () => repository.getEntitiesByAgentId(any(), type: any(named: 'type')),
      ).thenAnswer(
        (_) async => [
          nudge(id: 'ad-live', staleAt: DateTime.utc(2026, 8, 20)),
        ],
      );
      await withClock(Clock.fixed(now), run);
      expect(upserts.whereType<RelationshipNudgeEntity>(), isEmpty);
    });
  });

  group('relationshipCadenceWake', () {
    test('before the cadence hour it targets today, after it tomorrow — '
        'calendar components, not durations', () {
      final early = relationshipCadenceWake(
        agentId,
        DateTime(2026, 8, 16, 5),
      );
      expect(
        (early as ScheduledWakeEntity).scheduledAt,
        DateTime(2026, 8, 16, relationshipCadenceHour),
      );
      final late_ = relationshipCadenceWake(
        agentId,
        DateTime(2026, 8, 16, 12),
      );
      expect(
        (late_ as ScheduledWakeEntity).scheduledAt,
        DateTime(2026, 8, 17, relationshipCadenceHour),
      );
      expect(late_.workspaceKey, relationshipCadenceWorkspaceKey);
    });

    test('a consumed or missing cadence record is rewritten; a pending one '
        'for the same instant is left alone', () async {
      // Keep the cadence healthy so the ONLY wake in play is the cadence
      // tick itself (an overdue or stale fixture would also arm an
      // escalation).
      when(
        () => relationshipRepository.getAllCheckInsForRelationship(
          relationshipId,
        ),
      ).thenAnswer((_) async => [checkIn('c-1', DateTime(2026, 8, 14, 20))]);
      when(
        () => repository.getLatestReport(any(), any()),
      ).thenAnswer((_) async => freshReport(DateTime(2026, 8, 15)));
      // Default stubs: no existing record → the run writes one.
      await withClock(Clock.fixed(now), run);
      final wake = writtenWakes().single;
      expect(wake.status, ScheduledWakeStatus.pending);

      // Same pending record present → no rewrite.
      when(() => repository.getEntity(wake.id)).thenAnswer((_) async => wake);
      upserts.clear();
      await withClock(Clock.fixed(now), run);
      expect(writtenWakes(), isEmpty);

      // Consumed record → rewritten to the next tick.
      when(() => repository.getEntity(wake.id)).thenAnswer(
        (_) async => wake.copyWith(status: ScheduledWakeStatus.consumed),
      );
      upserts.clear();
      await withClock(Clock.fixed(now), run);
      expect(writtenWakes().single.status, ScheduledWakeStatus.pending);
    });
  });

  // The OS-reminder projection (ADR 0039, plan v2 phase 8). Phase A decides
  // when a person is due; the sink turns that into a durable row and an alarm.
  group('OS reminder projection', () {
    test('arms the reminder from the same derivation as the register', () async {
      await withClock(Clock.fixed(now), run);

      expect(reminders.cleared, isEmpty);
      final armed = reminders.armed.single;
      expect(armed.relationshipId, relationshipId);
      // The register and the alarm must agree about the due day, or the banner
      // and the notification would nudge on different dates.
      expect(armed.derivation.dueDayUtc, writtenRegister()!.dueAt);
      expect(armed.derivation.dueDayKey, '2026-08-08');
    });

    test('arms only after the agent transaction has committed', () async {
      await withClock(Clock.fixed(now), run);

      // The reminder row lives in notifications.sqlite behind its own
      // vector-clock scope and outbox enqueue; running it inside the agent
      // database's transaction zone would buffer its sync messages against an
      // unrelated commit.
      //
      // Asserting `events.last == 'arm'` would NOT catch that: the shared
      // mock runs the transaction body inline, so an arm moved inside it
      // still lands last. The begin/commit markers are what make the two
      // positions distinguishable.
      expect(events, contains('tx:commit'));
      expect(
        events.indexOf('arm'),
        greaterThan(events.lastIndexOf('tx:commit')),
      );
      // ...and the register really was written inside that transaction, so the
      // assertion above is comparing against a boundary that means something.
      final register = events.indexWhere(
        (e) => e.startsWith('upsert:') && e.contains('RelationshipHealth'),
      );
      expect(register, greaterThan(events.indexOf('tx:begin')));
      expect(register, lessThan(events.lastIndexOf('tx:commit')));
    });

    test(
      'a person who stops being eligible has their alarm cancelled',
      () async {
        // Un-marking important, going dormant or being deleted all withdraw
        // consent. An alarm armed weeks ago would otherwise still fire.
        final ineligible = <String, RelationshipEntry>{
          'not important': relationship(important: false),
          'dormant': relationship(
            status: RelationshipStatus.dormant(
              id: 'status-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
          ),
          'deleted': relationship(deletedAt: testDate),
        };

        for (final entry in ineligible.entries) {
          reminders.reset();
          when(
            () => relationshipRepository.getRelationshipByIdUnfiltered(
              relationshipId,
            ),
          ).thenAnswer((_) async => entry.value);

          await withClock(Clock.fixed(now), run);

          expect(reminders.cleared, [relationshipId], reason: entry.key);
          expect(reminders.armed, isEmpty, reason: entry.key);
        }
      },
    );

    test('a relationship that no longer resolves is cleared too', () async {
      when(
        () => relationshipRepository.getRelationshipByIdUnfiltered(
          relationshipId,
        ),
      ).thenAnswer((_) async => null);

      await withClock(Clock.fixed(now), run);

      expect(reminders.cleared, [relationshipId]);
      expect(reminders.armed, isEmpty);
    });

    test('an agent with no link touches neither path', () async {
      when(
        () => repository.getLinksFrom(
          agentId,
          type: AgentLinkTypes.agentRelationship,
        ),
      ).thenAnswer((_) async => []);

      await withClock(Clock.fixed(now), run);

      expect(reminders.armed, isEmpty);
      expect(reminders.cleared, isEmpty);
    });

    test('a wake still succeeds when the sink is not wired at all', () async {
      // Reminders are optional: hosts without a notification stack, and every
      // test that does not care, pass null.
      final bare = RelationshipAgentPhaseA(
        repository: repository,
        syncService: syncService,
        relationshipRepository: relationshipRepository,
      );

      final result = await withClock(
        Clock.fixed(now),
        () => bare.execute(
          agentIdentity: identity(),
          runKey: 'run-1',
          triggerTokens: const {},
          threadId: 'thread-1',
        ),
      );

      expect(result.success, isTrue);
      expect(writtenRegister(), isNotNull);
    });
  });
}

/// [MockAgentSyncService] with the transaction boundary made observable.
///
/// The shared mock runs the transaction body inline, which leaves "inside the
/// transaction" and "just after it" indistinguishable in a plain call log — an
/// ordering assertion against it passes whichever side the call is on. These
/// markers are what give that assertion teeth.
class _TransactionRecordingSyncService extends MockAgentSyncService {
  _TransactionRecordingSyncService(this._events);

  final List<String> _events;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    _events.add('tx:begin');
    try {
      return await action();
    } finally {
      _events.add('tx:commit');
    }
  }
}

/// Records what Phase A projected onto the reminder layer, and when.
///
/// A hand-rolled fake rather than a mock: the assertions here are about call
/// *ordering* relative to the agent transaction, which a shared `events` list
/// expresses directly.
class _RecordingReminderSink implements RelationshipReminderSink {
  _RecordingReminderSink(this._events);

  final List<String> _events;
  final List<
    ({String relationshipId, RelationshipCadenceDerivation derivation})
  >
  armed = [];
  final List<String> cleared = [];

  void reset() {
    armed.clear();
    cleared.clear();
    _events.clear();
  }

  @override
  Future<void> arm({
    required RelationshipEntry relationship,
    required RelationshipCadenceDerivation derivation,
  }) async {
    armed.add((relationshipId: relationship.meta.id, derivation: derivation));
    _events.add('arm');
  }

  @override
  Future<void> clearFor(String relationshipId) async {
    cleared.add(relationshipId);
    _events.add('clear');
  }
}
