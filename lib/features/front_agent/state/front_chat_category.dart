import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';

/// A category the user picked in the composer, for the conversation it was
/// picked in; a null [categoryId] is "Everything".
@immutable
class FrontChatCategoryPick {
  const FrontChatCategoryPick({
    required this.conversationId,
    required this.categoryId,
  });

  final String conversationId;
  final String? categoryId;
}

/// What the user picked since the open conversation's newest turn: held
/// beside the draft, keep-alive, so a chat not yet begun keeps its pick
/// until its first turn carries it. Keyed by the conversation it was made
/// in, so a pick never follows the user into another; the composer also
/// drops it on every switch (`FrontChatController`).
final frontChatCategoryPickProvider =
    NotifierProvider<FrontChatCategoryPicker, FrontChatCategoryPick?>(
      FrontChatCategoryPicker.new,
      name: 'frontChatCategoryPickProvider',
    );

class FrontChatCategoryPicker extends Notifier<FrontChatCategoryPick?> {
  @override
  FrontChatCategoryPick? build() => null;

  /// Scopes [conversationId] to [categoryId] from its next turn on; null for
  /// "Everything".
  void pick(String conversationId, String? categoryId) =>
      state = FrontChatCategoryPick(
        conversationId: conversationId,
        categoryId: categoryId,
      );

  /// Back to what the conversation's own turns say.
  void reset() => state = null;
}

/// The open conversation's category, which every turn sent from it carries
/// (`frontCategoriesKey`): what the user picked since, else the scope of its
/// newest turn; null for "Everything".
///
/// Only a category she may see is ever one: the options are `@`'s
/// ([frontMentionCategoriesProvider]), so lockdown and her allow-list hold
/// without more code. A stored one she may no longer see reads as
/// "Everything" — her workflow refuses to widen her scope to it anyway
/// (`frontNarrowedCategories`).
final Provider<CategoryDefinition?> frontChatCategoryProvider =
    Provider.autoDispose<CategoryDefinition?>((ref) {
      final conversationId = ref.watch(frontActiveConversationProvider).value;
      if (conversationId == null) return null;
      return frontChatCategoryOf(
        conversationId,
        pick: ref.watch(frontChatCategoryPickProvider),
        conversation: ref
            .watch(frontConversationsProvider)
            .value
            ?.byId(conversationId),
        options: ref.watch(frontMentionCategoriesProvider),
      );
    }, name: 'frontChatCategoryProvider');

/// The category [conversationId] is scoped to: [pick] when it was made
/// there, else the scope of [conversation]'s newest turn — and only while
/// it is one of [options]; null for "Everything". What the chip shows and
/// what a send carries, so the two never differ.
CategoryDefinition? frontChatCategoryOf(
  String conversationId, {
  required FrontChatCategoryPick? pick,
  required FrontConversation? conversation,
  required List<CategoryDefinition> options,
}) {
  final id = frontChatCategoryIdOf(
    conversationId,
    pick: pick,
    conversation: conversation,
  );
  if (id == null) return null;
  return options.where((category) => category.id == id).firstOrNull;
}

/// The id of the category [conversationId] is scoped to, before it is
/// checked against what she may see: [pick] when it was made there, else
/// the scope of [conversation]'s newest turn. A send carries this while the
/// categories are still loading, rather than dropping the scope.
String? frontChatCategoryIdOf(
  String conversationId, {
  required FrontChatCategoryPick? pick,
  required FrontConversation? conversation,
}) => pick != null && pick.conversationId == conversationId
    ? pick.categoryId
    : conversation?.categoryIds.firstOrNull;
