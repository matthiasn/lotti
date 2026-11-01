import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_category_scope.dart';

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
    container.listen(frontCategoryOptionsProvider, (_, _) {});
    await container.read(categoriesStreamProvider.future);
    await container.read(agentIdentityProvider(frontAgentId).future);
    return container;
  }

  List<String> idsOf(ProviderContainer c) =>
      c.read(frontCategoryOptionsProvider).map((c) => c.id).toList();

  test('the chips offer the active categories she may see, by name', () async {
    final container = await containerWith(const {'nests', 'colony', 'old'});

    expect(idsOf(container), ['colony', 'nests']);
  });

  test('with no allow-list every active category is offered', () async {
    final container = await containerWith(const {});

    expect(idsOf(container), ['colony', 'feeding', 'nests']);
  });

  test('each conversation keeps its own choice, and a second tap lets a '
      'chip go', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final scope = container.read(frontConversationCategoriesProvider.notifier)
      ..toggle('c-1', 'colony')
      ..toggle('c-1', 'nests')
      ..toggle('c-2', 'feeding');

    expect(scope.of('c-1'), {'colony', 'nests'});
    expect(scope.of('c-2'), {'feeding'});
    expect(scope.of('c-3'), isEmpty);

    scope.toggle('c-1', 'colony');
    expect(scope.of('c-1'), {'nests'});
  });
}
