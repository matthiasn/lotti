// Maps production action-message audit rows back to eval tool-call records.
//
// Scripted runs already know the raw tool calls. Live runs must not depend on
// the in-memory ConversationManager after the workflow deletes the conversation,
// so action messages are the durable source of tool-call evidence.

import 'dart:convert';

import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

import 'eval_models.dart';

List<ToolCallRecord> toolCallRecordsFromPersistedActions(
  Iterable<AgentDomainEntity> entities,
) {
  final payloadsById = <String, AgentMessagePayloadEntity>{
    for (final entity in entities.whereType<AgentMessagePayloadEntity>())
      entity.id: entity,
  };
  final messages =
      [
        for (final entity in entities.whereType<AgentMessageEntity>())
          if (entity.kind == AgentMessageKind.action &&
              entity.deletedAt == null)
            entity,
      ]..sort((a, b) {
        final byCreatedAt = a.createdAt.compareTo(b.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return a.id.compareTo(b.id);
      });

  return [
    for (final message in messages)
      ToolCallRecord(
        name: message.metadata.toolName ?? 'unknown_tool',
        args: _argsFromPayload(payloadsById[message.contentEntryId]?.content),
      ),
  ];
}

Map<String, dynamic> _argsFromPayload(Map<String, dynamic>? content) {
  if (content == null) return const <String, dynamic>{};

  // Task-agent action payloads store the original args as JSON in `text`.
  final text = content['text'];
  if (text is String) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return <String, dynamic>{'text': text};
    }
  }

  // Day-agent action payloads store the args map directly.
  return Map<String, dynamic>.from(content);
}
