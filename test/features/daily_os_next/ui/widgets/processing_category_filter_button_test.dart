import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEntitiesCacheService cache;
  late TestGetItMocks mocks;
  late CategoryDefinition work;
  late CategoryDefinition personal;

  setUp(() async {
    work = CategoryTestUtils.createTestCategory(
      id: 'cat_work',
      name: 'Actual Work',
    );
    personal = CategoryTestUtils.createTestCategory(
      id: 'cat_personal',
      name: 'Actual Personal',
    );
    cache = MockEntitiesCacheService();
    _stubCategories(cache, [personal, work]);
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EntitiesCacheService>(cache);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(
          body: Center(child: ProcessingCategoryFilterButton()),
        ),
      ),
    );
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('opens the Wolt multi-select picker with user categories', (
    tester,
  ) async {
    await pumpButton(tester);
    await openPicker(tester);

    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(find.text('Actual Personal'), findsOneWidget);
    expect(find.text('Actual Work'), findsOneWidget);
    expect(find.text('Health'), findsNothing);
    expect(find.text('Meals'), findsNothing);
  });

  testWidgets('persists omitted user categories when confirmed', (
    tester,
  ) async {
    await pumpButton(tester);
    await openPicker(tester);
    await tester.tap(find.text('Actual Personal'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    verify(
      () => mocks.settingsDb.saveSettingsItem(
        dailyOsExcludedCategoryIdsSettingsKey,
        '["cat_personal"]',
      ),
    ).called(1);
  });

  testWidgets('toggling a category off then on re-selects it', (
    tester,
  ) async {
    await pumpButton(tester);
    await openPicker(tester);

    // Both categories selected initially.
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));

    // Toggle off: the remove branch leaves one selected, one unchecked.
    await tester.tap(find.text('Actual Personal'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);

    // Toggle on again: the add branch re-selects it.
    await tester.tap(find.text('Actual Personal'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);

    // Confirm: no exclusions persisted because everything is selected again.
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    verify(
      () => mocks.settingsDb.saveSettingsItem(
        dailyOsExcludedCategoryIdsSettingsKey,
        '[]',
      ),
    ).called(1);
  });

  testWidgets('Include all re-selects every category after a deselection', (
    tester,
  ) async {
    await pumpButton(tester);
    await openPicker(tester);

    // Deselect one category so "Include all" has an observable effect.
    await tester.tap(find.text('Actual Personal'));
    await tester.pump();
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);

    await tester.tap(find.text('Include all'));
    await tester.pump();

    // Every category is selected again.
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    verify(
      () => mocks.settingsDb.saveSettingsItem(
        dailyOsExcludedCategoryIdsSettingsKey,
        '[]',
      ),
    ).called(1);
  });

  testWidgets('shows the empty message when no categories exist', (
    tester,
  ) async {
    _stubCategories(cache, const []);

    await pumpButton(tester);
    await openPicker(tester);

    expect(find.text('No categories available yet.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);

    // Confirming with no categories persists an empty exclusion set.
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    verify(
      () => mocks.settingsDb.saveSettingsItem(
        dailyOsExcludedCategoryIdsSettingsKey,
        '[]',
      ),
    ).called(1);
  });
}

void _stubCategories(
  MockEntitiesCacheService cache,
  List<CategoryDefinition> categories,
) {
  final categoriesById = {
    for (final category in categories) category.id: category,
  };
  when(() => cache.sortedCategories).thenReturn(categories);
  when(
    () => cache.getCategoryById(any()),
  ).thenAnswer((invocation) {
    final categoryId = invocation.positionalArguments.single as String?;
    return categoriesById[categoryId];
  });
}
