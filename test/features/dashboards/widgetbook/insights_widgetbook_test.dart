import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/widgetbook/insights_widgetbook.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildInsightsWidgetbookFolder', () {
    late WidgetbookUseCase useCase;

    setUp(() {
      final folder = buildInsightsWidgetbookFolder();
      final children = folder.children;
      expect(children, isNotNull);
      final component = children!.first as WidgetbookComponent;
      expect(component.name, 'Insights dashboard');
      useCase = component.useCases.single;
      expect(useCase.name, 'Overview');
    });

    Future<void> pumpInsights(
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

    testWidgets('renders page header with title', (tester) async {
      await pumpInsights(tester);

      expect(find.text('Insights'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('renders summary section with title and filter', (
      tester,
    ) async {
      await pumpInsights(tester);

      expect(find.text('This week'), findsWidgets);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('renders four summary metric cards in 2x2 grid', (
      tester,
    ) async {
      await pumpInsights(tester);

      expect(find.text('24.5h'), findsOneWidget);
      expect(find.text('Total tracked'), findsOneWidget);
      expect(find.text('+3.2h'), findsOneWidget);

      expect(find.text('7.2'), findsWidgets);
      expect(find.text('Avg. productivity'), findsOneWidget);

      expect(find.text('Design'), findsWidgets);
      expect(find.text('Top category'), findsOneWidget);

      expect(find.text('12'), findsWidgets);
      expect(find.text('Interruptions'), findsWidgets);
    });

    testWidgets('renders time distribution bars for all categories', (
      tester,
    ) async {
      await pumpInsights(tester);

      expect(find.text('Time distribution'), findsOneWidget);
      expect(find.text('9.3h'), findsOneWidget);
      expect(find.text('6.5h'), findsOneWidget);
      expect(find.text('4.2h'), findsOneWidget);
      expect(find.text('2.8h'), findsOneWidget);
      expect(find.text('1.7h'), findsOneWidget);
    });

    testWidgets('renders productivity pattern score rings', (tester) async {
      await pumpInsights(tester);

      // Scroll down to see productivity patterns
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('Productivity patterns'), findsOneWidget);
      expect(find.text('Productivity'), findsOneWidget);
      expect(find.text('Energy'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders AI insight card with tip text', (tester) async {
      await pumpInsights(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(
        find.textContaining('Your focus ratings are 40% higher'),
        findsOneWidget,
      );
      expect(find.text('✦'), findsWidgets);
    });

    testWidgets('renders interruptions section with stats and badge', (
      tester,
    ) async {
      await pumpInsights(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('29%'), findsOneWidget);
      expect(find.text('Per session avg'), findsOneWidget);
      expect(find.text('Most interrupted'), findsOneWidget);
    });

    testWidgets('renders planning vs reality comparison bars', (
      tester,
    ) async {
      await pumpInsights(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();

      expect(find.text('Planning vs reality'), findsOneWidget);
      expect(find.text('+1.3h'), findsOneWidget);
      expect(find.text('-1.5h'), findsOneWidget);
      expect(find.text('+1.2h'), findsOneWidget);
      expect(find.text('Planned'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);
    });

    testWidgets('renders wellbeing section with stats and AI tip', (
      tester,
    ) async {
      await pumpInsights(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -1100));
      await tester.pump();

      expect(find.text('Wellbeing'), findsOneWidget);
      expect(find.text('2.1h'), findsOneWidget);
      expect(find.text('Avg session'), findsOneWidget);
      expect(find.text('Breaks taken'), findsOneWidget);
      expect(find.text('4h+ streaks'), findsOneWidget);
      expect(
        find.textContaining('Great week for breaks'),
        findsOneWidget,
      );
    });

    testWidgets('see all links visible in sections', (tester) async {
      await pumpInsights(tester);

      // Time distribution and Productivity patterns have "See all"
      // may need to scroll to see both
      expect(find.text('See all'), findsAtLeast(1));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(find.text('See all'), findsAtLeast(1));
    });

    testWidgets('renders in light mode without errors', (tester) async {
      await pumpInsights(tester, theme: DesignSystemTheme.light());

      expect(find.text('Insights'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
