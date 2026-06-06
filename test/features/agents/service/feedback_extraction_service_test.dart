//ignore_for_file: avoid_redundant_argument_values
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/model/improver_slot_keys.dart';
import 'package:lotti/features/agents/service/feedback_extraction_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedFeedbackDecisionTimeSlot { before, since, inside, until, after }

enum _GeneratedFeedbackDecisionToolSlot {
  estimate,
  title,
  addChecklist,
  updateChecklist,
  migrateChecklist,
}

enum _GeneratedFeedbackDecisionContextSlot {
  none,
  rejectionReason,
  snakeReason,
  kebabReason,
  nestedFeedback,
  notesList,
  nonExplanatoryArgs,
  shortReason,
}

enum _GeneratedFeedbackDecisionSummarySlot {
  decisionSummary,
  changeSetSummary,
  toolNameFallback,
}

class _GeneratedFeedbackDecisionSpec {
  const _GeneratedFeedbackDecisionSpec({
    required this.timeSlot,
    required this.verdict,
    required this.toolSlot,
    required this.contextSlot,
    required this.summarySlot,
  });

  final _GeneratedFeedbackDecisionTimeSlot timeSlot;
  final ChangeDecisionVerdict verdict;
  final _GeneratedFeedbackDecisionToolSlot toolSlot;
  final _GeneratedFeedbackDecisionContextSlot contextSlot;
  final _GeneratedFeedbackDecisionSummarySlot summarySlot;

  bool get isChecklistTool => switch (toolSlot) {
    _GeneratedFeedbackDecisionToolSlot.addChecklist ||
    _GeneratedFeedbackDecisionToolSlot.updateChecklist ||
    _GeneratedFeedbackDecisionToolSlot.migrateChecklist => true,
    _ => false,
  };

  bool get hasExplanatoryContext => switch (contextSlot) {
    _GeneratedFeedbackDecisionContextSlot.rejectionReason ||
    _GeneratedFeedbackDecisionContextSlot.snakeReason ||
    _GeneratedFeedbackDecisionContextSlot.kebabReason ||
    _GeneratedFeedbackDecisionContextSlot.nestedFeedback ||
    _GeneratedFeedbackDecisionContextSlot.notesList => true,
    _ => false,
  };

  bool get suppressesAsBareChecklistRejection =>
      verdict == ChangeDecisionVerdict.rejected &&
      isChecklistTool &&
      !hasExplanatoryContext;

  String get toolName => switch (toolSlot) {
    _GeneratedFeedbackDecisionToolSlot.estimate => 'update_task_estimate',
    _GeneratedFeedbackDecisionToolSlot.title => 'update_task_title',
    _GeneratedFeedbackDecisionToolSlot.addChecklist =>
      TaskAgentToolNames.addChecklistItem,
    _GeneratedFeedbackDecisionToolSlot.updateChecklist =>
      TaskAgentToolNames.updateChecklistItems,
    _GeneratedFeedbackDecisionToolSlot.migrateChecklist =>
      TaskAgentToolNames.migrateChecklistItems,
  };

  FeedbackSentiment get expectedSentiment => switch (verdict) {
    ChangeDecisionVerdict.confirmed => FeedbackSentiment.positive,
    ChangeDecisionVerdict.rejected => FeedbackSentiment.negative,
    ChangeDecisionVerdict.deferred => FeedbackSentiment.neutral,
    ChangeDecisionVerdict.retracted => FeedbackSentiment.neutral,
  };

  DateTime createdAt({
    required DateTime since,
    required DateTime until,
  }) {
    return switch (timeSlot) {
      _GeneratedFeedbackDecisionTimeSlot.before => since.subtract(
        const Duration(microseconds: 1),
      ),
      _GeneratedFeedbackDecisionTimeSlot.since => since,
      _GeneratedFeedbackDecisionTimeSlot.inside => since.add(
        const Duration(days: 2, hours: 3),
      ),
      _GeneratedFeedbackDecisionTimeSlot.until => until,
      _GeneratedFeedbackDecisionTimeSlot.after => until.add(
        const Duration(microseconds: 1),
      ),
    };
  }

  bool isInWindow({
    required DateTime since,
    required DateTime until,
  }) {
    final created = createdAt(since: since, until: until);
    return !created.isBefore(since) && !created.isAfter(until);
  }

  ChangeDecisionEntity decision({
    required int index,
    required DateTime since,
    required DateTime until,
  }) {
    return makeTestChangeDecision(
      id: _decisionId(index),
      agentId: _agentId(index),
      changeSetId: _changeSetId(index),
      itemIndex: 0,
      toolName: toolName,
      verdict: verdict,
      createdAt: createdAt(since: since, until: until),
      rejectionReason: rejectionReason(index),
      humanSummary: decisionSummary(index),
      args: args(index),
    );
  }

  ChangeSetEntity? changeSet({
    required int index,
    required DateTime since,
    required DateTime until,
  }) {
    if (summarySlot != _GeneratedFeedbackDecisionSummarySlot.changeSetSummary) {
      return null;
    }

    return makeTestChangeSet(
      id: _changeSetId(index),
      agentId: _agentId(index),
      createdAt: createdAt(since: since, until: until),
      items: [
        ChangeItem(
          toolName: toolName,
          args: args(index) ?? const {},
          humanSummary: changeSetSummary(index),
        ),
      ],
    );
  }

  _ExpectedFeedbackDecisionItem expectedItem(int index) {
    return _ExpectedFeedbackDecisionItem(
      id: _decisionId(index),
      agentId: _agentId(index),
      sentiment: expectedSentiment,
      detail: expectedDetail(index),
    );
  }

  String expectedDetail(int index) {
    final reason = rejectionReason(index);
    final suffix = reason == null ? '' : ' — $reason';
    return '${verdict.name}: ${expectedSummary(index)}$suffix';
  }

  String expectedSummary(int index) {
    return switch (summarySlot) {
      _GeneratedFeedbackDecisionSummarySlot.decisionSummary => decisionSummary(
        index,
      )!,
      _GeneratedFeedbackDecisionSummarySlot.changeSetSummary =>
        changeSetSummary(index),
      _GeneratedFeedbackDecisionSummarySlot.toolNameFallback => toolName,
    };
  }

  String? decisionSummary(int index) {
    return switch (summarySlot) {
      _GeneratedFeedbackDecisionSummarySlot.decisionSummary =>
        'Generated decision summary $index',
      _ => null,
    };
  }

  String changeSetSummary(int index) => 'Generated change-set summary $index';

  String? rejectionReason(int index) {
    return switch (contextSlot) {
      _GeneratedFeedbackDecisionContextSlot.rejectionReason =>
        'Generated rejection reason $index',
      _ => null,
    };
  }

  Map<String, dynamic>? args(int index) {
    return switch (contextSlot) {
      _GeneratedFeedbackDecisionContextSlot.snakeReason => {
        'rejection_reason': 'Generated snake reason $index',
      },
      _GeneratedFeedbackDecisionContextSlot.kebabReason => {
        'rejection-reason': 'Generated kebab reason $index',
      },
      _GeneratedFeedbackDecisionContextSlot.nestedFeedback => {
        'feedback': {'text': 'Generated nested feedback $index'},
      },
      _GeneratedFeedbackDecisionContextSlot.notesList => {
        'notes': ['Generated note $index', 'Generated follow-up $index'],
      },
      _GeneratedFeedbackDecisionContextSlot.nonExplanatoryArgs => {
        'title': 'Generated checklist item $index',
        'status': 'open',
      },
      _GeneratedFeedbackDecisionContextSlot.shortReason => {'reason': 'ok'},
      _ => null,
    };
  }

  String _decisionId(int index) => 'generated-decision-$index';

  String _agentId(int index) => 'generated-agent-$index';

  String _changeSetId(int index) => 'generated-change-set-$index';

  @override
  String toString() {
    return '_GeneratedFeedbackDecisionSpec('
        'timeSlot: $timeSlot, verdict: $verdict, toolSlot: $toolSlot, '
        'contextSlot: $contextSlot, summarySlot: $summarySlot)';
  }
}

class _GeneratedFeedbackDecisionScenario {
  const _GeneratedFeedbackDecisionScenario({required this.decisions});

  final List<_GeneratedFeedbackDecisionSpec> decisions;

  _ExpectedFeedbackDecisionModel expectedModel({
    required DateTime since,
    required DateTime until,
  }) {
    final classifiedItems = <_ExpectedFeedbackDecisionItem>[];
    var totalDecisionsScanned = 0;
    var suppressedChecklistRejectionCount = 0;

    for (var index = 0; index < decisions.length; index += 1) {
      final decision = decisions[index];
      if (!decision.isInWindow(since: since, until: until)) {
        continue;
      }

      totalDecisionsScanned += 1;
      if (decision.suppressesAsBareChecklistRejection) {
        suppressedChecklistRejectionCount += 1;
        continue;
      }

      classifiedItems.add(decision.expectedItem(index));
    }

    return _ExpectedFeedbackDecisionModel(
      classifiedItems: classifiedItems,
      totalDecisionsScanned: totalDecisionsScanned,
      suppressedChecklistRejectionCount: suppressedChecklistRejectionCount,
    );
  }

  @override
  String toString() {
    return '_GeneratedFeedbackDecisionScenario(decisions: $decisions)';
  }
}

class _ExpectedFeedbackDecisionModel {
  const _ExpectedFeedbackDecisionModel({
    required this.classifiedItems,
    required this.totalDecisionsScanned,
    required this.suppressedChecklistRejectionCount,
  });

  final List<_ExpectedFeedbackDecisionItem> classifiedItems;
  final int totalDecisionsScanned;
  final int suppressedChecklistRejectionCount;

  bool get hasAggregateSuppressionItem =>
      suppressedChecklistRejectionCount >= 2;

  int get totalItemCount =>
      classifiedItems.length + (hasAggregateSuppressionItem ? 1 : 0);
}

class _ExpectedFeedbackDecisionItem {
  const _ExpectedFeedbackDecisionItem({
    required this.id,
    required this.agentId,
    required this.sentiment,
    required this.detail,
  });

  final String id;
  final String agentId;
  final FeedbackSentiment sentiment;
  final String detail;
}

extension _AnyGeneratedFeedbackDecisionScenario on glados.Any {
  glados.Generator<_GeneratedFeedbackDecisionTimeSlot>
  get feedbackDecisionTimeSlot =>
      glados.AnyUtils(this).choose(_GeneratedFeedbackDecisionTimeSlot.values);

  glados.Generator<ChangeDecisionVerdict> get feedbackDecisionVerdict =>
      glados.AnyUtils(this).choose(ChangeDecisionVerdict.values);

  glados.Generator<_GeneratedFeedbackDecisionToolSlot>
  get feedbackDecisionToolSlot =>
      glados.AnyUtils(this).choose(_GeneratedFeedbackDecisionToolSlot.values);

  glados.Generator<_GeneratedFeedbackDecisionContextSlot>
  get feedbackDecisionContextSlot => glados.AnyUtils(
    this,
  ).choose(_GeneratedFeedbackDecisionContextSlot.values);

  glados.Generator<_GeneratedFeedbackDecisionSummarySlot>
  get feedbackDecisionSummarySlot => glados.AnyUtils(
    this,
  ).choose(_GeneratedFeedbackDecisionSummarySlot.values);

  glados.Generator<_GeneratedFeedbackDecisionSpec> get feedbackDecisionSpec =>
      glados.CombinableAny(this).combine5(
        feedbackDecisionTimeSlot,
        feedbackDecisionVerdict,
        feedbackDecisionToolSlot,
        feedbackDecisionContextSlot,
        feedbackDecisionSummarySlot,
        (
          _GeneratedFeedbackDecisionTimeSlot timeSlot,
          ChangeDecisionVerdict verdict,
          _GeneratedFeedbackDecisionToolSlot toolSlot,
          _GeneratedFeedbackDecisionContextSlot contextSlot,
          _GeneratedFeedbackDecisionSummarySlot summarySlot,
        ) => _GeneratedFeedbackDecisionSpec(
          timeSlot: timeSlot,
          verdict: verdict,
          toolSlot: toolSlot,
          contextSlot: contextSlot,
          summarySlot: summarySlot,
        ),
      );

  glados.Generator<_GeneratedFeedbackDecisionScenario>
  get feedbackDecisionScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(0, 14, feedbackDecisionSpec)
          .map(
            (decisions) =>
                _GeneratedFeedbackDecisionScenario(decisions: decisions),
          );
}

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
    when(
      () => mockTemplateService.getTemplate(any()),
    ).thenAnswer((_) async => null);
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

    test('suppresses a single bare rejected checklist proposal', () async {
      final decision = makeTestChangeDecision(
        verdict: ChangeDecisionVerdict.rejected,
        toolName: TaskAgentToolNames.addChecklistItem,
        createdAt: DateTime(2024, 3, 15),
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, isEmpty);
      expect(result.totalDecisionsScanned, 1);
    });

    test('keeps rejected checklist proposals with explanation', () async {
      final decision = makeTestChangeDecision(
        verdict: ChangeDecisionVerdict.rejected,
        toolName: TaskAgentToolNames.updateChecklistItem,
        rejectionReason: 'This was premature; QA has not signed off yet.',
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
      expect(result.items.first.detail, contains('premature'));
    });

    test('keeps rejected checklist decision when args contain '
        'snake_case explanatory key', () async {
      final decision = makeTestChangeDecision(
        verdict: ChangeDecisionVerdict.rejected,
        toolName: TaskAgentToolNames.addChecklistItem,
        createdAt: DateTime(2024, 3, 15),
        args: {'rejection_reason': 'Not relevant to current sprint'},
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.negative);
    });

    test('keeps rejected checklist decision when args contain '
        'kebab-case explanatory key', () async {
      final decision = makeTestChangeDecision(
        verdict: ChangeDecisionVerdict.rejected,
        toolName: TaskAgentToolNames.updateChecklistItem,
        createdAt: DateTime(2024, 3, 15),
        args: {'rejection-reason': 'Duplicate of existing item'},
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.negative);
    });

    test('keeps rejected checklist decision when args contain '
        'nested map under explanatory key', () async {
      final decision = makeTestChangeDecision(
        verdict: ChangeDecisionVerdict.rejected,
        toolName: TaskAgentToolNames.addMultipleChecklistItems,
        createdAt: DateTime(2024, 3, 15),
        args: {
          'feedback': {'text': 'too early to add these items'},
        },
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.negative);
    });

    test('keeps rejected checklist decision when args contain '
        'list under explanatory key', () async {
      final decision = makeTestChangeDecision(
        verdict: ChangeDecisionVerdict.rejected,
        toolName: TaskAgentToolNames.migrateChecklistItems,
        createdAt: DateTime(2024, 3, 15),
        args: {
          'notes': ['first concern', 'second concern'],
        },
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.negative);
    });

    test('suppresses rejected checklist decision when args contain '
        'only non-explanatory keys', () async {
      final decision = makeTestChangeDecision(
        verdict: ChangeDecisionVerdict.rejected,
        toolName: TaskAgentToolNames.addChecklistItem,
        createdAt: DateTime(2024, 3, 15),
        args: {
          'title': 'Write integration tests for auth module',
          'status': 'open',
        },
      );
      stubDecisions([decision]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      // Non-explanatory keys should not prevent suppression.
      expect(result.items, isEmpty);
      expect(result.totalDecisionsScanned, 1);
    });

    test('aggregates repeated bare rejected checklist proposals', () async {
      final first = makeTestChangeDecision(
        id: 'cd-1',
        verdict: ChangeDecisionVerdict.rejected,
        toolName: TaskAgentToolNames.addChecklistItem,
        createdAt: DateTime(2024, 3, 15),
      );
      final second = makeTestChangeDecision(
        id: 'cd-2',
        verdict: ChangeDecisionVerdict.rejected,
        toolName: TaskAgentToolNames.updateChecklistItems,
        createdAt: DateTime(2024, 3, 16),
      );
      stubDecisions([first, second]);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.negative);
      expect(result.items.first.category, FeedbackCategory.prioritization);
      expect(
        result.items.first.detail,
        contains('Repeated rejected checklist proposals'),
      );
      expect(result.totalDecisionsScanned, 2);
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

    glados.Glados(
      glados.any.feedbackDecisionScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'generated decision extraction preserves window, suppression, '
      'and fallback semantics',
      (scenario) async {
        final decisions = <ChangeDecisionEntity>[];
        for (var index = 0; index < scenario.decisions.length; index += 1) {
          decisions.add(
            scenario.decisions[index].decision(
              index: index,
              since: windowStart,
              until: windowEnd,
            ),
          );
        }
        stubDecisions(decisions);

        for (var index = 0; index < scenario.decisions.length; index += 1) {
          final changeSet = scenario.decisions[index].changeSet(
            index: index,
            since: windowStart,
            until: windowEnd,
          );
          if (changeSet == null) {
            continue;
          }
          when(() => mockRepo.getEntity(changeSet.id)).thenAnswer(
            (_) async => changeSet,
          );
        }

        final expected = scenario.expectedModel(
          since: windowStart,
          until: windowEnd,
        );

        final result = await service.extract(
          templateId: kTestTemplateId,
          since: windowStart,
          until: windowEnd,
        );

        expect(result.windowStart, windowStart);
        expect(result.windowEnd, windowEnd);
        expect(result.totalObservationsScanned, 0);
        expect(result.totalDecisionsScanned, expected.totalDecisionsScanned);
        expect(result.items, hasLength(expected.totalItemCount));

        final decisionItems = result.items
            .where((item) => item.sourceEntityId != null)
            .toList();
        expect(decisionItems, hasLength(expected.classifiedItems.length));
        for (var index = 0; index < decisionItems.length; index += 1) {
          final actual = decisionItems[index];
          final expectedItem = expected.classifiedItems[index];

          expect(actual.source, FeedbackSources.decision);
          expect(actual.category, FeedbackCategory.accuracy);
          expect(actual.confidence, 1);
          expect(actual.sourceEntityId, expectedItem.id);
          expect(actual.agentId, expectedItem.agentId);
          expect(actual.sentiment, expectedItem.sentiment);
          expect(actual.detail, expectedItem.detail);
        }

        final aggregateItems = result.items
            .where((item) => item.sourceEntityId == null)
            .toList();
        if (expected.hasAggregateSuppressionItem) {
          expect(aggregateItems, hasLength(1));
          final aggregate = aggregateItems.single;
          expect(aggregate.source, FeedbackSources.decision);
          expect(aggregate.category, FeedbackCategory.prioritization);
          expect(aggregate.sentiment, FeedbackSentiment.negative);
          expect(aggregate.agentId, kTestTemplateId);
          expect(aggregate.confidence, 1);
          expect(
            aggregate.detail,
            contains('Repeated rejected checklist proposals'),
          );
          expect(
            aggregate.detail,
            contains(
              '${expected.suppressedChecklistRejectionCount} '
              'checklist changes',
            ),
          );
        } else {
          expect(aggregateItems, isEmpty);
        }
      },
      tags: 'glados',
    );

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

    test('classifies critical grievance observation as negative '
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
      when(
        () => mockRepo.getEntity('payload-grievance'),
      ).thenAnswer((_) async => payload);

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

    test('classifies critical excellence observation as positive '
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
      when(
        () => mockRepo.getEntity('payload-excellence'),
      ).thenAnswer((_) async => payload);

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

    test('classifies critical templateImprovement observation as negative '
        'regardless of text sentiment', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-improvement',
      );
      // Text contains only POSITIVE keywords ("excellent", "great"), yet the
      // explicit critical templateImprovement category must force negative
      // sentiment — proving the category branch wins over text heuristics.
      final payload = makeTestMessagePayload(
        id: 'payload-improvement',
        content: {
          'text':
              'The template did great work but could be excellent if the '
              'priority directive were tightened.',
          'priority': 'critical',
          'category': 'templateImprovement',
        },
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(
        () => mockRepo.getEntity('payload-improvement'),
      ).thenAnswer((_) async => payload);

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
      // templateImprovement maps to the general feedback category.
      expect(item.category, FeedbackCategory.general);
    });

    test('classifies critical operational observation via text heuristic '
        'rather than category-derived sentiment', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-critical-operational',
      );
      // Critical priority with the operational category falls through to the
      // keyword heuristic. Negative keywords ("error", "failed") must drive a
      // negative sentiment, distinguishing this from the fixed-sentiment
      // grievance/excellence/templateImprovement branches.
      final payload = makeTestMessagePayload(
        id: 'payload-critical-operational',
        content: {
          'text': 'A transient error occurred and the sync job failed midway.',
          'priority': 'critical',
          'category': 'operational',
        },
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(
        () => mockRepo.getEntity('payload-critical-operational'),
      ).thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      final item = result.items.first;
      // Derived from negative keywords, not a fixed category sentiment.
      expect(item.sentiment, FeedbackSentiment.negative);
      expect(item.observationPriority, ObservationPriority.critical);
      // Still critical, so confidence is pinned to full.
      expect(item.confidence, 1.0);
      expect(item.category, FeedbackCategory.general);
    });

    test('classifies critical operational observation as positive when text '
        'is positive', () async {
      stubEmptyData();
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
        contentEntryId: 'payload-critical-op-positive',
      );
      // Same operational fall-through branch, but positive keywords flip the
      // heuristic result — confirming the branch genuinely consults the text.
      final payload = makeTestMessagePayload(
        id: 'payload-critical-op-positive',
        content: {
          'text':
              'The migration completed successfully and the result was '
              'excellent.',
          'priority': 'critical',
          'category': 'operational',
        },
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observation]);
      when(
        () => mockRepo.getEntity('payload-critical-op-positive'),
      ).thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.sentiment, FeedbackSentiment.positive);
      expect(result.items.first.confidence, 1.0);
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
      when(
        () => mockRepo.getEntity('payload-routine'),
      ).thenAnswer((_) async => payload);

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
      when(
        () => mockRepo.getEntity('payload-enrich-1'),
      ).thenAnswer((_) async => payload);

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
      when(
        () => mockRepo.getEntity('payload-long'),
      ).thenAnswer((_) async => payload);

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
      when(
        () => mockRepo.getEntity('payload-empty'),
      ).thenAnswer((_) async => payload);

      final result = await service.extract(
        templateId: kTestTemplateId,
        since: windowStart,
        until: windowEnd,
      );

      expect(result.items, hasLength(1));
      expect(result.items.first.detail, 'Observation recorded');
    });

    // One parameterized body per sentiment outcome — the cases differ only
    // in the observation text and the expected classification.
    for (final (label, text, expected) in [
      (
        'positive keywords as positive',
        'Task completed successfully and approved by user.',
        FeedbackSentiment.positive,
      ),
      (
        'negative keywords as negative',
        'Agent encountered an error and the task failed.',
        FeedbackSentiment.negative,
      ),
      (
        // Two negative keywords (error, crash) vs one positive (resolved).
        'mixed keywords as the dominant sentiment',
        'System error caused a crash but was resolved.',
        FeedbackSentiment.negative,
      ),
      (
        // Exactly one positive (resolved) and one negative (error) keyword:
        // balanced scores must classify as neutral.
        'balanced keywords as neutral',
        'The error was resolved.',
        FeedbackSentiment.neutral,
      ),
    ]) {
      test('classifies observation with $label', () async {
        stubEmptyData();
        final observation = makeTestMessage(
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 3, 15),
          contentEntryId: 'payload-sentiment',
        );
        final payload = makeTestMessagePayload(
          id: 'payload-sentiment',
          content: {'text': text},
        );
        when(
          () => mockTemplateService.getRecentInstanceObservations(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [observation]);
        when(
          () => mockRepo.getEntity('payload-sentiment'),
        ).thenAnswer((_) async => payload);

        final result = await service.extract(
          templateId: kTestTemplateId,
          since: windowStart,
          until: windowEnd,
        );

        expect(result.items, hasLength(1));
        expect(result.items.first.sentiment, expected, reason: text);
      });
    }

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

    test('uses change-set item summary when decision humanSummary '
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

    test('falls back to toolName and includes rejection reason '
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
      when(
        () => mockRepo.getEntity('payload-fail'),
      ).thenThrow(Exception('payload read failed'));

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
    test(
      'critical getter filters items with critical observation priority',
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
      },
    );

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
      when(
        () => mockTemplateService.getAgentsForTemplate(improverTplId),
      ).thenAnswer(
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

    test(
      'extracts no evolution feedback when template has no agents',
      () async {
        stubEmptyImproverData();
        when(
          () => mockTemplateService.getAgentsForTemplate(improverTplId),
        ).thenAnswer((_) async => []);

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
      },
    );

    test('classifies completed sessions with high rating '
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

    test('classifies completed sessions with low rating '
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

    test('flags excessive directive churn when version count '
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

    test('does not flag directive churn when version count '
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
      when(
        () => mockTemplateService.getAgentsForTemplate(improverTplId),
      ).thenAnswer(
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

  group('extractForSoul', () {
    late MockSoulDocumentService mockSoulService;

    setUp(() {
      mockSoulService = MockSoulDocumentService();
      service = FeedbackExtractionService(
        agentRepository: mockRepo,
        templateService: mockTemplateService,
        soulDocumentService: mockSoulService,
      );
    });

    test('returns empty map when no templates use the soul', () async {
      when(
        () => mockSoulService.getTemplatesUsingSoul(any()),
      ).thenAnswer((_) async => []);

      final result = await service.extractForSoul(
        soulId: 'soul-1',
        since: windowStart,
        until: windowEnd,
      );

      expect(result, isEmpty);
    });

    test('returns empty map when soulDocumentService is null', () async {
      final serviceWithoutSoul = FeedbackExtractionService(
        agentRepository: mockRepo,
        templateService: mockTemplateService,
      );

      final result = await serviceWithoutSoul.extractForSoul(
        soulId: 'soul-1',
        since: windowStart,
        until: windowEnd,
      );

      expect(result, isEmpty);
    });

    test('uses clock.now() as window end when until is omitted', () async {
      final now = DateTime(2024, 3, 18, 9, 45);
      when(
        () => mockSoulService.getTemplatesUsingSoul('soul-1'),
      ).thenAnswer((_) async => ['template-1']);
      stubEmptyData();

      final result = await withClock(
        Clock.fixed(now),
        () => service.extractForSoul(
          soulId: 'soul-1',
          since: windowStart,
        ),
      );

      expect(result, hasLength(1));
      // The clock-derived effectiveUntil is propagated into each template's
      // extraction window.
      expect(result['template-1']!.windowEnd, now);
    });

    test('aggregates feedback from single template', () async {
      when(
        () => mockSoulService.getTemplatesUsingSoul('soul-1'),
      ).thenAnswer((_) async => ['template-1']);
      stubEmptyData();

      // Add one observation with payload.
      final obs = makeTestMessage(
        id: 'obs-1',
        agentId: 'agent-1',
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15),
      );
      when(
        () => mockTemplateService.getRecentInstanceObservations(
          'template-1',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [obs]);

      final result = await service.extractForSoul(
        soulId: 'soul-1',
        since: windowStart,
        until: windowEnd,
      );

      expect(result, hasLength(1));
      expect(result.containsKey('template-1'), isTrue);
      expect(result['template-1']!.items, hasLength(1));
    });

    test('aggregates feedback from multiple templates', () async {
      when(
        () => mockSoulService.getTemplatesUsingSoul('soul-1'),
      ).thenAnswer((_) async => ['template-1', 'template-2']);
      stubEmptyData();

      final result = await service.extractForSoul(
        soulId: 'soul-1',
        since: windowStart,
        until: windowEnd,
      );

      expect(result, hasLength(2));
      expect(result.containsKey('template-1'), isTrue);
      expect(result.containsKey('template-2'), isTrue);
    });

    test('skips one template when extraction throws', () async {
      when(
        () => mockSoulService.getTemplatesUsingSoul('soul-1'),
      ).thenAnswer((_) async => ['template-fails', 'template-ok']);
      stubEmptyData();
      when(
        () => mockRepo.getRecentDecisionsForTemplate(
          'template-fails',
          since: any(named: 'since'),
        ),
      ).thenThrow(Exception('template read failed'));

      final result = await service.extractForSoul(
        soulId: 'soul-1',
        since: windowStart,
        until: windowEnd,
      );

      expect(result.keys, ['template-ok']);
    });
  });

  group('classifyTextSentiment', () {
    test('canonical examples including the balanced-neutral path', () {
      expect(
        FeedbackExtractionService.classifyTextSentiment(''),
        FeedbackSentiment.neutral,
      );
      expect(
        FeedbackExtractionService.classifyTextSentiment('task completed'),
        FeedbackSentiment.positive,
      );
      expect(
        FeedbackExtractionService.classifyTextSentiment('hit a problem'),
        FeedbackSentiment.negative,
      );
      // Exactly one positive and one negative keyword: balanced -> neutral.
      expect(
        FeedbackExtractionService.classifyTextSentiment(
          'the error was resolved',
        ),
        FeedbackSentiment.neutral,
      );
    });

    glados.Glados(
      glados.any.sentimentScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'classification equals the sign of independently recomputed '
      'keyword-containment counts, case-insensitively',
      (scenario) {
        final text = scenario.text;

        // Recompute the score from the published keyword lists rather than
        // trusting the generator's intent: generated keyword combinations
        // can embed extra keywords as substrings (e.g. "fail" in "failed").
        final lower = text.toLowerCase();
        final positives = FeedbackExtractionService.positiveSentimentKeywords
            .where(lower.contains)
            .length;
        final negatives = FeedbackExtractionService.negativeSentimentKeywords
            .where(lower.contains)
            .length;
        final expected = positives > negatives
            ? FeedbackSentiment.positive
            : negatives > positives
            ? FeedbackSentiment.negative
            : FeedbackSentiment.neutral;

        expect(
          FeedbackExtractionService.classifyTextSentiment(text),
          expected,
          reason: text,
        );
        // Case-insensitivity: shouting the same text changes nothing.
        expect(
          FeedbackExtractionService.classifyTextSentiment(text.toUpperCase()),
          expected,
          reason: 'uppercased: $text',
        );
      },
      tags: 'glados',
    );
  });

  group('argsContainExplanatoryContext', () {
    test('canonical examples', () {
      expect(
        FeedbackExtractionService.argsContainExplanatoryContext(null),
        isFalse,
      );
      expect(
        FeedbackExtractionService.argsContainExplanatoryContext(const {}),
        isFalse,
      );
      expect(
        FeedbackExtractionService.argsContainExplanatoryContext(const {
          'reason': 'too early in the flow',
        }),
        isTrue,
      );
      // Short values (<4 chars after trim) carry no meaningful signal.
      expect(
        FeedbackExtractionService.argsContainExplanatoryContext(const {
          'reason': ' no ',
        }),
        isFalse,
      );
      // Non-explanatory keys never classify, however long the value.
      expect(
        FeedbackExtractionService.argsContainExplanatoryContext(const {
          'title': 'a perfectly long explanation that does not count',
        }),
        isFalse,
      );
      // Explanatory parent key propagates to nested string values.
      expect(
        FeedbackExtractionService.argsContainExplanatoryContext(const {
          'feedback': {'text': 'too early'},
        }),
        isTrue,
      );
    });

    glados.Glados(
      glados.any.explanatoryArgsScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'key-separator variants classify identically and the outcome matches '
      'value meaningfulness',
      (scenario) {
        final results = scenario.variantArgs
            .map(FeedbackExtractionService.argsContainExplanatoryContext)
            .toList();

        // Normalisation invariance: rejection_reason / rejection-reason /
        // rejectionReason wrappings of the SAME payload agree.
        expect(
          results.toSet(),
          hasLength(1),
          reason: 'variants disagreed: $scenario',
        );
        // And the shared outcome is exactly "the explanatory value is
        // meaningful" (>=4 chars after trim), independent of nesting depth.
        expect(results.first, scenario.expectedOutcome, reason: '$scenario');
      },
      tags: 'glados',
    );
  });
}

/// Deterministic sentiment text built from the real keyword lists: picks
/// `positivePicks` / `negativePicks` distinct keywords by seed and joins them
/// with neutral filler, with seed-driven casing.
class _SentimentScenario {
  _SentimentScenario(int positivePicks, int negativePicks, int seed) {
    const positives = FeedbackExtractionService.positiveSentimentKeywords;
    const negatives = FeedbackExtractionService.negativeSentimentKeywords;
    final parts = <String>[
      for (var i = 0; i < positivePicks; i++)
        positives[(seed + i * 7) % positives.length],
      for (var i = 0; i < negativePicks; i++)
        negatives[(seed + i * 11) % negatives.length],
    ];
    // Seed-driven shuffle-by-rotation and mixed casing.
    final rotation = parts.isEmpty ? 0 : seed % parts.length;
    final rotated = [...parts.sublist(rotation), ...parts.sublist(0, rotation)];
    final styled = [
      for (var i = 0; i < rotated.length; i++)
        (seed + i).isEven ? rotated[i] : rotated[i].toUpperCase(),
    ];
    text = styled.isEmpty ? 'nothing to see here' : styled.join(' and then ');
  }

  late final String text;

  @override
  String toString() => '_SentimentScenario(text: $text)';
}

/// Builds the SAME explanatory payload wrapped under each key-separator
/// variant of one explanatory key, nested at a seed-chosen depth inside
/// maps/lists. The variants must classify identically.
class _ExplanatoryArgsScenario {
  _ExplanatoryArgsScenario(
    int keyPick,
    int depth,
    int seed, {
    required bool meaningful,
  }) {
    const baseKeys = [
      ['rejection_reason', 'rejection-reason', 'rejectionReason'],
      ['reason', 'REASON', 'Reason'],
      ['note_s', 'note-s', 'noteS'],
      ['feed_back', 'feed-back', 'feedBack'],
    ];
    final variants = baseKeys[keyPick % baseKeys.length];
    final value = meaningful ? 'because it was scheduled too early' : 'ok';
    expectedOutcome = meaningful;

    Map<String, dynamic> wrap(String key) {
      // Nest the explanatory entry under non-explanatory containers.
      var node = <String, dynamic>{key: value};
      for (var i = 0; i < depth % 3; i++) {
        node = (seed + i).isEven
            ? <String, dynamic>{'container$i': node}
            : <String, dynamic>{
                'list$i': <Object>[node, 'filler'],
              };
      }
      return node;
    }

    variantArgs = [for (final v in variants) wrap(v)];
  }

  late final List<Map<String, dynamic>> variantArgs;
  late final bool expectedOutcome;

  @override
  String toString() =>
      '_ExplanatoryArgsScenario(expected: $expectedOutcome, '
      'args: $variantArgs)';
}

extension _AnyFeedbackPureFunctionScenarios on glados.Any {
  glados.Generator<_SentimentScenario> get sentimentScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 1 << 16),
        _SentimentScenario.new,
      );

  glados.Generator<_ExplanatoryArgsScenario> get explanatoryArgsScenario =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 16),
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 1 << 16),
        glados.AnyUtils(this).choose([false, true]),
        (int keyPick, int depth, int seed, bool meaningful) =>
            _ExplanatoryArgsScenario(
              keyPick,
              depth,
              seed,
              meaningful: meaningful,
            ),
      );
}
