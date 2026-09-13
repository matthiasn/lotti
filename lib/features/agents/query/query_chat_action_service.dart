import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_store.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_task_action_planner.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';

typedef QueryActionContextReader =
    Future<QueryTaskActionContext> Function(
      String taskId,
      Iterable<String> relatedIds,
    );

/// The only bridge from query chat to task mutations. Callers supply identifiers
/// and a human verdict, never executable arguments. Saved reviewed arguments,
/// live chat visibility and task ownership are checked at every dispatch.
class QueryChatActionService {
  QueryChatActionService({
    required this.store,
    required this.readContext,
    required this.dispatch,
    required this.labels,
    required this.enabled,
  });

  final QueryChatStore store;
  final QueryActionContextReader readContext;
  final ApprovedTaskToolDispatch dispatch;
  final LabelsRepository labels;
  final bool Function() enabled;
  final _running = <String>{};

  Future<({QueryChatAnswer answer, String taskId})> _authorize(
    String agentId,
    String chatId,
    String questionId,
  ) async {
    if (!enabled()) throw const QueryScopeUnavailable();
    final chat = (await store.load(
      agentId,
    )).chats.where((c) => c.id == chatId).firstOrNull;
    final answer = chat?.answerFor(questionId)?.data;
    if (chat == null ||
        chat.archived ||
        chat.scope.kind != QueryScopeKind.task ||
        answer is! QueryChatAnswer ||
        answer.proposedActions.isEmpty) {
      throw const QueryScopeUnavailable();
    }
    final current = await store.access.load([
      chat.scope.id,
      ...answer.dependencies.map((s) => s.id),
    ]);
    final home = current.entries[chat.scope.id];
    if (home is! Task ||
        !current.allowsEntry(home) ||
        !current.allowsEvent(answer) ||
        answer.dependencies.any(
          (s) =>
              current.entries[s.id]?.meta.categoryId != s.categoryId ||
              current.entries[s.id]?.meta.deletedAt != null,
        )) {
      throw const QueryScopeUnavailable();
    }
    return (answer: answer, taskId: chat.scope.id);
  }

  Future<List<ToolExecutionResult>> resolve({
    required String agentId,
    required String chatId,
    required String questionId,
    required bool approved,
  }) async {
    final key = '$agentId:$chatId:$questionId';
    if (!_running.add(key)) return const [];
    try {
      await _authorize(agentId, chatId, questionId);
      final set = await store.decideActions(
        agentId,
        chatId,
        questionId,
        approved: approved,
      );
      if (set == null) {
        if (approved) throw const QueryScopeUnavailable();
        return const [];
      }
      // Both dispatch channels re-check access; the receipt remains separate
      // from model arguments and is present only for a persisted chat approval.
      Future<ToolExecutionResult> authorizedDispatch(
        String name,
        Map<String, dynamic> args,
        String taskId, [
        ChecklistItemProvenance? approval,
      ]) async {
        final current = await _authorize(agentId, chatId, questionId);
        if (taskId != current.taskId) throw const QueryScopeUnavailable();
        final context = await readContext(
          taskId,
          current.answer.dependencies.map((s) => s.id),
        );
        await QueryTaskActionPlanner.validateItem(
          ChangeItem(toolName: name, args: args, humanSummary: ''),
          context,
        );
        // Re-check after asynchronous context reads and immediately before
        // the existing handler is allowed to mutate the task.
        await _authorize(agentId, chatId, questionId);
        return dispatch(name, args, taskId, approval);
      }

      final service = ChangeSetConfirmationService(
        syncService: store.sync,
        labelsRepository: labels,
        toolDispatcher: authorizedDispatch,
        approvedToolDispatcher: authorizedDispatch,
      );
      return await service.confirmAll(set);
    } finally {
      _running.remove(key);
    }
  }
}
