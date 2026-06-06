import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_filter.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:mocktail/mocktail.dart';

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

  Future<void> openModal(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('dashboard_category_filter')));
    // Bounded pump for the bottom-sheet entrance animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Icon filterIcon(WidgetTester tester) => tester.widget<Icon>(
    find.descendant(
      of: find.byKey(const Key('dashboard_category_filter')),
      matching: find.byType(Icon),
    ),
  );

  double chipOpacity(WidgetTester tester, String name) => tester
      .widget<Opacity>(
        find.ancestor(
          of: find.widgetWithText(ActionChip, name),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

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

    testWidgets('opens the modal listing one dimmed chip per category', (
      tester,
    ) async {
      await pumpFilter(tester);
      await openModal(tester);

      expect(find.byType(ActionChip), findsNWidgets(2));
      // Unselected chips render dimmed.
      expect(chipOpacity(tester, 'Mindfulness'), 0.4);
      expect(chipOpacity(tester, 'Yoga'), 0.4);
    });

    testWidgets('tapping a chip selects it and activates the filter icon', (
      tester,
    ) async {
      await pumpFilter(tester);
      await openModal(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'Mindfulness'));
      await tester.pump();

      // The tapped chip lights up; the other stays dimmed.
      expect(chipOpacity(tester, 'Mindfulness'), 1.0);
      expect(chipOpacity(tester, 'Yoga'), 0.4);

      // The filter button behind the sheet flips to the active state.
      final icon = filterIcon(tester);
      final tokens = tester
          .element(find.byKey(const Key('dashboard_category_filter')))
          .designTokens;
      expect(icon.icon, Icons.filter_alt_rounded);
      expect(icon.color, tokens.colors.text.highEmphasis);
    });

    testWidgets('tapping a selected chip clears the selection again', (
      tester,
    ) async {
      await pumpFilter(tester);
      await openModal(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'Mindfulness'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ActionChip, 'Mindfulness'));
      await tester.pump();

      expect(chipOpacity(tester, 'Mindfulness'), 0.4);
      expect(filterIcon(tester).icon, Icons.filter_alt_outlined);
    });
  });
}
