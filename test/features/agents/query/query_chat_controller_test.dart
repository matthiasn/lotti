import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_controller.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_summary_reader.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../test_data/entity_factories.dart';
import 'query_test_utils.dart';

void main() {
  const key = (
    agentId: 'agent',
    scope: QueryScope(kind: QueryScopeKind.task, id: 'task'),
  );
  final provider = queryChatControllerProvider(key);
  late QueryPersistenceBench bench;
  late ProviderContainer container;
  late QueryChatController controller;
  late StreamController<QueryChatData> history;
  late StreamController<bool> privacy;
  late StreamController<bool> enabled;
  late Future<void> Function(String chatId) inspect;
  late Future<void> Function(String chatId) compose;
  late MockDomainLogger logger;
  Exception? setupError;
  Stream<String>? synthesis;
  QuerySummaryReader? summaryReader;
  var recall = false;
  var malformed = false;
  var unavailable = false;
  final now = DateTime(2026, 9, 10, 12);

  setUpAll(registerAllFallbackValues);
  setUp(() {
    logger = MockDomainLogger();
    setupError = null;
    bench = QueryPersistenceBench()..add('task');
    inspect = (_) async {};
    compose = (_) async {};
    recall = false;
    malformed = false;
    synthesis = null;
    summaryReader = null;
    unavailable = false;
    history = StreamController<QueryChatData>.broadcast();
    privacy = StreamController<bool>.broadcast();
    enabled = StreamController<bool>.broadcast();
    container = ProviderContainer(
      overrides: [
        configFlagProvider('enable_query_chat').overrideWith((ref) async* {
          yield true;
          yield* enabled.stream;
        }),
        domainLoggerProvider.overrideWithValue(logger),
        queryChatStoreProvider.overrideWithValue(bench.store),
        queryChatDataProvider(key).overrideWith((ref) => history.stream),
        configFlagProvider(
          'private',
        ).overrideWith((ref) async* {
          yield false;
          yield* privacy.stream;
        }),
        queryBuilderFactoryProvider.overrideWithValue((
          scope,
          agentId,
          chatId,
        ) async {
          if (unavailable) throw const QueryInferenceUnavailable();
          if (setupError case final error?) throw error;
          return QueryAnswerBuilder(
            summaryReader: summaryReader,
            crawler: bench.crawler,
            access: bench.crawler.access,
            inference: QueryTextInference(
              generate: (system, prompt) async* {
                final input = jsonDecode(prompt) as Map<String, dynamic>;
                if (system.startsWith('Task-summary orientation.')) {
                  yield jsonEncode({
                    'taskIds': ['other'],
                    'useProject': false,
                    'needsHomeEvidence': false,
                  });
                  return;
                }
                if (system.contains('Inspect sources together')) {
                  await inspect(chatId);
                  final sources = (input['sources'] as List)
                      .cast<Map<String, dynamic>>();
                  yield jsonEncode({
                    'question': input['question'],
                    'terms': ['feeder'],
                    'sufficient': sources.isNotEmpty,
                    'searchCategory': false,
                    'memoryIds': <String>[
                      if (recall)
                        for (final memory in input['memories'] as List)
                          (memory as Map<String, dynamic>)['id'] as String,
                    ],
                    'passages': [
                      for (final source in sources)
                        {
                          'sourceId': source['id'],
                          'quote': source['text'],
                          'summary': 'Feeder decision',
                        },
                    ],
                  });
                } else if (system.contains('Rephrase')) {
                  yield jsonEncode({
                    'question': input['question'],
                    'terms': ['feeder'],
                  });
                } else if (system.contains('Extract passages')) {
                  await inspect(chatId);
                  yield jsonEncode({
                    'passages': [
                      {'quote': input['source'], 'summary': 'Feeder decision'},
                    ],
                  });
                } else if (system.contains('Select only')) {
                  yield '{"ids":[]}';
                } else {
                  await compose(chatId);
                  if (synthesis case final stream?) {
                    yield* stream;
                    return;
                  }
                  yield malformed
                      ? 'invalid'
                      : jsonEncode({
                          'answer': 'Answer for $chatId [1]',
                          'conclusion': 'Feeder decision.',
                        });
                }
              },
            ),
          );
        }),
      ],
    );
    controller = container.read(provider.notifier);
  });
  tearDown(() async {
    container.dispose();
    await history.close();
    await privacy.close();
    await enabled.close();
    await bench.close();
  });

  test(
    'disabling query chat cancels work without deleting saved history',
    () => withClock(Clock.fixed(now), () async {
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(configFlagProvider('enable_query_chat').future);
      final id = await controller.create('Feeder');
      final entered = Completer<void>();
      final release = Completer<void>();
      inspect = (_) async {
        entered.complete();
        await release.future;
      };
      controller.updateDraft(id, 'What was approved?');
      final running = controller.send(id);
      await entered.future;
      enabled.add(false);
      await container.pump();
      expect(
        container.read(provider).local(id).status,
        QueryTurnStatus.cancelled,
      );
      release.complete();
      await running;
      final saved = (await bench.store.load('agent')).chats.single;
      expect(
        saved.questions.single.data,
        isA<QueryChatQuestion>().having(
          (q) => q.text,
          'question',
          'What was approved?',
        ),
      );
      expect(saved.answerFor(saved.questions.single.id), isNull);
    }),
  );

  test('privacy change clears a published draft awaiting projection', () async {
    await withClock(Clock.fixed(now), () async {
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(configFlagProvider('private').future);
      final id = await controller.create('Feeder');
      controller.updateDraft(id, 'What was recorded?');
      await controller.send(id);
      final local = container.read(provider).local(id);
      expect(local.status, QueryTurnStatus.idle);
      expect(local.provisional?.text, 'Answer for $id [1]');
      final saved = await bench.store.load('agent');
      expect(saved.chats.single.answerFor(local.requestQuestionId!), isNotNull);

      privacy.add(true);
      await container.pump();
      expect(container.read(configFlagProvider('private')).value, isTrue);
      privacy.add(false);
      await container.pump();

      expect(container.read(provider).local(id).provisional, isNull);
      expect(container.read(provider).local(id).status, QueryTurnStatus.idle);
      expect(
        (await bench.store.load('agent')).chats.single.answerFor(
          local.requestQuestionId!,
        ),
        saved.chats.single.answerFor(local.requestQuestionId!),
      );
    });
  });

  for (final outcome in [
    'publish',
    'refresh',
    'invalid citation',
    'cancel',
    'privacy',
    'moved',
    'load failure',
    'deleted',
    'forgotten',
    'history error',
    'summary moved',
    'summary deleted',
  ]) {
    test(
      'provisional synthesis $outcome preserves the publication boundary',
      () async {
        await withClock(Clock.fixed(now), () async {
          final summaryOutcome = outcome.startsWith('summary ');
          if (summaryOutcome) {
            for (final id in ['task', 'other']) {
              bench.entries[id] = testTask.copyWith(
                meta: testTask.meta.copyWith(
                  id: id,
                  categoryId: categoryMindfulness.id,
                  private: false,
                ),
                data: testTask.data.copyWith(title: 'Penguin $id'),
              );
            }
            final reports = MockAgentRepository();
            when(
              () => reports.getLatestTaskReportsForTaskIds(any()),
            ).thenAnswer(
              (_) async => {
                for (final id in ['task', 'other'])
                  id: makeTestReport(
                    id: 'report-$id',
                    tldr: 'Calibration complete.',
                  ),
              },
            );
            summaryReader = QuerySummaryReader(
              journal: bench.db,
              access: bench.crawler.access,
              repository: reports,
            );
          }
          String? memoryChat;
          if (outcome == 'forgotten') {
            memoryChat = await controller.create('Earlier feeder discussion');
            controller.updateDraft(memoryChat, 'What did we record?');
            await controller.send(memoryChat);
            recall = true;
          }
          var stopped = false;
          final stream = StreamController<String>(
            onCancel: () => stopped = true,
          );
          synthesis = stream.stream;
          addTearDown(() {
            container.read(provider).chats.keys.forEach(controller.cancel);
            unawaited(stream.close());
          });
          final started = Completer<void>();
          compose = (_) async => started.complete();
          final chatId = await controller.create('Synthetic habitat');
          controller.updateDraft(chatId, 'What was recorded?');
          final seen = Completer<void>();
          final subscription = container.listen(provider, (_, next) {
            if (next.local(chatId).provisional?.text.isNotEmpty == true &&
                !seen.isCompleted) {
              seen.complete();
            }
          });
          final request = controller.send(chatId);
          await started.future;
          final text = summaryOutcome
              ? 'The Penguin other summary records calibration.'
              : outcome == 'invalid citation'
              ? 'Unsupported [999]'
              : 'Recorded [1]';
          stream.add('{"answer":"$text');
          await seen.future;
          final draft = container.read(provider).local(chatId).provisional!;
          expect(draft.text, text);
          final before = await bench.store.load('agent');
          expect(
            before.chats
                .firstWhere((c) => c.id == chatId)
                .answerFor(draft.questionId),
            isNull,
          );
          final initialAccess = await bench.crawler.access.load(['task']);
          if (summaryOutcome) {
            expect(draft.evidence, isEmpty);
            final owner = bench.entries['other']!;
            bench.entries['other'] = owner.copyWith(
              meta: outcome == 'summary moved'
                  ? owner.meta.copyWith(categoryId: null)
                  : owner.meta.copyWith(deletedAt: now),
            );
          }
          if (outcome == 'privacy' || outcome == 'moved') {
            final task = bench.entries['task']!;
            bench.entries['task'] = task.copyWith(
              meta: outcome == 'privacy'
                  ? task.meta.copyWith(private: true)
                  : task.meta.copyWith(categoryId: bench.categories.first.id),
            );
          }
          if (outcome == 'load failure') {
            when(
              bench.db.getAllCategories,
            ).thenThrow(StateError('Access unavailable'));
          }
          if (outcome == 'deleted') {
            await bench.store.delete('agent', chatId, forget: true);
          }
          if (outcome == 'forgotten') {
            expect(draft.recalledMemoryIds, isNotEmpty);
            await bench.store.delete('agent', memoryChat!, forget: true);
          }
          if (outcome == 'history error') {
            history.addError(StateError('History unavailable'));
            await container.pump();
          } else if ([
            'privacy',
            'moved',
            'load failure',
            'deleted',
            'forgotten',
            'refresh',
            'summary moved',
            'summary deleted',
          ].contains(outcome)) {
            history.add(
              QueryChatData(
                projection: ['deleted', 'forgotten'].contains(outcome)
                    ? await bench.store.load('agent')
                    : before,
                access: initialAccess,
              ),
            );
            await container.pump();
          }
          if (outcome == 'load failure') {
            when(
              bench.db.getAllCategories,
            ).thenAnswer((_) async => bench.categories);
          }
          if (outcome == 'cancel') controller.cancel(chatId);
          if (['publish', 'refresh', 'invalid citation'].contains(outcome)) {
            stream.add('","conclusion":""}');
            await stream.close();
          } else {
            expect(container.read(provider).local(chatId).provisional, isNull);
          }
          await request;
          final after = await bench.store.load('agent');
          final local = container.read(provider).local(chatId);
          final savedChat = after.chats
              .where((c) => c.id == chatId)
              .firstOrNull;
          if (outcome == 'publish' || outcome == 'refresh') {
            expect(
              (savedChat!.answerFor(draft.questionId)!.data as QueryChatAnswer)
                  .text,
              draft.text,
            );
            expect(local.draftRetracted, isFalse);
            history.add(
              QueryChatData(projection: after, access: initialAccess),
            );
            await container.pump();
            expect(container.read(provider).local(chatId).provisional, isNull);
          } else {
            expect(local.provisional, isNull);
            expect(savedChat?.answerFor(draft.questionId), isNull);
            expect(local.draftRetracted, outcome == 'invalid citation');
            if (outcome == 'deleted') {
              expect(
                container.read(provider).chats.containsKey(chatId),
                isFalse,
              );
              expect(savedChat, isNull);
            } else {
              expect(local.requestQuestionId, draft.questionId);
            }
            expect(stopped, isTrue);
          }
          subscription.close();
          await stream.close();
        });
      },
    );
  }

  test(
    'searching changes to answering only at synthesis and resets on retry',
    () async {
      final inspecting = Completer<void>();
      final inspected = Completer<void>();
      final composing = Completer<void>();
      final composed = Completer<void>();
      inspect = (_) async {
        inspecting.complete();
        await inspected.future;
      };
      compose = (_) async {
        composing.complete();
        await composed.future;
      };
      final id = await controller.create('Feeder');
      controller.updateDraft(id, 'Which decision?');
      malformed = true;
      final pending = controller.send(id);
      await inspecting.future;
      expect(container.read(provider).local(id).answering, isFalse);
      expect(
        container.read(provider).local(id).status,
        QueryTurnStatus.running,
      );
      inspected.complete();
      await composing.future;
      expect(container.read(provider).local(id).answering, isTrue);
      expect(
        container.read(provider).local(id).status,
        QueryTurnStatus.running,
      );
      composed.complete();
      await pending;
      expect(container.read(provider).local(id).status, QueryTurnStatus.failed);
      final question = (await bench.store.load(
        'agent',
      )).chats.single.questions.single;
      malformed = false;
      inspect = (_) async {
        expect(container.read(provider).local(id).answering, isFalse);
      };
      compose = (_) async {
        expect(container.read(provider).local(id).answering, isTrue);
      };
      await controller.send(id, retryQuestionId: question.id);
      expect(container.read(provider).local(id).status, QueryTurnStatus.idle);
    },
  );

  for (final error in [
    const FormatException('Private source text must not reach logs'),
    const MeliousInferenceException('Secret response body', statusCode: 401),
  ]) {
    test(
      'setup failure logs safe diagnostics for ${error.runtimeType}',
      () async {
        final id = await controller.create('Feeder');
        controller.updateDraft(id, 'Private question text');
        setupError = error;
        await controller.send(id);
        expect(
          container.read(provider).local(id).status,
          QueryTurnStatus.failed,
        );
        expect(
          container.read(provider).local(id).draft,
          'Private question text',
        );
        expect(
          (await bench.store.load('agent')).chats.single.questions,
          isEmpty,
        );
        final status = error is MeliousInferenceException
            ? ' (httpStatus=401)'
            : '';
        verify(
          () => logger.error(
            LogDomain.chat,
            error.runtimeType.toString(),
            errorType: error.runtimeType,
            message: 'Query failed during setup$status',
            subDomain: 'query.send',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
        verifyNoMoreInteractions(logger);
      },
    );
  }

  test(
    'concurrent replies and drafts stay with their originating chat',
    () => withClock(Clock.fixed(now), () async {
      final first = await controller.create('Feeder');
      final second = await controller.create('Roll call');
      final entered = Completer<void>();
      final release = Completer<void>();
      inspect = (chatId) async {
        if (chatId == first) {
          entered.complete();
          await release.future;
        }
      };
      controller
        ..select(first)
        ..updateDraft(first, 'First question?');
      final running = controller.send(first);
      await entered.future;
      controller
        ..select(second)
        ..updateDraft(second, 'Second question?');
      await controller.send(second);
      controller.updateDraft(second, 'Unsent follow-up');
      final intermediate = await bench.store.load('agent');
      expect(
        intermediate.chats
            .singleWhere((c) => c.id == first)
            .events
            .where((e) => e.data is QueryChatAnswer),
        isEmpty,
      );
      expect(
        intermediate.chats
            .singleWhere((c) => c.id == second)
            .events
            .where((e) => e.data is QueryChatAnswer)
            .length,
        1,
      );
      release.complete();
      await running;
      final finalProjection = await bench.store.load('agent');
      for (final chat in finalProjection.chats) {
        expect(
          (chat.answerFor(chat.questions.single.id)!.data as QueryChatAnswer)
              .text,
          'Answer for ${chat.id} [1]',
        );
      }
      expect(container.read(provider).selectedId, second);
      expect(container.read(provider).local(second).draft, 'Unsent follow-up');
      expect(
        container.read(provider).local(first).status,
        QueryTurnStatus.idle,
      );
    }),
  );

  test(
    'delete during inference cannot resurrect a chat or its memory',
    () => withClock(Clock.fixed(now), () async {
      final id = await controller.create('Feeder');
      final entered = Completer<void>();
      final release = Completer<void>();
      inspect = (_) async {
        entered.complete();
        await release.future;
      };
      controller.updateDraft(id, 'Decision?');
      final running = controller.send(id);
      await entered.future;
      await controller.delete(id, forget: true);
      release.complete();
      await running;
      final data = await bench.store.load('agent');
      expect(data.chats, isEmpty);
      expect(data.memories, isEmpty);
      expect(container.read(provider).chats.containsKey(id), isFalse);
    }),
  );

  test(
    'explicit cancellation persists a retryable turn without publishing an answer',
    () => withClock(Clock.fixed(now), () async {
      final id = await controller.create('Feeder');
      final entered = Completer<void>();
      final release = Completer<void>();
      inspect = (_) async {
        entered.complete();
        await release.future;
      };
      controller.updateDraft(id, 'Decision?');
      final running = controller.send(id);
      await entered.future;
      controller.cancel(id);
      expect(
        container.read(provider).local(id).status,
        QueryTurnStatus.cancelled,
      );
      controller.updateDraft(id, 'Follow-up after cancellation');
      await controller.send(id);
      expect(
        (await bench.store.load('agent')).chats.single.questions.length,
        1,
      );
      release.complete();
      await running;
      final projection = await bench.store.load('agent');
      final chat = projection.chats.single;
      expect(
        chat.events.last.data,
        QueryChatEventData.cancelled(questionId: chat.questions.single.id),
      );
      expect(chat.answerFor(chat.questions.single.id), isNull);
      expect(projection.memories, isEmpty);
      expect(
        container.read(provider).local(id).draft,
        'Follow-up after cancellation',
      );
      expect(
        container.read(provider).local(id).status,
        QueryTurnStatus.cancelled,
      );
      inspect = (_) async {};
      compose = (_) async {};
      await controller.send(id, retryQuestionId: chat.questions.single.id);
      final retried = (await bench.store.load('agent')).chats.single;
      expect(retried.questions.length, 1);
      expect(retried.answerFor(chat.questions.single.id), isNotNull);
      expect(container.read(provider).local(id).status, QueryTurnStatus.idle);
    }),
  );

  test(
    'synced deletion cancels inference and removes the selected chat draft',
    () => withClock(Clock.fixed(now), () async {
      final id = await controller.create('Feeder');
      final entered = Completer<void>();
      final release = Completer<void>();
      inspect = (_) async {
        entered.complete();
        await release.future;
      };
      controller.updateDraft(id, 'Decision?');
      final running = controller.send(id);
      await entered.future;
      final access = await bench.crawler.access.load(['task']);
      history.add(
        QueryChatData(
          projection: await bench.store.load('agent'),
          access: access,
        ),
      );
      await container.read(queryChatDataProvider(key).future);
      controller.updateDraft(id, 'Unsent private follow-up');
      await bench.store.delete('agent', id, forget: true);
      final removed = Completer<void>();
      final subscription = container.listen(provider, (_, next) {
        if (next.selectedId == null && !removed.isCompleted) removed.complete();
      });
      addTearDown(subscription.close);
      history.add(
        QueryChatData(
          projection: await bench.store.load('agent'),
          access: access,
        ),
      );
      await removed.future;
      expect(container.read(provider).chats.containsKey(id), isFalse);
      release.complete();
      await running;
      expect(container.read(provider).selectedId, isNull);
      expect(container.read(provider).chats.containsKey(id), isFalse);
      expect((await bench.store.load('agent')).memories, isEmpty);
    }),
  );

  test(
    'disposing the controller cancels an active request without publishing',
    () => withClock(Clock.fixed(now), () async {
      final id = await controller.create('Feeder');
      final entered = Completer<void>();
      final release = Completer<void>();
      inspect = (_) async {
        entered.complete();
        await release.future;
      };
      controller.updateDraft(id, 'Decision?');
      final running = controller.send(id);
      await entered.future;
      container.invalidate(provider);
      release.complete();
      await running;
      final projection = await bench.store.load('agent');
      final chat = projection.chats.single;
      expect(chat.answerFor(chat.questions.single.id), isNull);
      expect(
        chat.events.last.data,
        QueryChatEventData.cancelled(questionId: chat.questions.single.id),
      );
      expect(projection.memories, isEmpty);
      expect(container.read(provider).chats, isEmpty);
    }),
  );

  test(
    'private drafts and stale retries cannot append a question or rerun inference',
    () => withClock(Clock.fixed(now), () async {
      final id = await controller.create('Feeder');
      controller.updateDraft(id, 'Private decision?', private: true);
      await controller.send(id);
      expect((await bench.store.load('agent')).chats.single.questions, isEmpty);
      expect(container.read(provider).local(id).draft, 'Private decision?');
      controller.updateDraft(id, 'Public decision?', private: false);
      await controller.send(id);
      final answered = (await bench.store.load('agent')).chats.single;
      inspect = (_) =>
          throw StateError('A stale retry must not inspect sources');
      for (final questionId in [
        answered.questions.single.id,
        'unknown-question',
      ]) {
        await controller.send(id, retryQuestionId: questionId);
        expect(container.read(provider).local(id).status, QueryTurnStatus.idle);
        expect(
          (await bench.store.load('agent')).chats.single.events,
          answered.events,
        );
      }
    }),
  );

  test(
    'retry replaces a failed attempt without duplicating the question',
    () => withClock(Clock.fixed(now), () async {
      final id = await controller.create('Feeder');
      controller.updateDraft(id, 'Decision?');
      malformed = true;
      await controller.send(id);
      expect(container.read(provider).local(id).status, QueryTurnStatus.failed);
      final failed = (await bench.store.load('agent')).chats.single;
      expect(
        container.read(provider).local(id).requestQuestionId,
        failed.questions.single.id,
      );
      malformed = false;
      await controller.send(id, retryQuestionId: failed.questions.single.id);
      final recovered = (await bench.store.load('agent')).chats.single;
      expect(recovered.questions.length, 1);
      expect(recovered.answerFor(recovered.questions.single.id), isNotNull);
      expect(container.read(provider).local(id).status, QueryTurnStatus.idle);
    }),
  );

  test(
    'a new pre-save failure clears the previous request question id',
    () async {
      final id = await controller.create('Feeder');
      controller.updateDraft(id, 'First question');
      await controller.send(id);
      final first = (await bench.store.load(
        'agent',
      )).chats.single.questions.single;
      expect(container.read(provider).local(id).requestQuestionId, first.id);
      controller.updateDraft(id, 'Second question');
      setupError = const FormatException('setup failed');
      await controller.send(id);
      expect(container.read(provider).local(id).status, QueryTurnStatus.failed);
      expect(container.read(provider).local(id).requestQuestionId, isNull);
      expect(container.read(provider).local(id).draft, 'Second question');
      expect(
        (await bench.store.load('agent')).chats.single.questions,
        hasLength(1),
      );
    },
  );

  test(
    'missing inference keeps the editable draft and does not persist a turn',
    () => withClock(Clock.fixed(now), () async {
      final id = await controller.create('Feeder');
      controller.updateDraft(id, 'Decision?');
      unavailable = true;
      await controller.send(id);
      expect(
        container.read(provider).local(id).status,
        QueryTurnStatus.unavailable,
      );
      expect(container.read(provider).local(id).draft, 'Decision?');
      expect((await bench.store.load('agent')).chats.single.questions, isEmpty);
      verifyNoMoreInteractions(logger);
    }),
  );

  test(
    'creation retains private authoring provenance across its asynchronous visibility read',
    () => withClock(Clock.fixed(now), () async {
      final privateContainer = ProviderContainer(
        overrides: [
          queryChatStoreProvider.overrideWithValue(bench.store),
          configFlagProvider(
            'private',
          ).overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(privateContainer.dispose);
      final privacySubscription = privateContainer.listen(
        configFlagProvider('private'),
        (_, _) {},
      );
      addTearDown(privacySubscription.close);
      final privateController = privateContainer.read(provider.notifier);
      await privateContainer.read(configFlagProvider('private').future);
      bench.showPrivate = true;
      final entered = Completer<void>();
      final release = Completer<void>();
      when(bench.db.getAllCategories).thenAnswer((_) async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        return bench.categories;
      });
      final creating = privateController.create('Private feeder decision');
      await entered.future;
      bench.showPrivate = false;
      final failed = expectLater(
        creating,
        throwsA(isA<QueryScopeUnavailable>()),
      );
      release.complete();
      await failed;
      expect((await bench.store.load('agent')).chats, isEmpty);
    }),
  );
}
