import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    as agent_providers;
import 'package:lotti/features/daily_os_next/state/day_agent_persona_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../agents/test_data/wake_factories.dart';

void main() {
  final date = DateTime(2026, 7, 23);
  const dayId = 'dayplan-2026-07-23';
  final perDayId = perDayAgentId(dayId);

  final silenceAgentUpdates = agentUpdateStreamProvider.overrideWith(
    (ref, agentId) => const Stream<Set<String>>.empty(),
  );

  ProviderContainer container({
    required bool running,
    AgentDomainEntity? owner,
    List<AgentDomainEntity> ownerEntities = const [],
    List<WakeTokenUsageEntity> tokenUsage = const [],
  }) {
    final repository = MockAgentRepository();
    when(
      () => repository.getEntitiesByAgentId(
        any(),
        type: AgentEntityTypes.dayStatusEvent,
      ),
    ).thenAnswer((_) async => ownerEntities);
    when(
      () => repository.getTokenUsageForAgent(any()),
    ).thenAnswer((_) async => tokenUsage);
    final result = ProviderContainer(
      overrides: [
        silenceAgentUpdates,
        dayAgentIsRunningProvider.overrideWith((ref, d) => running),
        agent_providers.dayAgentProvider.overrideWith(
          (ref, d) async => owner,
        ),
        agentRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  AgentIdentityEntity perDayIdentity() => makeTestIdentity(
    id: perDayId,
    agentId: perDayId,
    kind: AgentKinds.dayAgent,
  );

  group('dayAgentPersonaStateProvider', () {
    test('a running wake wins over any status event', () async {
      final c = container(
        running: true,
        owner: perDayIdentity(),
        ownerEntities: [makeTestDayStatusEvent(dayId: dayId)],
      );

      expect(
        await c.read(dayAgentPersonaStateProvider(date).future),
        DayAgentPersonaState.working,
      );
    });

    test(
      'newest event decides: attention, then celebrating on close',
      () async {
        final attention = container(
          running: false,
          owner: perDayIdentity(),
          ownerEntities: [
            makeTestDayStatusEvent(
              id: 'day_status:$dayId:older-close',
              dayId: dayId,
              status: DayStatusKind.dayClosed,
              reasons: const [],
              raisedAt: DateTime(2026, 7, 23, 8),
              createdAt: DateTime(2026, 7, 23, 8),
            ),
            makeTestDayStatusEvent(
              id: 'day_status:$dayId:newer-attention',
              dayId: dayId,
              raisedAt: DateTime(2026, 7, 23, 14),
              createdAt: DateTime(2026, 7, 23, 14),
            ),
          ],
        );
        expect(
          await attention.read(dayAgentPersonaStateProvider(date).future),
          DayAgentPersonaState.attention,
          reason: 'The newer attentionNeeded outranks the older close.',
        );

        final celebrating = container(
          running: false,
          owner: perDayIdentity(),
          ownerEntities: [
            makeTestDayStatusEvent(
              id: 'day_status:$dayId:close',
              dayId: dayId,
              status: DayStatusKind.dayClosed,
              reasons: const [],
              raisedAt: DateTime(2026, 7, 23, 21),
              createdAt: DateTime(2026, 7, 23, 21),
            ),
          ],
        );
        expect(
          await celebrating.read(dayAgentPersonaStateProvider(date).future),
          DayAgentPersonaState.celebrating,
        );
      },
    );

    test(
      'idle without an owner, without events, on onTrack, and for '
      "foreign-day or deleted events (the coordinator's other days must "
      'not bleed in)',
      () async {
        final noOwner = container(running: false);
        expect(
          await noOwner.read(dayAgentPersonaStateProvider(date).future),
          DayAgentPersonaState.idle,
        );

        final filtered = container(
          running: false,
          owner: perDayIdentity(),
          ownerEntities: [
            makeTestDayStatusEvent(
              id: 'day_status:other:1',
              dayId: 'dayplan-2026-07-22',
            ),
            makeTestDayStatusEvent(
              id: 'day_status:$dayId:deleted',
              dayId: dayId,
              deletedAt: DateTime(2026, 7, 23, 9),
            ),
            makeTestDayStatusEvent(
              id: 'day_status:$dayId:ontrack',
              dayId: dayId,
              status: DayStatusKind.onTrack,
              reasons: const [],
            ),
          ],
        );
        expect(
          await filtered.read(dayAgentPersonaStateProvider(date).future),
          DayAgentPersonaState.idle,
        );
      },
    );
  });

  group('dayAgentTokenSpendProvider', () {
    test('sums input/output/thoughts tokens for a per-day agent', () async {
      final c = container(
        running: false,
        owner: perDayIdentity(),
        tokenUsage: [
          makeTestWakeTokenUsage(
            id: 'usage-1',
            agentId: perDayId,
            inputTokens: 1000,
            outputTokens: 200,
            thoughtsTokens: 50,
          ),
          makeTestWakeTokenUsage(
            id: 'usage-2',
            agentId: perDayId,
            inputTokens: 500,
            outputTokens: 100,
            thoughtsTokens: null,
          ),
        ],
      );

      expect(await c.read(dayAgentTokenSpendProvider(date).future), 1850);
    });

    test(
      'returns null for a coordinator-owned day (lifetime aggregate would '
      "misattribute other days' spend)",
      () async {
        final c = container(
          running: false,
          owner: makeTestIdentity(
            id: dailyOsPlannerAgentId,
            agentId: dailyOsPlannerAgentId,
            kind: AgentKinds.dayAgent,
          ),
          tokenUsage: [
            makeTestWakeTokenUsage(id: 'usage-1', inputTokens: 999),
          ],
        );

        expect(await c.read(dayAgentTokenSpendProvider(date).future), isNull);
      },
    );
  });
}
