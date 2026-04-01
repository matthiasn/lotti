import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/widgetbook/insights_widgetbook.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('Time distribution detail page', () {
    late WidgetbookUseCase useCase;

    setUp(() {
      final folder = buildInsightsWidgetbookFolder();
      final children = folder.children!;
      final component = children[1] as WidgetbookComponent;
      expect(component.name, 'Time distribution');
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
      expect(find.text('Time distribution'), findsOneWidget);
    });

    testWidgets('renders week dropdown', (tester) async {
      await pumpPage(tester);

      expect(find.text('Week'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('renders donut chart with total label', (tester) async {
      await pumpPage(tester);

      expect(find.text('24.5h'), findsOneWidget);
      expect(find.text('total'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders category list with dots, hours, and percentages', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('Design'), findsWidgets);
      expect(find.text('9.3h'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);

      expect(find.text('Development'), findsWidgets);
      expect(find.text('6.5h'), findsOneWidget);
      expect(find.text('27%'), findsOneWidget);

      expect(find.text('Meetings'), findsWidgets);
      expect(find.text('4.2h'), findsOneWidget);
      expect(find.text('17%'), findsOneWidget);
    });

    testWidgets('renders vs last week section header', (tester) async {
      await pumpPage(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('vs last week'), findsOneWidget);
    });

    testWidgets('renders week comparison deltas', (tester) async {
      await pumpPage(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('+1.2h'), findsOneWidget);
      expect(find.text('-0.8h'), findsOneWidget);
      expect(find.text('+0.5h'), findsOneWidget);
      expect(find.text('+0.3h'), findsOneWidget);
      expect(find.text('-0.2h'), findsOneWidget);
    });

    testWidgets('renders in light mode without errors', (tester) async {
      await pumpPage(tester, theme: DesignSystemTheme.light());

      expect(find.text('Time distribution'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
