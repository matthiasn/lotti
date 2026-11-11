import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';

/// How many tasks named in the conversation the prompt carries.
const int frontConversationTasksMax = 8;

final RegExp _taskLink = RegExp('lotti://task/([A-Za-z0-9-]+)');

/// The tasks this conversation named, most recently named first, at most
/// [frontConversationTasksMax], each once: what "that one", "the previous
/// task" or "the one about X" resolves against.
///
/// [turns] are the conversation's visible messages with their payloads, in
/// any order. A task counts as named when her words link it or her reply
/// shows it as a card (listed or closed), a question
/// offered it, a dispatch routed to it, or a tap made or filed into it —
/// the made task has no link anywhere else, and "a follow-up to that" right
/// after the tap means it. A mention is dated by its message, a made task by
/// the tap: a door record keeps the time it was walked, and an old inbox
/// item tapped now is the newest thing named.
List<String> frontConversationTaskIds(
  Iterable<(AgentMessageEntity, AgentMessagePayloadEntity)> turns,
) {
  final mentions = [
    for (final (message, payload) in turns)
      for (final (id, at) in _taskIdsOf(message, payload.content))
        (id: id, at: at ?? message.createdAt),
  ];
  // List.sort is not stable: the index keeps a message's own order.
  final ordered =
      [
        for (final (i, mention) in mentions.indexed) (i, mention),
      ]..sort((a, b) {
        final byTime = b.$2.at.compareTo(a.$2.at);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
  final ids = <String>{};
  for (final (_, mention) in ordered) {
    if (ids.length >= frontConversationTasksMax) break;
    ids.add(mention.id);
  }
  return ids.toList();
}

/// The tasks one message names, each with the time it was named when that
/// is not the message's own.
Iterable<(String, DateTime?)> _taskIdsOf(
  AgentMessageEntity message,
  Map<String, Object?> content,
) sync* {
  Iterable<(String, DateTime?)> linked(Object? text) => text is String
      ? _taskLink.allMatches(text).map((match) => (match.group(1)!, null))
      : const [];

  if (message.kind == AgentMessageKind.user) {
    yield* linked(content['text']);
    return;
  }
  switch (message.metadata.toolName) {
    case FrontAgentToolNames.replyToUser:
      yield* linked(content['text']);
      // The tasks her cards show, which her words no longer link: latest
      // closed first, so the cap keeps the ones closed last.
      final cards = FrontClosedTaskCard.listFromJson(content['closedTasks']);
      for (final card in cards.reversed) {
        yield (card.id, null);
      }
      // What her surface shows: the tasks her cards list, and — as stored
      // since replies have surfaces — the ones a closed-task lookup found.
      final surface = FrontReplySurface.fromJson(content['surface']);
      for (final id in surface?.taskIds ?? const <String>[]) {
        yield (id, null);
      }
    case FrontAgentToolNames.askUser:
      yield* linked(content['question']);
      if (content['options'] case final List<Object?> options) {
        for (final option in options) {
          if (option case {
            'kind': 'task',
            'id': final String id,
          } when id.isNotEmpty) {
            yield (id, null);
          }
        }
      }
    case FrontAgentToolNames.dispatch:
      if (content['segments'] is! List) return;
      for (final segment in FrontDispatch.fromJson(content).segments) {
        if (segment.destinationId case final id?
            when segment.kind == FrontDestinationKind.task) {
          yield (id, null);
        }
        if (segment.task?.followsUpTaskId case final id?) yield (id, null);
      }
    case frontDoorToolName:
      final record = FrontDoorRecord.fromJson(content);
      if (record == null) return;
      if (record.outcome case FrontDoorTaskCreated(:final taskId, :final at)) {
        yield (taskId, at);
      }
      if (record.destinationId case final id?
          when record.kind == FrontDestinationKind.task) {
        yield (id, null);
      }
  }
}
