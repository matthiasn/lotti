import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('DashboardChart', () {
    testWidgets('renders chart, header, and respects height', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DashboardChart(
            chart: Text('Chart Content'),
            chartHeader: Text('Chart Header'),
            height: 200,
          ),
        ),
      );

      expect(find.text('Chart Content'), findsOneWidget);
      expect(find.text('Chart Header'), findsOneWidget);

      final sizedBox = tester.widget<SizedBox>(
        find.byType(SizedBox).first,
      );
      expect(sizedBox.height, 200);
    });

    testWidgets('renders overlay when provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DashboardChart(
            chart: Text('Chart'),
            chartHeader: Text('Header'),
            height: 200,
            overlay: Text('Overlay Content'),
          ),
        ),
      );

      expect(find.text('Overlay Content'), findsOneWidget);
    });

    testWidgets('does not render overlay when null', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DashboardChart(
            chart: Text('Chart'),
            chartHeader: Text('Header'),
            height: 200,
          ),
        ),
      );

      expect(find.text('Overlay Content'), findsNothing);
    });

    testWidgets('applies top margin to chart padding', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DashboardChart(
            chart: Text('Chart'),
            chartHeader: Text('Header'),
            height: 300,
            topMargin: 20,
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.byWidgetPredicate(
          (w) =>
              w is Padding &&
              w.padding is EdgeInsets &&
              (w.padding as EdgeInsets).top == 45, // 25 + 20
        ),
      );
      expect(padding, isNotNull);
    });
  });
}
