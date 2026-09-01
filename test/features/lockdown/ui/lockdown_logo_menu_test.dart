import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/features/lockdown/ui/lockdown_logo_menu.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

CategoryDefinition _category(String id, String name, {CategoryIcon? icon}) {
  final date = DateTime(2026);
  return CategoryDefinition(
    id: id,
    name: name,
    color: '#FF0000',
    icon: icon,
    createdAt: date,
    updatedAt: date,
    vectorClock: null,
    private: false,
    active: true,
  );
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EntitiesCacheService>(
          MockEntitiesCacheService(),
        );
      },
    );
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(tearDownTestGetIt);

  /// Builds the menu rows and header for [categories] against the live
  /// controller in [container].
  Future<({List<DesignSystemContextMenuItem> items, String header})> build(
    WidgetTester tester,
    List<CategoryDefinition> categories,
  ) async {
    late List<DesignSystemContextMenuItem> items;
    late String header;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: makeTestableWidget2(
          Consumer(
            builder: (context, ref, _) {
              final lockdown = ref.watch(lockdownControllerProvider);
              header = LockdownLogoMenu.header(context, lockdown);
              items = LockdownLogoMenu.items(
                context,
                ref,
                lockdown: lockdown,
                categories: categories,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return (items: items, header: header);
  }

  testWidgets('inactive: one row per category, no exit row, picker heading', (
    tester,
  ) async {
    final menu = await build(tester, [
      _category('work', 'Work', icon: CategoryIcon.fitness),
      _category('health', 'Health'),
    ]);

    expect(menu.header, 'Lock to a category');
    expect(menu.items.map((i) => i.label), ['Work', 'Health']);
    expect(menu.items.every((i) => !i.isSelected), isTrue);
    expect(menu.items.first.icon, categoryIconData[CategoryIcon.fitness]);
    expect(menu.items.first.iconColor, const Color(0xFFFF0000));
    expect(find.byKey(lockdownMenuClearKey), findsNothing);
    expect(menu.items.any((i) => i.key == lockdownMenuClearKey), isFalse);
  });

  testWidgets('tapping a category row locks the app to that category', (
    tester,
  ) async {
    final menu = await build(tester, [_category('work', 'Work')]);

    menu.items.single.onTap!();

    expect(
      container.read(lockdownControllerProvider),
      const LockdownState(categoryIds: {'work'}),
    );
  });

  testWidgets(
    'active: only the locked category (selected, inert) plus the exit row',
    (tester) async {
      container
          .read(lockdownControllerProvider.notifier)
          .lockToCategory('work');
      // Even an unfiltered list must not name the hidden category.
      final menu = await build(tester, [
        _category('work', 'Work'),
        _category('health', 'Health'),
      ]);

      expect(menu.header, 'Locked down');
      expect(menu.items.map((i) => i.label), ['Work', 'Exit lockdown']);
      expect(menu.items.first.isSelected, isTrue);
      expect(menu.items.first.onTap, isNull);
      expect(menu.items.last.key, lockdownMenuClearKey);

      menu.items.last.onTap!();
      expect(container.read(lockdownControllerProvider).isActive, isFalse);
    },
  );

  testWidgets('no categories: a single placeholder row that does nothing', (
    tester,
  ) async {
    final menu = await build(tester, const []);

    expect(menu.items.single.label, 'No categories yet');
    expect(menu.items.single.onTap, isNull);
  });
}
