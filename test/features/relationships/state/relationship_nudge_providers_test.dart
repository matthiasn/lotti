import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationship_nudge_providers.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const relationshipId = 'person-1';
  final agentId = relationshipAgentIdFor(relationshipId);
  final testDate = DateTime(2026, 8, 1, 9);
  final now = DateTime(2026, 8, 16, 12);

  late MockAgentRepository repository;
  late MockAgentService agentService;
  late MockRelationshipRepository relationshipRepository;
  late MockUpdateNotifications updateNotifications;

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

  RelationshipNudgeEntity nudge(
    String id, {
    NudgeStatus status = NudgeStatus.active,
    DateTime? activatedAt,
    DateTime? staleAt,
    DateTime? snoozedUntil,
    DateTime? dismissedForDayAt,
  }) =>
      AgentDomainEntity.relationshipNudge(
            id: id,
            agentId: agentId,
            status: status,
            brief: const NudgeBrief(
              headline: 'Check in with Anna.',
              tone: NudgeTone.nudge,
              animation: NudgeBannerAnimation.steady,
            ),
            briefDigest: 'd-$id',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
            activatedAt: activatedAt,
            staleAt: staleAt,
            snoozedUntil: snoozedUntil,
            dismissedForDayAt: dismissedForDayAt,
          )
          as RelationshipNudgeEntity;

  /// The person's cadence register, as Phase A writes it: due on [dueAt].
  AgentDomainEntity register({
    required DateTime dueAt,
    DateTime? deletedAt,
  }) => AgentDomainEntity.relationshipHealth(
    id: relationshipHealthId(agentId),
    agentId: agentId,
    relationshipId: relationshipId,
    status: RelationshipCadenceStatus.ok,
    cadenceDays: 7,
    referenceAt: testDate.toUtc(),
    dueAt: dueAt,
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
    deletedAt: deletedAt,
  );

  ProviderContainer container({bool flagEnabled = true}) {
    final c = ProviderContainer(
      overrides: withServiceOverrides([
        configFlagProvider(
          enableRelationshipsFlag,
        ).overrideWith((ref) => Stream.value(flagEnabled)),
        agentRepositoryProvider.overrideWithValue(repository),
        agentServiceProvider.overrideWithValue(agentService),
        relationshipRepositoryProvider.overrideWithValue(
          relationshipRepository,
        ),
        updateNotificationsProvider.overrideWithValue(updateNotifications),
      ]),
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    await setUpTestGetIt();
    repository = MockAgentRepository();
    agentService = MockAgentService();
    relationshipRepository = MockRelationshipRepository();
    updateNotifications = MockUpdateNotifications();
    when(
      () => updateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [identity()]);
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
    when(
      () => relationshipRepository.getRelationshipById(relationshipId),
    ).thenAnswer(
      (_) async => RelationshipEntry(
        meta: Metadata(
          id: relationshipId,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: RelationshipData(
          title: 'Anna',
          important: true,
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      ),
    );
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.relationshipNudge,
      ),
    ).thenAnswer((_) async => []);
    // No cadence register unless a test seeds one.
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
  });

  tearDown(tearDownTestGetIt);

  Future<void> warmFlag(ProviderContainer c) async {
    final sub = c.listen(
      configFlagProvider(enableRelationshipsFlag),
      (_, _) {},
    );
    addTearDown(sub.close);
    await c.read(configFlagProvider(enableRelationshipsFlag).future);
  }

  test('the rollout flag gates the source: off means empty, even for rows '
      'that synced in from a flagged-on device', () async {
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.relationshipNudge,
      ),
    ).thenAnswer((_) async => [nudge('ad-1')]);
    final c = container(flagEnabled: false);
    await warmFlag(c);
    expect(await c.read(activeRelationshipNudgesProvider.future), isEmpty);
  });

  test('an active banner becomes a relationship-kind entry whose tap lands '
      'on the person (the resolved ADR 0059 open question)', () async {
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.relationshipNudge,
      ),
    ).thenAnswer(
      (_) async => [nudge('ad-1', activatedAt: DateTime(2026, 8, 15))],
    );
    final c = container();
    await warmFlag(c);
    final entries = await withClock(
      Clock.fixed(now),
      () => c.read(activeRelationshipNudgesProvider.future),
    );
    final entry = entries.single;
    expect(entry.kind, NudgeBannerKind.relationship);
    expect(entry.subjectTitle, 'Anna');
    expect(entry.tapRoute, '/people/$relationshipId');
    expect(entry.nudge.id, 'ad-1');
  });

  test('stale, snoozed and non-active rows never surface', () async {
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.relationshipNudge,
      ),
    ).thenAnswer(
      (_) async => [
        nudge('ad-live', activatedAt: DateTime(2026, 8, 15)),
        nudge('ad-stale', staleAt: DateTime(2026, 8, 10)),
        nudge('ad-snoozed', snoozedUntil: DateTime(2026, 8, 20)),
        nudge('ad-dismissed', status: NudgeStatus.dismissed),
      ],
    );
    final c = container();
    await warmFlag(c);
    final entries = await withClock(
      Clock.fixed(now),
      () => c.read(activeRelationshipNudgesProvider.future),
    );
    expect(entries.map((e) => e.nudge.id), ['ad-live']);
  });

  test('an active banner dismissed for today stays hidden until local '
      'midnight', () async {
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.relationshipNudge,
      ),
    ).thenAnswer(
      (_) async => [
        nudge(
          'ad-quiet',
          activatedAt: DateTime(2026, 8, 15),
          dismissedForDayAt: DateTime(2026, 8, 16, 9),
        ),
      ],
    );
    final c = container();
    await warmFlag(c);
    final entries = await withClock(
      Clock.fixed(now),
      () => c.read(activeRelationshipNudgesProvider.future),
    );
    expect(entries, isEmpty);
  });

  test('several live banners sort newest-activation first', () async {
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.relationshipNudge,
      ),
    ).thenAnswer(
      (_) async => [
        nudge(
          'ad-old',
          activatedAt: DateTime(2026, 8, 14),
          staleAt: DateTime(2026, 8, 18),
        ),
        nudge(
          'ad-new',
          activatedAt: DateTime(2026, 8, 15),
          staleAt: DateTime(2026, 8, 17),
        ),
      ],
    );
    final c = container();
    await warmFlag(c);
    final entries = await withClock(
      Clock.fixed(now),
      () => c.read(activeRelationshipNudgesProvider.future),
    );
    expect(entries.map((e) => e.nudge.id), ['ad-new', 'ad-old']);
  });

  test('a deleted person contributes nothing — no orphaned banners', () async {
    when(
      () => relationshipRepository.getRelationshipById(relationshipId),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.relationshipNudge,
      ),
    ).thenAnswer((_) async => [nudge('ad-1')]);
    final c = container();
    await warmFlag(c);
    expect(await c.read(activeRelationshipNudgesProvider.future), isEmpty);
  });

  test('only a relationship agent, person or private-flag write re-reads the '
      'banners — not every agent write in the app', () async {
    final updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    when(
      () => updateNotifications.updateStream,
    ).thenAnswer((_) => updates.stream);
    final c = container();
    await warmFlag(c);
    final sub = c.listen(activeRelationshipNudgesProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(activeRelationshipNudgesProvider.future);
    verify(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).called(1);

    Future<void> send(Set<String> ids) async {
      updates.add(ids);
      await pumpEventQueue();
      await c.read(activeRelationshipNudgesProvider.future);
    }

    // A task agent's wake: the global agent token rides along.
    await send({'task-agent-7', agentNotification});
    verifyNever(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    );

    for (final ids in [
      {agentId, agentNotification},
      {relationshipId, relationshipNotification},
      {privateToggleNotification},
    ]) {
      await send(ids);
      verify(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).called(1);
    }
  });

  group('relationshipCadenceOkUntil — no reminder within the cadence', () {
    final noon = DateTime.utc(2026, 8, 16, 12);

    test('the due day while it is still ahead, and only then', () {
      final tomorrow = DateTime.utc(2026, 8, 17);
      expect(
        relationshipCadenceOkUntil(register(dueAt: tomorrow), noon),
        tomorrow,
      );
      // The due day itself is due — the day a reminder is for — and so is
      // every day after it.
      expect(
        relationshipCadenceOkUntil(
          register(dueAt: DateTime.utc(2026, 8, 16)),
          noon,
        ),
        isNull,
      );
      expect(
        relationshipCadenceOkUntil(
          register(dueAt: DateTime.utc(2026, 8, 10)),
          noon,
        ),
        isNull,
      );
    });

    test('lapses at UTC midnight of the due day, the instant Phase A uses', () {
      final register_ = register(dueAt: DateTime.utc(2026, 8, 17));
      expect(
        relationshipCadenceOkUntil(
          register_,
          DateTime.utc(2026, 8, 16, 23, 59, 59),
        ),
        isNotNull,
      );
      expect(
        relationshipCadenceOkUntil(register_, DateTime.utc(2026, 8, 17)),
        isNull,
      );
    });

    test('no live register hides nothing', () {
      expect(relationshipCadenceOkUntil(null, noon), isNull);
      expect(
        relationshipCadenceOkUntil(
          register(
            dueAt: DateTime.utc(2026, 8, 30),
            deletedAt: DateTime.utc(2026, 8, 2),
          ),
          noon,
        ),
        isNull,
      );
      expect(
        relationshipCadenceOkUntil(nudge('not-a-register'), noon),
        isNull,
      );
    });
  });

  test('a banner for a person still within their cadence stays off the dock '
      'until the due day comes — a peer that raised it right after a '
      'check-in cannot make this device nag', () {
    fakeAsync((async) {
      withClock(async.getClock(now), () {
        when(
          () => repository.getEntity(relationshipHealthId(agentId)),
        ).thenAnswer(
          (_) async => register(dueAt: DateTime.utc(2026, 8, 17)),
        );
        when(
          () => repository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.relationshipNudge,
          ),
        ).thenAnswer((_) async => [nudge('ad-1')]);
        final c = container();
        final flag = c.listen(
          configFlagProvider(enableRelationshipsFlag),
          (_, _) {},
        );
        async.flushMicrotasks();
        List<NudgeBannerEntry>? latest;
        final sub = c.listen(
          activeRelationshipNudgesProvider,
          (_, next) => latest = next.value,
          fireImmediately: true,
        );
        async
          ..flushMicrotasks()
          ..elapse(Duration.zero);
        expect(latest, isEmpty);

        // Past the due day's UTC midnight the provider re-reads on its own
        // and the banner speaks.
        async
          ..elapse(const Duration(days: 1))
          ..flushMicrotasks();
        expect(latest?.map((e) => e.nudge.id), ['ad-1']);

        sub.close();
        flag.close();
      });
    });
  });

  test('a source disposed while it reads never arms its deadline timer', () {
    fakeAsync((async) {
      withClock(async.getClock(now), () {
        final nudges = Completer<List<AgentDomainEntity>>();
        when(
          () => repository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.relationshipNudge,
          ),
        ).thenAnswer((_) => nudges.future);
        final c = container();
        final flag = c.listen(
          configFlagProvider(enableRelationshipsFlag),
          (_, _) {},
        );
        async.flushMicrotasks();
        final sub = c.listen(activeRelationshipNudgesProvider, (_, _) {});
        async.flushMicrotasks();
        verify(
          () => repository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.relationshipNudge,
          ),
        ).called(1);

        sub.close();
        // Riverpod disposes an unlistened autoDispose provider on its
        // scheduler's zero-length timer, not in a microtask.
        async.elapse(Duration.zero);
        nudges.complete([
          nudge('ad-1', staleAt: now.add(const Duration(hours: 1))),
        ]);
        async
          ..flushMicrotasks()
          // Past the stale deadline: a timer armed for the disposed
          // generation would invalidate a dead ref here and throw.
          ..elapse(const Duration(hours: 2));

        expect(async.pendingTimers, isEmpty);
        flag.close();
      });
    });
  });

  // ADR 0063: the person page says a tapped reminder is paused, and until
  // when — only for a pause the tap made, never for a snooze the user chose.
  group('pausedRelationshipReminderProvider', () {
    final until = now.add(const Duration(minutes: 40));

    RelationshipNudgeEntity paused(
      NudgeSnoozeReason? reason, {
      DateTime? snoozedUntil,
      int? activation,
    }) {
      final base = nudge('ad-1', snoozedUntil: snoozedUntil ?? until);
      return base.copyWith(
        snoozeHistory: [
          NudgeSnooze(
            id: 'snooze-1',
            activation: activation ?? base.activationCount,
            snoozedAt: now.subtract(const Duration(minutes: 20)),
            snoozedUntil: snoozedUntil ?? until,
            duration: NudgeBannerSnoozeDuration.oneHour,
            durationMinutes: 60,
            utcOffsetMinutes: 0,
            reason: reason,
          ),
        ],
      );
    }

    setUp(() {
      when(
        () => repository.getEntity(agentId),
      ).thenAnswer((_) async => identity());
    });

    Future<PausedRelationshipReminder?> read(
      RelationshipNudgeEntity row,
    ) async {
      when(
        () => repository.getEntitiesByAgentId(
          agentId,
          type: AgentEntityTypes.relationshipNudge,
        ),
      ).thenAnswer((_) async => [row]);
      final c = container();
      return withClock(
        Clock.fixed(now),
        () => c.read(pausedRelationshipReminderProvider(relationshipId).future),
      );
    }

    test(
      'a reminder the tap paused comes back as its entry and deadline',
      () async {
        final result = await read(paused(NudgeSnoozeReason.opened));

        expect(result?.until.isAtSameMomentAs(until), isTrue);
        expect(result?.entry.nudge.id, 'ad-1');
        expect(result?.entry.tapRoute, '/people/$relationshipId');
        expect(result?.entry.subjectTitle, 'Anna');
      },
    );

    for (final (label, row) in [
      ('a snooze the user chose', paused(NudgeSnoozeReason.chosen)),
      ('an older snooze without a reason', paused(null)),
      (
        'a pause that already ended',
        paused(
          NudgeSnoozeReason.opened,
          snoozedUntil: now.subtract(const Duration(minutes: 1)),
        ),
      ),
      (
        'a pause from an earlier activation',
        paused(NudgeSnoozeReason.opened, activation: 99),
      ),
      ('a banner that was never paused', nudge('ad-1')),
      (
        'a retired banner',
        paused(NudgeSnoozeReason.opened).copyWith(status: NudgeStatus.retired),
      ),
    ]) {
      test('$label says nothing', () async {
        expect(await read(row), isNull);
      });
    }

    // Codex review on #4356: an earlier chosen eight-hour snooze keeps its
    // later deadline over a concurrent opened pause; the pause is not in
    // force, so the page must not claim it.
    test('a chosen snooze whose deadline won over a concurrent opened '
        'pause says nothing', () async {
      final chosenUntil = now.add(const Duration(hours: 8));
      final base = nudge('ad-1', snoozedUntil: chosenUntil);
      final row = base.copyWith(
        snoozeHistory: [
          NudgeSnooze(
            id: 'chosen',
            activation: base.activationCount,
            snoozedAt: now.subtract(const Duration(minutes: 30)),
            snoozedUntil: chosenUntil,
            duration: NudgeBannerSnoozeDuration.eightHours,
            durationMinutes: 480,
            utcOffsetMinutes: 0,
            reason: NudgeSnoozeReason.chosen,
          ),
          NudgeSnooze(
            id: 'opened',
            activation: base.activationCount,
            snoozedAt: now.subtract(const Duration(minutes: 20)),
            snoozedUntil: until,
            duration: NudgeBannerSnoozeDuration.oneHour,
            durationMinutes: 60,
            utcOffsetMinutes: 0,
            reason: NudgeSnoozeReason.opened,
          ),
        ],
      );

      expect(await read(row), isNull);
    });

    test('a person whose agent is gone says nothing', () async {
      when(() => repository.getEntity(agentId)).thenAnswer((_) async => null);

      expect(await read(paused(NudgeSnoozeReason.opened)), isNull);
    });
  });
}
