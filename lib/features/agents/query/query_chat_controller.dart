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
    this.answering = false,
    this.requestQuestionId,
    this.provisional,
    this.draftRetracted = false,
  });
  final String draft;
  final bool draftPrivate;
  final QueryTurnStatus status;
  final int checked;
  final bool expanded;
  final bool homeOnly;
  final QuerySourceKind? kind;
  final bool answering;

  /// Ephemeral synthesis only; never persisted before validation.
  final QueryChatAnswer? provisional;
  final bool draftRetracted;

  /// The saved question for the current/last attempt; null before persistence.
  final String? requestQuestionId;

  QueryChatLocal copyWith({
    String? draft,
    bool? draftPrivate,
    QueryTurnStatus? status,
    int? checked,
    bool? expanded,
    bool? homeOnly,
    QuerySourceKind? kind,
    bool clearKind = false,
    bool? answering,
    String? requestQuestionId,
    bool clearRequestQuestion = false,
    QueryChatAnswer? provisional,
    bool clearProvisional = false,
    bool? draftRetracted,
  }) => QueryChatLocal(
    draft: draft ?? this.draft,
    draftPrivate: draftPrivate ?? this.draftPrivate,
    status: status ?? this.status,
    checked: checked ?? this.checked,
    expanded: expanded ?? this.expanded,
    homeOnly: homeOnly ?? this.homeOnly,
    kind: clearKind ? null : kind ?? this.kind,
    answering: answering ?? this.answering,
    provisional: clearProvisional ? null : provisional ?? this.provisional,
    draftRetracted: draftRetracted ?? this.draftRetracted,
    requestQuestionId: clearRequestQuestion
        ? null
        : requestQuestionId ?? this.requestQuestionId,
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
      if (projection == null) {
        if (next.hasError) _cancelAll();
        return;
      }
      for (final entry in state.chats.entries.toList()) {
        final draft = entry.value.provisional;
        if (draft == null) continue;
        final chat = projection.chats
            .where((c) => c.id == entry.key)
            .firstOrNull;
        if (chat == null) {
          _runs.remove(entry.key)?.cancel();
          state = QueryChatSession(
            selectedId: state.selectedId == entry.key ? null : state.selectedId,
            chats: {...state.chats}..remove(entry.key),
          );
          continue;
        }
        if (chat.answerFor(draft.questionId) != null &&
            entry.value.status != QueryTurnStatus.running) {
          _set(entry.key, entry.value.copyWith(clearProvisional: true));
        } else if (_runs[entry.key] case final run?) {
          if (draft.recalledMemoryIds.any(
            (id) => !projection.memories.any((m) => m.id == id),
          )) {
            cancel(entry.key);
          } else {
            unawaited(_recheckProvisional(entry.key, draft, run));
          }
        }
      }
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
      _releaseIdleHistory();
    });
  }

  void _releaseIdleHistory() {
    if (_runs.isNotEmpty ||
        state.chats.values.any((c) => c.provisional != null)) {
      return;
    }
    _runningHistory?.close();
    _runningHistory = null;
    _observed.clear();
  }

  Future<void> _recheckProvisional(
    String id,
    QueryChatAnswer draft,
    QueryCancellation run,
  ) async {
    try {
      final access = await ref
          .read(queryChatStoreProvider)
          .access
          .load(
            draft.dependencies.map((source) => source.id),
          );
      if (!ref.mounted || run.isCancelled || !identical(_runs[id], run)) return;
      final scoped = [
        ...draft.evidence.map((e) => e.source),
        ...draft.coverage.unreadableSources,
        ...draft.dependencies.where((s) => s.id == key.scope.id),
      ];
      if (!access.allowsContent(draft.dependencies, private: draft.private) ||
          scoped.any(
            (s) => access.entries[s.id]?.meta.categoryId != s.categoryId,
          ) ||
          (key.scope.kind == QueryScopeKind.category &&
              !access.allowsCategory(key.scope.id))) {
        cancel(id);
      }
    } catch (_) {
      if (ref.mounted && identical(_runs[id], run)) cancel(id);
    }
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
    _set(
      id,
      state
          .local(id)
          .copyWith(status: QueryTurnStatus.cancelled, clearProvisional: true),
    );
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
    _set(
      id,
      state
          .local(id)
          .copyWith(status: QueryTurnStatus.cancelled, clearProvisional: true),
    );
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
        answering: false,
        clearProvisional: true,
        draftRetracted: false,
        requestQuestionId: retryQuestionId,
        clearRequestQuestion: retryQuestionId == null,
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
      _set(id, state.local(id).copyWith(requestQuestionId: question.id));
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
        onSynthesisReady: (answer) {
          cancellation.check();
          _set(id, state.local(id).copyWith(provisional: answer));
        },
        onAnswerText: (text) {
          cancellation.check();
          if (!ref.mounted || !identical(_runs[id], cancellation)) return;
          final current = state.local(id).provisional;
          if (current != null) {
            _set(
              id,
              state
                  .local(id)
                  .copyWith(provisional: current.copyWith(text: text)),
            );
          }
        },
        onAnswering: () {
          if (!cancellation.isCancelled) {
            stage = 'answer';
            _set(id, state.local(id).copyWith(answering: true));
          }
        },
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
        final visible = ref
            .read(queryChatDataProvider(key))
            .value
            ?.projection
            .chats
            .where((c) => c.id == id)
            .firstOrNull
            ?.answerFor(question.id);
        _set(
          id,
          state
              .local(id)
              .copyWith(
                status: QueryTurnStatus.idle,
                clearProvisional: visible != null,
              ),
        );
      }
    } catch (error, stack) {
      if (ref.mounted && identical(_runs[id], cancellation)) {
        final local = state.local(id);
        _set(
          id,
          local.copyWith(
            draftRetracted:
                local.provisional?.text.isNotEmpty == true &&
                error is! QueryCancelled &&
                error is! QueryScopeUnavailable,
            clearProvisional: true,
          ),
        );
      }
      if (error is! QueryCancelled &&
          error is! QueryScopeUnavailable &&
          error is! QueryInferenceUnavailable) {
        // Provider errors can contain prompts, responses or credentials.
        // Record only their type, stage and numeric HTTP status, never text.
        final httpStatus = error is MeliousInferenceException
            ? error.statusCode
            : null;
        logger.error(
          LogDomain.chat,
          error.runtimeType.toString(),
          errorType: error.runtimeType,
          message:
              'Query failed during $stage'
              '${httpStatus == null ? '' : ' (httpStatus=$httpStatus)'}',
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
