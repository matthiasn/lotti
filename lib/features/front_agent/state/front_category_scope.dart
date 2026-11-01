import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';

/// The categories a conversation's chips can narrow her answers to: the
/// active ones she may see — her allow-list, or every visible category when
/// it is empty — by name. `categoriesStreamProvider` is scoped by lockdown,
/// so a locked-away category is never offered.
final Provider<List<CategoryDefinition>> frontCategoryOptionsProvider =
    Provider.autoDispose<List<CategoryDefinition>>((ref) {
      final categories = ref.watch(categoriesStreamProvider).value ?? const [];
      final identity = ref.watch(agentIdentityProvider(frontAgentId)).value;
      final allowed = identity is AgentIdentityEntity
          ? identity.allowedCategoryIds
          : const <String>{};
      return categories
          .where(
            (c) => c.active && (allowed.isEmpty || allowed.contains(c.id)),
          )
          .sortedBy((c) => c.name.toLowerCase());
    }, name: 'frontCategoryOptionsProvider');

/// The chips chosen per conversation, for the session: none chosen is her
/// whole allow-list. Each turn carries its conversation's choice when sent.
final NotifierProvider<FrontConversationCategories, Map<String, Set<String>>>
frontConversationCategoriesProvider =
    NotifierProvider<FrontConversationCategories, Map<String, Set<String>>>(
      FrontConversationCategories.new,
      name: 'frontConversationCategoriesProvider',
    );

class FrontConversationCategories extends Notifier<Map<String, Set<String>>> {
  @override
  Map<String, Set<String>> build() => const {};

  /// The categories chosen in [conversationId]; empty for none.
  Set<String> of(String conversationId) => state[conversationId] ?? const {};

  /// Chooses [categoryId] in [conversationId], or lets it go.
  void toggle(String conversationId, String categoryId) {
    final chosen = {...of(conversationId)};
    if (!chosen.remove(categoryId)) chosen.add(categoryId);
    state = {...state, conversationId: chosen};
  }
}
