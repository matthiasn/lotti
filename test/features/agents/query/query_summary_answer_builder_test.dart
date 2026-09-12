import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_summary_answer_builder.dart';
import 'package:lotti/features/agents/query/query_summary_reader.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../test_data/entity_factories.dart';
import 'query_test_utils.dart';

void main() {
  const scope = QueryScope(kind: QueryScopeKind.task, id: 'home');
  final category = categoryMindfulness.id;
  late QueryTestBench bench;
  late MockAgentRepository repository;
  late QuerySummaryReader reader;
  late Map<String, AgentReportEntity> reports;
  late List<Map<String, dynamic>> prompts;
  late Map<String, Object?> plan;
  late Map<String, Object?> response;
  late QueryCancellation cancellation;
  void Function()? onSelection;
  void Function()? onAnswer;

  setUp(() {
    bench = QueryTestBench();
    repository = MockAgentRepository();
    reports = {};
    for (final id in ['home', 'other']) {
      bench.entries[id] = testTask.copyWith(
        meta: testTask.meta.copyWith(
          id: id,
          categoryId: category,
          private: false,
        ),
        data: testTask.data.copyWith(title: 'Penguin $id'),
      );
      reports[id] = makeTestReport(
        id: 'report-$id',
        tldr: 'The $id TLDR records completed feeder calibration.',
        content: 'FULL $id: the lower-pressure setting prevents pellet jams.',
        oneLiner: 'ACTION LABEL $id',
      );
    }
    when(() => repository.getLatestTaskReportsForTaskIds(any())).thenAnswer(
      (call) async => {
        for (final id in call.positionalArguments.first as List<String>)
          id: ?reports[id],
      },
    );
    reader = QuerySummaryReader(
      journal: bench.db,
      access: bench.crawler.access,
      repository: repository,
    );
    prompts = [];
    plan = {
      'taskIds': ['other'],
      'useProject': false,
      'needsHomeEvidence': false,
    };
    response = {
      'answer': 'The Penguin other task summary records completed calibration.',
      'ownerIds': ['other'],
      'unresolved': false,
    };
    cancellation = QueryCancellation();
    onSelection = null;
    onAnswer = null;
  });

  Future<QueryChatAnswer?> build({
    QueryScope queryScope = scope,
    int maxBytes = 24000,
    void Function(String)? onText,
    void Function(QueryChatAnswer)? onReady,
  }) =>
      QuerySummaryAnswerBuilder(
        reader: reader,
        access: bench.crawler.access,
        maxInputBytes: maxBytes,
        inference: QueryTextInference(
          generate: (system, prompt) {
            prompts.add(jsonDecode(prompt) as Map<String, dynamic>);
            if (system.startsWith('Task-summary orientation.')) {
              onSelection?.call();
              return Stream.value(jsonEncode(plan));
            }
            onAnswer?.call();
            return Stream.value(jsonEncode(response));
          },
        ),
      ).build(
        scope: queryScope,
        questionId: 'question',
        question: 'What did the completed calibration establish?',
        conversation: const [],
        historyDependencies: const [],
        private: false,
        homeOnly: false,
        cancellation: cancellation,
        onAnswerText: onText,
        onSynthesisReady: onReady,
      );

  test('two calls use TLDRs then only the selected summary', () async {
    final result = await build();
    expect(prompts, hasLength(2));
    expect(prompts.first.keys.take(2), ['project', 'tasks']);
    expect(prompts.last.keys.first, 'summaries');
    expect(jsonEncode(prompts.first), contains('home TLDR'));
    expect(jsonEncode(prompts.first), contains('other TLDR'));
    expect(jsonEncode(prompts.first), isNot(contains('FULL')));
    expect(jsonEncode(prompts.first), isNot(contains('ACTION LABEL')));
    expect(jsonEncode(prompts.last), contains('other TLDR'));
    expect(jsonEncode(prompts.last), isNot(contains('home TLDR')));
    expect(jsonEncode(prompts.last), contains('FULL other'));
    expect(result!.evidence, isEmpty);
    expect(result.coverage.checked, 0);
    expect(result.coverage.incomplete, isFalse);
    expect(result.text, response['answer']);
    expect(bench.searches, isEmpty);
  });

  test(
    'full summaries are included only on request for selected IDs',
    () async {
      await build();
      expect(jsonEncode(prompts.first), isNot(contains('FULL')));
      expect(jsonEncode(prompts.last), contains('FULL other'));
      expect(jsonEncode(prompts.last), isNot(contains('FULL home')));
      expect(prompts, hasLength(2));
    },
  );

  test('home evidence routing is confined to the home task', () async {
    plan['needsHomeEvidence'] = true;
    // A different task's gaps cannot trigger a raw-entry fallback.
    final other = await build();
    expect(other, isNotNull);
    plan['taskIds'] = ['home'];
    prompts.clear();
    expect(await build(), isNull);
    expect(prompts, hasLength(1));
    prompts.clear();
    plan['taskIds'] = ['other'];
    final categoryAnswer = await build(
      queryScope: QueryScope(kind: QueryScopeKind.category, id: category),
    );
    expect(categoryAnswer, isNotNull);
    expect(bench.searches, isEmpty);
  });

  test('unknown selection IDs fail before synthesis', () async {
    plan['taskIds'] = ['foreign'];
    await expectLater(build(), throwsFormatException);
    expect(prompts, hasLength(1));
  });

  for (final invalid in ['citation', 'owner', 'title', 'shape']) {
    test('invalid summary attribution is rejected: $invalid', () async {
      switch (invalid) {
        case 'citation':
          response['answer'] = '${response['answer']} [1]';
        case 'owner':
          response['ownerIds'] = ['foreign'];
        case 'title':
          response['answer'] = 'Some summary says so.';
        case 'shape':
          response.remove('unresolved');
      }
      await expectLater(build(), throwsFormatException);
    });
  }

  test('unresolved questions produce incomplete coverage', () async {
    response['unresolved'] = true;
    response['answer'] =
        'The Penguin other summary leaves the exact wording open; '
        'its task agent would need to answer that.';
    final result = await build();
    expect(result!.coverage.incomplete, isTrue);
    expect(result.evidence, isEmpty);
  });

  test(
    'an unanswered question can have no attributed substantive claim',
    () async {
      response = {
        'answer':
            'The available summaries do not establish the requested wording.',
        'ownerIds': <String>[],
        'unresolved': true,
      };
      final answer = await build();
      expect(answer!.coverage.incomplete, isTrue);
      response['unresolved'] = false;
      await expectLater(build(), throwsFormatException);
    },
  );

  for (final atSelection in [true, false]) {
    test(
      'owner visibility is rechecked after inference: $atSelection',
      () async {
        void hideOwner() {
          final task = bench.entries['other']!;
          bench.entries['other'] = task.copyWith(
            meta: task.meta.copyWith(private: true),
          );
        }

        if (atSelection) {
          onSelection = hideOwner;
        } else {
          onAnswer = hideOwner;
        }
        await expectLater(build(), throwsA(isA<QueryScopeUnavailable>()));
        expect(prompts, hasLength(atSelection ? 1 : 2));
      },
    );
  }

  test('cancellation after selection prevents synthesis', () async {
    onSelection = cancellation.cancel;
    await expectLater(build(), throwsA(isA<QueryCancelled>()));
    expect(prompts, hasLength(1));
  });

  test('oversized input is rejected before inference', () async {
    await expectLater(build(maxBytes: 1), throwsFormatException);
    expect(prompts, isEmpty);
  });

  test(
    'oversized full report falls back to TLDR with incomplete coverage',
    () async {
      reports['other'] = reports['other']!.copyWith(
        content: List.filled(30000, 'x').join(),
      );
      final answer = await build();
      final supplied = (prompts.last['summaries'] as List).single as Map;
      expect(supplied.containsKey('content'), isFalse);
      expect(supplied['tldr'], contains('other TLDR'));
      expect(prompts.last['summaryCoverageIncomplete'], isTrue);
      expect(answer!.coverage.incomplete, isTrue);
    },
  );

  test('selection cannot request a TLDR omitted by the input budget', () async {
    reports['other'] = reports['other']!.copyWith(
      tldr: List.filled(30000, 'x').join(),
    );
    await expectLater(build(), throwsFormatException);
    expect(prompts, hasLength(1));
    expect(prompts.single['summaryCoverageIncomplete'], isTrue);
    expect(
      (prompts.single['tasks'] as List).map((s) => (s as Map)['taskId']),
      ['home'],
    );
  });

  test(
    'a missing home report uses the home evidence route without a call',
    () async {
      reports.clear();
      expect(await build(), isNull);
      expect(prompts, isEmpty);
    },
  );

  test('streaming uses the same answer text and owner dependencies', () async {
    final streamed = <String>[];
    QueryChatAnswer? draft;
    final result = await build(
      onText: streamed.add,
      onReady: (value) => draft = value,
    );
    expect(streamed.last, result!.text);
    expect(draft!.evidence, isEmpty);
    expect(
      draft!.dependencies.map((s) => s.id),
      containsAll(['home', 'other']),
    );
  });
}
