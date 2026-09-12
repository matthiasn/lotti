import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:uuid/uuid.dart';

/// Synced chat mutations. The deletion marker is permanent: retries, replies
/// and memory writes must re-read it inside their committing transaction.
class QueryChatStore {
  const QueryChatStore({required this.sync, required this.access});

  final AgentSyncService sync;
  final QuerySourceAccess access;
  static const _uuid = Uuid();

  Future<QueryChatProjection> load(String agentId) async => QueryChatProjection(
    (await sync.repository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.queryChatEvent,
    )).whereType<AgentQueryChatEventEntity>(),
  );

  Future<AgentQueryChatEventEntity> _append(
    String agentId,
    String chatId,
    QueryChatEventData data, {
    String? id,
  }) async {
    final previous = await sync.repository.getEntitiesByAgentIdAndSubtype(
      agentId,
      type: AgentEntityTypes.queryChatEvent,
      subtype: chatId,
    );
    var createdAt = clock.now();
    for (final event in previous.whereType<AgentQueryChatEventEntity>()) {
      if (!event.createdAt.isBefore(createdAt)) {
        createdAt = event.createdAt.add(const Duration(microseconds: 1));
      }
    }
    final event =
        AgentDomainEntity.queryChatEvent(
              id: id ?? _uuid.v4(),
              agentId: agentId,
              chatId: chatId,
              data: data,
              createdAt: createdAt,
              vectorClock: null,
            )
            as AgentQueryChatEventEntity;
    await sync.upsertEntity(event);
    return event;
  }

  Future<QueryChatHistory> _chat(String agentId, String chatId) async {
    final chat = (await load(
      agentId,
    )).chats.where((chat) => chat.id == chatId).firstOrNull;
    if (chat == null) throw const QueryScopeUnavailable();
    return chat;
  }

  Future<QueryAccessSnapshot> _checkHome(QueryScope scope) async {
    final current = await access.load([scope.id]);
    final home = current.entries[scope.id];
    if (scope.kind == QueryScopeKind.category
        ? !current.allowsCategory(scope.id)
        : home == null || !current.allowsEntry(home)) {
      throw const QueryScopeUnavailable();
    }
    return current;
  }

  Future<String> create(
    String agentId,
    QueryScope scope,
    String title, {
    bool private = false,
  }) async {
    final current = await _checkHome(scope);
    if (private && !current.showPrivate) throw const QueryScopeUnavailable();
    final id = _uuid.v4();
    await _append(
      agentId,
      id,
      QueryChatEventData.created(
        scope: scope,
        title: _title(title),
        private: private || current.showPrivate,
      ),
    );
    return id;
  }

  static String _title(String value) {
    final title = value.trim();
    if (title.isEmpty || title.length > 120) {
      throw ArgumentError('Invalid chat title');
    }
    return title;
  }

  Future<void> rename(
    String agentId,
    String chatId,
    String title, {
    bool private = false,
  }) => _edit(
    agentId,
    chatId,
    QueryChatEventData.renamed(title: _title(title), private: private),
  );

  Future<void> archive(
    String agentId,
    String chatId, {
    required bool archived,
  }) => _edit(agentId, chatId, QueryChatEventData.archived(archived: archived));

  Future<void> markRead(String agentId, String chatId, String throughEventId) =>
      _edit(
        agentId,
        chatId,
        QueryChatEventData.read(throughEventId: throughEventId),
      );

  Future<void> _edit(String agentId, String chatId, QueryChatEventData data) =>
      sync.runInTransaction(() async {
        final chat = await _chat(agentId, chatId);
        final current = await _checkHome(chat.scope);
        if (data is QueryChatRenamed && data.private && !current.showPrivate) {
          throw const QueryScopeUnavailable();
        }
        await _append(
          agentId,
          chatId,
          data is QueryChatRenamed
              ? data.copyWith(private: data.private || current.showPrivate)
              : data,
        );
      });

  Future<AgentQueryChatEventEntity> ask(
    String agentId,
    String chatId,
    String text, {
    bool private = false,
  }) => sync.runInTransaction(() async {
    final chat = await _chat(agentId, chatId);
    if (chat.archived || text.trim().isEmpty || text.length > 16000) {
      throw ArgumentError('Chat cannot accept this question');
    }
    await _checkHome(chat.scope);
    final refs = {
      for (final row in chat.events)
        for (final ref in queryEventDependencies(row.data)) ref.id: ref,
    };
    final current = await access.load([chat.scope.id, ...refs.keys]);
    if (private && !current.showPrivate) throw const QueryScopeUnavailable();
    final dependencies = <String, QuerySourceRef>{
      if (current.entries[chat.scope.id] case final home?)
        home.meta.id: current.reference(home),
      for (final row in chat.events.where((e) => current.allowsEvent(e.data)))
        for (final ref in queryEventDependencies(row.data)) ref.id: ref,
    };
    return _append(
      agentId,
      chatId,
      QueryChatEventData.question(
        text: text.trim(),
        private: private || current.showPrivate,
        dependencies: dependencies.values.toList(),
      ),
    );
  });

  /// A stable answer id makes simultaneous retries converge to one visible
  /// answer. A forgotten memory can never be recreated by a late completion.
  Future<bool> publish(
    String agentId,
    String chatId,
    QueryBuiltAnswer result,
  ) => sync.runInTransaction(() async {
    final projection = await load(agentId);
    final chat = projection.chats.where((c) => c.id == chatId).firstOrNull;
    if (chat == null || chat.answerFor(result.answer.questionId) != null) {
      return false;
    }
    final question = chat.questions
        .where((q) => q.id == result.answer.questionId)
        .firstOrNull;
    if (question == null) return false;
    await _checkHome(chat.scope);
    final current = await access.load(
      result.answer.dependencies.map((s) => s.id),
    );
    if (!current.allowsEvent(result.answer) ||
        !current.allowsEvent(question.data)) {
      throw const QueryScopeUnavailable();
    }
    if (result.answer.summaryBased &&
        (result.memory != null || result.answer.evidence.isNotEmpty)) {
      throw const FormatException(
        'Summary answer cannot publish exact evidence or memory',
      );
    }
    // Recall may have been forgotten on another device while inference ran.
    final liveMemoryIds = projection.memories.map((e) => e.id).toSet();
    if (!liveMemoryIds.containsAll(result.answer.recalledMemoryIds)) {
      return false;
    }
    await _append(
      agentId,
      chatId,
      result.answer,
      id: '${result.answer.questionId}:answer',
    );
    if (result.memory case final memory?) {
      if (!current.allowsEvent(memory)) throw const QueryScopeUnavailable();
      await _append(
        agentId,
        chatId,
        memory,
        id: '${result.answer.questionId}:memory',
      );
    }
    return true;
  });

  Future<void> fail(
    String agentId,
    String chatId,
    String questionId, {
    bool cancelled = false,
  }) => sync.runInTransaction(() async {
    final chat = (await load(
      agentId,
    )).chats.where((c) => c.id == chatId).firstOrNull;
    if (chat == null || chat.answerFor(questionId) != null) return;
    await _append(
      agentId,
      chatId,
      cancelled
          ? QueryChatEventData.cancelled(questionId: questionId)
          : QueryChatEventData.failed(questionId: questionId),
    );
  });

  Future<void> delete(String agentId, String chatId, {required bool forget}) =>
      sync.runInTransaction(() async {
        final rows = (await sync.repository.getEntitiesByAgentIdAndSubtype(
          agentId,
          type: AgentEntityTypes.queryChatEvent,
          subtype: chatId,
        )).whereType<AgentQueryChatEventEntity>();
        await _append(
          agentId,
          chatId,
          QueryChatEventData.deleted(forget: forget),
        );
        for (final row in rows) {
          if (row.data is QueryChatDeleted ||
              (!forget && row.data is QueryChatMemory)) {
            continue;
          }
          await sync.upsertEntity(row.copyWith(deletedAt: clock.now()));
        }
      });
}
