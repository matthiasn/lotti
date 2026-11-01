import 'package:flutter/foundation.dart';

/// The conversation every turn written before conversations existed belongs
/// to. It is fixed rather than minted, so every device derives the same one
/// from the same untagged turns and the history never splits after sync —
/// and no migration is ever written.
const earlierConversationId = 'front-chat:earlier';

/// The key under which a user turn's payload names its conversation.
const frontConversationKey = 'conversationId';

/// The conversation a user turn belongs to, read from its payload [content]:
/// the one it names, else [earlierConversationId].
String frontConversationOf(Map<String, Object?> content) {
  final id = content[frontConversationKey];
  return id is String && id.trim().isNotEmpty ? id : earlierConversationId;
}

/// The key under which a user turn's payload names the categories its
/// question is narrowed to — the conversation's chips when it was sent.
const frontCategoriesKey = 'categoryIds';

/// The categories a user turn's payload [content] narrows its question to;
/// empty for none (her whole allow-list).
Set<String> frontCategoriesOf(Map<String, Object?> content) {
  final ids = content[frontCategoriesKey];
  return ids is List ? {...ids.whereType<String>()} : const {};
}

/// One conversation with the front agent, as the chat list shows it.
///
/// A conversation exists once it holds a turn: there is no creation record.
/// Its title is the user's own first question until they rename it.
@immutable
class FrontConversation {
  const FrontConversation({
    required this.id,
    required this.title,
    required this.lastActivity,
    required this.archived,
    this.preview,
  });

  final String id;
  final String title;

  /// The first line of her last answer, so a row says where the
  /// conversation got to; null until she has answered.
  final String? preview;

  /// When its newest turn was written.
  final DateTime lastActivity;
  final bool archived;
}

/// Every conversation the user has with her: the live ones newest first,
/// and the ids of those deleted, whose turns stay out of every view.
@immutable
class FrontConversationIndex {
  const FrontConversationIndex({
    required this.conversations,
    this.deletedIds = const {},
  });

  static const empty = FrontConversationIndex(conversations: []);

  /// Not deleted, newest activity first; archived ones included.
  final List<FrontConversation> conversations;
  final Set<String> deletedIds;

  /// The conversation the surface opens on when the user picked none: the
  /// newest one not archived.
  FrontConversation? get latest =>
      conversations.where((c) => !c.archived).firstOrNull;

  FrontConversation? byId(String? id) =>
      conversations.where((c) => c.id == id).firstOrNull;
}
