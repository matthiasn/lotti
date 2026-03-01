import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/improver_slot_keys.dart';
import 'package:lotti/features/agents/service/feedback_extraction_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockAgentRepository mockRepo;
  late MockAgentTemplateService mockTemplateService;
  late FeedbackExtractionService service;

  final windowStart = DateTime(2024, 3, 10);
  final windowEnd = DateTime(2024, 3, 20);
  const improverTemplateId = 'template-improver-001';
  const taskTemplateId = 'task-template-001';

  setUp(() {
    mockRepo = MockAgentRepository();
    mockTemplateService = MockAgentTemplateService();

    service = FeedbackExtractionService(
      agentRepository: mockRepo,
      templateService: mockTemplateService,
    );
  });

  setUpAll(registerAllFallbackValues);

  /// Stubs that return empty data for all base data sources.
  void stubEmptyBaseData() {
    when(
      () => mockRepo.getRecentDecisionsForTemplate(
        any(),
        since: any(named: 'since'),
      ),
    ).thenAnswer((_) async => <ChangeDecisionEntity>[]);
    when(
      () => mockTemplateService.getRecentInstanceObservations(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <AgentMessageEntity>[]);
    when(
      () => mockTemplateService.getRecentInstanceReports(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <AgentReportEntity>[]);
    when(
      () => mockRepo.getWakeRunsForTemplate(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
  }

  /// Stub an improver agent instance governed by the template.
  void stubImproverAgentInstances({
    String agentId = 'improver-agent-1',
    String activeTemplateId = taskTemplateId,
  }) {
    when(() => mockTemplateService.getAgentsForTemplate(improverTemplateId))
        .thenAnswer(
      (_) async => [
        makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.templateImprover,
        ),
      ],
    );
    when(() => mockRepo.getAgentState(agentId)).thenAnswer(
      (_) async => makeTestState(
        agentId: agentId,
        slots: AgentSlots(activeTemplateId: activeTemplateId),
      ),
    );
  }

  /// Stub evolution sessions for a target template.
  void stubEvolutionSessions(
    String templateId,
    List<EvolutionSessionEntity> sessions,
  ) {
    when(
      () => mockTemplateService.getEvolutionSessions(
        templateId,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => sessions);
  }

  /// Stub version history for a target template.
  void stubVersionHistory(
    String templateId,
    List<AgentTemplateVersionEntity> versions,
  ) {
    when(
      () => mockTemplateService.getVersionHistory(
        templateId,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => versions);
  }

  group('evolution session feedback extraction', () {
    test('extracts no evolution feedback when template has no agents',
        () async {
      stubEmptyBaseData();
      when(() => mockTemplateService.getAgentsForTemplate(improverTemplateId))
          .thenAnswer((_) async => []);

      final result = await service.extract(
        templateId: improverTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      // Only base feedback items (all empty), no evolution session items.
      expect(
        result.items.where(
          (i) => i.source == FeedbackSources.evolutionSession,
        ),
        isEmpty,
      );
    });

    test(
        'classifies completed sessions with high rating '
        'as positive', () async {
      stubEmptyBaseData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTemplateId, [
        makeTestEvolutionSession(
          id: 'session-1',
          status: EvolutionSessionStatus.completed,
          userRating: 4.5,
          createdAt: DateTime(2024, 3, 15),
        ),
      ]);
      stubVersionHistory(taskTemplateId, []);

      final result = await service.extract(
        templateId: improverTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      final evoItems = result.items
          .where((i) => i.source == FeedbackSources.evolutionSession)
          .toList();
      expect(evoItems, hasLength(1));
      expect(evoItems.first.sentiment, FeedbackSentiment.positive);
      expect(evoItems.first.detail, contains('4.5'));
    });

    test(
        'classifies completed sessions with low rating '
        'as negative', () async {
      stubEmptyBaseData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTemplateId, [
        makeTestEvolutionSession(
          id: 'session-1',
          status: EvolutionSessionStatus.completed,
          userRating: 1.5,
          createdAt: DateTime(2024, 3, 15),
        ),
      ]);
      stubVersionHistory(taskTemplateId, []);

      final result = await service.extract(
        templateId: improverTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      final evoItems = result.items
          .where((i) => i.source == FeedbackSources.evolutionSession)
          .toList();
      expect(evoItems, hasLength(1));
      expect(evoItems.first.sentiment, FeedbackSentiment.negative);
    });

    test('classifies abandoned sessions as negative', () async {
      stubEmptyBaseData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTemplateId, [
        makeTestEvolutionSession(
          id: 'session-1',
          status: EvolutionSessionStatus.abandoned,
          createdAt: DateTime(2024, 3, 15),
        ),
      ]);
      stubVersionHistory(taskTemplateId, []);

      final result = await service.extract(
        templateId: improverTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      final evoItems = result.items
          .where((i) => i.source == FeedbackSources.evolutionSession)
          .toList();
      expect(evoItems, hasLength(1));
      expect(evoItems.first.sentiment, FeedbackSentiment.negative);
      expect(evoItems.first.detail, contains('abandoned'));
    });

    test('classifies completed sessions without rating as neutral', () async {
      stubEmptyBaseData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTemplateId, [
        makeTestEvolutionSession(
          id: 'session-1',
          status: EvolutionSessionStatus.completed,
          createdAt: DateTime(2024, 3, 15),
        ),
      ]);
      stubVersionHistory(taskTemplateId, []);

      final result = await service.extract(
        templateId: improverTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      final evoItems = result.items
          .where((i) => i.source == FeedbackSources.evolutionSession)
          .toList();
      expect(evoItems, hasLength(1));
      expect(evoItems.first.sentiment, FeedbackSentiment.neutral);
    });

    test('filters out sessions outside the time window', () async {
      stubEmptyBaseData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTemplateId, [
        // Before window
        makeTestEvolutionSession(
          id: 'session-early',
          status: EvolutionSessionStatus.completed,
          userRating: 5,
          createdAt: DateTime(2024, 3, 5),
        ),
        // Inside window
        makeTestEvolutionSession(
          id: 'session-inside',
          status: EvolutionSessionStatus.completed,
          userRating: 4,
          createdAt: DateTime(2024, 3, 15),
        ),
        // After window
        makeTestEvolutionSession(
          id: 'session-late',
          status: EvolutionSessionStatus.completed,
          userRating: 5,
          createdAt: DateTime(2024, 3, 25),
        ),
      ]);
      stubVersionHistory(taskTemplateId, []);

      final result = await service.extract(
        templateId: improverTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      final evoItems = result.items
          .where((i) => i.source == FeedbackSources.evolutionSession)
          .toList();
      expect(evoItems, hasLength(1));
      expect(evoItems.first.sourceEntityId, 'session-inside');
    });

    test(
        'flags excessive directive churn when version count '
        'exceeds threshold', () async {
      stubEmptyBaseData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTemplateId, []);
      // Create more versions than the churn threshold within the window.
      stubVersionHistory(
        taskTemplateId,
        List.generate(
          ImproverSlotDefaults.maxDirectiveChurnVersions + 1,
          (i) => makeTestTemplateVersion(
            id: 'version-$i',
            agentId: taskTemplateId,
            version: i + 1,
            createdAt: DateTime(2024, 3, 12 + i),
          ),
        ),
      );

      final result = await service.extract(
        templateId: improverTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      final churnItems = result.items
          .where((i) => i.source == FeedbackSources.directiveChurn)
          .toList();
      expect(churnItems, hasLength(1));
      expect(churnItems.first.sentiment, FeedbackSentiment.negative);
      expect(churnItems.first.detail, contains('Excessive directive churn'));
    });

    test(
        'does not flag directive churn when version count '
        'is within threshold', () async {
      stubEmptyBaseData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTemplateId, []);
      // Create exactly the threshold number of versions.
      stubVersionHistory(
        taskTemplateId,
        List.generate(
          ImproverSlotDefaults.maxDirectiveChurnVersions,
          (i) => makeTestTemplateVersion(
            id: 'version-$i',
            agentId: taskTemplateId,
            version: i + 1,
            createdAt: DateTime(2024, 3, 12 + i),
          ),
        ),
      );

      final result = await service.extract(
        templateId: improverTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      final churnItems = result.items
          .where((i) => i.source == FeedbackSources.directiveChurn)
          .toList();
      expect(churnItems, isEmpty);
    });

    test('skips agents without activeTemplateId in state', () async {
      stubEmptyBaseData();
      when(() => mockTemplateService.getAgentsForTemplate(improverTemplateId))
          .thenAnswer(
        (_) async => [
          makeTestIdentity(
            id: 'agent-no-target',
            agentId: 'agent-no-target',
            kind: AgentKinds.templateImprover,
          ),
        ],
      );
      when(() => mockRepo.getAgentState('agent-no-target')).thenAnswer(
        (_) async => makeTestState(agentId: 'agent-no-target'),
      );

      final result = await service.extract(
        templateId: improverTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      final evoItems = result.items
          .where((i) => i.source == FeedbackSources.evolutionSession)
          .toList();
      expect(evoItems, isEmpty);
    });
  });
}
