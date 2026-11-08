import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';

/// The categories `@` offers in her composer: the active ones she may see —
/// her allow-list, or every visible category when it is empty — by name.
/// Naming one in the question narrows her answer to it.
/// `categoriesStreamProvider` is scoped by lockdown, so a locked-away
/// category is never offered.
final Provider<List<CategoryDefinition>> frontMentionCategoriesProvider =
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
    }, name: 'frontMentionCategoriesProvider');
