import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_filter.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final categoryYoga = categoryMindfulness.copyWith(
    id: 'category-yoga',
    name: 'Yoga',
    color: '#FFFFFFFF',
  );

  setUp(() async {
    final mocks = await setUpTestGetIt();
    when(
      mocks.journalDb.getAllCategories,
    ).thenAnswer((_) async => [categoryMindfulness, categoryYoga]);

    // The picker rows resolve their icon via the cache.
    final mockCache = MockEntitiesCacheService();
    when(
      () => mockCache.sortedCategories,
    ).thenReturn([categoryMindfulness, categoryYoga]);
    when(
      () => mockCache.getCategoryById(categoryMindfulness.id),
    ).thenReturn(categoryMindfulness);
    when(
      () => mockCache.getCategoryById(categoryYoga.id),
    ).thenReturn(categoryYoga);
    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
    getIt.registerSingleton<EntitiesCacheService>(mockCache);
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpFilter(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const DashboardsFilter()),
    );
    // Let the categories stream resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('dashboard_category_filter')));
    // Bounded pump for the bottom-sheet entrance animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> applyPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('category-picker-apply')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Icon filterIcon(WidgetTester tester) => tester.widget<Icon>(
    find.descendant(
      of: find.byKey(const Key('dashboard_category_filter')),
      matching: find.byType(Icon),
    ),
  );

  group('DashboardsFilter', () {
    testWidgets('shows the outlined low-emphasis icon with no selection', (
      tester,
    ) async {
      await pumpFilter(tester);

      final icon = filterIcon(tester);
      final tokens = tester
          .element(find.byKey(const Key('dashboard_category_filter')))
          .designTokens;
      expect(icon.icon, Icons.filter_alt_outlined);
      expect(icon.color, tokens.colors.text.lowEmphasis);
    });

    testWidgets('opens the picker listing every category', (tester) async {
      await pumpFilter(tester);
      await openPicker(tester);

      expect(find.byType(CategoryPickerSheet), findsOneWidget);
      expect(find.text('Mindfulness'), findsOneWidget);
      expect(find.text('Yoga'), findsOneWidget);
    });

    testWidgets('icon stays inactive until Apply commits the selection', (
      tester,
    ) async {
      await pumpFilter(tester);
      await openPicker(tester);

      await tester.tap(find.text('Mindfulness'));
      await tester.pump();

      // Deferred: staging a category does not change the filter behind the
      // sheet — the icon only flips once Apply commits.
      expect(filterIcon(tester).icon, Icons.filter_alt_outlined);

      await applyPicker(tester);

      final icon = filterIcon(tester);
      final tokens = tester
          .element(find.byKey(const Key('dashboard_category_filter')))
          .designTokens;
      expect(icon.icon, Icons.filter_alt_rounded);
      expect(icon.color, tokens.colors.text.highEmphasis);
    });

    testWidgets('deselecting and applying clears the filter again', (
      tester,
    ) async {
      await pumpFilter(tester);

      // Select + Apply.
      await openPicker(tester);
      await tester.tap(find.text('Mindfulness'));
      await tester.pump();
      await applyPicker(tester);
      expect(filterIcon(tester).icon, Icons.filter_alt_rounded);

      // Reopen (seeded with the committed set), deselect + Apply.
      await openPicker(tester);
      await tester.tap(find.text('Mindfulness'));
      await tester.pump();
      await applyPicker(tester);
      expect(filterIcon(tester).icon, Icons.filter_alt_outlined);
    });
  });
}
