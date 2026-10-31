import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/service/front_chat_history_service.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';

/// Projects the front thread for the chat surface.
///
/// The shared `agentChatProjection` shows user rows and `reply_to_user`
/// rows; the front thread also has questions (`ask_user`, shown as her turn
/// with its options) and doors (`front_door`, shown under the user turn they
/// answer). A dispatch record is never shown: the doors are what the user
/// sees of it. A goal's or person's reply to a door is read from that
/// agent's own thread, by the message id the door recorded — attributed
/// text, never relayed through the front agent (decision 2).
class FrontChatThreadBuilder {
  const FrontChatThreadBuilder({required AgentRepository repository})
    : this._(repository);

  const FrontChatThreadBuilder._(this._repository);

  final AgentRepository _repository;

  /// At most this many visible messages, the newest ones — the shared
  /// projection's bound, per conversation.
  static const int maxMessages = 50;

  /// The thread of one conversation, [conversationId] — or with none, of
  /// every conversation but those [excluded] (the deleted ones), which is
  /// what the inbox gathers from.
  ///
  /// A user turn's conversation is the one its payload names; everything a
  /// run wrote for the turn — her reply, her question, the doors — is in
  /// the turn's conversation through its `operationId`.
  Future<FrontChatThread> build({
    String? conversationId,
    Set<String> excluded = const {},
  }) async {
    final rows = await _repository.getAgentMessages(frontAgentId);
    rows.sort(_chronological);

    // The turns in scope, with their words: read first — in one batch, as
    // the whole history is scoped — so a reply that reached this device
    // before its turn is still placed by it.
    final turnPayloads = await _repository.getEntitiesByIds({
      for (final row in rows)
        if (isFrontUserTurn(row)) ?row.contentEntryId,
    });
    final turnTexts = <String, String>{};
    for (final row in rows) {
      if (!isFrontUserTurn(row)) continue;
      final payload = turnPayloads[row.contentEntryId];
      if (payload is! AgentMessagePayloadEntity) continue;
      final conversation = frontConversationOf(payload.content);
      final inScope = conversationId == null
          ? !excluded.contains(conversation)
          : conversation == conversationId;
      final text = payload.content['text'];
      if (inScope && text is String && text.trim().isNotEmpty) {
        turnTexts[row.id] = text;
      }
    }

    final messages = <AgentChatMessage>[];
    final options = <String, List<FrontAskOption>>{};
    final doorRecords = <String, List<(String, FrontDoorRecord)>>{};

    for (final row in rows) {
      if (isFrontUserTurn(row)) {
        final text = turnTexts[row.id];
        if (text == null) continue;
        messages.add(_message(row, AgentChatRole.user, text));
      } else if (!turnTexts.containsKey(row.metadata.operationId)) {
        // Written for a turn of another conversation, or of none.
        continue;
      } else if (isFrontAnswerRow(row)) {
        switch (row.metadata.toolName) {
          case FrontAgentToolNames.replyToUser:
            final text = await _text(row.contentEntryId, 'text');
            if (text == null) continue;
            messages.add(_message(row, AgentChatRole.agent, text));
          case FrontAgentToolNames.askUser:
            final payload = await _payload(row.contentEntryId);
            final question = payload?.content['question'];
            if (question is! String || question.trim().isEmpty) continue;
            messages.add(_message(row, AgentChatRole.agent, question));
            final raw = payload!.content['options'];
            options[row.id] = [
              if (raw is List)
                for (final item in raw) ?FrontAskOption.fromJson(item),
            ];
        }
      } else if (_isDoorRow(row)) {
        final payload = await _payload(row.contentEntryId);
        final record = payload == null
            ? null
            : FrontDoorRecord.fromJson(payload.content);
        if (record == null) continue;
        doorRecords.putIfAbsent(row.metadata.operationId!, () => []).add((
          row.id,
          record,
        ));
      }
    }

    // The newest fifty — and every turn with a door still waiting on the
    // user, however old: the inbox is this thread filtered, so what the
    // user has not acted on must not scroll out of existence.
    final awaiting = {
      for (final entry in doorRecords.entries)
        if (entry.value.any((d) => frontDoorAwaitsUser(d.$2.outcome)))
          entry.key,
    };
    final window = messages.length <= maxMessages
        ? messages
        : messages.sublist(messages.length - maxMessages);
    // A waiting turn keeps the message right after it too: her reply, which
    // carries the turn's doors on the surface — or the next user turn, which
    // tells the surface no reply followed. Without it the doors would ride
    // whichever unrelated reply the window happened to show next.
    final kept = {...awaiting};
    for (var i = 0; i + 1 < messages.length; i++) {
      if (awaiting.contains(messages[i].id)) kept.add(messages[i + 1].id);
    }
    final windowIds = {for (final m in window) m.id};
    final visible = [
      for (final m in messages)
        if (windowIds.contains(m.id) || kept.contains(m.id)) m,
    ];
    final visibleIds = {for (final m in visible) m.id};

    final doors = <String, List<FrontDoorEntry>>{};
    final specialists = <String>{};
    for (final entry in doorRecords.entries) {
      if (!visibleIds.contains(entry.key)) continue;
      final records = entry.value
        ..sort((a, b) => a.$2.segmentIndex.compareTo(b.$2.segmentIndex));
      doors[entry.key] = [
        for (final (doorId, record) in records)
          FrontDoorEntry(
            doorId: doorId,
            record: record,
            specialistReply: await _specialistReply(record, specialists),
          ),
      ];
    }

    return FrontChatThread(
      messages: visible,
      optionsByMessageId: {
        for (final entry in options.entries)
          if (visibleIds.contains(entry.key)) entry.key: entry.value,
      },
      doorsByMessageId: doors,
      specialistAgentIds: specialists,
    );
  }

  /// The reply a goal or person agent wrote for the turn [record] handed
  /// it: the `reply_to_user` row of that agent whose `operationId` is the
  /// turn's message id.
  Future<String?> _specialistReply(
    FrontDoorRecord record,
    Set<String> specialists,
  ) async {
    if (record.outcome case FrontDoorChatTurn(
      :final specialistAgentId,
      :final specialistMessageId,
    )) {
      specialists.add(specialistAgentId);
      final rows = await _repository.getAgentMessages(specialistAgentId);
      for (final row in rows) {
        if (row.kind == AgentMessageKind.action &&
            row.metadata.toolName == AgentConversationToolNames.replyToUser &&
            row.metadata.operationId == specialistMessageId) {
          return _text(row.contentEntryId, 'text');
        }
      }
    }
    return null;
  }

  static bool _isDoorRow(AgentMessageEntity row) =>
      row.kind == AgentMessageKind.action &&
      row.metadata.toolName == frontDoorToolName &&
      row.metadata.operationId != null;

  static AgentChatMessage _message(
    AgentMessageEntity row,
    AgentChatRole role,
    String text,
  ) => AgentChatMessage(
    id: row.id,
    role: role,
    text: text.trim(),
    createdAt: row.createdAt,
    runKey: row.metadata.runKey,
  );

  Future<AgentMessagePayloadEntity?> _payload(String? id) async {
    if (id == null) return null;
    final entity = await _repository.getEntity(id);
    return entity is AgentMessagePayloadEntity ? entity : null;
  }

  Future<String?> _text(String? payloadId, String key) async {
    final payload = await _payload(payloadId);
    final text = payload?.content[key];
    return text is String && text.trim().isNotEmpty ? text : null;
  }

  static int _chronological(AgentMessageEntity a, AgentMessageEntity b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }
}
