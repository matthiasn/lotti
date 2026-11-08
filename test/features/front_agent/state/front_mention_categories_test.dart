import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';

import '../../agents/test_data/entity_factories.dart';
import '../../categories/test_utils.dart';

void main() {
  final categories = [
    CategoryTestUtils.createTestCategory(id: 'nests', name: 'Nests'),
    CategoryTestUtils.createTestCategory(id: 'colony', name: 'colony'),
    CategoryTestUtils.createTestCategory(
      id: 'old',
      name: 'Archive',
      active: false,
    ),
    CategoryTestUtils.createTestCategory(id: 'feeding', name: 'Feeding'),
  ];

  Future<ProviderContainer> containerWith(Set<String> allowed) async {
    final container = ProviderContainer(
      overrides: [
        categoriesStreamProvider.overrideWith(
          (ref) => Stream.value(categories),
        ),
        agentIdentityProvider.overrideWith(
          (ref, id) async => makeTestIdentity(
            id: frontAgentId,
            agentId: frontAgentId,
            kind: AgentKinds.frontAgent,
            allowedCategoryIds: allowed,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(frontMentionCategoriesProvider, (_, _) {});
    await container.read(categoriesStreamProvider.future);
    await container.read(agentIdentityProvider(frontAgentId).future);
    return container;
  }

  List<String> idsOf(ProviderContainer c) =>
      c.read(frontMentionCategoriesProvider).map((c) => c.id).toList();

  test('@ offers the active categories she may see, by name', () async {
    final container = await containerWith(const {'nests', 'colony', 'old'});

    expect(idsOf(container), ['colony', 'nests']);
  });

  test('with no allow-list every active category is offered', () async {
    final container = await containerWith(const {});

    expect(idsOf(container), ['colony', 'feeding', 'nests']);
  });

  test('before she exists, every active category is offered', () async {
    final container = ProviderContainer(
      overrides: [
        categoriesStreamProvider.overrideWith(
          (ref) => Stream.value(categories),
        ),
        agentIdentityProvider.overrideWith((ref, id) async => null),
      ],
    );
    addTearDown(container.dispose);
    container.listen(frontMentionCategoriesProvider, (_, _) {});
    await container.read(categoriesStreamProvider.future);
    await container.read(agentIdentityProvider(frontAgentId).future);

    expect(idsOf(container), ['colony', 'feeding', 'nests']);
  });
}
