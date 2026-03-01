import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/improver_slot_keys.dart';
import 'package:lotti/features/agents/service/improver_agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService mockAgentService;
  late MockAgentTemplateService mockTemplateService;
  late MockAgentRepository mockRepository;
  late MockAgentSyncService mockSyncService;
  late MockWakeOrchestrator mockOrchestrator;
  late ImproverAgentService service;

  final testDate = DateTime(2024, 3, 15, 10, 30);
  const targetTemplateId = 'target-template-001';
  const improverTemplateId = ImproverAgentService.improverTemplateId;

  AgentTemplateEntity makeTargetTemplate({
    String id = 'target-template-001',
    String displayName = 'Laura',
  }) {
    return makeTestTemplate(
      id: id,
      agentId: id,
      displayName: displayName,
    );
  }

  AgentTemplateEntity makeImproverTemplate() {
    return makeTestTemplate(
      id: improverTemplateId,
      agentId: improverTemplateId,
      displayName: 'Template Improver',
    );
  }

  AgentIdentityEntity makeIdentity({
    String agentId = 'improver-agent-1',
    String displayName = 'Laura Improver',
  }) {
    return makeTestIdentity(
      id: agentId,
      agentId: agentId,
      kind: AgentKinds.templateImprover,
      displayName: displayName,
      currentStateId: 'state-$agentId',
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
    mockTemplateService = MockAgentTemplateService();
    mockRepository = MockAgentRepository();
    mockSyncService = MockAgentSyncService();
    mockOrchestrator = MockWakeOrchestrator();

    // Stub syncService write methods.
    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSyncService.upsertLink(any())).thenAnswer((_) async {});

    service = ImproverAgentService(
      agentService: mockAgentService,
      agentTemplateService: mockTemplateService,
      repository: mockRepository,
      syncService: mockSyncService,
      orchestrator: mockOrchestrator,
    );
  });

  group('ImproverAgentService', () {
    group('createImproverAgent', () {
      test(
          'creates agent identity, updates state slots, '
          'and creates both links', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity();
          final state = makeState();

          // Target template exists.
          when(() => mockTemplateService.getTemplate(targetTemplateId))
              .thenAnswer((_) async => makeTargetTemplate());

          // No existing improver for this template.
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);

          // Improver template exists.
          when(() => mockTemplateService.getTemplate(improverTemplateId))
              .thenAnswer((_) async => makeImproverTemplate());

          // Agent creation.
          when(
            () => mockAgentService.createAgent(
              kind: AgentKinds.templateImprover,
              displayName: 'Laura Improver',
              config: const AgentConfig(),
            ),
          ).thenAnswer((_) async => identity);

          // State retrieval after creation.
          when(() => mockRepository.getAgentState(identity.agentId))
              .thenAnswer((_) async => state);

          final result = await service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          );

          expect(result.agentId, identity.agentId);
          expect(result.kind, AgentKinds.templateImprover);

          // Verify state was updated with improver slots.
          final capturedEntities = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState =
              capturedEntities.whereType<AgentStateEntity>().first;
          expect(
            updatedState.slots.activeTemplateId,
            targetTemplateId,
          );
          expect(
            updatedState.slots.feedbackWindowDays,
            ImproverSlotDefaults.defaultFeedbackWindowDays,
          );
          expect(updatedState.slots.recursionDepth, 0);
          expect(updatedState.slots.totalSessionsCompleted, 0);
          expect(updatedState.scheduledWakeAt, isNotNull);

          // Verify both links were created.
          final capturedLinks = verify(
            () => mockSyncService.upsertLink(captureAny()),
          ).captured;
          expect(capturedLinks, hasLength(2));

          final improverTargetLink =
              capturedLinks.whereType<ImproverTargetLink>().first;
          expect(improverTargetLink.fromId, identity.agentId);
          expect(improverTargetLink.toId, targetTemplateId);

          final templateAssignmentLink =
              capturedLinks.whereType<TemplateAssignmentLink>().first;
          expect(templateAssignmentLink.fromId, improverTemplateId);
          expect(templateAssignmentLink.toId, identity.agentId);
        });
      });

      test('sets scheduledWakeAt to now + feedbackWindowDays', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity();
          final state = makeState();

          when(() => mockTemplateService.getTemplate(targetTemplateId))
              .thenAnswer((_) async => makeTargetTemplate());
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);
          when(() => mockTemplateService.getTemplate(improverTemplateId))
              .thenAnswer((_) async => makeImproverTemplate());
          when(
            () => mockAgentService.createAgent(
              kind: any(named: 'kind'),
              displayName: any(named: 'displayName'),
              config: any(named: 'config'),
            ),
          ).thenAnswer((_) async => identity);
          when(() => mockRepository.getAgentState(identity.agentId))
              .thenAnswer((_) async => state);

          await service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          );

          final capturedEntities = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState =
              capturedEntities.whereType<AgentStateEntity>().first;

          final expectedWake = testDate.add(
            const Duration(
              days: ImproverSlotDefaults.defaultFeedbackWindowDays,
            ),
          );
          expect(updatedState.scheduledWakeAt, expectedWake);
        });
      });

      test('throws StateError when target template not found', () async {
        when(() => mockTemplateService.getTemplate(targetTemplateId))
            .thenAnswer((_) async => null);

        expect(
          () => service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Target template'),
            ),
          ),
        );
      });

      test(
          'throws StateError when improver already exists '
          'for target template', () async {
        final existingIdentity = makeIdentity(agentId: 'existing-improver');

        when(() => mockTemplateService.getTemplate(targetTemplateId))
            .thenAnswer((_) async => makeTargetTemplate());

        // An improver link already exists.
        when(
          () => mockRepository.getLinksTo(
            targetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer(
          (_) async => [
            AgentLink.improverTarget(
              id: 'link-1',
              fromId: existingIdentity.agentId,
              toId: targetTemplateId,
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          ],
        );

        when(() => mockAgentService.getAgent(existingIdentity.agentId))
            .thenAnswer((_) async => existingIdentity);

        expect(
          () => service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('already exists'),
            ),
          ),
        );
      });

      test('throws StateError when improver template not found', () async {
        when(() => mockTemplateService.getTemplate(targetTemplateId))
            .thenAnswer((_) async => makeTargetTemplate());
        when(
          () => mockRepository.getLinksTo(
            targetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockTemplateService.getTemplate(improverTemplateId))
            .thenAnswer((_) async => null);

        expect(
          () => service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Improver template'),
            ),
          ),
        );
      });

      test('uses custom display name when provided', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity(displayName: 'My Custom Improver');
          final state = makeState();

          when(() => mockTemplateService.getTemplate(targetTemplateId))
              .thenAnswer((_) async => makeTargetTemplate());
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);
          when(() => mockTemplateService.getTemplate(improverTemplateId))
              .thenAnswer((_) async => makeImproverTemplate());
          when(
            () => mockAgentService.createAgent(
              kind: AgentKinds.templateImprover,
              displayName: 'My Custom Improver',
              config: any(named: 'config'),
            ),
          ).thenAnswer((_) async => identity);
          when(() => mockRepository.getAgentState(identity.agentId))
              .thenAnswer((_) async => state);

          await service.createImproverAgent(
            targetTemplateId: targetTemplateId,
            displayName: 'My Custom Improver',
          );

          verify(
            () => mockAgentService.createAgent(
              kind: AgentKinds.templateImprover,
              displayName: 'My Custom Improver',
              config: any(named: 'config'),
            ),
          ).called(1);
        });
      });

      test('passes recursionDepth to state slots', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity();
          final state = makeState();

          when(() => mockTemplateService.getTemplate(targetTemplateId))
              .thenAnswer((_) async => makeTargetTemplate());
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);
          when(() => mockTemplateService.getTemplate(improverTemplateId))
              .thenAnswer((_) async => makeImproverTemplate());
          when(
            () => mockAgentService.createAgent(
              kind: any(named: 'kind'),
              displayName: any(named: 'displayName'),
              config: any(named: 'config'),
            ),
          ).thenAnswer((_) async => identity);
          when(() => mockRepository.getAgentState(identity.agentId))
              .thenAnswer((_) async => state);

          await service.createImproverAgent(
            targetTemplateId: targetTemplateId,
            recursionDepth: 1,
          );

          final capturedEntities = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState =
              capturedEntities.whereType<AgentStateEntity>().first;
          expect(updatedState.slots.recursionDepth, 1);
        });
      });
    });

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

        when(() => mockAgentService.getAgent(identity.agentId))
            .thenAnswer((_) async => identity);

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
      test(
          'updates scheduledWakeAt, lastOneOnOneAt, '
          'and increments totalSessionsCompleted', () async {
        await withClock(Clock.fixed(testDate), () async {
          const agentId = 'improver-agent-1';
          final state = makeState(
            slots: const AgentSlots(
              activeTemplateId: 'target-template-001',
              feedbackWindowDays: 7,
              totalSessionsCompleted: 2,
              recursionDepth: 0,
            ),
          );

          when(() => mockRepository.getAgentState(agentId))
              .thenAnswer((_) async => state);

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
          expect(updatedState.slots.totalSessionsCompleted, 3);
          expect(updatedState.updatedAt, testDate);
        });
      });

      test('uses default feedbackWindowDays when slot is null', () async {
        await withClock(Clock.fixed(testDate), () async {
          const agentId = 'improver-agent-1';
          final state = makeState(
            slots: const AgentSlots(
              activeTemplateId: 'target-template-001',
              totalSessionsCompleted: 0,
            ),
          );

          when(() => mockRepository.getAgentState(agentId))
              .thenAnswer((_) async => state);

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

      test('throws StateError when agent state not found', () async {
        when(() => mockRepository.getAgentState('missing-agent'))
            .thenAnswer((_) async => null);

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

      test('increments from zero when totalSessionsCompleted is null',
          () async {
        await withClock(Clock.fixed(testDate), () async {
          const agentId = 'improver-agent-1';
          final state = makeState(
            slots: const AgentSlots(
              activeTemplateId: 'target-template-001',
              feedbackWindowDays: 14,
            ),
          );

          when(() => mockRepository.getAgentState(agentId))
              .thenAnswer((_) async => state);

          await service.scheduleNextRitual(agentId);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = captured.first as AgentStateEntity;
          expect(updatedState.slots.totalSessionsCompleted, 1);
          expect(
            updatedState.scheduledWakeAt,
            testDate.add(const Duration(days: 14)),
          );
        });
      });
    });
  });
}
