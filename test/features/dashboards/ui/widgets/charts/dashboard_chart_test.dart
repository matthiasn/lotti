import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('DashboardChart', () {
    testWidgets('renders the header and chart inside the level-02 surface', (
      tester,
    ) async {
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

      // The card paints the design-system level-02 surface with a hairline
      // border — not the default dark Card that made charts read as black
      // boxes in dark mode.
      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(DashboardChart),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, dsTokensLight.colors.background.level02);
      expect(decoration.border, isNotNull);
    });

    testWidgets('sizes the chart area to the given height', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DashboardChart(
            chart: Text('Chart'),
            chartHeader: Text('Header'),
            height: 240,
          ),
        ),
      );

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((b) => b.height == 240),
        isTrue,
        reason: 'Expected a SizedBox sizing the chart area to 240',
      );
    });

    testWidgets('composites the overlay over the chart when provided', (
      tester,
    ) async {
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
      expect(
        find.descendant(
          of: find.byType(DashboardChart),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses no overlay Stack when none is given', (tester) async {
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
      expect(
        find.descendant(
          of: find.byType(DashboardChart),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
    });
  });

  group('DashboardChartHeader', () {
    testWidgets('renders title, subtitle, trailing and a tappable action', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        makeTestableWidget(
          DashboardChartHeader(
            title: 'Heart Rate',
            subtitle: 'Resting, beats per minute',
            trailing: const Text('72'),
            action: IconButton(
              onPressed: () => tapped = true,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ),
      );

      expect(find.text('Heart Rate'), findsOneWidget);
      expect(find.text('Resting, beats per minute'), findsOneWidget);
      expect(find.text('72'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(tapped, isTrue);
    });

    testWidgets('omits subtitle and action when not provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DashboardChartHeader(title: 'Steps'),
        ),
      );

      expect(find.text('Steps'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('renders an empty subtitle as no caption row', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DashboardChartHeader(title: 'Weight', subtitle: ''),
        ),
      );

      // Title plus the empty subtitle: only the title Text should exist.
      expect(
        find.descendant(
          of: find.byType(DashboardChartHeader),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
    });
  });
}
