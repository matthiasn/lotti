import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../../projects/test_utils.dart';
import '../test_data/ai_config_factories.dart';
import '../test_data/entity_factories.dart';
import '../test_data/template_factories.dart';
import 'query_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  test(
    'chat action state streams local writes without wake notifications',
    () async {
      final bench = QueryPersistenceBench();
      addTearDown(bench.close);
      final container = ProviderContainer(
        overrides: [agentDatabaseProvider.overrideWithValue(bench.agentDb)],
      );
      addTearDown(container.dispose);
      final provider = queryActionChangeSetProvider((
        agentId: 'agent',
        questionId: 'q',
      ));
      final values = <ChangeSetEntity?>[];
      final subscription = container.listen(provider, (_, value) {
        if (value.hasValue) values.add(value.value);
      });
      addTearDown(subscription.close);
      expect(await container.read(provider.future), isNull);
      final set = ChangeSetEntity(
        id: 'query-chat:q:actions',
        agentId: 'agent',
        taskId: 'task',
        threadId: 'chat',
        runKey: 'query-chat:q',
        status: ChangeSetStatus.pending,
        items: const [
          ChangeItem(
            toolName: 'add_checklist_item',
            args: {'title': 'Feeder'},
            humanSummary: 'Feeder',
          ),
        ],
        createdAt: DateTime(2026, 9, 13),
        vectorClock: null,
      );
      final changed = Completer<void>();
      final changeSubscription = container.listen(provider, (_, value) {
        if (value.value?.items.single.status == ChangeItemStatus.confirmed &&
            !changed.isCompleted) {
          changed.complete();
        }
      });
      addTearDown(changeSubscription.close);
      await bench.store.sync.upsertEntity(set);
      await bench.store.sync.upsertEntity(
        set.copyWith(
          status: ChangeSetStatus.resolved,
          items: [
            set.items.single.copyWith(status: ChangeItemStatus.confirmed),
          ],
        ),
      );
      await changed.future;
      expect(values.last!.items.single.status, ChangeItemStatus.confirmed);
      final wrongAgent = queryActionChangeSetProvider((
        agentId: 'foreign',
        questionId: 'q',
      ));
      final other = container.listen(wrongAgent, (_, _) {});
      addTearDown(other.close);
      expect(await container.read(wrongAgent.future), isNull);
    },
  );

  for (final destroyed in [false, true]) {
    test(
      'project scope reuses its current identity and excludes destroyed=$destroyed agents',
      () async {
        final bench = QueryTestBench();
        final project = makeTestProject(
          id: 'project',
          categoryId: categoryMindfulness.id,
        );
        bench.entries['project'] = project;
        final identity = makeTestIdentity(
          lifecycle: destroyed
              ? AgentLifecycle.destroyed
              : AgentLifecycle.active,
        );
        final container = ProviderContainer(
          overrides: [
            querySourceAccessProvider.overrideWithValue(bench.crawler.access),
            projectAgentProvider(
              'project',
            ).overrideWith((ref) async => identity),
          ],
        );
        addTearDown(container.dispose);
        final target = await container.read(
          queryChatTargetProvider(
            const QueryScope(kind: QueryScopeKind.project, id: 'project'),
          ).future,
        );
        expect(target.label, project.data.title);
        expect(target.agent, destroyed ? isNull : same(identity));
        expect(target.categoryId, categoryMindfulness.id);
      },
    );
  }

  test(
    'a category provisions its query-only identity with the live profile',
    () async {
      final bench = QueryTestBench();
      final category = bench.categories.single.copyWith(
        defaultProfileId: 'category-profile',
      );
      bench.categories[0] = category;
      final id = '${AgentKinds.categoryAgent}:${category.id}';
      final service = MockAgentService();
      final identity = makeTestIdentity(
        id: id,
        agentId: id,
        kind: AgentKinds.categoryAgent,
      );
      when(() => service.getAgent(id)).thenAnswer((_) async => null);
      when(
        () => service.createAgent(
          kind: AgentKinds.categoryAgent,
          displayName: category.name,
          agentId: id,
          allowedCategoryIds: {category.id},
          config: const AgentConfig(profileId: 'category-profile'),
        ),
      ).thenAnswer((_) async => identity);
      final container = ProviderContainer(
        overrides: [
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          agentServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final target = await container.read(
        queryChatTargetProvider(
          QueryScope(kind: QueryScopeKind.category, id: category.id),
        ).future,
      );
      expect(target.agent, same(identity));
      verify(
        () => service.createAgent(
          kind: AgentKinds.categoryAgent,
          displayName: category.name,
          agentId: id,
          allowedCategoryIds: {category.id},
          config: const AgentConfig(profileId: 'category-profile'),
        ),
      ).called(1);
    },
  );

  group('runtime wiring', () {
    setUp(() async {
      await setUpTestGetIt();
    });
    tearDown(tearDownTestGetIt);
    test('unavailable chat slot uses the setup recovery path', () async {
      final bench = QueryPersistenceBench()
        ..add('task', category: categoryMindfulness.id);
      addTearDown(bench.close);
      final cloud = MockCloudInferenceRepository();
      const scope = QueryScope(kind: QueryScopeKind.task, id: 'task');
      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(bench.db),
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          agentRepositoryProvider.overrideWithValue(bench.repository),
          cloudInferenceRepositoryProvider.overrideWithValue(cloud),
          queryProfileProvider((agentId: 'agent', scope: scope)).overrideWith(
            (ref) async => ResolvedProfile(
              thinkingModelId: 'thinking',
              thinkingProvider: testInferenceProvider(),
              chatModelUnavailable: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(queryBuilderFactoryProvider)(scope, 'agent', 'chat'),
        throwsA(isA<QueryInferenceUnavailable>()),
      );
      verifyZeroInteractions(cloud);
    });

    for (final kind in QueryScopeKind.values) {
      test(
        '$kind keeps profile loading alive across frames for a query',
        () async {
          final bench = QueryPersistenceBench()
            ..add('task', category: categoryMindfulness.id);
          addTearDown(bench.close);
          final fts = Fts5Db(inMemoryDatabase: true);
          getIt.registerSingleton<Fts5Db>(fts);
          addTearDown(fts.close);
          final provider = testInferenceProvider();
          final profile = ResolvedProfile(
            thinkingModelId: 'query-model',
            thinkingProvider: provider,
          );
          final cloud = MockCloudInferenceRepository();
          when(
            () => cloud.generate(
              any(),
              model: 'query-model',
              temperature: 0.2,
              baseUrl: provider.baseUrl,
              apiKey: provider.apiKey,
              provider: provider,
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              geminiThinkingMode: any(named: 'geminiThinkingMode'),
              impactCollector: any(named: 'impactCollector'),
            ),
          ).thenAnswer(
            (invocation) {
              expect(
                invocation.namedArguments[#systemMessage],
                allOf(startsWith('inspect'), contains('device clock')),
              );
              final input =
                  jsonDecode(invocation.positionalArguments.single as String)
                      as Map<String, dynamic>;
              expect(input['source'], 'Only the feeder note');
              expect(input['currentTime'], isA<Map<String, dynamic>>());
              expect(input.keys, unorderedEquals(['source', 'currentTime']));
              return Stream.value(
                const CreateChatCompletionStreamResponse(
                  id: 'response',
                  object: 'chat.completion.chunk',
                  created: 0,
                  choices: [
                    ChatCompletionStreamResponseChoice(
                      index: 0,
                      delta: ChatCompletionStreamResponseDelta(
                        content: '{"passages":[]}',
                      ),
                    ),
                  ],
                ),
              );
            },
          );
          bench.categories[0] = bench.categories.single.copyWith(
            defaultProfileId: 'category-profile',
          );
          final started = Completer<void>();
          final lookup = Completer<void>();
          final identity = makeTestIdentity();
          final template = makeTestTemplate();
          final version = makeTestTemplateVersion(agentId: template.id);
          final resolver = MockProfileResolver();
          when(
            () => resolver.resolveByProfileId('category-profile'),
          ).thenAnswer((_) async => profile);
          when(
            () => resolver.resolveDetailed(
              agentConfig: identity.config,
              template: template,
              version: version,
            ),
          ).thenAnswer(
            (_) async => ResolvedAgentSetup(
              status: AgentSetupResolutionStatus.resolved,
              profile: profile,
            ),
          );
          // The factory checks access once before reading the category profile.
          // Hold that profile's own database lookup across the disposal frame.
          var categoryReads = 0;
          when(bench.db.getAllCategories).thenAnswer((_) async {
            if (kind == QueryScopeKind.category && ++categoryReads == 2) {
              started.complete();
              await lookup.future;
            }
            return bench.categories;
          });
          final container = ProviderContainer(
            overrides: [
              journalDbProvider.overrideWithValue(bench.db),
              agentSyncServiceProvider.overrideWithValue(bench.store.sync),
              agentRepositoryProvider.overrideWithValue(bench.repository),
              cloudInferenceRepositoryProvider.overrideWithValue(cloud),
              profileResolverProvider.overrideWithValue(resolver),
              agentIdentityProvider('agent').overrideWith((ref) async {
                started.complete();
                await lookup.future;
                return identity;
              }),
              templateForAgentProvider('agent').overrideWith(
                (ref) async => template,
              ),
              activeTemplateVersionProvider(template.id).overrideWith(
                (ref) async => version,
              ),
            ],
          );
          addTearDown(container.dispose);
          final scope = QueryScope(
            kind: kind,
            id: kind == QueryScopeKind.category
                ? categoryMindfulness.id
                : 'task',
          );
          final pending = container.read(queryBuilderFactoryProvider)(
            scope,
            'agent',
            'chat',
          );
          final completion = expectLater(pending, completes);
          await started.future;
          // Database reads take real frames in the app. An immediate mock
          // resolution conceals disposal of a profile read without a listener.
          await container.pump();
          lookup.complete();
          await completion;
          final builder = await pending;
          expect(builder.summaryReader?.repository, same(bench.repository));
          await container.pump();
          expect(
            container.exists(
              queryProfileProvider((agentId: 'agent', scope: scope)),
            ),
            isFalse,
            reason: 'Completed profile reads must not retain unused providers',
          );
          final corpus = await builder.crawler.discover(scope, ['feeder']);
          expect(corpus.documents.map((d) => d.entry.meta.id), ['task']);
          expect(
            await builder.inference.complete(
              system: 'inspect',
              input: {'source': 'Only the feeder note'},
              cancellation: QueryCancellation(),
            ),
            {'passages': <Object>[]},
          );
          final id = await container
              .read(queryChatStoreProvider)
              .create('agent', scope, 'Feeder');
          expect((await bench.store.load('agent')).chats.single.id, id);
          if (kind == QueryScopeKind.category) {
            verify(
              () => resolver.resolveByProfileId('category-profile'),
            ).called(1);
          } else {
            verifyNever(() => resolver.resolveByProfileId(any()));
          }
        },
      );
    }
  });
  for (final unavailable in [false, true]) {
    test(
      'profile loading releases its lifetime after unavailable=$unavailable',
      () async {
        final started = Completer<void>();
        final resolved = Completer<ResolvedAgentSetup?>();
        final container = ProviderContainer(
          overrides: [
            agentResolvedSetupProvider('agent').overrideWith((ref) {
              started.complete();
              return resolved.future;
            }),
          ],
        );
        addTearDown(container.dispose);
        final provider = queryProfileProvider((
          agentId: 'agent',
          scope: const QueryScope(kind: QueryScopeKind.project, id: 'project'),
        ));
        final error = StateError('Setup lookup failed');
        final pending = container.read(provider.future);
        final expectation = expectLater(
          pending,
          unavailable ? completion(isNull) : throwsA(same(error)),
        );
        await started.future;
        await container.pump();
        if (unavailable) {
          resolved.complete();
        } else {
          resolved.completeError(error);
        }
        await expectation;
        await container.pump();
        expect(container.exists(provider), isFalse);
      },
    );
  }
  test(
    'task query resolves the existing summary agent and live scope',
    () async {
      final bench = QueryTestBench();
      final task = testTask.copyWith(
        meta: testTask.meta.copyWith(categoryId: categoryMindfulness.id),
      );
      bench.entries[task.meta.id] = task;
      final identity = makeTestIdentity();
      final container = ProviderContainer(
        overrides: [
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          taskAgentProvider(task.meta.id).overrideWith((ref) async => identity),
        ],
      );
      addTearDown(container.dispose);
      final target = await container.read(
        queryChatTargetProvider(
          QueryScope(kind: QueryScopeKind.task, id: task.meta.id),
        ).future,
      );
      expect(target.agent, same(identity));
      expect(target.label, task.data.title);
      expect(target.categoryId, categoryMindfulness.id);
    },
  );

  test(
    'category query reuses its deterministic identity without creating another agent',
    () async {
      final bench = QueryTestBench();
      final id = '${AgentKinds.categoryAgent}:${categoryMindfulness.id}';
      final identity = makeTestIdentity(
        id: id,
        agentId: id,
        kind: AgentKinds.categoryAgent,
      );
      final service = MockAgentService();
      when(() => service.getAgent(id)).thenAnswer((_) async => identity);
      final container = ProviderContainer(
        overrides: [
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          agentServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final target = await container.read(
        queryChatTargetProvider(
          QueryScope(kind: QueryScopeKind.category, id: categoryMindfulness.id),
        ).future,
      );
      expect(target.agent?.id, id);
      expect(target.label, categoryMindfulness.name);
      verify(() => service.getAgent(id)).called(1);
      verifyNoMoreInteractions(service);
    },
  );

  test(
    'hidden home is rejected before resolving or provisioning an identity',
    () async {
      final bench = QueryTestBench()..add('task', private: true);
      final container = ProviderContainer(
        overrides: [
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        queryChatTargetProvider(
          const QueryScope(kind: QueryScopeKind.task, id: 'task'),
        ),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await expectLater(
        container.read(
          queryChatTargetProvider(
            const QueryScope(kind: QueryScopeKind.task, id: 'task'),
          ).future,
        ),
        throwsA(isA<QueryScopeUnavailable>()),
      );
    },
  );

  test(
    'history observes synced events and live journal visibility changes',
    () => withClock(Clock.fixed(DateTime(2026, 9, 11)), () async {
      final bench = QueryPersistenceBench()..add('home');
      final journal = JournalDb(inMemoryDatabase: true, background: false);
      addTearDown(bench.close);
      addTearDown(journal.close);
      const scope = QueryScope(kind: QueryScopeKind.task, id: 'home');
      const key = (agentId: 'agent', scope: scope);
      final id = await bench.store.create('agent', scope, 'Feeder');
      final container = ProviderContainer(
        overrides: [
          queryChatStoreProvider.overrideWithValue(bench.store),
          agentDatabaseProvider.overrideWithValue(bench.agentDb),
          journalDbProvider.overrideWithValue(journal),
        ],
      );
      addTearDown(container.dispose);
      final provider = queryChatDataProvider(key);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      expect(initial.projection.chats.single.title, 'Feeder');
      Future<QueryChatData> nextWhere(bool Function(QueryChatData) predicate) {
        final result = Completer<QueryChatData>();
        final sub = container.listen(provider, (_, next) {
          if (!result.isCompleted &&
              next.value != null &&
              predicate(next.value!)) {
            result.complete(next.value);
          }
        });
        return result.future.whenComplete(sub.close);
      }

      final questionArrives = nextWhere(
        (value) => value.projection.chats.single.questions.isNotEmpty,
      );
      await bench.store.ask('agent', id, 'Which feeder?');
      final withQuestion = await questionArrives;
      final question = withQuestion.projection.chats.single.questions.single;
      expect(withQuestion.access.allowsEvent(question.data), isTrue);
      final privateArrives = nextWhere(
        (value) => value.access.entries['home']!.meta.private == true,
      );
      bench.add('home', private: true);
      journal.notifyUpdates({TableUpdate(journal.journal.actualTableName)});
      final withPrivate = await privateArrives;
      expect(withPrivate.access.allowsEvent(question.data), isFalse);
      final failure = Completer<Object>();
      final errorSubscription = container.listen(provider, (_, next) {
        if (next.hasError && !failure.isCompleted) {
          failure.complete(next.error!);
        }
      });
      addTearDown(errorSubscription.close);
      when(
        bench.db.getAllCategories,
      ).thenThrow(StateError('journal unavailable'));
      journal.notifyUpdates({
        TableUpdate(journal.categoryDefinitions.actualTableName),
      });
      expect(await failure.future, isA<StateError>());
      when(bench.db.getAllCategories).thenAnswer((_) async => bench.categories);
      final deletionArrives = nextWhere(
        (value) => value.projection.chats.isEmpty,
      );
      await bench.store.delete('agent', id, forget: true);
      expect((await deletionArrives).projection.chats, isEmpty);
    }),
  );
}
