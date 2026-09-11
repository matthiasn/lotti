import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/services/domain_logging.dart';

enum QueryTurnStatus { idle, running, failed, unavailable, hidden, cancelled }

class QueryChatLocal {
  const QueryChatLocal({
    this.draft = '',
    this.draftPrivate = false,
    this.status = QueryTurnStatus.idle,
    this.checked = 0,
    this.expanded = false,
    this.homeOnly = false,
    this.kind,
  });
  final String draft;
  final bool draftPrivate;
  final QueryTurnStatus status;
  final int checked;
  final bool expanded;
  final bool homeOnly;
  final QuerySourceKind? kind;

  QueryChatLocal copyWith({
    String? draft,
    bool? draftPrivate,
    QueryTurnStatus? status,
    int? checked,
    bool? expanded,
    bool? homeOnly,
    QuerySourceKind? kind,
    bool clearKind = false,
  }) => QueryChatLocal(
    draft: draft ?? this.draft,
    draftPrivate: draftPrivate ?? this.draftPrivate,
    status: status ?? this.status,
    checked: checked ?? this.checked,
    expanded: expanded ?? this.expanded,
    homeOnly: homeOnly ?? this.homeOnly,
    kind: clearKind ? null : kind ?? this.kind,
  );
}

class QueryChatSession {
  const QueryChatSession({this.selectedId, this.chats = const {}});
  final String? selectedId;
  final Map<String, QueryChatLocal> chats;
  QueryChatLocal local(String id) => chats[id] ?? const QueryChatLocal();
}

/// Kept alive so navigating to a source or switching chats preserves drafts
/// and running requests. Each request owns its cancellation token.
final NotifierProviderFamily<
  QueryChatController,
  QueryChatSession,
  QueryChatKey
>
queryChatControllerProvider =
    NotifierProvider.family<
      QueryChatController,
      QueryChatSession,
      QueryChatKey
    >(QueryChatController.new);

class QueryChatController extends Notifier<QueryChatSession> {
  QueryChatController(this.key);
  final QueryChatKey key;
  final _runs = <String, QueryCancellation>{};
  final _observed = <String>{};
  ProviderSubscription<AsyncValue<QueryChatData>>? _runningHistory;

  @override
  QueryChatSession build() {
    ref
      ..listen(configFlagProvider('private'), (previous, next) {
        if (previous?.value == true && next.value != true) _cancelAll();
      })
      ..listen(lockdownControllerProvider, (_, _) => _cancelAll())
      ..onDispose(() {
        for (final run in _runs.values) {
          run.cancel();
        }
        _runs.clear();
        _runningHistory?.close();
      });
    return const QueryChatSession();
  }

  /// Only active requests retain a database subscription after navigation.
  /// Drafts can remain in memory without reloading every opened task's history
  /// on each journal notification.
  void _watchRunningHistory() {
    _runningHistory ??= ref.listen(queryChatDataProvider(key), (_, next) {
      final projection = next.value?.projection;
      if (projection == null) return;
      final live = projection.chats.map((c) => c.id).toSet();
      for (final removed in _observed.difference(live)) {
        _runs.remove(removed)?.cancel();
        final remaining = {...state.chats}..remove(removed);
        state = QueryChatSession(
          selectedId: state.selectedId == removed ? null : state.selectedId,
          chats: remaining,
        );
      }
      _observed
        ..clear()
        ..addAll(live);
    });
  }

  void _releaseIdleHistory() {
    if (_runs.isNotEmpty) return;
    _runningHistory?.close();
    _runningHistory = null;
    _observed.clear();
  }

  void _set(String id, QueryChatLocal local) {
    if (!ref.mounted) return;
    state = QueryChatSession(
      selectedId: state.selectedId,
      chats: {...state.chats, id: local},
    );
  }

  void _cancelAll() {
    _runs.keys.toList().forEach(cancel);
  }

  void select(String? id) =>
      state = QueryChatSession(selectedId: id, chats: state.chats);

  Future<String> create(String title, {bool private = false}) async {
    final authoredPrivate =
        private || ref.read(configFlagProvider('private')).value == true;
    final id = await ref
        .read(queryChatStoreProvider)
        .create(key.agentId, key.scope, title, private: authoredPrivate);
    if (ref.mounted) select(id);
    return id;
  }

  void updateDraft(String id, String text, {bool? private}) => _set(
    id,
    state
        .local(id)
        .copyWith(
          draft: text,
          draftPrivate:
              private ?? ref.read(configFlagProvider('private')).value ?? false,
        ),
  );

  void narrow(
    String id, {
    bool? homeOnly,
    QuerySourceKind? kind,
    bool clearKind = false,
  }) => _set(
    id,
    state
        .local(id)
        .copyWith(homeOnly: homeOnly, kind: kind, clearKind: clearKind),
  );

  Future<void> rename(String id, String title, {bool private = false}) => ref
      .read(queryChatStoreProvider)
      .rename(
        key.agentId,
        id,
        title,
        private:
            private || ref.read(configFlagProvider('private')).value == true,
      );
  Future<void> archive(String id, {required bool archived}) async {
    await ref
        .read(queryChatStoreProvider)
        .archive(key.agentId, id, archived: archived);
    if (ref.mounted && archived && state.selectedId == id) select(null);
  }

  Future<void> markRead(String id, String throughEventId) => ref
      .read(queryChatStoreProvider)
      .markRead(key.agentId, id, throughEventId);

  Future<void> delete(String id, {required bool forget}) async {
    _runs.remove(id)?.cancel();
    _releaseIdleHistory();
    await ref
        .read(queryChatStoreProvider)
        .delete(key.agentId, id, forget: forget);
    if (!ref.mounted) return;
    final remaining = {...state.chats}..remove(id);
    state = QueryChatSession(
      selectedId: state.selectedId == id ? null : state.selectedId,
      chats: remaining,
    );
  }

  void cancel(String id) {
    _runs[id]?.cancel();
    // Keep the slot occupied until cleanup completes, preventing a retry from
    // racing a cancelled request's terminal event.
    _set(id, state.local(id).copyWith(status: QueryTurnStatus.cancelled));
  }

  Future<void> send(String id, {String? retryQuestionId}) async {
    if (_runs.containsKey(id)) return;
    final local = state.local(id);
    if (retryQuestionId == null && local.draft.trim().isEmpty) return;
    if (local.draftPrivate &&
        ref.read(configFlagProvider('private')).value != true) {
      return;
    }
    final cancellation = QueryCancellation();
    _runs[id] = cancellation;
    _set(
      id,
      local.copyWith(
        status: QueryTurnStatus.running,
        checked: 0,
        expanded: false,
      ),
    );
    final store = ref.read(queryChatStoreProvider);
    final logger = ref.read(domainLoggerProvider);
    AgentQueryChatEventEntity? question;
    var stage = 'setup';
    try {
      _watchRunningHistory();
      final builder = await ref.read(queryBuilderFactoryProvider)(
        key.scope,
        key.agentId,
        id,
      );
      cancellation.check();
      stage = 'loadChat';
      var projection = await store.load(key.agentId);
      var chat = projection.chats.where((c) => c.id == id).firstOrNull;
      if (chat == null || chat.archived) throw const QueryScopeUnavailable();
      if (retryQuestionId == null) {
        stage = 'saveQuestion';
        question = await store.ask(
          key.agentId,
          id,
          local.draft,
          private: local.draftPrivate,
        );
        if (state.local(id).draft == local.draft) {
          _set(id, state.local(id).copyWith(draft: ''));
        }
      } else {
        question = chat.questions
            .where((q) => q.id == retryQuestionId)
            .firstOrNull;
        if (question == null || chat.answerFor(question.id) != null) {
          _set(id, state.local(id).copyWith(status: QueryTurnStatus.idle));
          return;
        }
      }
      cancellation.check();
      stage = 'readHistory';
      projection = await store.load(key.agentId);
      chat = projection.chats.where((c) => c.id == id).firstOrNull;
      if (chat == null) throw const QueryCancelled();
      stage = 'search';
      final result = await builder.build(
        chat: chat,
        question: question,
        memories: projection.memories,
        cancellation: cancellation,
        homeOnly: local.homeOnly,
        kind: local.kind,
        onProgress: (checked, {required expanded}) {
          if (!cancellation.isCancelled) {
            _set(
              id,
              state.local(id).copyWith(checked: checked, expanded: expanded),
            );
          }
        },
      );
      cancellation.check();
      stage = 'publish';
      final published = await store.publish(key.agentId, id, result);
      if (!published) throw const QueryCancelled();
      if (ref.mounted) {
        _set(id, state.local(id).copyWith(status: QueryTurnStatus.idle));
      }
    } catch (error, stack) {
      if (error is! QueryCancelled && error is! QueryScopeUnavailable) {
        // Provider errors can contain prompts, responses or credentials.
        // Record only their type, stage and numeric HTTP status, never text.
        final httpStatus = error is MeliousInferenceException
            ? error.statusCode
            : null;
        logger.error(
          LogDomain.chat,
          error.runtimeType,
          message:
              'Query failed during $stage (errorType=${error.runtimeType}'
              '${httpStatus == null ? '' : ', httpStatus=$httpStatus'})',
          subDomain: 'query.send',
          stackTrace: stack,
        );
      }
      if (question != null) {
        try {
          await store.fail(
            key.agentId,
            id,
            question.id,
            cancelled: error is QueryCancelled,
          );
        } catch (_) {
          /* The UI still offers retry if persisting the failure fails. */
        }
      }
      if (ref.mounted && identical(_runs[id], cancellation)) {
        _set(
          id,
          state
              .local(id)
              .copyWith(
                status: switch (error) {
                  QueryInferenceUnavailable() => QueryTurnStatus.unavailable,
                  QueryScopeUnavailable() => QueryTurnStatus.hidden,
                  QueryCancelled() => QueryTurnStatus.cancelled,
                  _ => QueryTurnStatus.failed,
                },
              ),
        );
      }
    } finally {
      if (identical(_runs[id], cancellation)) _runs.remove(id);
      _releaseIdleHistory();
    }
  }
}
