import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';

/// Which of the front agent's durable user turns are still unanswered.
///
/// A turn is answered once a front run wrote any of its three carriers for
/// it — a dispatch, a question or a reply — each an `action` row whose
/// `operationId` is the turn's id. Recovery (ADR 0069) reads the complete
/// visible conversation for the same reason the goal history does: a limit
/// on one side of a pair can strand an orphan or replay an answered turn.
class FrontChatHistoryService {
  const FrontChatHistoryService({required AgentRepository repository})
    : this._(repository);

  const FrontChatHistoryService._(this._repository);

  final AgentRepository _repository;

  /// The oldest durable user turn that has not been answered yet.
  Future<String?> oldestPendingMessageId() async =>
      (await pendingMessageIds()).firstOrNull;

  /// Every durable user turn that has not been answered yet, oldest first.
  Future<List<String>> pendingMessageIds() async {
    final messages = (await _repository.getAgentMessages(
      frontAgentId,
    )).where((m) => m.deletedAt == null).toList()..sort(_chronological);
    final answered = <String>{
      for (final message in messages)
        if (isFrontAnswerRow(message) && message.metadata.operationId != null)
          message.metadata.operationId!,
    };
    return [
      for (final message in messages)
        if (isFrontUserTurn(message) && !answered.contains(message.id))
          message.id,
    ];
  }

  static int _chronological(AgentMessageEntity a, AgentMessageEntity b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }
}

/// A user turn the front agent must answer: a `user` row the chat service
/// wrote (no run key — a wake never writes one) with its payload attached.
bool isFrontUserTurn(AgentMessageEntity message) =>
    message.kind == AgentMessageKind.user &&
    message.metadata.runKey == null &&
    message.contentEntryId != null;

/// A record a front run wrote to answer a turn: its dispatch, its question
/// or its reply. The strategy's own tool-call log shares the tool names but
/// carries no `operationId`, so it is not one.
bool isFrontAnswerRow(AgentMessageEntity message) =>
    message.kind == AgentMessageKind.action &&
    message.metadata.operationId != null &&
    const {
      FrontAgentToolNames.dispatch,
      FrontAgentToolNames.askUser,
      FrontAgentToolNames.replyToUser,
    }.contains(message.metadata.toolName);
