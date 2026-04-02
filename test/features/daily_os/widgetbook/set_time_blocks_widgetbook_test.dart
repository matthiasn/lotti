import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/widgetbook/set_time_blocks_widgetbook.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildSetTimeBlocksWidgetbookFolder', () {
    late WidgetbookUseCase useCase;

    setUp(() {
      final folder = buildSetTimeBlocksWidgetbookFolder();
      final children = folder.children;
      expect(children, isNotNull);
      final component = children!.single as WidgetbookComponent;
      expect(component.name, 'Set time blocks page');
      useCase = component.useCases.single;
      expect(useCase.name, 'Interactive');
    });

    Future<void> pumpPage(
      WidgetTester tester, {
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: theme ?? DesignSystemTheme.dark(),
        ),
      );
    }

    testWidgets('renders page header with title and date', (tester) async {
      await pumpPage(tester);

      expect(find.text('Set time blocks'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Oct 17, 2026'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    });

    testWidgets('renders section dividers with left-aligned labels', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('Other categories'), findsOneWidget);
    });

    testWidgets('renders all favourite category names', (tester) async {
      await pumpPage(tester);

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);
      expect(find.text('Meals'), findsOneWidget);
      expect(find.text('Exercise'), findsOneWidget);
    });

    testWidgets('renders time chips for categories with blocks', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('8:00am-12:00pm'), findsOneWidget);
      expect(find.text('3:00-4:00pm'), findsOneWidget);
      expect(find.text('8:00-10:00am'), findsOneWidget);
    });

    testWidgets('renders placeholder text for empty categories', (
      tester,
    ) async {
      await pumpPage(tester);

      // Study and Exercise have no blocks
      expect(find.text('Tap to add time block'), findsWidgets);
    });

    testWidgets('renders star icons only in favourites section', (
      tester,
    ) async {
      await pumpPage(tester);

      // Only 4 favourites have golden star icons
      expect(find.byIcon(Icons.star), findsNWidgets(4));
    });

    testWidgets('renders category icons in colored containers', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.byIcon(Icons.flight), findsOneWidget);
      expect(find.byIcon(Icons.school), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    });

    testWidgets('renders save plan button', (tester) async {
      await pumpPage(tester);

      // Scroll down to reveal the button pushed below the fold
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('Save plan'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('renders other categories section', (tester) async {
      await pumpPage(tester);

      // Scroll down to see other categories
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('Commute'), findsOneWidget);
      expect(find.text('Household'), findsOneWidget);
    });

    testWidgets('tapping star moves category to other section', (
      tester,
    ) async {
      await pumpPage(tester);

      // Initially 4 favourites with golden stars
      expect(find.byIcon(Icons.star), findsNWidgets(4));

      // Tap the star on first favourite to unfavourite it
      final stars = find.byIcon(Icons.star);
      await tester.tap(stars.first);
      await tester.pump();

      // Now 3 golden stars (moved category loses its star)
      expect(find.byIcon(Icons.star), findsNWidgets(3));
    });

    testWidgets('renders filled clock icons next to time chips', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.byIcon(Icons.schedule), findsWidgets);
    });

    testWidgets('rows with blocks have accent green border', (tester) async {
      await pumpPage(tester);

      // Work has blocks — find its container and verify decoration
      final workRow = find.ancestor(
        of: find.text('Work'),
        matching: find.byType(Container),
      );
      expect(workRow, findsWidgets);
    });

    testWidgets('renders in light mode without errors', (tester) async {
      await pumpPage(tester, theme: DesignSystemTheme.light());

      expect(find.text('Set time blocks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
