//ignore_for_file: avoid_redundant_argument_values
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
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

  setUp(() {
    mockRepo = MockAgentRepository();
    mockTemplateService = MockAgentTemplateService();

    service = FeedbackExtractionService(
      agentRepository: mockRepo,
      templateService: mockTemplateService,
    );
  });

  setUpAll(registerAllFallbackValues);

  /// Stubs that return empty data for all data sources.
  void stubEmptyData() {
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
    // Default: no entity found for payload lookups.
    when(() => mockRepo.getEntity(any())).thenAnswer((_) async => null);
    // Template kind check: null → not an improver, skips evolution feedback.
    when(() => mockTemplateService.getTemplate(any()))
        .thenAnswer((_) async => null);
  }

  /// Stubs decisions for decision classification tests.
  void stubDecisions(List<ChangeDecisionEntity> decisions) {
    stubEmptyData();
    when(
      () => mockRepo.getRecentDecisionsForTemplate(
        any(),
        since: any(named: 'since'),
      ),
    ).thenAnswer((_) async => decisions);
  }

  group('extract', () {
    test('returns empty feedback when no data exists', () async {
      stubEmptyData();

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, isEmpty);
      expect(result.totalObservationsScanned, 0);
      expect(result.totalDecisionsScanned, 0);
      expect(result.windowStart, windowStart);
      expect(result.windowEnd, windowEnd);
    });

    test('uses clock.now() when until is not provided', () async {
      final now = DateTime(2024, 3, 20, 12, 30);
      stubEmptyData();

      final result = await withClock(
        Clock.fixed(now),
        () => service.extract(
          templateId: kTestTemplateId,
          since: windowStart,
        ),
      );

      expect(result.windowEnd, now);
    });

    test('throws ArgumentError when until is before since', () {
      expect(
        () => service.extract(
          templateId: kTestTemplateId,
          since: windowEnd,
          until: windowStart,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must not be before since'),
          ),
        ),
      );
    });

    test('classifies confirmed decisions as positive', () async {
      final decision = makeTestChangeDecision(
        createdAt: DateTime(2024, 3, 15),
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.positive);
      expect(result.items.first.category, FeedbackCategory.accuracy);
      expect(result.items.first.source, FeedbackSources.decision);
      expect(result.items.first.confidence, 1.0);
      expect(result.totalDecisionsScanned, 1);
    });

    test('classifies rejected decisions as negative', () async {
      final decision = makeTestChangeDecision(
        verdict: ChangeDecisionVerdict.rejected,
        createdAt: DateTime(2024, 3, 15),
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.negative);
      expect(
        result.items.first.detail,
        contains('rejected'),
      );
    });

    test('classifies deferred decisions as neutral', () async {
      final decision = makeTestChangeDecision(
        verdict: ChangeDecisionVerdict.deferred,
        createdAt: DateTime(2024, 3, 15),
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.neutral);
    });

    test('classifies high-confidence reports as positive', () async {
      stubEmptyData();
      final report = makeTestReport(
        confidence: 0.9,
        createdAt: DateTime(2024, 3, 15),
      );
      when(
        () => mockTemplateService.getRecentInstanceReports(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [report]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.positive);
      expect(result.items.first.source, FeedbackSources.metric);
      expect(result.items.first.confidence, 0.9);
    });

    test('classifies low-confidence reports as negative', () async {
      stubEmptyData();
      final report = makeTestReport(
        confidence: 0.2,
        createdAt: DateTime(2024, 3, 15),
      );
      when(
        () => mockTemplateService.getRecentInstanceReports(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [report]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.negative);
    });

    test('classifies mid-confidence reports as neutral', () async {
      stubEmptyData();
      final report = makeTestReport(
        confidence: 0.5,
        createdAt: DateTime(2024, 3, 15),
      );
      when(
        () => mockTemplateService.getRecentInstanceReports(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [report]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.neutral);
    });

    test('skips reports with no confidence', () async {
      stubEmptyData();
      final report = makeTestReport(
        createdAt: DateTime(2024, 3, 15),
      );
      when(
        () => mockTemplateService.getRecentInstanceReports(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [report]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, isEmpty);
    });

    test('filters items outside the date window', () async {
      // Decision before the window
      final earlyDecision = makeTestChangeDecision(
        id: 'cd-early',
        createdAt: DateTime(2024, 3, 5),
      );
      // Decision after the window
      final lateDecision = makeTestChangeDecision(
        id: 'cd-late',
        createdAt: DateTime(2024, 3, 25),
      );
      // Decision inside the window
      final insideDecision = makeTestChangeDecision(
        id: 'cd-inside',
        createdAt: DateTime(2024, 3, 15),
      );
      stubDecisions([earlyDecision, lateDecision, insideDecision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sourceEntityId, 'cd-inside');
      expect(result.totalDecisionsScanned, 1);
    });

    test('classifies observations as neutral with default detail', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.neutral);
      expect(result.items.first.source, FeedbackSources.observation);
      expect(result.items.first.category, FeedbackCategory.general);
      expect(result.items.first.detail, 'Observation recorded');
      expect(result.totalObservationsScanned, 1);
    });

    test(
        'classifies critical grievance observation as negative '
        'with full confidence', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-grievance',
      );
      final payload = makeTestMessagePayload(
        id: 'payload-grievance',
        content: {
          'text': 'User asked me to change priority to P0 but I kept P1.',
          'priority': 'critical',
          'category': 'grievance',
        },
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(() => mockRepo.getEntity('payload-grievance'))
          .thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      final item = result.items.first;
      expect(item.sentiment, FeedbackSentiment.negative);
      expect(item.observationPriority, ObservationPriority.critical);
      expect(item.confidence, 1.0);
      expect(item.category, FeedbackCategory.prioritization);
    });

    test(
        'classifies critical excellence observation as positive '
        'with full confidence', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-excellence',
      );
      final payload = makeTestMessagePayload(
        id: 'payload-excellence',
        content: {
          'text': 'User praised the report quality.',
          'priority': 'critical',
          'category': 'excellence',
        },
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(() => mockRepo.getEntity('payload-excellence'))
          .thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      final item = result.items.first;
      expect(item.sentiment, FeedbackSentiment.positive);
      expect(item.observationPriority, ObservationPriority.critical);
      expect(item.confidence, 1.0);
    });

    test('routine observations fall back to keyword heuristic', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-routine',
      );
      final payload = makeTestMessagePayload(
        id: 'payload-routine',
        content: {
          'text': 'Task completed successfully.',
          'priority': 'routine',
          'category': 'operational',
        },
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(() => mockRepo.getEntity('payload-routine'))
          .thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      final item = result.items.first;
      // "completed" and "successfully" are positive keywords.
      expect(item.sentiment, FeedbackSentiment.positive);
      expect(item.observationPriority, ObservationPriority.routine);
      expect(item.confidence, isNull);
    });

    test('enriches observation detail with payload text', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-enrich-1',
      );
      final payload = makeTestMessagePayload(
        id: 'payload-enrich-1',
        content: {'text': 'The agent noticed high CPU usage on the server.'},
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(() => mockRepo.getEntity('payload-enrich-1'))
          .thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(
        result.items.first.detail,
        'The agent noticed high CPU usage on the server.',
      );
    });

    test('truncates long observation payload text to 200 chars', () async {
      stubEmptyData();
      final longText = 'A' * 250;
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-long',
      );
      final payload = makeTestMessagePayload(
        id: 'payload-long',
        content: {'text': longText},
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(() => mockRepo.getEntity('payload-long'))
          .thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      // Truncated to maxLength (including ellipsis).
      expect(result.items.first.detail.length, 200);
      expect(result.items.first.detail, endsWith('…'));
    });

    test('falls back to default detail when payload has no text', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-empty',
      );
      final payload = makeTestMessagePayload(
        id: 'payload-empty',
        content: {'data': 'some non-text content'},
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(() => mockRepo.getEntity('payload-empty'))
          .thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.detail, 'Observation recorded');
    });

    test('classifies observation with positive keywords as positive', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-positive',
      );
      final payload = makeTestMessagePayload(
        id: 'payload-positive',
        content: {'text': 'Task completed successfully and approved by user.'},
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(() => mockRepo.getEntity('payload-positive'))
          .thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.positive);
    });

    test('classifies observation with negative keywords as negative', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-negative',
      );
      final payload = makeTestMessagePayload(
        id: 'payload-negative',
        content: {'text': 'Agent encountered an error and the task failed.'},
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(() => mockRepo.getEntity('payload-negative'))
          .thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.negative);
    });

    test('classifies observation with mixed keywords as dominant sentiment',
        () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-mixed',
      );
      // Two negative keywords (error, crash) vs one positive (resolved)
      final payload = makeTestMessagePayload(
        id: 'payload-mixed',
        content: {'text': 'System error caused a crash but was resolved.'},
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(() => mockRepo.getEntity('payload-mixed'))
          .thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      // 2 negative > 1 positive → negative
      expect(result.items.first.sentiment, FeedbackSentiment.negative);
    });

    test('uses humanSummary in decision detail when available', () async {
      stubEmptyData();
      final decision = makeTestChangeDecision(
        createdAt: DateTime(2024, 3, 15),
        humanSummary: 'Added label "urgent" to task #42',
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(
        result.items.first.detail,
        'confirmed: Added label "urgent" to task #42',
      );
    });

    test(
        'uses change-set item summary when decision humanSummary '
        'is missing', () async {
      stubEmptyData();
      final decision = makeTestChangeDecision(
        createdAt: DateTime(2024, 3, 15),
        changeSetId: 'cs-summary',
        humanSummary: null,
        itemIndex: 0,
        toolName: 'fallback_tool',
      );
      stubDecisions([decision]);
      when(() => mockRepo.getEntity('cs-summary')).thenAnswer(
        (_) async => makeTestChangeSet(id: 'cs-summary'),
      );

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.detail, 'confirmed: Set estimate to 2 hours');
    });

    test(
        'falls back to toolName and includes rejection reason '
        'when no summary exists', () async {
      stubEmptyData();
      final decision = makeTestChangeDecision(
        createdAt: DateTime(2024, 3, 15),
        verdict: ChangeDecisionVerdict.rejected,
        humanSummary: null,
        changeSetId: 'cs-missing',
        toolName: 'update_title',
        rejectionReason: 'unsafe change',
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(
        result.items.first.detail,
        'rejected: update_title — unsafe change',
      );
    });

    test('continues when change-set fetch fails for a decision', () async {
      stubEmptyData();
      final decision = makeTestChangeDecision(
        createdAt: DateTime(2024, 3, 15),
        humanSummary: null,
        changeSetId: 'cs-fail',
        toolName: 'safe_fallback_tool',
      );
      stubDecisions([decision]);
      when(() => mockRepo.getEntity('cs-fail')).thenThrow(Exception('db down'));

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.detail, contains('safe_fallback_tool'));
    });

    test('continues when observation payload fetch fails', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-fail',
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(() => mockRepo.getEntity('payload-fail'))
          .thenThrow(Exception('payload read failed'));

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.detail, 'Observation recorded');
      expect(result.items.first.sentiment, FeedbackSentiment.neutral);
    });

    test('classifies high wake run rating as positive', () async {
      stubEmptyData();
      final wakeRun = makeTestWakeRun(
        userRating: 5,
        createdAt: DateTime(2024, 3, 15),
      );
      when(
        () => mockRepo.getWakeRunsForTemplate(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [wakeRun]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.positive);
      expect(result.items.first.source, FeedbackSources.rating);
      expect(result.items.first.detail, contains('5.0'));
    });

    test('classifies low wake run rating as negative', () async {
      stubEmptyData();
      final wakeRun = makeTestWakeRun(
        userRating: 1,
        createdAt: DateTime(2024, 3, 15),
      );
      when(
        () => mockRepo.getWakeRunsForTemplate(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [wakeRun]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.negative);
    });

    test('classifies mid wake run rating as neutral', () async {
      stubEmptyData();
      final wakeRun = makeTestWakeRun(
        userRating: 3,
        createdAt: DateTime(2024, 3, 15),
      );
      when(
        () => mockRepo.getWakeRunsForTemplate(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [wakeRun]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.neutral);
    });

    test('skips wake runs without user rating', () async {
      stubEmptyData();
      final wakeRun = makeTestWakeRun(
        createdAt: DateTime(2024, 3, 15),
      );
      when(
        () => mockRepo.getWakeRunsForTemplate(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [wakeRun]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, isEmpty);
    });
  });

  group('ClassifiedFeedbackX', () {
    test('positive getter filters positive items', () {
      final feedback = makeTestClassifiedFeedback(
        items: [
          makeTestClassifiedFeedbackItem(detail: 'good'),
          makeTestClassifiedFeedbackItem(
            sentiment: FeedbackSentiment.negative,
            detail: 'bad',
          ),
          makeTestClassifiedFeedbackItem(detail: 'also good'),
        ],
      );

      expect(feedback.positive, hasLength(2));
      expect(
        feedback.positive.every(
          (i) => i.sentiment == FeedbackSentiment.positive,
        ),
        isTrue,
      );
    });

    test('negative getter filters negative items', () {
      final feedback = makeTestClassifiedFeedback(
        items: [
          makeTestClassifiedFeedbackItem(),
          makeTestClassifiedFeedbackItem(
            sentiment: FeedbackSentiment.negative,
          ),
          makeTestClassifiedFeedbackItem(
            sentiment: FeedbackSentiment.neutral,
          ),
        ],
      );

      expect(feedback.negative, hasLength(1));
      expect(
        feedback.negative.first.sentiment,
        FeedbackSentiment.negative,
      );
    });

    test('byCategory groups items correctly', () {
      final feedback = makeTestClassifiedFeedback(
        items: [
          makeTestClassifiedFeedbackItem(detail: 'a1'),
          makeTestClassifiedFeedbackItem(
            category: FeedbackCategory.tooling,
            detail: 't1',
          ),
          makeTestClassifiedFeedbackItem(detail: 'a2'),
        ],
      );

      final grouped = feedback.byCategory;
      expect(grouped, hasLength(2));
      expect(grouped[FeedbackCategory.accuracy], hasLength(2));
      expect(grouped[FeedbackCategory.tooling], hasLength(1));
    });

    test('empty feedback returns empty positive/negative/byCategory', () {
      final feedback = makeTestClassifiedFeedback();

      expect(feedback.positive, isEmpty);
      expect(feedback.negative, isEmpty);
      expect(feedback.byCategory, isEmpty);
    });

    test('critical getter filters items with critical observation priority',
        () {
      final feedback = makeTestClassifiedFeedback(
        items: [
          makeTestClassifiedFeedbackItem(
            detail: 'grievance',
            sentiment: FeedbackSentiment.negative,
            observationPriority: ObservationPriority.critical,
          ),
          makeTestClassifiedFeedbackItem(
            detail: 'routine observation',
            observationPriority: ObservationPriority.routine,
          ),
          makeTestClassifiedFeedbackItem(
            detail: 'excellence note',
            observationPriority: ObservationPriority.critical,
          ),
        ],
      );

      expect(feedback.critical, hasLength(2));
      expect(
        feedback.critical.map((i) => i.detail),
        containsAll(['grievance', 'excellence note']),
      );
    });

    test('grievances filters critical + negative items', () {
      final feedback = makeTestClassifiedFeedback(
        items: [
          makeTestClassifiedFeedbackItem(
            detail: 'real grievance',
            sentiment: FeedbackSentiment.negative,
            observationPriority: ObservationPriority.critical,
          ),
          makeTestClassifiedFeedbackItem(
            detail: 'excellence',
            sentiment: FeedbackSentiment.positive,
            observationPriority: ObservationPriority.critical,
          ),
          makeTestClassifiedFeedbackItem(
            detail: 'routine negative',
            sentiment: FeedbackSentiment.negative,
          ),
        ],
      );

      expect(feedback.grievances, hasLength(1));
      expect(feedback.grievances.single.detail, 'real grievance');
    });

    test('excellenceNotes filters critical + positive items', () {
      final feedback = makeTestClassifiedFeedback(
        items: [
          makeTestClassifiedFeedbackItem(
            detail: 'great work',
            sentiment: FeedbackSentiment.positive,
            observationPriority: ObservationPriority.critical,
          ),
          makeTestClassifiedFeedbackItem(
            detail: 'grievance',
            sentiment: FeedbackSentiment.negative,
            observationPriority: ObservationPriority.critical,
          ),
        ],
      );

      expect(feedback.excellenceNotes, hasLength(1));
      expect(feedback.excellenceNotes.single.detail, 'great work');
    });
  });

  group('evolution session feedback extraction', () {
    const improverTplId = 'template-improver-001';
    const taskTplId = 'task-template-001';

    /// Stubs that return empty data plus an improver-kind template.
    void stubEmptyImproverData() {
      stubEmptyData();
      when(() => mockTemplateService.getTemplate(improverTplId)).thenAnswer(
        (_) async => makeTestTemplate(
          id: improverTplId,
          agentId: improverTplId,
          kind: AgentTemplateKind.templateImprover,
        ),
      );
    }

    /// Stub an improver agent instance governed by the template.
    void stubImproverAgentInstances({
      String agentId = 'improver-agent-1',
      String activeTemplateId = taskTplId,
    }) {
      when(() => mockTemplateService.getAgentsForTemplate(improverTplId))
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

    test('skips evolution feedback for non-improver templates', () async {
      stubEmptyData();
      // getTemplate returns null → not an improver template.

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(
        result.items.where(
          (i) => i.source == FeedbackSources.evolutionSession,
        ),
        isEmpty,
      );
      // Should NOT have called getAgentsForTemplate at all.
      verifyNever(
        () => mockTemplateService.getAgentsForTemplate(any()),
      );
    });

    test('extracts no evolution feedback when template has no agents',
        () async {
      stubEmptyImproverData();
      when(() => mockTemplateService.getAgentsForTemplate(improverTplId))
          .thenAnswer((_) async => []);

      final result = await service.extract(
        templateId: improverTplId,
        since: windowStart,
        until: windowEnd,
      );

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
      stubEmptyImproverData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTplId, [
        makeTestEvolutionSession(
          id: 'session-1',
          status: EvolutionSessionStatus.completed,
          userRating: 4.5,
          createdAt: DateTime(2024, 3, 15),
        ),
      ]);
      stubVersionHistory(taskTplId, []);

      final result = await service.extract(
        templateId: improverTplId,
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
      stubEmptyImproverData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTplId, [
        makeTestEvolutionSession(
          id: 'session-1',
          status: EvolutionSessionStatus.completed,
          userRating: 1.5,
          createdAt: DateTime(2024, 3, 15),
        ),
      ]);
      stubVersionHistory(taskTplId, []);

      final result = await service.extract(
        templateId: improverTplId,
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
      stubEmptyImproverData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTplId, [
        makeTestEvolutionSession(
          id: 'session-1',
          status: EvolutionSessionStatus.abandoned,
          createdAt: DateTime(2024, 3, 15),
        ),
      ]);
      stubVersionHistory(taskTplId, []);

      final result = await service.extract(
        templateId: improverTplId,
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
      stubEmptyImproverData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTplId, [
        makeTestEvolutionSession(
          id: 'session-1',
          status: EvolutionSessionStatus.completed,
          createdAt: DateTime(2024, 3, 15),
        ),
      ]);
      stubVersionHistory(taskTplId, []);

      final result = await service.extract(
        templateId: improverTplId,
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
      stubEmptyImproverData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTplId, [
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
      stubVersionHistory(taskTplId, []);

      final result = await service.extract(
        templateId: improverTplId,
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
      stubEmptyImproverData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTplId, []);
      stubVersionHistory(
        taskTplId,
        List.generate(
          ImproverSlotDefaults.maxDirectiveChurnVersions + 1,
          (i) => makeTestTemplateVersion(
            id: 'version-$i',
            agentId: taskTplId,
            version: i + 1,
            createdAt: DateTime(2024, 3, 12 + i),
          ),
        ),
      );

      final result = await service.extract(
        templateId: improverTplId,
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
      stubEmptyImproverData();
      stubImproverAgentInstances();
      stubEvolutionSessions(taskTplId, []);
      stubVersionHistory(
        taskTplId,
        List.generate(
          ImproverSlotDefaults.maxDirectiveChurnVersions,
          (i) => makeTestTemplateVersion(
            id: 'version-$i',
            agentId: taskTplId,
            version: i + 1,
            createdAt: DateTime(2024, 3, 12 + i),
          ),
        ),
      );

      final result = await service.extract(
        templateId: improverTplId,
        since: windowStart,
        until: windowEnd,
      );

      final churnItems = result.items
          .where((i) => i.source == FeedbackSources.directiveChurn)
          .toList();
      expect(churnItems, isEmpty);
    });

    test('skips agents without activeTemplateId in state', () async {
      stubEmptyImproverData();
      when(() => mockTemplateService.getAgentsForTemplate(improverTplId))
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
        templateId: improverTplId,
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
