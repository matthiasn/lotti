import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_store.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';

final querySourceAccessProvider = Provider<QuerySourceAccess>(
  (ref) => QuerySourceAccess(
    journal: ref.watch(journalDbProvider),
    readLockdown: () => ref.read(lockdownControllerProvider),
  ),
);

final queryChatStoreProvider = Provider<QueryChatStore>(
  (ref) => QueryChatStore(
    sync: ref.watch(agentSyncServiceProvider),
    access: ref.watch(querySourceAccessProvider),
  ),
);

class QueryChatTarget {
  const QueryChatTarget({
    required this.scope,
    required this.label,
    required this.agent,
    this.categoryId,
    this.categoryLabel,
  });
  final QueryScope scope;
  final String label;
  final AgentIdentityEntity? agent;
  final String? categoryId;
  final String? categoryLabel;
}

/// Reading the query surface reuses its task/project identity. A category's
/// query-only identity is a deterministic singleton with no wake subscription.
final FutureProviderFamily<QueryChatTarget, QueryScope>
queryChatTargetProvider = FutureProvider.autoDispose
    .family<QueryChatTarget, QueryScope>((ref, scope) async {
      ref.watch(lockdownControllerProvider);
      final access = await ref.watch(querySourceAccessProvider).load([
        scope.id,
      ]);
      final home = access.entries[scope.id];
      if (scope.kind == QueryScopeKind.category
          ? !access.allowsCategory(scope.id)
          : home == null || !access.allowsEntry(home)) {
        throw const QueryScopeUnavailable();
      }
      final categoryId = scope.kind == QueryScopeKind.category
          ? scope.id
          : home!.meta.categoryId;
      final category = access.categories[categoryId];
      AgentIdentityEntity? agent;
      String label;
      switch (scope.kind) {
        case QueryScopeKind.task:
          if (home is! Task) throw const QueryScopeUnavailable();
          label = home.data.title;
          agent = (await ref.watch(
            taskAgentProvider(scope.id).future,
          ))?.mapOrNull(agent: (e) => e);
        case QueryScopeKind.project:
          if (home is! ProjectEntry) throw const QueryScopeUnavailable();
          label = home.data.title;
          agent = (await ref.watch(
            projectAgentProvider(scope.id).future,
          ))?.mapOrNull(agent: (e) => e);
        case QueryScopeKind.category:
          label = category!.name;
          final service = ref.watch(agentServiceProvider);
          final id = '${AgentKinds.categoryAgent}:${scope.id}';
          agent =
              await service.getAgent(id) ??
              await service.createAgent(
                kind: AgentKinds.categoryAgent,
                displayName: label,
                agentId: id,
                allowedCategoryIds: {scope.id},
                config: AgentConfig(profileId: category.defaultProfileId),
              );
      }
      if (agent?.lifecycle == AgentLifecycle.destroyed ||
          agent?.deletedAt != null) {
        agent = null;
      }
      return QueryChatTarget(
        scope: scope,
        label: label,
        agent: agent,
        categoryId: categoryId,
        categoryLabel: category?.name,
      );
    }, retry: (_, _) => null);

typedef QueryBuilderFactory =
    Future<QueryAnswerBuilder> Function(
      QueryScope scope,
      String agentId,
      String chatId,
    );

class QueryInferenceUnavailable implements Exception {
  const QueryInferenceUnavailable();
}

/// Both question answering and explicit audio enrichment use the same live
/// agent/category profile, including a deliberately disabled configuration.
final FutureProviderFamily<ResolvedProfile?, QueryChatKey>
queryProfileProvider = FutureProvider.autoDispose
    .family<ResolvedProfile?, QueryChatKey>((ref, key) async {
      if (key.scope.kind == QueryScopeKind.category) {
        final current = await ref.read(querySourceAccessProvider).load([
          key.scope.id,
        ]);
        if (!current.allowsCategory(key.scope.id)) return null;
        final profileId = current.categories[key.scope.id]?.defaultProfileId;
        return profileId == null
            ? null
            : ref.read(profileResolverProvider).resolveByProfileId(profileId);
      }
      return (await ref.watch(
        agentResolvedSetupProvider(key.agentId).future,
      ))?.profile;
    }, retry: (_, _) => null);

final queryBuilderFactoryProvider = Provider<QueryBuilderFactory>((ref) {
  final access = ref.watch(querySourceAccessProvider);
  final journal = ref.watch(journalDbProvider);
  final cloud = ref.watch(cloudInferenceRepositoryProvider);
  return (scope, agentId, chatId) async {
    final current = await access.load([scope.id]);
    final categoryId = scope.kind == QueryScopeKind.category
        ? scope.id
        : current.entries[scope.id]?.meta.categoryId;
    final profile = await ref.read(
      queryProfileProvider((agentId: agentId, scope: scope)).future,
    );
    if (profile == null) throw const QueryInferenceUnavailable();
    return QueryAnswerBuilder(
      crawler: QueryJournalCrawler(
        journal: journal,
        access: access,
        search: (terms) => getIt<Fts5Db>().findMatching(terms).get(),
      ),
      access: access,
      inference: QueryTextInference.forProfile(
        cloud: cloud,
        profile: profile,
        agentId: agentId,
        chatId: chatId,
        categoryId: categoryId,
        taskId: scope.kind == QueryScopeKind.task ? scope.id : null,
        capture: getIt.isRegistered<AiInteractionCapture>()
            ? getIt<AiInteractionCapture>()
            : null,
      ),
    );
  };
});

class QueryChatData {
  const QueryChatData({required this.projection, required this.access});
  final QueryChatProjection projection;
  final QueryAccessSnapshot access;
}

typedef QueryChatKey = ({String agentId, QueryScope scope});

/// Database changes refresh the snapshot without replacing established history
/// with a loading shell. Generation checks discard an older, slower read.
final StreamProviderFamily<QueryChatData, QueryChatKey> queryChatDataProvider =
    StreamProvider.autoDispose.family<QueryChatData, QueryChatKey>((ref, key) {
      final store = ref.watch(queryChatStoreProvider);
      final agentDb = ref.watch(agentDatabaseProvider);
      final journal = ref.watch(journalDbProvider);
      final controller = StreamController<QueryChatData>();
      var generation = 0;
      var disposed = false;
      Future<void> refresh() async {
        final revision = ++generation;
        try {
          final projection = await store.load(key.agentId);
          final sources = <String>{
            key.scope.id,
            for (final chat in projection.chats) chat.scope.id,
            for (final row in [
              ...projection.chats.expand((c) => c.events),
              ...projection.memories,
            ])
              ...queryEventDependencies(row.data).map((s) => s.id),
          };
          final access = await store.access.load(sources);
          if (!disposed && revision == generation) {
            controller.add(
              QueryChatData(projection: projection, access: access),
            );
          }
        } catch (error, stack) {
          if (!disposed && revision == generation) {
            controller.addError(error, stack);
          }
        }
      }

      final agentChanges = agentDb
          .tableUpdates(TableUpdateQuery.onTable(agentDb.agentEntities))
          .listen((_) => unawaited(refresh()));
      final journalChanges = journal
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              journal.journal,
              journal.categoryDefinitions,
              journal.configFlags,
            ]),
          )
          .listen((_) => unawaited(refresh()));
      ref
        ..listen(lockdownControllerProvider, (_, _) => unawaited(refresh()))
        ..onDispose(() {
          disposed = true;
          unawaited(agentChanges.cancel());
          unawaited(journalChanges.cancel());
          unawaited(controller.close());
        });
      unawaited(refresh());
      return controller.stream;
    });

/// Detail hosts keep their state while the query pane temporarily replaces
/// their content. Each task/project/category owns its own navigation toggle.
final NotifierProviderFamily<QueryPaneOpen, bool, QueryScope>
queryPaneOpenProvider =
    NotifierProvider.family<QueryPaneOpen, bool, QueryScope>(QueryPaneOpen.new);

class QueryPaneOpen extends Notifier<bool> {
  QueryPaneOpen(this.scope);
  final QueryScope scope;
  @override
  bool build() => false;
  bool get open => state;
  set open(bool value) => state = value;
}
