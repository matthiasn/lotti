import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
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
    syncService = MockAgentSyncService();
    relationshipRepository = MockRelationshipRepository();
    upserts = [];
    escalationCallbacks = 0;
    phaseA = RelationshipAgentPhaseA(
      repository: repository,
      syncService: syncService,
      relationshipRepository: relationshipRepository,
      onEscalationArmed: () => escalationCallbacks++,
    );
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
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
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(
      () => relationshipRepository.getRelationshipById(relationshipId),
    ).thenAnswer((_) async => relationship());
    when(
      () => relationshipRepository.getAllCheckInsForRelationship(
        relationshipId,
      ),
    ).thenAnswer((_) async => []);
  });

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
      'register — important is the single consent switch (ADR 0039)', () async {
    final ineligible = [
      relationship(important: false),
      relationship(
        status: RelationshipStatus.dormant(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
      relationship(deletedAt: testDate),
    ];
    for (final entry in ineligible) {
      upserts.clear();
      when(
        () => relationshipRepository.getRelationshipById(relationshipId),
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

  test('inside the cadence: register says ok with the check-in as the '
      'reference; no escalation, no callback', () async {
    final lastCheckIn = DateTime(2026, 8, 14, 20);
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
    expect(register.referenceAt, lastCheckIn);
    expect(register.lastCheckInAt, lastCheckIn);
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
    expect(writtenRegister()!.referenceAt, DateTime(2026, 8, 15));
  });

  test('no check-ins yet: the baseline is tracking start and the default '
      'cadence applies — the first reminder is never suppressed', () async {
    when(
      () => relationshipRepository.getRelationshipById(relationshipId),
    ).thenAnswer(
      (_) async => relationship(
        cadenceDays: null,
        trackingStart: DateTime(2026, 8, 10, 15),
      ),
    );
    await withClock(Clock.fixed(now), run);

    final register = writtenRegister()!;
    expect(register.lastCheckInAt, isNull);
    expect(register.referenceAt, DateTime(2026, 8, 10, 15));
    expect(register.cadenceDays, relationshipDefaultCadenceDays);
    expect(register.dueAt, DateTime.utc(2026, 9, 9));
    expect(register.status, RelationshipCadenceStatus.ok);
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
      // tick itself (an overdue fixture would also arm an escalation).
      when(
        () => relationshipRepository.getAllCheckInsForRelationship(
          relationshipId,
        ),
      ).thenAnswer((_) async => [checkIn('c-1', DateTime(2026, 8, 14, 20))]);
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
}
