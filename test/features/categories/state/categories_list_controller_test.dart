import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockCategoryRepository repository;
  late StreamController<List<CategoryDefinition>> categoriesController;
  late ProviderContainer container;

  setUp(() {
    repository = MockCategoryRepository();
    // Non-broadcast: events buffer until the provider subscribes.
    categoriesController = StreamController<List<CategoryDefinition>>();
    when(
      repository.watchCategories,
    ).thenAnswer((_) => categoriesController.stream);

    container = ProviderContainer(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    // LIFO teardown: dispose the container FIRST so the provider's stream
    // subscription cancels before close() awaits listener completion.
    addTearDown(categoriesController.close);
    addTearDown(container.dispose);
  });

  test('streams category lists from the repository', () async {
    final category = CategoryTestUtils.createTestCategory(
      id: 'cat-1',
      name: 'Work',
    );

    final sub = container.listen(categoriesStreamProvider, (_, _) {});
    addTearDown(sub.close);

    categoriesController.add([category]);
    final first = await container.read(categoriesStreamProvider.future);
    expect(first, [category]);

    // Subsequent emissions propagate too.
    categoriesController.add([]);
    await pumpEventQueue();
    expect(container.read(categoriesStreamProvider).value, isEmpty);
  });

  test('propagates stream errors as AsyncError', () async {
    final sub = container.listen(categoriesStreamProvider, (_, _) {});
    addTearDown(sub.close);

    categoriesController.addError(StateError('watch failed'));
    await expectLater(
      container.read(categoriesStreamProvider.future),
      throwsA(isA<StateError>()),
    );

    final state = container.read(categoriesStreamProvider);
    expect(state.hasError, isTrue);
  });
}
