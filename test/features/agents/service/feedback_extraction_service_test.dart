import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
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
    when(() => mockTemplateService.getAgentsForTemplate(any()))
        .thenAnswer((_) async => <AgentIdentityEntity>[]);
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

  /// Stubs agents + decisions for decision classification tests.
  void stubDecisions(List<ChangeDecisionEntity> decisions) {
    final agent = makeTestIdentity();
    when(() => mockTemplateService.getAgentsForTemplate(any()))
        .thenAnswer((_) async => [agent]);
    when(
      () => mockRepo.getRecentDecisions(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => decisions);
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
      expect(result.items.first.source, 'decision');
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
      expect(result.items.first.source, 'metric');
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

    test('classifies observations as neutral', () async {
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
      expect(result.items.first.source, 'observation');
      expect(result.items.first.category, FeedbackCategory.general);
      expect(result.totalObservationsScanned, 1);
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
      expect(result.items.first.source, 'rating');
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
  });
}
