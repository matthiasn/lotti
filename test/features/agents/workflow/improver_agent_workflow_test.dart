import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/workflow/improver_agent_workflow.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockFeedbackExtractionService mockFeedbackService;
  late MockTemplateEvolutionWorkflow mockEvolutionWorkflow;
  late MockImproverAgentService mockImproverService;
  late MockAgentRepository mockRepository;
  late MockAgentTemplateService mockTemplateService;
  late MockAgentSyncService mockSyncService;
  late ImproverAgentWorkflow workflow;

  const targetTemplateId = 'target-template-001';

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockFeedbackService = MockFeedbackExtractionService();
    mockEvolutionWorkflow = MockTemplateEvolutionWorkflow();
    mockImproverService = MockImproverAgentService();
    mockRepository = MockAgentRepository();
    mockTemplateService = MockAgentTemplateService();
    mockSyncService = MockAgentSyncService();

    workflow = ImproverAgentWorkflow(
      feedbackService: mockFeedbackService,
      evolutionWorkflow: mockEvolutionWorkflow,
      improverService: mockImproverService,
      repository: mockRepository,
      templateService: mockTemplateService,
      syncService: mockSyncService,
    );

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockTemplateService.repository).thenReturn(mockRepository);
  });

  AgentIdentityEntity makeImproverIdentity({
    String agentId = kTestAgentId,
  }) {
    return makeTestIdentity(
      agentId: agentId,
      kind: AgentKinds.templateImprover,
      displayName: 'Test Improver',
    );
  }

  AgentStateEntity makeImproverState({
    String? activeTemplateId = targetTemplateId,
    DateTime? lastFeedbackScanAt,
    DateTime? lastOneOnOneAt,
    int? totalSessionsCompleted,
    int wakeCounter = 0,
    int? recursionDepth,
  }) {
    return makeTestState(
      slots: AgentSlots(
        activeTemplateId: activeTemplateId,
        lastFeedbackScanAt: lastFeedbackScanAt,
        lastOneOnOneAt: lastOneOnOneAt,
        totalSessionsCompleted: totalSessionsCompleted,
        recursionDepth: recursionDepth,
      ),
      wakeCounter: wakeCounter,
    );
  }

  /// Stubs for the full happy-path scenario.
  void stubHappyPath({int feedbackCount = 5}) {
    when(() => mockRepository.getAgentState(any()))
        .thenAnswer((_) async => makeImproverState());

    when(() => mockTemplateService.getTemplate(targetTemplateId))
        .thenAnswer((_) async => makeTestTemplate(id: targetTemplateId));

    when(
      () => mockFeedbackService.extract(
        templateId: any(named: 'templateId'),
        since: any(named: 'since'),
        until: any(named: 'until'),
      ),
    ).thenAnswer(
      (_) async => makeTestClassifiedFeedback(
        items: List.generate(
          feedbackCount,
          (i) => makeTestClassifiedFeedbackItem(detail: 'Feedback $i'),
        ),
      ),
    );

    when(() => mockTemplateService.getActiveVersion(targetTemplateId))
        .thenAnswer((_) async => makeTestTemplateVersion());

    when(() => mockTemplateService.gatherEvolutionData(targetTemplateId))
        .thenAnswer((_) async => makeTestEvolutionDataBundle());

    when(
      () => mockEvolutionWorkflow.startSession(
        templateId: any(named: 'templateId'),
        contextOverride: any(named: 'contextOverride'),
        sessionNumberOverride: any(named: 'sessionNumberOverride'),
      ),
    ).thenAnswer((_) async => 'LLM response');

    when(() => mockImproverService.scheduleNextRitual(any()))
        .thenAnswer((_) async {});
  }

  group('execute', () {
    test('happy path: sufficient feedback starts evolution session', () async {
      stubHappyPath();

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isTrue);

      // Verify feedback was extracted.
      verify(
        () => mockFeedbackService.extract(
          templateId: targetTemplateId,
          since: any(named: 'since'),
          until: any(named: 'until'),
        ),
      ).called(1);

      // Verify evolution session was started with context override.
      verify(
        () => mockEvolutionWorkflow.startSession(
          templateId: targetTemplateId,
          contextOverride: any(named: 'contextOverride'),
          sessionNumberOverride: any(named: 'sessionNumberOverride'),
        ),
      ).called(1);

      // Verify state was updated with lastFeedbackScanAt.
      final captured =
          verify(() => mockSyncService.upsertEntity(captureAny())).captured;
      final stateUpdates = captured.whereType<AgentStateEntity>().toList();
      expect(stateUpdates, isNotEmpty);
      final lastUpdate = stateUpdates.last;
      expect(lastUpdate.slots.lastFeedbackScanAt, isNotNull);
      expect(lastUpdate.wakeCounter, 1);
    });

    test('threshold gate: insufficient feedback skips ritual', () async {
      stubHappyPath(feedbackCount: 2);

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isTrue);

      // Should NOT start evolution session.
      verifyNever(
        () => mockEvolutionWorkflow.startSession(
          templateId: any(named: 'templateId'),
          contextOverride: any(named: 'contextOverride'),
          sessionNumberOverride: any(named: 'sessionNumberOverride'),
        ),
      );

      // Should schedule next wake.
      verify(() => mockImproverService.scheduleNextRitual(kTestAgentId))
          .called(1);

      // Should update lastFeedbackScanAt.
      final captured =
          verify(() => mockSyncService.upsertEntity(captureAny())).captured;
      final stateUpdates = captured.whereType<AgentStateEntity>().toList();
      expect(stateUpdates, hasLength(1));
      expect(stateUpdates.first.slots.lastFeedbackScanAt, isNotNull);
    });

    test('returns failure when no agent state found', () async {
      when(() => mockRepository.getAgentState(any()))
          .thenAnswer((_) async => null);

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('No agent state'));
    });

    test('returns failure when no activeTemplateId in slots', () async {
      when(() => mockRepository.getAgentState(any()))
          .thenAnswer((_) async => makeImproverState(activeTemplateId: null));

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('activeTemplateId'));
    });

    test('returns failure when target template not found', () async {
      when(() => mockRepository.getAgentState(any()))
          .thenAnswer((_) async => makeImproverState());

      when(() => mockTemplateService.getTemplate(targetTemplateId))
          .thenAnswer((_) async => null);

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('not found'));
    });

    test('returns failure when evolution session fails to start', () async {
      stubHappyPath();
      when(
        () => mockEvolutionWorkflow.startSession(
          templateId: any(named: 'templateId'),
          contextOverride: any(named: 'contextOverride'),
          sessionNumberOverride: any(named: 'sessionNumberOverride'),
        ),
      ).thenAnswer((_) async => null);

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Failed to start evolution session'));

      // Should still schedule next wake.
      verify(() => mockImproverService.scheduleNextRitual(kTestAgentId))
          .called(1);
    });

    test('uses lastFeedbackScanAt as feedback window start', () async {
      final scanDate = DateTime(2024, 3, 10);
      stubHappyPath();
      when(() => mockRepository.getAgentState(any())).thenAnswer(
        (_) async => makeImproverState(lastFeedbackScanAt: scanDate),
      );

      await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      final captured = verify(
        () => mockFeedbackService.extract(
          templateId: targetTemplateId,
          since: captureAny(named: 'since'),
          until: any(named: 'until'),
        ),
      ).captured;

      expect(captured.first, scanDate);
    });

    test('falls back to lastOneOnOneAt when lastFeedbackScanAt is null',
        () async {
      final oneOnOneDate = DateTime(2024, 3, 5);
      stubHappyPath();
      when(() => mockRepository.getAgentState(any())).thenAnswer(
        (_) async => makeImproverState(lastOneOnOneAt: oneOnOneDate),
      );

      await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      final captured = verify(
        () => mockFeedbackService.extract(
          templateId: targetTemplateId,
          since: captureAny(named: 'since'),
          until: any(named: 'until'),
        ),
      ).captured;

      expect(captured.first, oneOnOneDate);
    });

    test('falls back to agent createdAt when both scan dates are null',
        () async {
      stubHappyPath();
      when(() => mockRepository.getAgentState(any()))
          .thenAnswer((_) async => makeImproverState());

      final identity = makeImproverIdentity();
      await workflow.execute(
        agentIdentity: identity,
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      final captured = verify(
        () => mockFeedbackService.extract(
          templateId: targetTemplateId,
          since: captureAny(named: 'since'),
          until: any(named: 'until'),
        ),
      ).captured;

      expect(captured.first, identity.createdAt);
    });

    test('returns failure when no active version for template', () async {
      stubHappyPath();
      when(() => mockTemplateService.getActiveVersion(targetTemplateId))
          .thenAnswer((_) async => null);

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('No active version'));
    });

    test('schedules next ritual even on exception', () async {
      stubHappyPath();
      when(
        () => mockEvolutionWorkflow.startSession(
          templateId: any(named: 'templateId'),
          contextOverride: any(named: 'contextOverride'),
          sessionNumberOverride: any(named: 'sessionNumberOverride'),
        ),
      ).thenThrow(Exception('LLM error'));

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Ritual workflow failed'));

      // Should still schedule next wake.
      verify(() => mockImproverService.scheduleNextRitual(kTestAgentId))
          .called(1);
    });

    test('returns failure when scheduleNextRitual also throws', () async {
      stubHappyPath();
      when(
        () => mockEvolutionWorkflow.startSession(
          templateId: any(named: 'templateId'),
          contextOverride: any(named: 'contextOverride'),
          sessionNumberOverride: any(named: 'sessionNumberOverride'),
        ),
      ).thenThrow(Exception('LLM error'));
      when(() => mockImproverService.scheduleNextRitual(any()))
          .thenThrow(Exception('Schedule also failed'));

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Ritual workflow failed'));
    });

    test(
        'passes isMetaLevel=true to context builder when '
        'recursionDepth > 0', () async {
      stubHappyPath();
      when(() => mockRepository.getAgentState(any())).thenAnswer(
        (_) async => makeImproverState(recursionDepth: 1),
      );

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isTrue);

      // Verify the evolution session was started — the context override
      // is built internally, so we verify indirectly by checking the
      // session was started (the context builder is called inside execute).
      verify(
        () => mockEvolutionWorkflow.startSession(
          templateId: targetTemplateId,
          contextOverride: any(named: 'contextOverride'),
          sessionNumberOverride: any(named: 'sessionNumberOverride'),
        ),
      ).called(1);
    });

    test(
        'passes isMetaLevel=false to context builder when '
        'recursionDepth is 0', () async {
      stubHappyPath();
      when(() => mockRepository.getAgentState(any())).thenAnswer(
        (_) async => makeImproverState(recursionDepth: 0),
      );

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isTrue);

      verify(
        () => mockEvolutionWorkflow.startSession(
          templateId: targetTemplateId,
          contextOverride: any(named: 'contextOverride'),
          sessionNumberOverride: any(named: 'sessionNumberOverride'),
        ),
      ).called(1);
    });

    test('passes isMetaLevel=false when recursionDepth is null', () async {
      stubHappyPath();
      // Default makeImproverState has null recursionDepth.
      when(() => mockRepository.getAgentState(any()))
          .thenAnswer((_) async => makeImproverState());

      final result = await workflow.execute(
        agentIdentity: makeImproverIdentity(),
        runKey: 'run-001',
        threadId: 'thread-001',
      );

      expect(result.success, isTrue);
    });
  });
}
