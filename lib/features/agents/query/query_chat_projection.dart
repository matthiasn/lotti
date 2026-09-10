import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';

/// A chat's durable projection. Drafts, scroll positions and running requests
/// belong to device-local controllers, not this synced history.
class QueryChatHistory {
  const QueryChatHistory({
    required this.id,
    required this.scope,
    required this.title,
    required this.private,
    required this.archived,
    required this.lastActivity,
    required this.events,
    required this.unread,
  });

  final String id;
  final QueryScope scope;
  final String title;
  final bool private;
  final bool archived;
  final DateTime lastActivity;
  final List<AgentQueryChatEventEntity> events;
  final bool unread;

  List<AgentQueryChatEventEntity> get questions => events
      .where((event) => event.data is QueryChatQuestion)
      .toList(growable: false);

  AgentQueryChatEventEntity? answerFor(String questionId) => events
      .where(
        (event) =>
            event.data is QueryChatAnswer &&
            (event.data as QueryChatAnswer).questionId == questionId,
      )
      .lastOrNull;

  bool failed(String questionId) {
    if (answerFor(questionId) != null) return false;
    return events.any(
      (event) => switch (event.data) {
        QueryChatFailed(questionId: final id) => id == questionId,
        QueryChatCancelled(questionId: final id) => id == questionId,
        _ => false,
      },
    );
  }
}

/// Order-independent fold. A deletion wins over every other event, including
/// late replies and renames from a concurrently running device.
class QueryChatProjection {
  QueryChatProjection(Iterable<AgentQueryChatEventEntity> input) {
    final events = input.where((e) => e.deletedAt == null).toList()
      ..sort(compareQueryEvents);
    final grouped = <String, List<AgentQueryChatEventEntity>>{};
    final deleted = <String, bool>{};
    for (final event in events) {
      grouped.putIfAbsent(event.chatId, () => []).add(event);
      if (event.data case QueryChatDeleted(:final forget)) {
        deleted[event.chatId] = (deleted[event.chatId] ?? false) || forget;
      }
    }
    final available = {
      for (final event in events)
        if (event.data is QueryChatMemory && deleted[event.chatId] != true)
          event.id: event,
    };
    // A retained conclusion cannot reintroduce learning forgotten at its
    // origin through a chain of recalls in other chats.
    var removed = true;
    while (removed) {
      final invalid = available.values
          .where(
            (event) => (event.data as QueryChatMemory).recalledMemoryIds.any(
              (id) => !available.containsKey(id),
            ),
          )
          .map((event) => event.id)
          .toList();
      removed = invalid.isNotEmpty;
      invalid.forEach(available.remove);
    }
    memories = List.unmodifiable(available.values);
    final result = <QueryChatHistory>[];
    for (final MapEntry(key: id, value: rows) in grouped.entries) {
      if (deleted.containsKey(id)) continue;
      final creation = rows
          .where((e) => e.data is QueryChatCreated)
          .firstOrNull;
      if (creation == null) continue;
      final created = creation.data as QueryChatCreated;
      var title = created.title;
      var private = created.private;
      var archived = false;
      var readIndex = -1;
      final rowIndexes = {
        for (var index = 0; index < rows.length; index++) rows[index].id: index,
      };
      var lastActivity = creation.createdAt;
      for (final row in rows) {
        switch (row.data) {
          case QueryChatRenamed(title: final value, private: final hidden):
            title = value;
            private = hidden;
          case QueryChatArchived(archived: final value):
            archived = value;
          case QueryChatRead(:final throughEventId):
            final seenIndex = rowIndexes[throughEventId] ?? -1;
            if (seenIndex > readIndex) readIndex = seenIndex;
          default:
            break;
        }
        if (row.data is QueryChatQuestion || row.data is QueryChatAnswer) {
          lastActivity = row.createdAt;
        }
      }
      final lastAnswer = rows
          .where((e) => e.data is QueryChatAnswer)
          .lastOrNull;
      result.add(
        QueryChatHistory(
          id: id,
          scope: created.scope,
          title: title,
          private: private,
          archived: archived,
          lastActivity: lastActivity,
          events: List.unmodifiable(rows),
          unread: lastAnswer != null && rows.indexOf(lastAnswer) > readIndex,
        ),
      );
    }
    result.sort((a, b) {
      final time = b.lastActivity.compareTo(a.lastActivity);
      return time != 0 ? time : a.id.compareTo(b.id);
    });
    chats = List.unmodifiable(result);
  }

  late final List<QueryChatHistory> chats;
  late final List<AgentQueryChatEventEntity> memories;
}

int compareQueryEvents(
  AgentQueryChatEventEntity a,
  AgentQueryChatEventEntity b,
) {
  final time = a.createdAt.compareTo(b.createdAt);
  return time != 0 ? time : a.id.compareTo(b.id);
}
