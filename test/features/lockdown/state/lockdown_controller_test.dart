import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';
import 'package:lotti/features/lockdown/state/lockdown_category_options.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

CategoryDefinition _category(
  String id,
  String name, {
  bool active = true,
}) {
  final date = DateTime(2026);
  return CategoryDefinition(
    id: id,
    name: name,
    createdAt: date,
    updatedAt: date,
    vectorClock: null,
    private: false,
    active: active,
  );
}

void main() {
  late MockEntitiesCacheService cache;
  late ProviderContainer container;

  setUp(() async {
    cache = MockEntitiesCacheService();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EntitiesCacheService>(cache);
      },
    );
    container = ProviderContainer(
      overrides: [
        categoriesStreamProvider.overrideWith(
          (ref) => Stream.value([
            _category('zeta', 'Zeta'),
            _category('alpha', 'Alpha'),
            _category('gone', 'Gone', active: false),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(tearDownTestGetIt);

  group('LockdownController', () {
    test('starts inactive', () {
      expect(
        container.read(lockdownControllerProvider),
        LockdownState.inactive,
      );
    });

    test('lockToCategory stores a single-element set and mirrors it into the '
        'entities cache', () {
      container.read(lockdownControllerProvider.notifier).lockToCategory('a');

      final state = container.read(lockdownControllerProvider);
      expect(state.categoryIds, {'a'});
      expect(state.isActive, isTrue);
      verify(() => cache.lockedCategoryIds = {'a'}).called(1);
    });

    test('lockToCategories accepts several ids (model is multi-ready)', () {
      container.read(lockdownControllerProvider.notifier).lockToCategories({
        'a',
        'b',
      });

      expect(container.read(lockdownControllerProvider).categoryIds, {
        'a',
        'b',
      });
      verify(() => cache.lockedCategoryIds = {'a', 'b'}).called(1);
    });

    test('clear restores the inactive state and empties the cache scope', () {
      final controller = container.read(lockdownControllerProvider.notifier)
        ..lockToCategory('a')
        ..clear();

      expect(
        container.read(lockdownControllerProvider),
        LockdownState.inactive,
      );
      verify(() => cache.lockedCategoryIds = const <String>{}).called(1);
      expect(controller.state.isActive, isFalse);
    });

    test('re-applying the same state does not touch the cache again', () {
      container.read(lockdownControllerProvider.notifier)
        ..lockToCategory('a')
        ..lockToCategory('a');

      verify(() => cache.lockedCategoryIds = {'a'}).called(1);
    });
  });

  // Lockdown scoping of the underlying stream is covered by
  // categories_list_controller_test.dart; this provider only sorts and drops
  // inactive categories.
  group('lockdownCategoryOptionsProvider', () {
    setUp(() async {
      // Keep the derived provider (and the stream beneath it) alive for the
      // test; an unlistened stream provider is torn down before it emits.
      final subscription = container.listen(
        lockdownCategoryOptionsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(categoriesStreamProvider.future);
    });

    test('lists active categories sorted by name while inactive', () {
      final names = container
          .read(lockdownCategoryOptionsProvider)
          .map((c) => c.name)
          .toList();
      expect(names, ['Alpha', 'Zeta']);
    });
  });
}
