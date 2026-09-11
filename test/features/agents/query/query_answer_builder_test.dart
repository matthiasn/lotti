import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';

import '../../../test_data/test_data.dart';
import 'query_test_utils.dart';

void main() {
  final date = DateTime(2026, 9, 10);
  final question = AgentQueryChatEventEntity(
    id: 'question',
    agentId: 'agent',
    chatId: 'chat',
    data: const QueryChatEventData.question(text: 'What was decided?'),
    createdAt: date,
    vectorClock: null,
  );
  final chat = QueryChatHistory(
    id: 'chat',
    scope: const QueryScope(kind: QueryScopeKind.task, id: 'task'),
    title: 'Feeder',
    private: false,
    archived: false,
    lastActivity: date,
    events: [question],
    unread: false,
  );

  test(
    'only verified passages enter the answer context and shared learning',
    () async {
      final bench = QueryTestBench()
        ..add('task')
        ..add('irrelevant')
        ..link('task', 'irrelevant');
      Map<String, dynamic>? answerInput;
      final inference = QueryTextInference(
        generate: (system, prompt) {
          final input = jsonDecode(prompt) as Map<String, dynamic>;
          final Map<String, Object?> result;
          if (system.contains('Rephrase')) {
            result = {
              'question': 'Feeder decision?',
              'terms': ['feeder'],
            };
          } else if (system.contains('Extract passages')) {
            result = {
              'passages': input['source'].toString().contains('irrelevant')
                  ? []
                  : [
                      {
                        'quote': 'Feeder decision in task.',
                        'summary': 'A feeder decision.',
                        'reason': 'Task note.',
                      },
                    ],
            };
          } else {
            answerInput = input;
            result = {
              'answer': 'The task records the feeder decision [1].',
              'conclusion': 'The task records the feeder decision.',
            };
          }
          return Stream.value(jsonEncode(result));
        },
      );
      final result =
          await QueryAnswerBuilder(
            crawler: bench.crawler,
            access: bench.crawler.access,
            inference: inference,
          ).build(
            chat: chat,
            question: question,
            memories: [],
            cancellation: QueryCancellation(),
            onProgress: (_, {required expanded}) {},
          );
      expect(result.answer.evidence.single.quote, 'Feeder decision in task.');
      expect(result.answer.dependencies.map((s) => s.id), ['task']);
      expect(jsonEncode(answerInput), isNot(contains('irrelevant')));
      expect(result.answer.coverage.checked, 2);
      expect(result.memory?.text, 'The task records the feeder decision.');
      expect(result.memory?.dependencies, result.answer.dependencies);
    },
  );

  test(
    'fabricated quotations are rejected and coverage is marked incomplete',
    () async {
      final bench = QueryTestBench()..add('task');
      final inference = QueryTextInference(
        generate: (system, _) => Stream.value(
          jsonEncode(
            system.contains('Rephrase')
                ? {'question': 'Feeder?', 'terms': <String>[]}
                : system.contains('Extract passages')
                ? {
                    'passages': [
                      {'quote': 'This never appeared in the note.'},
                    ],
                  }
                : {
                    'answer': 'No verified passage was found.',
                    'conclusion': '',
                  },
          ),
        ),
      );
      final result =
          await QueryAnswerBuilder(
            crawler: bench.crawler,
            access: bench.crawler.access,
            inference: inference,
          ).build(
            chat: chat,
            question: question,
            memories: [],
            cancellation: QueryCancellation(),
            onProgress: (_, {required expanded}) {},
          );
      expect(result.answer.evidence, isEmpty);
      expect(result.answer.coverage.incomplete, isTrue);
      expect(result.memory, isNull);
    },
  );

  test(
    'a source made private during inference prevents the answer from being published',
    () async {
      final bench = QueryTestBench()..add('task');
      var answerCalls = 0;
      final inference = QueryTextInference(
        generate: (system, _) {
          if (system.contains('Rephrase')) {
            return Stream.value('{"question":"Feeder?", "terms":[]}');
          }
          if (system.contains('Extract passages')) {
            bench.add('task', private: true);
            return Stream.value(
              '{"passages":[{"quote":"Feeder decision in task."}]}',
            );
          }
          answerCalls++;
          return Stream.value(
            '{"answer":"Should not be shown", "conclusion":""}',
          );
        },
      );
      await expectLater(
        QueryAnswerBuilder(
          crawler: bench.crawler,
          access: bench.crawler.access,
          inference: inference,
        ).build(
          chat: chat,
          question: question,
          memories: [],
          cancellation: QueryCancellation(),
          onProgress: (_, {required expanded}) {},
        ),
        throwsA(isA<QueryScopeUnavailable>()),
      );
      expect(answerCalls, 0);
    },
  );

  test(
    'long-source evidence retains bounded context and deduplicates overlap',
    () async {
      final bench = QueryTestBench()..add('task');
      const quotes = [
        'First feeder decision.',
        'Second feeder decision.',
        'Third feeder decision.',
      ];
      final text =
          '${'a' * 2000}${quotes[0]}${'b' * 8900}${quotes[1]}${'c' * 13000}${quotes[2]}${'d' * 6000}';
      bench.entries['task'] = bench.entries['task']!.copyWith(
        entryText: EntryText(plainText: text),
      );
      final inference = QueryTextInference(
        generate: (system, prompt) {
          final input = jsonDecode(prompt) as Map<String, dynamic>;
          return Stream.value(
            jsonEncode(
              system.contains('Rephrase')
                  ? {'question': 'Feeder?', 'terms': <String>[]}
                  : system.contains('Extract passages')
                  ? {
                      'passages': [
                        for (final quote in quotes)
                          if ((input['source'] as String).contains(quote))
                            {'quote': quote},
                      ],
                    }
                  : {
                      'answer': 'Three feeder decisions [1] [2] [3].',
                      'conclusion': '',
                    },
            ),
          );
        },
      );
      final result =
          await QueryAnswerBuilder(
            crawler: bench.crawler,
            access: bench.crawler.access,
            inference: inference,
          ).build(
            chat: chat,
            question: question,
            memories: [],
            cancellation: QueryCancellation(),
            onProgress: (_, {required expanded}) {},
          );
      expect(result.answer.evidence.map((e) => e.quote), quotes);
      for (final evidence in result.answer.evidence) {
        expect(evidence.sourceText.length, lessThanOrEqualTo(12000));
        expect(evidence.label.length, lessThanOrEqualTo(120));
        expect(text, contains(evidence.sourceText));
        expect(evidence.hasValidPassage, isTrue);
      }
    },
  );

  test(
    'recall selects only relevant visible same-category conclusions and inherits their sources',
    () async {
      final category = categoryMindfulness.id;
      final bench = QueryTestBench()
        ..add('task', category: category)
        ..add('history', category: category)
        ..add('remembered', category: category)
        ..add('private', category: category, private: true)
        ..add('elsewhere', category: 'another-category');
      QuerySourceRef source(String id) => QuerySourceRef(
        id: id,
        private: false,
        categoryPrivate: false,
        categoryId: category,
      );
      final memories = [
        for (var i = 0; i < 45; i++)
          question.copyWith(
            id: 'memory-$i',
            chatId: 'previous-chat',
            data: QueryChatEventData.memory(
              questionId: 'past',
              text: 'Feeder conclusion $i',
              dependencies: [source('remembered')],
            ),
          ),
        for (final id in ['private', 'elsewhere'])
          question.copyWith(
            id: id,
            chatId: 'previous-chat',
            data: QueryChatEventData.memory(
              questionId: 'past',
              text: 'Must not enter recall',
              dependencies: [source(id)],
            ),
          ),
      ];
      final history = QueryChatHistory(
        id: chat.id,
        scope: chat.scope,
        title: chat.title,
        private: false,
        archived: false,
        lastActivity: date,
        unread: false,
        events: [
          question.copyWith(id: 'previous-question'),
          question.copyWith(
            id: 'previous-answer',
            data: QueryChatEventData.answer(
              questionId: 'previous-question',
              text: 'Earlier feeder discussion',
              coverage: const QueryCoverage(),
              dependencies: [source('history')],
            ),
          ),
          question,
        ],
      );
      final prompts = <String, Map<String, dynamic>>{};
      final inference = QueryTextInference(
        generate: (system, prompt) {
          final input = jsonDecode(prompt) as Map<String, dynamic>;
          if (system.contains('Rephrase')) {
            prompts['plan'] = input;
            return Stream.value('{"terms":[]}');
          }
          if (system.contains('Extract passages')) {
            return Stream.value('{"passages":[]}');
          }
          if (system.contains('Select only')) {
            prompts['selection'] = input;
            return Stream.value(
              '{"ids":["memory-44","private","elsewhere","fabricated"]}',
            );
          }
          prompts['answer'] = input;
          return Stream.value(
            '{"answer":"The remembered conclusion applies, without newly verified evidence.","conclusion":""}',
          );
        },
      );
      final result =
          await QueryAnswerBuilder(
            crawler: bench.crawler,
            access: bench.crawler.access,
            inference: inference,
          ).build(
            chat: history,
            question: question,
            memories: memories,
            cancellation: QueryCancellation(),
            onProgress: (_, {required expanded}) {},
          );
      expect(
        (prompts['plan']!['conversation'] as List).map(
          (Object? message) => (message! as Map<String, dynamic>)['text'],
        ),
        ['What was decided?', 'Earlier feeder discussion', 'What was decided?'],
      );
      final selected = (prompts['selection']!['memories'] as List)
          .cast<Map<String, dynamic>>();
      expect(selected, hasLength(40));
      expect(selected.first['id'], 'memory-44');
      expect(selected.last['id'], 'memory-5');
      expect(prompts['answer']!['memories'], [
        {'id': 'memory-44', 'text': 'Feeder conclusion 44'},
      ]);
      expect(result.answer.recalledMemoryIds, ['memory-44']);
      expect(result.answer.dependencies.map((s) => s.id).toSet(), {
        'task',
        'history',
        'remembered',
      });
      expect(result.memory, isNull);
    },
  );

  for (final malformed in [
    'not JSON',
    '{"passages":true}',
    '{"passages":[7,{"quote":9},{"quote":""}]}',
  ]) {
    test(
      'malformed inspection stays out of final context: $malformed',
      () async {
        final bench = QueryTestBench()..add('task');
        final inference = QueryTextInference(
          generate: (system, _) => Stream.value(
            system.contains('Rephrase')
                ? '{}'
                : system.contains('Extract passages')
                ? malformed
                : '{"answer":"No verified evidence.","conclusion":""}',
          ),
        );
        final result =
            await QueryAnswerBuilder(
              crawler: bench.crawler,
              access: bench.crawler.access,
              inference: inference,
            ).build(
              chat: chat,
              question: question,
              memories: [],
              cancellation: QueryCancellation(),
              onProgress: (_, {required expanded}) {},
            );
        expect(result.answer.evidence, isEmpty);
        expect(result.answer.coverage.incomplete, isTrue);
        expect(result.memory, isNull);
      },
    );
  }
}
