import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/improver_slot_keys.dart';
import 'package:lotti/features/agents/service/improver_agent_service.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService mockAgentService;
  late MockAgentRepository mockRepository;
  late MockAgentSyncService mockSyncService;
  late ImproverAgentService service;
  late List<String> notifiedAgentIds;

  final testDate = DateTime(2024, 3, 15, 10, 30);
  const targetTemplateId = 'target-template-001';

  AgentIdentityEntity makeIdentity({
    String agentId = 'improver-agent-1',
    String displayName = 'Laura Improver',
    AgentConfig config = const AgentConfig(),
  }) {
    return makeTestIdentity(
      id: agentId,
      agentId: agentId,
      kind: AgentKinds.templateImprover,
      displayName: displayName,
      currentStateId: 'state-$agentId',
      config: config,
    );
  }

  AgentStateEntity makeState({
    String id = 'state-improver-agent-1',
    String agentId = 'improver-agent-1',
    AgentSlots slots = const AgentSlots(),
    DateTime? scheduledWakeAt,
  }) {
    return makeTestState(
      id: id,
      agentId: agentId,
      revision: 0,
      slots: slots,
      scheduledWakeAt: scheduledWakeAt,
    );
  }

  setUp(() {
    mockAgentService = MockAgentService();
    mockRepository = MockAgentRepository();
    mockSyncService = MockAgentSyncService();
    notifiedAgentIds = [];

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    stubAppendMilestone(mockSyncService);
    // Default: no identity, so scheduleNextRitual's config read falls back to
    // the legacy slot (PR 4 B4). Tests needing config override this.
    when(() => mockAgentService.getAgent(any())).thenAnswer((_) async => null);

    service = ImproverAgentService(
      agentService: mockAgentService,
      repository: mockRepository,
      syncService: mockSyncService,
      onPersistedStateChanged: notifiedAgentIds.add,
    );
  });

  group('ImproverAgentService', () {
    group('getImproverForTemplate', () {
      test('returns identity when improver link exists', () async {
        final identity = makeIdentity();

        when(
          () => mockRepository.getLinksTo(
            targetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer(
          (_) async => [
            AgentLink.improverTarget(
              id: 'link-1',
              fromId: identity.agentId,
              toId: targetTemplateId,
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          ],
        );

        when(
          () => mockAgentService.getAgent(identity.agentId),
        ).thenAnswer((_) async => identity);

        final result = await service.getImproverForTemplate(targetTemplateId);

        expect(result, isNotNull);
        expect(result!.agentId, identity.agentId);
      });

      test('skips stale links and returns first valid agent', () async {
        final identity = makeIdentity();

        when(
          () => mockRepository.getLinksTo(
            targetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer(
          (_) async => [
            AgentLink.improverTarget(
              id: 'stale-link',
              fromId: 'missing-agent',
              toId: targetTemplateId,
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
            AgentLink.improverTarget(
              id: 'valid-link',
              fromId: identity.agentId,
              toId: targetTemplateId,
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          ],
        );

        when(
          () => mockAgentService.getAgent('missing-agent'),
        ).thenAnswer((_) async => null);
        when(
          () => mockAgentService.getAgent(identity.agentId),
        ).thenAnswer((_) async => identity);

        final result = await service.getImproverForTemplate(targetTemplateId);

        expect(result, isNotNull);
        expect(result!.agentId, identity.agentId);
      });

      test('returns null when no improver link exists', () async {
        when(
          () => mockRepository.getLinksTo(
            targetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer((_) async => []);

        final result = await service.getImproverForTemplate(targetTemplateId);

        expect(result, isNull);
      });
    });

    group('scheduleNextRitual', () {
      test('updates scheduledWakeAt, lastOneOnOneAt, '
          'and increments totalSessionsCompleted', () async {
        await withClock(Clock.fixed(testDate), () async {
          const agentId = 'improver-agent-1';
          final state = makeState(
            slots: const AgentSlots(
              activeTemplateId: 'target-template-001',
              feedbackWindowDays: 7,
              totalSessionsCompleted: GCounter({'test-host': 2}),
              recursionDepth: 0,
            ),
          );

          when(
            () => mockRepository.getAgentState(agentId),
          ).thenAnswer((_) async => state);

          await service.scheduleNextRitual(agentId);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = captured.first as AgentStateEntity;
          expect(
            updatedState.scheduledWakeAt,
            testDate.add(const Duration(days: 7)),
          );
          expect(updatedState.slots.lastOneOnOneAt, testDate);
          // Host-attributed: the increment lands under the local host bucket.
          expect(updatedState.slots.totalSessionsCompleted.byHost, {
            'test-host': 3,
          });
          expect(updatedState.updatedAt, testDate);
          expect(notifiedAgentIds, [agentId]);
          // The completed ritual event-sources lastOneOnOneAt (PR 4, B2).
          expect(capturedMilestones(mockSyncService), [
            AgentMilestone.oneOnOneCompleted,
          ]);
        });
      });

      test('prefers config.feedbackWindowDays over the legacy slot', () async {
        await withClock(Clock.fixed(testDate), () async {
          const agentId = 'improver-agent-1';
          // The legacy slot says 7, but the re-homed config (PR 4 B4) says 14;
          // config wins.
          final state = makeState(
            slots: const AgentSlots(
              activeTemplateId: 'target-template-001',
              feedbackWindowDays: 7,
            ),
          );
          when(
            () => mockRepository.getAgentState(agentId),
          ).thenAnswer((_) async => state);
          when(() => mockAgentService.getAgent(agentId)).thenAnswer(
            (_) async =>
                makeIdentity(config: const AgentConfig(feedbackWindowDays: 14)),
          );

          await service.scheduleNextRitual(agentId);

          final updatedState =
              verify(
                    () => mockSyncService.upsertEntity(captureAny()),
                  ).captured.first
                  as AgentStateEntity;
          expect(
            updatedState.scheduledWakeAt,
            testDate.add(const Duration(days: 14)),
          );
        });
      });

      test('uses default feedbackWindowDays when slot is null', () async {
        await withClock(Clock.fixed(testDate), () async {
          const agentId = 'improver-agent-1';
          final state = makeState(
            slots: const AgentSlots(activeTemplateId: 'target-template-001'),
          );

          when(
            () => mockRepository.getAgentState(agentId),
          ).thenAnswer((_) async => state);

          await service.scheduleNextRitual(agentId);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = captured.first as AgentStateEntity;
          expect(
            updatedState.scheduledWakeAt,
            testDate.add(
              const Duration(
                days: ImproverSlotDefaults.defaultFeedbackWindowDays,
              ),
            ),
          );
        });
      });

      test('falls back to default when feedbackWindowDays is zero', () async {
        await withClock(Clock.fixed(testDate), () async {
          const agentId = 'improver-agent-1';
          final state = makeState(
            slots: const AgentSlots(
              activeTemplateId: 'target-template-001',
              feedbackWindowDays: 0,
            ),
          );

          when(
            () => mockRepository.getAgentState(agentId),
          ).thenAnswer((_) async => state);

          await service.scheduleNextRitual(agentId);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = captured.first as AgentStateEntity;
          expect(
            updatedState.scheduledWakeAt,
            testDate.add(
              const Duration(
                days: ImproverSlotDefaults.defaultFeedbackWindowDays,
              ),
            ),
          );
        });
      });

      test(
        'falls back to default when feedbackWindowDays is negative',
        () async {
          await withClock(Clock.fixed(testDate), () async {
            const agentId = 'improver-agent-1';
            final state = makeState(
              slots: const AgentSlots(
                activeTemplateId: 'target-template-001',
                feedbackWindowDays: -5,
              ),
            );

            when(
              () => mockRepository.getAgentState(agentId),
            ).thenAnswer((_) async => state);

            await service.scheduleNextRitual(agentId);

            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;

            final updatedState = captured.first as AgentStateEntity;
            expect(
              updatedState.scheduledWakeAt,
              testDate.add(
                const Duration(
                  days: ImproverSlotDefaults.defaultFeedbackWindowDays,
                ),
              ),
            );
          });
        },
      );

      test('throws StateError when agent state not found', () async {
        when(
          () => mockRepository.getAgentState('missing-agent'),
        ).thenAnswer((_) async => null);

        expect(
          () => service.scheduleNextRitual('missing-agent'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Agent state not found'),
            ),
          ),
        );
      });

      test(
        'increments from zero when totalSessionsCompleted is null',
        () async {
          await withClock(Clock.fixed(testDate), () async {
            const agentId = 'improver-agent-1';
            final state = makeState(
              slots: const AgentSlots(
                activeTemplateId: 'target-template-001',
                feedbackWindowDays: 14,
              ),
            );

            when(
              () => mockRepository.getAgentState(agentId),
            ).thenAnswer((_) async => state);

            await service.scheduleNextRitual(agentId);

            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;

            final updatedState = captured.first as AgentStateEntity;
            expect(updatedState.slots.totalSessionsCompleted.byHost, {
              'test-host': 1,
            });
            expect(
              updatedState.scheduledWakeAt,
              testDate.add(const Duration(days: 14)),
            );
          });
        },
      );
    });
  });
}
