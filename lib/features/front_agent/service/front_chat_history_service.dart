import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';

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

  /// Every durable user turn the front agent has not routed, asked about
  /// or replied to yet, oldest first — the turns a wake must still take
  /// through the model. A routed turn is never routed again.
  Future<List<String>> unroutedMessageIds() async {
    final messages = await _liveMessages();
    final answered = _answeredIds(messages);
    return [
      for (final message in messages)
        if (isFrontUserTurn(message) && !answered.contains(message.id))
          message.id,
    ];
  }

  /// Every durable user turn that still needs a wake, oldest first: the
  /// unrouted ones, and the routed ones whose doors are not all walked. A
  /// recovery record is consumed when its wake is enqueued, before the
  /// doors finish, so a walk that died after the dispatch was written must
  /// stay eligible for the next recovery pass — which walks the doors
  /// without routing the turn again.
  Future<List<String>> pendingMessageIds() async {
    final messages = await _liveMessages();
    final answered = _answeredIds(messages);
    final pending = <String>[];
    for (final message in messages) {
      if (!isFrontUserTurn(message)) continue;
      if (!answered.contains(message.id) ||
          await _doorsUnfinished(message.id, messages)) {
        pending.add(message.id);
      }
    }
    return pending;
  }

  /// Whether the newest dispatch for [messageId] has a segment without a
  /// `done` door record. A turn answered without a dispatch has no doors.
  Future<bool> _doorsUnfinished(
    String messageId,
    List<AgentMessageEntity> messages,
  ) async {
    AgentMessageEntity? dispatch;
    for (final message in messages) {
      if (isFrontAnswerRow(message) &&
          message.metadata.toolName == FrontAgentToolNames.dispatch &&
          message.metadata.operationId == messageId) {
        dispatch = message;
      }
    }
    if (dispatch == null) return false;
    final payload = await _payload(dispatch.contentEntryId);
    final segments = payload == null
        ? null
        : frontDispatchFromPayload(payload)?.segments.length;
    if (segments == null) return false;
    var done = 0;
    for (final message in messages) {
      if (message.kind != AgentMessageKind.action ||
          message.metadata.toolName != frontDoorToolName ||
          message.metadata.operationId != messageId ||
          !message.id.startsWith(dispatch.id)) {
        continue;
      }
      final record = await _payload(message.contentEntryId);
      final door = record == null
          ? null
          : FrontDoorRecord.fromJson(record.content);
      if (door?.status == FrontDoorStatus.done) done++;
    }
    return done < segments;
  }

  Future<AgentMessagePayloadEntity?> _payload(String? id) async {
    if (id == null) return null;
    final entity = await _repository.getEntity(id);
    return entity is AgentMessagePayloadEntity ? entity : null;
  }

  Future<List<AgentMessageEntity>> _liveMessages() async =>
      (await _repository.getAgentMessages(
        frontAgentId,
      )).where((m) => m.deletedAt == null).toList()..sort(_chronological);

  static Set<String> _answeredIds(List<AgentMessageEntity> messages) => {
    for (final message in messages)
      if (isFrontAnswerRow(message) && message.metadata.operationId != null)
        message.metadata.operationId!,
  };

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
