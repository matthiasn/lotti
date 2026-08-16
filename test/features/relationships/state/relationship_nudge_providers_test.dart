import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationship_nudge_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

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

  ProviderContainer container({bool flagEnabled = true}) {
    final c = ProviderContainer(
      overrides: [
        configFlagProvider(
          enableRelationshipsFlag,
        ).overrideWith((ref) => Stream.value(flagEnabled)),
        agentRepositoryProvider.overrideWithValue(repository),
        agentServiceProvider.overrideWithValue(agentService),
        relationshipRepositoryProvider.overrideWithValue(
          relationshipRepository,
        ),
        updateNotificationsProvider.overrideWithValue(updateNotifications),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
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
  });

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
}
