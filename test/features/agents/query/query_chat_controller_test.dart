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
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
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
  late Future<void> Function(String chatId) inspect;
  var malformed = false;
  var unavailable = false;
  final now = DateTime(2026, 9, 10, 12);

  setUpAll(registerAllFallbackValues);
  setUp(() {
    bench = QueryPersistenceBench()..add('task');
    inspect = (_) async {};
    malformed = false;
    unavailable = false;
    container = ProviderContainer(
      overrides: [
        queryChatStoreProvider.overrideWithValue(bench.store),
        queryChatDataProvider(key).overrideWith((ref) => const Stream.empty()),
        configFlagProvider(
          'private',
        ).overrideWith((ref) => Stream.value(false)),
        queryBuilderFactoryProvider.overrideWithValue((
          scope,
          agentId,
          chatId,
        ) async {
          if (unavailable) throw const QueryInferenceUnavailable();
          return QueryAnswerBuilder(
            crawler: bench.crawler,
            access: bench.crawler.access,
            inference: QueryTextInference(
              generate: (system, prompt) async* {
                final input = jsonDecode(prompt) as Map<String, dynamic>;
                if (system.contains('Rephrase')) {
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
    await bench.close();
  });

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
    'retry replaces a failed attempt without duplicating the question',
    () => withClock(Clock.fixed(now), () async {
      final id = await controller.create('Feeder');
      controller.updateDraft(id, 'Decision?');
      malformed = true;
      await controller.send(id);
      expect(container.read(provider).local(id).status, QueryTurnStatus.failed);
      final failed = (await bench.store.load('agent')).chats.single;
      malformed = false;
      await controller.send(id, retryQuestionId: failed.questions.single.id);
      final recovered = (await bench.store.load('agent')).chats.single;
      expect(recovered.questions.length, 1);
      expect(recovered.answerFor(recovered.questions.single.id), isNotNull);
      expect(container.read(provider).local(id).status, QueryTurnStatus.idle);
    }),
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
