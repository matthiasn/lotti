import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/widgetbook/insights_widgetbook.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('Productivity patterns detail page', () {
    late WidgetbookUseCase useCase;

    setUp(() {
      final folder = buildInsightsWidgetbookFolder();
      final children = folder.children!;
      final component = children[2] as WidgetbookComponent;
      expect(component.name, 'Productivity patterns');
      useCase = component.useCases.single;
      expect(useCase.name, 'Detail');
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

    testWidgets('renders header with back button and title', (tester) async {
      await pumpPage(tester);

      expect(find.text('Back'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
      expect(find.text('Productivity patterns'), findsOneWidget);
    });

    testWidgets('renders week dropdown', (tester) async {
      await pumpPage(tester);

      expect(find.text('Week'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('renders three score ring cards', (tester) async {
      await pumpPage(tester);

      expect(find.text('Productivity'), findsWidgets);
      expect(find.text('Energy'), findsWidgets);
      expect(find.text('Focus'), findsWidgets);
      expect(find.text('7.2'), findsOneWidget);
      expect(find.text('6.1'), findsOneWidget);
      expect(find.text('7.8'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders daily breakdown section with day labels', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('Daily breakdown'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('renders highlights section', (tester) async {
      await pumpPage(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('Highlights'), findsOneWidget);
      expect(
        find.textContaining('Best day: Tuesday'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Lowest day: Saturday'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Peak hours: 9am'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.byIcon(Icons.trending_down), findsNWidgets(2));
    });

    testWidgets('renders in light mode without errors', (tester) async {
      await pumpPage(tester, theme: DesignSystemTheme.light());

      expect(find.text('Productivity patterns'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
