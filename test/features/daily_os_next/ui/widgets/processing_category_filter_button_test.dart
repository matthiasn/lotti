import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

// Exact Wolt modal transition durations for the bottom-sheet modal type the
// picker resolves to under the phone-sized test surface (width 390 < 560
// breakpoint): opening uses the enter duration, applying (pop) uses the
// reverse duration. Pumping the precise duration once drives the transition
// to completion without resorting to pumpAndSettle.
const _modalEnterDuration = Duration(milliseconds: 350);
const _modalReverseDuration = Duration(milliseconds: 250);

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
      isAvailableForDayPlan: true,
    );
    personal = CategoryTestUtils.createTestCategory(
      id: 'cat_personal',
      name: 'Actual Personal',
      isAvailableForDayPlan: true,
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
    await tester.pump(_modalEnterDuration);
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('category-picker-apply')));
    await tester.pump();
    await tester.pump(_modalReverseDuration);
  }

  // The number of rows currently included (checked) in the multi picker.
  int includedCount(WidgetTester tester) => tester
      .widgetList<DesignSystemCheckbox>(find.byType(DesignSystemCheckbox))
      .where((cb) => cb.value == true)
      .length;

  testWidgets('opens the picker seeded with the included categories', (
    tester,
  ) async {
    await pumpButton(tester);
    await openPicker(tester);

    expect(find.text('Actual Personal'), findsOneWidget);
    expect(find.text('Actual Work'), findsOneWidget);
    expect(find.text('Health'), findsNothing);
    // No exclusions yet -> both day-plan categories start included.
    expect(includedCount(tester), 2);
  });

  testWidgets('persists omitted categories as exclusions when applied', (
    tester,
  ) async {
    await pumpButton(tester);
    await openPicker(tester);
    await tester.tap(find.text('Actual Personal'));
    await tester.pump();
    await apply(tester);

    verify(
      () => mocks.settingsDb.saveSettingsItem(
        dailyOsExcludedCategoryIdsSettingsKey,
        '["cat_personal"]',
      ),
    ).called(1);
  });

  testWidgets('toggling a category off then on re-includes it', (
    tester,
  ) async {
    await pumpButton(tester);
    await openPicker(tester);
    expect(includedCount(tester), 2);

    await tester.tap(find.text('Actual Personal'));
    await tester.pump();
    expect(includedCount(tester), 1);

    await tester.tap(find.text('Actual Personal'));
    await tester.pump();
    expect(includedCount(tester), 2);

    await apply(tester);

    // Everything included again -> no exclusions persisted.
    verify(
      () => mocks.settingsDb.saveSettingsItem(
        dailyOsExcludedCategoryIdsSettingsKey,
        '[]',
      ),
    ).called(1);
  });

  testWidgets('only categories opted into day planning appear', (
    tester,
  ) async {
    final unflagged = CategoryTestUtils.createTestCategory(
      id: 'cat_unflagged',
      name: 'Not For Day Plan',
    );
    final optedOut = CategoryTestUtils.createTestCategory(
      id: 'cat_opted_out',
      name: 'Opted Out',
      isAvailableForDayPlan: false,
    );
    _stubCategories(cache, [personal, work, unflagged, optedOut]);

    await pumpButton(tester);
    await openPicker(tester);

    expect(find.text('Actual Personal'), findsOneWidget);
    expect(find.text('Actual Work'), findsOneWidget);
    expect(find.text('Not For Day Plan'), findsNothing);
    expect(find.text('Opted Out'), findsNothing);
    expect(includedCount(tester), 2);
  });

  testWidgets('shows the empty state when no category is day-plan enabled', (
    tester,
  ) async {
    _stubCategories(cache, [
      CategoryTestUtils.createTestCategory(
        id: 'cat_unflagged',
        name: 'Not For Day Plan',
      ),
    ]);

    await pumpButton(tester);
    await openPicker(tester);

    expect(find.text('No matches'), findsOneWidget);
    expect(includedCount(tester), 0);
  });

  testWidgets('applying with no day-plan categories persists no exclusions', (
    tester,
  ) async {
    _stubCategories(cache, const []);

    await pumpButton(tester);
    await openPicker(tester);
    expect(find.text('No matches'), findsOneWidget);

    await apply(tester);

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
