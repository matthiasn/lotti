import 'dart:convert';

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';

/// Maximum durable dialogue context added to one goal wake.
///
/// The current user turn is carried separately as authoritative pending input;
/// this slice exists only to preserve the exchanges needed to understand a
/// clarification or a short follow-up without letting chat history grow the
/// wake forever.
const int goalRecentDialogueTokenBudget = 900;
const int goalRecentDialogueMessageLimit = 12;

enum GoalChatHistoryRole { user, assistant }

typedef GoalChatHistoryEntry = ({
  String id,
  GoalChatHistoryRole role,
  String text,
  DateTime createdAt,
});

/// Reads bounded visible goal dialogue and identifies unanswered user turns.
class GoalChatHistoryService {
  const GoalChatHistoryService(this._repository);

  final AgentRepository _repository;

  /// The oldest durable user turn that has not been answered yet.
  ///
  /// New replies link their source through `operationId`. For replies written
  /// before that link existed, the immediately preceding unmatched user turn
  /// is paired deterministically so an upgrade does not replay old dialogue.
  Future<String?> oldestPendingMessageId(String agentId) async =>
      (await pendingMessageIds(agentId)).firstOrNull;

  /// Every durable user turn that has not been answered yet, oldest first.
  ///
  /// Recovery deliberately reads the complete visible conversation. Applying
  /// independent limits to user and reply rows can omit only one side of a
  /// pair, either replaying an answered turn or stranding an older orphan.
  Future<List<String>> pendingMessageIds(String agentId) async {
    final messages = await _visibleMessages(agentId, limit: null);
    final answered = <String>{};
    for (final message in messages.where(_isAssistantReply)) {
      final sourceId = message.metadata.operationId;
      if (sourceId != null) answered.add(sourceId);
    }

    for (final reply in messages.where(_isLegacyAssistantReply)) {
      final preceding = messages.lastWhere(
        (message) =>
            _isUserTurn(message) &&
            _comesBefore(message, reply) &&
            !answered.contains(message.id),
        orElse: () => reply,
      );
      if (preceding != reply) answered.add(preceding.id);
    }

    return messages
        .where(_isUserTurn)
        .where((message) => !answered.contains(message.id))
        .map((message) => message.id)
        .toList(growable: false);
  }

  /// Recent completed dialogue before the source turn selected for this wake.
  Future<List<GoalChatHistoryEntry>> recentDialogue({
    required String agentId,
    required AgentMessageEntity before,
    int tokenBudget = goalRecentDialogueTokenBudget,
  }) async {
    final messages = (await _visibleMessages(
      agentId,
      limit: 50,
    )).where((message) => _comesBefore(message, before)).toList();
    final selected = <GoalChatHistoryEntry>[];
    for (final message in messages.reversed) {
      if (selected.length >= goalRecentDialogueMessageLimit) break;
      final payloadId = message.contentEntryId;
      if (payloadId == null) continue;
      final payload = await _repository.getEntity(payloadId);
      final text = payload is AgentMessagePayloadEntity
          ? payload.content['text']
          : null;
      if (text is! String || text.trim().isEmpty) continue;
      final entry = (
        id: message.id,
        role: _isUserTurn(message)
            ? GoalChatHistoryRole.user
            : GoalChatHistoryRole.assistant,
        text: text.trim(),
        createdAt: message.createdAt,
      );
      if (selected.isEmpty) {
        final bounded = _fitEntry(entry, tokenBudget);
        if (bounded == null) break;
        selected.add(bounded);
        continue;
      }
      final candidate = [entry, ...selected];
      if (_estimatedTokens(candidate.map(_json).toList()) > tokenBudget) break;
      selected.add(entry);
    }
    return selected.reversed.toList(growable: false);
  }

  static Map<String, Object> toJson(GoalChatHistoryEntry entry) => _json(entry);

  Future<List<AgentMessageEntity>> _visibleMessages(
    String agentId, {
    required int? limit,
  }) async {
    final users = await _repository.getMessagesByKind(
      agentId,
      AgentMessageKind.user,
      limit: limit,
    );
    final actions = await _repository.getMessagesByKindAndToolName(
      agentId,
      AgentMessageKind.action,
      AgentConversationToolNames.replyToUser,
      limit: limit,
    );
    return <AgentMessageEntity>[
      ...users.where(_isUserTurn),
      ...actions.where(_isAssistantReply),
    ]..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  }

  static bool _isUserTurn(AgentMessageEntity message) =>
      message.deletedAt == null &&
      message.kind == AgentMessageKind.user &&
      message.metadata.runKey == null;

  static bool _isAssistantReply(AgentMessageEntity message) =>
      message.deletedAt == null &&
      message.kind == AgentMessageKind.action &&
      message.metadata.toolName == AgentConversationToolNames.replyToUser &&
      message.contentEntryId != null;

  static bool _isLegacyAssistantReply(AgentMessageEntity message) =>
      _isAssistantReply(message) && message.metadata.operationId == null;

  static bool _comesBefore(
    AgentMessageEntity candidate,
    AgentMessageEntity boundary,
  ) {
    final byTime = candidate.createdAt.compareTo(boundary.createdAt);
    return byTime < 0 ||
        (byTime == 0 && candidate.id.compareTo(boundary.id) < 0);
  }

  static Map<String, Object> _json(GoalChatHistoryEntry entry) => {
    'role': entry.role.name,
    'text': entry.text,
    'createdAt': entry.createdAt.toIso8601String(),
  };

  static GoalChatHistoryEntry? _fitEntry(
    GoalChatHistoryEntry entry,
    int tokenBudget,
  ) {
    if (tokenBudget <= 0) return null;
    if (_estimatedTokens([_json(entry)]) <= tokenBudget) return entry;

    final runes = entry.text.runes.toList(growable: false);
    var low = 0;
    var high = runes.length;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final candidate = (
        id: entry.id,
        role: entry.role,
        text: '${String.fromCharCodes(runes.take(mid)).trimRight()}…',
        createdAt: entry.createdAt,
      );
      if (_estimatedTokens([_json(candidate)]) <= tokenBudget) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    final bounded = (
      id: entry.id,
      role: entry.role,
      text: '${String.fromCharCodes(runes.take(low)).trimRight()}…',
      createdAt: entry.createdAt,
    );
    return _estimatedTokens([_json(bounded)]) <= tokenBudget ? bounded : null;
  }

  static int _estimatedTokens(Object value) {
    final encoded = jsonEncode(value);
    final heuristic = TextChunker.estimateTokens(encoded);
    final bytes = (utf8.encode(encoded).length / 4).ceil();
    return heuristic > bytes ? heuristic : bytes;
  }
}
