import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_summary_reader.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../test_data/entity_factories.dart';
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
    'wired summary reader bypasses raw retrieval and durable conclusions',
    () async {
      final bench = QueryTestBench();
      bench.entries['task'] = testTask.copyWith(
        meta: testTask.meta.copyWith(
          id: 'task',
          categoryId: categoryMindfulness.id,
          private: false,
        ),
        data: testTask.data.copyWith(title: 'Penguin feeder'),
      );
      final reports = MockAgentRepository();
      when(() => reports.getLatestTaskReportsForTaskIds(any())).thenAnswer(
        (_) async => {
          'task': makeTestReport(
            tldr: 'Calibration is complete.',
            content: 'Calibration established the lower-pressure setting.',
          ),
        },
      );
      final calls = <Map<String, dynamic>>[];
      final result =
          await QueryAnswerBuilder(
            crawler: bench.crawler,
            access: bench.crawler.access,
            summaryReader: QuerySummaryReader(
              journal: bench.db,
              access: bench.crawler.access,
              repository: reports,
            ),
            inference: QueryTextInference(
              generate: (system, prompt) {
                calls.add(jsonDecode(prompt) as Map<String, dynamic>);
                return Stream.value(
                  jsonEncode(
                    system.startsWith('Task-summary orientation.')
                        ? {
                            'taskIds': ['task'],
                            'useProject': false,
                            'needsHomeEvidence': false,
                          }
                        : {
                            'answer':
                                'The Penguin feeder summary records the lower-pressure setting.',
                            'ownerIds': ['task'],
                            'unresolved': false,
                            'conclusion': 'This must not enter shared memory.',
                          },
                  ),
                );
              },
            ),
          ).build(
            chat: chat,
            question: question,
            memories: const [],
            cancellation: QueryCancellation(),
            onProgress: (_, {required expanded}) {},
          );
      expect(calls, hasLength(2));
      expect(calls.first.containsKey('tasks'), isTrue);
      expect(calls.last.containsKey('summaries'), isTrue);
      expect(result.answer.text, contains('Penguin feeder summary'));
      expect(result.answer.evidence, isEmpty);
      expect(result.answer.coverage.checked, 0);
      expect(result.memory, isNull);
      expect(bench.searches, isEmpty);
      expect(bench.categoryReads, 1);
    },
  );

  for (final questionPresent in [true, false]) {
    test(
      'old-question retry excludes later turns and memories (present=$questionPresent)',
      () async {
        final bench = QueryTestBench()..add('task');
        final earlier = question.copyWith(
          id: 'earlier',
          createdAt: date.subtract(const Duration(minutes: 1)),
          data: const QueryChatEventData.question(
            text: 'Earlier feeder context',
          ),
        );
        final later = question.copyWith(
          id: 'later',
          createdAt: date.add(const Duration(minutes: 1)),
          data: const QueryChatEventData.question(
            text: 'Future unrelated topic',
          ),
        );
        final laterMemory = later.copyWith(
          id: 'later-memory',
          data: const QueryChatEventData.memory(
            questionId: 'later',
            text: 'Future unrelated conclusion',
          ),
        );
        final retryChat = QueryChatHistory(
          id: chat.id,
          scope: chat.scope,
          title: chat.title,
          private: false,
          archived: false,
          lastActivity: later.createdAt,
          events: [earlier, if (questionPresent) question, later, laterMemory],
          unread: false,
        );
        final prompts = <Map<String, dynamic>>[];
        final result =
            await QueryAnswerBuilder(
              maxBatchBytes: 1,
              crawler: bench.crawler,
              access: bench.crawler.access,
              inference: QueryTextInference(
                generate: (system, prompt) {
                  final input = jsonDecode(prompt) as Map<String, dynamic>;
                  prompts.add(input);
                  return Stream.value(
                    jsonEncode(
                      system.contains('Rephrase')
                          ? {
                              'question': 'What was decided?',
                              'terms': <String>[],
                            }
                          : system.contains('Extract passages')
                          ? {
                              'passages': [
                                {'quote': input['source']},
                              ],
                            }
                          : {
                              'answer': 'The original feeder decision [1].',
                              'conclusion': 'The original feeder decision.',
                            },
                    ),
                  );
                },
              ),
            ).build(
              chat: retryChat,
              question: question,
              memories: [laterMemory],
              cancellation: QueryCancellation(),
              onProgress: (_, {required expanded}) {},
            );
        expect(prompts.first['conversation'], [
          if (questionPresent)
            {'role': 'user', 'text': 'Earlier feeder context'},
          {'role': 'user', 'text': 'What was decided?'},
        ]);
        expect(jsonEncode(prompts), isNot(contains('Future unrelated')));
        expect(prompts, hasLength(3));
        expect(result.answer.recalledMemoryIds, isEmpty);
        expect(result.memory?.text, 'The original feeder decision.');
        expect(result.answer.evidence.single.quote, 'Feeder decision in task.');
      },
    );
  }

  group('fitting home inspection', () {
    late QueryTestBench bench;
    late List<String> stages;
    late List<Map<String, dynamic>> batchInputs;
    late List<String> batchPrompts;
    late List<int> batchSizes;
    late List<(int, bool)> progress;
    late QueryCancellation cancellation;
    var wanted = 'source-1';
    var memories = <AgentQueryChatEventEntity>[];
    var memoryIds = <String>[];
    var forceCategory = false;
    Map<String, Object?>? invalidBatch;
    void Function()? duringBatch;
    Map<String, dynamic>? answerInput;

    setUp(() {
      bench = QueryTestBench()..add('task', category: categoryMindfulness.id);
      for (var i = 1; i < 12; i++) {
        bench
          ..add('source-$i', category: categoryMindfulness.id)
          ..link('task', 'source-$i');
      }
      bench.add('wider', category: categoryMindfulness.id);
      stages = [];
      batchInputs = [];
      batchPrompts = [];
      batchSizes = [];
      progress = [];
      cancellation = QueryCancellation();
      wanted = 'source-1';
      memories = [];
      memoryIds = [];
      forceCategory = false;
      invalidBatch = null;
      duringBatch = null;
      answerInput = null;
    });

    Future<QueryBuiltAnswer> build({
      bool homeOnly = false,
      int sourceCalls = 90,
      int maxBytes = QueryAnswerBuilder.defaultBatchInputBytes,
      AgentQueryChatEventEntity? askedQuestion,
    }) =>
        QueryAnswerBuilder(
          crawler: bench.crawler,
          access: bench.crawler.access,
          maxSourceCalls: sourceCalls,
          maxBatchBytes: maxBytes,
          inference: QueryTextInference(
            generate: (system, prompt) {
              final input = jsonDecode(prompt) as Map<String, dynamic>;
              Map<String, Object?> result;
              if (system.contains('Inspect sources together')) {
                stages.add('batch');
                batchInputs.add(input);
                batchPrompts.add(prompt);
                batchSizes.add(
                  utf8.encode(system).length + utf8.encode(prompt).length,
                );
                duringBatch?.call();
                final sources = (input['sources'] as List)
                    .cast<Map<String, dynamic>>();
                final selected = sources
                    .where((source) => source['id'] == wanted)
                    .firstOrNull;
                result =
                    invalidBatch ??
                    {
                      'question': 'What was decided?',
                      'terms': ['feeder'],
                      'sufficient': selected != null,
                      'searchCategory': forceCategory,
                      'memoryIds': memoryIds,
                      'passages': [
                        if (selected != null)
                          {
                            'sourceId': wanted,
                            'quote': selected['text'],
                            'summary': 'Recorded decision',
                            'reason': 'Answers the question',
                          },
                      ],
                    };
              } else if (system.contains('Rephrase')) {
                stages.add('plan');
                result = {
                  'question': 'What was decided?',
                  'terms': ['feeder'],
                };
              } else if (system.contains('Shortlist sources')) {
                stages.add('shortlist');
                result = {
                  'ids': [wanted],
                };
              } else if (system.contains('Extract passages')) {
                stages.add('extract');
                result = {
                  'passages': [
                    {'quote': input['source']},
                  ],
                };
              } else {
                stages.add('answer');
                answerInput = input;
                result = {
                  'answer': (input['evidence'] as List).isEmpty
                      ? 'Not established.'
                      : 'The feeder decision is recorded [1].',
                  'conclusion': '',
                };
              }
              return Stream.value(jsonEncode(result));
            },
          ),
        ).build(
          chat: chat,
          question: askedQuestion ?? question,
          memories: memories,
          cancellation: cancellation,
          homeOnly: homeOnly,
          onProgress: (checked, {required expanded}) =>
              progress.add((checked, expanded)),
        );

    test(
      'twelve short home sources need two calls and no category search',
      () async {
        final result = await build();
        expect(stages, ['batch', 'answer']);
        expect(bench.categoryReads, 0);
        expect(bench.searches, isEmpty);
        expect(batchInputs.single['sources'] as List, hasLength(12));
        expect(result.answer.coverage.checked, 12);
        expect(result.answer.coverage.homeChecked, 12);
        expect(result.answer.coverage.categoryChecked, 0);
        expect(progress.last.$1, 12);
        for (var i = 1; i < progress.length; i++) {
          expect(progress[i].$1, greaterThanOrEqualTo(progress[i - 1].$1));
        }
        expect(result.answer.coverage.expanded, isFalse);
        expect(result.answer.coverage.incomplete, isFalse);
        expect(result.answer.evidence.single.source.id, wanted);
        expect(
          result.answer.evidence.single.quote,
          'Feeder decision in source-1.',
        );
        expect(
          jsonEncode(answerInput),
          isNot(contains('Feeder decision in source-2.')),
        );
      },
    );

    test(
      'unchanged sources form the same prefix ahead of a new question',
      () async {
        await build();
        final first = batchPrompts.single;
        expect(first, startsWith('{"sources":'));
        final prefix = first.substring(0, first.indexOf(',"question":'));
        expect(prefix, contains('Feeder decision in source-11.'));
        expect(prefix, contains('Feeder decision in task.'));
        final reversed = bench.links.reversed.toList();
        bench.links
          ..clear()
          ..addAll(reversed);
        await build(
          askedQuestion: question.copyWith(
            id: 'follow-up',
            data: const QueryChatQuestion(text: 'What happened next?'),
          ),
        );
        expect(batchPrompts.last, startsWith(prefix));
        expect(batchInputs.last['question'], 'What happened next?');
        expect(batchPrompts.last, isNot(first));
      },
    );

    test('home batch budget includes the clock sent to the provider', () async {
      await build(homeOnly: true);
      final budget = batchSizes.single - 1;
      stages.clear();
      await build(homeOnly: true, maxBytes: budget);
      expect(stages, isNot(contains('batch')));
      expect(stages, contains('extract'));
      expect(batchSizes, hasLength(1));
    });

    test('one inspection budget still counts every batched source', () async {
      final result = await build(sourceCalls: 1);
      expect(stages, ['batch', 'answer']);
      expect(result.answer.coverage.checked, 12);
      expect(result.answer.evidence.single.source.id, wanted);
    });

    test(
      'discarding passages at the per-source cap marks coverage incomplete',
      () async {
        invalidBatch = {
          'question': 'What was decided?',
          'terms': ['feeder'],
          'sufficient': true,
          'searchCategory': false,
          'memoryIds': <String>[],
          'passages': [
            for (final quote in [
              'Feeder',
              'decision',
              'source-1',
              'Feeder decision',
            ])
              {'sourceId': wanted, 'quote': quote},
          ],
        };
        final result = await build();
        expect(result.answer.evidence, hasLength(3));
        expect(result.answer.coverage.incomplete, isTrue);
        expect(result.answer.coverage.checked, 12);
      },
    );

    test(
      'insufficient home evidence expands once without inspecting home again',
      () async {
        wanted = 'wider';
        final result = await build();
        expect(stages, ['batch', 'batch', 'answer']);
        expect(
          (batchInputs.last['sources'] as List).map(
            (source) => (source as Map)['id'],
          ),
          ['wider'],
        );
        expect(result.answer.evidence.single.outsideHome, isTrue);
        expect(result.answer.coverage.checked, 13);
        expect(result.answer.coverage.homeChecked, 12);
        expect(result.answer.coverage.categoryChecked, 1);
        expect(result.answer.coverage.expanded, isTrue);
      },
    );

    test(
      'an explicit category request expands even with sufficient home evidence',
      () async {
        forceCategory = true;
        await build();
        expect(stages, ['batch', 'batch', 'answer']);
        expect(
          ((batchInputs.last['sources'] as List).single as Map)['id'],
          'wider',
        );
      },
    );

    for (final hasWider in [true, false]) {
      test(
        'expansion reinspects a new representation (wider=$hasWider)',
        () async {
          forceCategory = true;
          if (!hasWider) bench.entries.remove('wider');
          duringBatch = () {
            if (batchInputs.length != 1) return;
            final entry = bench.entries[wanted]!;
            bench.entries[wanted] = entry.copyWith(
              meta: entry.meta.copyWith(updatedAt: DateTime(2026, 9, 12)),
            );
          };
          final result = await build();
          if (!hasWider) {
            expect(progress.every((event) => !event.$2), isTrue);
          }
          expect(stages, ['batch', 'batch', 'answer']);
          expect(
            (batchInputs.last['sources'] as List).map(
              (source) => (source as Map)['id'],
            ),
            contains(wanted),
          );
          expect(
            result.answer.evidence.single.textVersionDate,
            DateTime(2026, 9, 12),
          );
          expect(
            result.answer.evidence.single.quote,
            'Feeder decision in source-1.',
          );
        },
      );
    }

    test('home-only does not expand an insufficient answer', () async {
      wanted = 'wider';
      final result = await build(homeOnly: true);
      expect(stages, ['batch', 'answer']);
      expect(bench.categoryReads, 0);
      expect(result.answer.evidence, isEmpty);
    });

    for (final invalid in [
      'foreign source',
      'nonverbatim quote',
      'missing sufficiency',
      'unknown memory',
      'malformed passage',
    ]) {
      test('rejects a batch with $invalid before synthesis', () async {
        invalidBatch = {
          'question': 'What was decided?',
          'terms': ['feeder'],
          'sufficient': true,
          'searchCategory': false,
          'memoryIds': <String>[],
          'passages': [
            {
              'sourceId': invalid == 'foreign source'
                  ? 'not-supplied'
                  : 'source-1',
              'quote': invalid == 'nonverbatim quote'
                  ? 'Invented decision'
                  : 'Feeder decision in source-1.',
            },
          ],
        };
        switch (invalid) {
          case 'missing sufficiency':
            invalidBatch!.remove('sufficient');
          case 'unknown memory':
            invalidBatch!['memoryIds'] = ['not-supplied'];
          case 'malformed passage':
            invalidBatch!['passages'] = ['not a passage object'];
        }
        await expectLater(build(), throwsFormatException);
        expect(stages, ['batch']);
        expect(answerInput, isNull);
      });
    }

    test('privacy changing during a batch prevents the answer', () async {
      duringBatch = () {
        final entry = bench.entries[wanted]!;
        bench.entries[wanted] = entry.copyWith(
          meta: entry.meta.copyWith(private: true),
        );
      };
      await expectLater(build(), throwsA(isA<QueryScopeUnavailable>()));
      expect(stages, ['batch']);
    });

    test('oversized home text retains bounded exact-source windows', () async {
      final entry = bench.entries[wanted]!;
      bench.entries[wanted] = entry.copyWith(
        entryText: EntryText(
          plainText: '${'x' * 13000} The final feeder decision.',
        ),
      );
      final result = await build();
      expect(stages, ['plan', 'shortlist', 'extract', 'extract', 'answer']);
      expect(result.answer.evidence, hasLength(2));
      expect(
        result.answer.evidence.every((e) => e.sourceText.length <= 12000),
        isTrue,
      );
      expect(
        result.answer.evidence.last.quote,
        endsWith('The final feeder decision.'),
      );
      expect(result.answer.coverage.incomplete, isTrue);
    });

    AgentQueryChatEventEntity memory(String id, String text) =>
        AgentQueryChatEventEntity(
          id: id,
          agentId: 'agent',
          chatId: 'earlier-chat',
          createdAt: date.subtract(const Duration(days: 1)),
          vectorClock: null,
          data: QueryChatMemory(
            questionId: 'earlier-question',
            text: text,
            dependencies: [
              QuerySourceRef(
                id: 'memory-source',
                categoryId: categoryMindfulness.id,
                private: false,
                categoryPrivate: false,
              ),
            ],
          ),
        );

    test(
      'memory selection shares inspection and forwards only the selected conclusion',
      () async {
        bench.add('memory-source', category: categoryMindfulness.id);
        memories = [
          memory('relevant', 'Previously recorded feeder context.'),
          memory('irrelevant', 'Unrelated earlier conversation.'),
        ];
        memoryIds = ['relevant'];
        final result = await build();
        expect(stages, ['batch', 'answer']);
        expect(batchInputs.single['memories'] as List, hasLength(2));
        expect(result.answer.recalledMemoryIds, ['relevant']);
        expect(
          jsonEncode(answerInput),
          contains('Previously recorded feeder context.'),
        );
        expect(
          jsonEncode(answerInput),
          isNot(contains('Unrelated earlier conversation.')),
        );
      },
    );

    test(
      'a recalled source moving category during inspection aborts the answer',
      () async {
        bench
          ..add('memory-source', category: categoryMindfulness.id)
          ..categories.add(categoryMindfulness.copyWith(id: 'other-category'));
        memories = [memory('relevant', 'Previously recorded feeder context.')];
        memoryIds = ['relevant'];
        duringBatch = () {
          final entry = bench.entries['memory-source']!;
          bench.entries['memory-source'] = entry.copyWith(
            meta: entry.meta.copyWith(categoryId: 'other-category'),
          );
        };
        await expectLater(build(), throwsA(isA<QueryScopeUnavailable>()));
        expect(stages, ['batch']);
      },
    );

    test(
      'discovery without remaining inspection budget does not claim category coverage',
      () async {
        wanted = 'wider';
        final result = await build(sourceCalls: 1);
        expect(stages, ['batch', 'answer']);
        expect(result.answer.coverage.checked, 12);
        expect(result.answer.coverage.expanded, isFalse);
        expect(result.answer.coverage.incomplete, isTrue);
        expect(result.answer.evidence, isEmpty);
      },
    );

    test('cancelling a batch prevents synthesis', () async {
      duringBatch = cancellation.cancel;
      await expectLater(build(), throwsA(isA<QueryCancelled>()));
      expect(stages, ['batch']);
    });
  });

  // A one-byte input budget exercises the bounded oversized-input fallback.
  group('oversized-corpus source shortlisting', () {
    late QueryTestBench bench;
    late List<String> calls;
    late Map<String, dynamic> shortlistInput;
    Map<String, dynamic>? answerInput;
    Object? selected;
    void Function()? duringShortlist;
    late QueryCancellation cancellation;
    late List<(int, bool)> progress;

    setUp(() {
      bench = QueryTestBench()..add('task');
      for (var i = 1; i < 42; i++) {
        bench
          ..add('source-$i')
          ..link('task', 'source-$i');
      }
      calls = [];
      progress = [];
      selected = ['source-41'];
      duringShortlist = null;
      answerInput = null;
      cancellation = QueryCancellation();
    });

    Future<QueryBuiltAnswer> build() =>
        QueryAnswerBuilder(
          maxBatchBytes: 1,
          crawler: bench.crawler,
          access: bench.crawler.access,
          inference: QueryTextInference(
            generate: (system, prompt) {
              final input = jsonDecode(prompt) as Map<String, dynamic>;
              if (system.contains('Rephrase')) {
                calls.add('plan');
                return Stream.value(
                  jsonEncode({
                    'question': 'Feeder?',
                    'terms': ['feeder'],
                  }),
                );
              }
              if (system.contains('Shortlist sources')) {
                calls.add('shortlist');
                shortlistInput = input;
                duringShortlist?.call();
                return Stream.value(jsonEncode({'ids': selected}));
              }
              if (system.contains('Extract passages')) {
                calls.add('extract');
                return Stream.value(
                  jsonEncode({
                    'passages': [
                      {'quote': input['source']},
                    ],
                  }),
                );
              }
              calls.add('answer');
              answerInput = input;
              return Stream.value(
                jsonEncode({
                  'answer': 'Here is what the sources establish.',
                  'conclusion': '',
                }),
              );
            },
          ),
        ).build(
          chat: chat,
          question: question,
          memories: [],
          cancellation: cancellation,
          onProgress: (checked, {required expanded}) =>
              progress.add((checked, expanded)),
        );

    test(
      '42 sources share one shortlist and only matches reach exact inspection',
      () async {
        final result = await build();
        expect(calls, ['plan', 'shortlist', 'extract', 'answer']);
        final sources = shortlistInput['sources'] as List;
        expect(sources, hasLength(42));
        expect(
          (sources.last as Map)['preview'],
          'Feeder decision in source-41.',
        );
        expect((sources.last as Map)['truncated'], isFalse);
        expect(result.answer.evidence.single.source.id, 'source-41');
        expect(
          result.answer.evidence.single.quote,
          'Feeder decision in source-41.',
        );
        expect(result.answer.coverage.checked, 1);
        expect(result.answer.coverage.homeChecked, 1);
        expect(result.answer.coverage.categoryChecked, 0);
        expect(result.answer.coverage.expanded, isFalse);
        expect(result.answer.coverage.incomplete, isTrue);
        expect(jsonEncode(answerInput), isNot(contains('source-40')));
      },
    );

    test(
      'current scope progress changes before wider and home inspections',
      () async {
        final category = categoryMindfulness.id;
        bench.entries.updateAll(
          (_, entry) =>
              entry.copyWith(meta: entry.meta.copyWith(categoryId: category)),
        );
        bench.add('wider', category: category);
        selected = ['wider', 'source-1'];
        final result = await build();
        expect(progress, [
          (0, true),
          (1, true),
          (1, false),
          (2, false),
          (2, false),
        ]);
        expect(result.answer.coverage.homeChecked, 1);
        expect(result.answer.coverage.categoryChecked, 1);
        expect(result.answer.coverage.expanded, isTrue);
      },
    );

    for (final moveCategory in [false, true]) {
      test(
        'unreadable source change before answering fails closed (move=$moveCategory)',
        () async {
          bench.entries['recording'] = testAudioEntry.copyWith(
            meta: testAudioEntry.meta.copyWith(
              id: 'recording',
              categoryId: null,
            ),
            entryText: null,
            data: testAudioEntry.data.copyWith(transcripts: []),
          );
          bench.link('task', 'recording');
          duringShortlist = () {
            final entry = bench.entries['recording']!;
            bench.entries['recording'] = entry.copyWith(
              meta: entry.meta.copyWith(
                private: !moveCategory,
                categoryId: moveCategory ? categoryMindfulness.id : null,
              ),
            );
          };
          await expectLater(build(), throwsA(isA<QueryScopeUnavailable>()));
          expect(calls, isNot(contains('answer')));
        },
      );
    }

    test(
      'unreadable source references remain privacy dependencies of the answer',
      () async {
        bench.entries['recording'] = testAudioEntry.copyWith(
          meta: testAudioEntry.meta.copyWith(id: 'recording', categoryId: null),
          entryText: null,
          data: testAudioEntry.data.copyWith(transcripts: []),
        );
        bench.link('task', 'recording');
        final result = await build();
        expect(result.answer.coverage.unreadableSources.single.id, 'recording');
        expect(
          result.answer.dependencies.map((source) => source.id),
          contains('recording'),
        );
        expect(
          result.answer.evidence.single.textVersionDate,
          bench.entries['source-41']!.meta.updatedAt,
        );
      },
    );

    test(
      'long previews retain the opening plus a term hit or ending',
      () async {
        bench.entries['source-1'] = bench.entries['source-1']!.copyWith(
          entryText: EntryText(
            plainText: '${'a' * 900} feeder decision ${'b' * 900}',
          ),
        );
        bench.entries['source-2'] = bench.entries['source-2']!.copyWith(
          entryText: EntryText(plainText: '${'x' * 1700} Closing discussion'),
        );
        await build();
        final sources = shortlistInput['sources'] as List;
        final hit = sources.cast<Map<String, dynamic>>().singleWhere(
          (s) => s['id'] == 'source-1',
        );
        final tail = sources.cast<Map<String, dynamic>>().singleWhere(
          (s) => s['id'] == 'source-2',
        );
        expect(
          hit['preview'],
          allOf(startsWith('a' * 400), contains('feeder decision')),
        );
        expect(tail['preview'], endsWith('Closing discussion'));
        expect((hit['preview'] as String).length, lessThan(810));
        expect(hit['truncated'], isTrue);
        expect(tail['truncated'], isTrue);
      },
    );

    test(
      'ranking is retained and inspection is bounded to eight sources',
      () async {
        selected = [for (var i = 41; i > 0; i--) 'source-$i'];
        final result = await build();
        expect(calls.where((c) => c == 'extract'), hasLength(8));
        expect(result.answer.evidence.map((e) => e.source.id), [
          for (var i = 41; i > 33; i--) 'source-$i',
        ]);
        expect(result.answer.coverage.incomplete, isTrue);
      },
    );

    test('no shortlisted matches does not claim exhaustive coverage', () async {
      selected = <String>[];
      final result = await build();
      expect(calls, ['plan', 'shortlist', 'answer']);
      expect(result.answer.evidence, isEmpty);
      expect(result.answer.coverage.checked, 0);
      expect(result.answer.coverage.incomplete, isTrue);
    });

    for (final invalid in [
      null,
      'source-1',
      [7],
      ['not-in-scope'],
    ]) {
      test('rejects malformed or foreign source selection $invalid', () async {
        selected = invalid;
        await expectLater(build(), throwsFormatException);
        expect(calls, ['plan', 'shortlist']);
      });
    }

    for (final change in ['private', 'deleted', 'moved']) {
      test(
        'rechecks $change sources before sending the batched preview',
        () async {
          when(() => bench.db.getProjectIdMapForTasks(any())).thenAnswer((
            _,
          ) async {
            final entry = bench.entries['source-41']!;
            bench.entries['source-41'] = entry.copyWith(
              meta: switch (change) {
                'private' => entry.meta.copyWith(private: true),
                'deleted' => entry.meta.copyWith(deletedAt: date),
                _ => entry.meta.copyWith(categoryId: categoryMindfulness.id),
              },
            );
            return {};
          });
          await expectLater(build(), throwsA(isA<QueryScopeUnavailable>()));
          expect(calls, ['plan']);
        },
      );
    }

    test(
      'a source hidden during shortlisting cannot be inspected or quoted',
      () async {
        duringShortlist = () {
          final entry = bench.entries['source-41']!;
          bench.entries['source-41'] = entry.copyWith(
            meta: entry.meta.copyWith(private: true),
          );
        };
        await expectLater(build(), throwsA(isA<QueryScopeUnavailable>()));
        expect(calls, ['plan', 'shortlist']);
        expect(answerInput, isNull);
      },
    );

    test('cancelling the overview prevents full-text inspection', () async {
      duringShortlist = cancellation.cancel;
      await expectLater(build(), throwsA(isA<QueryCancelled>()));
      expect(calls, ['plan', 'shortlist']);
    });
  });

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
            maxBatchBytes: 1,
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
            maxBatchBytes: 1,
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
          maxBatchBytes: 1,
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
            maxBatchBytes: 1,
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
            maxBatchBytes: 1,
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
              maxBatchBytes: 1,
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
