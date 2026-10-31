import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/service/front_chat_history_service.dart';
import 'package:uuid/uuid.dart';

/// The user's conversations with the front agent: which exist, what they
/// are called, and renaming, archiving and deleting them.
///
/// A conversation is the user turns whose payload names it (see
/// [frontConversationOf]); its lifecycle is the query chat's own synced
/// events — `renamed`, `archived`, `deleted` — written under the front
/// agent's id with the conversation as the chat. A conversation has no
/// `created` event, so query chat's projection never lists one, and the
/// front agent's headless journal questions, which have no lifecycle
/// events, are never taken for a conversation here.
class FrontConversationService {
  const FrontConversationService({
    required AgentRepository repository,
    required AgentSyncService syncService,
  }) : this._(repository, syncService);

  const FrontConversationService._(this._repository, this._sync);

  final AgentRepository _repository;
  final AgentSyncService _sync;
  static const _uuid = Uuid();

  /// The longest title kept, as query chat bounds its own.
  static const maxTitleLength = 120;

  Future<FrontConversationIndex> load() async {
    final turns =
        (await _repository.getAgentMessages(
            frontAgentId,
          )).where((m) => m.deletedAt == null && isFrontUserTurn(m)).toList()
          ..sort((a, b) {
            final byTime = a.createdAt.compareTo(b.createdAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    final payloads = await _repository.getEntitiesByIds({
      for (final turn in turns) turn.contentEntryId!,
    });

    final firstText = <String, String>{};
    final lastActivity = <String, DateTime>{};
    for (final turn in turns) {
      final payload = payloads[turn.contentEntryId];
      if (payload is! AgentMessagePayloadEntity) continue;
      final id = frontConversationOf(payload.content);
      final text = payload.content['text'];
      if (text is String && text.trim().isNotEmpty) {
        firstText.putIfAbsent(id, () => _titleOf(text));
      }
      lastActivity[id] = turn.createdAt;
    }

    final events =
        (await _repository.getEntitiesByAgentId(
              frontAgentId,
              type: AgentEntityTypes.queryChatEvent,
            ))
            .whereType<AgentQueryChatEventEntity>()
            .where((e) => e.deletedAt == null)
            .toList()
          ..sort(compareQueryEvents);
    final renamed = <String, String>{};
    final archived = <String, bool>{};
    final deleted = <String>{};
    for (final event in events) {
      switch (event.data) {
        case QueryChatRenamed(:final title):
          renamed[event.chatId] = title;
        case QueryChatArchived(archived: final value):
          archived[event.chatId] = value;
        case QueryChatDeleted():
          deleted.add(event.chatId);
        default:
          break;
      }
    }

    final conversations =
        [
          for (final MapEntry(key: id, value: last) in lastActivity.entries)
            if (!deleted.contains(id))
              FrontConversation(
                id: id,
                title: renamed[id] ?? firstText[id] ?? '',
                lastActivity: last,
                archived: archived[id] ?? false,
              ),
        ]..sort((a, b) {
          final byTime = b.lastActivity.compareTo(a.lastActivity);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
    return FrontConversationIndex(
      conversations: conversations,
      deletedIds: deleted,
    );
  }

  Future<void> rename(String conversationId, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('Invalid conversation title');
    return _append(
      conversationId,
      QueryChatEventData.renamed(title: _bounded(trimmed)),
    );
  }

  Future<void> archive(String conversationId, {required bool archived}) =>
      _append(conversationId, QueryChatEventData.archived(archived: archived));

  /// Deletes the conversation for good: it leaves the list and its turns
  /// leave every view, the inbox included, on every device.
  Future<void> delete(String conversationId) =>
      _append(conversationId, const QueryChatEventData.deleted(forget: false));

  /// Appends one lifecycle event, stamped after the conversation's newest,
  /// so the fold reads them in the order they were made.
  Future<void> _append(String conversationId, QueryChatEventData data) async {
    final previous = await _repository.getEntitiesByAgentIdAndSubtype(
      frontAgentId,
      type: AgentEntityTypes.queryChatEvent,
      subtype: conversationId,
    );
    var createdAt = clock.now();
    for (final event in previous.whereType<AgentQueryChatEventEntity>()) {
      if (!event.createdAt.isBefore(createdAt)) {
        createdAt = event.createdAt.add(const Duration(microseconds: 1));
      }
    }
    await _sync.upsertEntity(
      AgentDomainEntity.queryChatEvent(
        id: _uuid.v4(),
        agentId: frontAgentId,
        chatId: conversationId,
        data: data,
        createdAt: createdAt,
        vectorClock: null,
      ),
    );
  }

  /// A title from the first question: its first line, bounded.
  static String _titleOf(String text) =>
      _bounded(text.trim().split('\n').first.trim());

  static String _bounded(String value) => value.length <= maxTitleLength
      ? value
      : '${value.substring(0, maxTitleLength - 1).trimRight()}…';
}
