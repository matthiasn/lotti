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

    testWidgets('renders the date axis under the chart when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DashboardChart(
            chart: Text('Chart'),
            chartHeader: Text('Header'),
            height: 200,
            dateAxis: Text('Date Axis'),
          ),
        ),
      );

      expect(find.text('Date Axis'), findsOneWidget);
    });

    testWidgets('hides the date axis while loading (chart not shown)', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DashboardChart(
            chart: Text('Chart'),
            chartHeader: Text('Header'),
            height: 200,
            isLoading: true,
            dateAxis: Text('Date Axis'),
          ),
        ),
      );

      // The chart itself is replaced by the progress affordance, so the date
      // axis must not render either.
      expect(find.text('Chart'), findsNothing);
      expect(find.text('Date Axis'), findsNothing);
    });

    testWidgets('hides the date axis when empty (no data in range)', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DashboardChart(
            chart: Text('Chart'),
            chartHeader: Text('Header'),
            height: 200,
            isEmpty: true,
            emptyMessage: 'No data',
            dateAxis: Text('Date Axis'),
          ),
        ),
      );

      expect(find.text('No data'), findsOneWidget);
      expect(find.text('Date Axis'), findsNothing);
    });

    testWidgets(
      'collapses an empty card so it never reserves the full chart height',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            const DashboardChart(
              chart: Text('Chart'),
              chartHeader: Text('Header'),
              height: 240,
              isEmpty: true,
              emptyMessage: 'No data',
              footer: Text('Legend'),
            ),
          ),
        );

        // The notice replaces the plot: the chart content and its legend never
        // render, so an empty card adds no visual weight beyond the header.
        expect(find.text('No data'), findsOneWidget);
        expect(find.text('Chart'), findsNothing);
        expect(find.text('Legend'), findsNothing);

        // Critically, no SizedBox reserves the 240px chart area — that height
        // is exactly the space the collapse reclaims for the charts that have
        // data.
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(
          sizedBoxes.any((b) => b.height == 240),
          isFalse,
          reason: 'An empty card must not reserve the full chart height',
        );

        // The collapsed card is far shorter than the reserved height it
        // replaces.
        expect(
          tester.getSize(find.byType(DashboardChart)).height,
          lessThan(240),
        );
      },
    );

    testWidgets(
      'an empty card without a message collapses to just its header',
      (tester) async {
        Future<double> cardHeight({String? emptyMessage}) async {
          await tester.pumpWidget(
            makeTestableWidget(
              DashboardChart(
                chart: const Text('Chart'),
                chartHeader: const Text('Header'),
                height: 240,
                isEmpty: true,
                emptyMessage: emptyMessage,
              ),
            ),
          );
          return tester.getSize(find.byType(DashboardChart)).height;
        }

        final withMessage = await cardHeight(emptyMessage: 'No data');
        final withoutMessage = await cardHeight();

        // No stray gap under the header: dropping the message leaves only the
        // header, so the card is strictly shorter than when a notice is shown.
        expect(find.text('No data'), findsNothing);
        expect(withoutMessage, lessThan(withMessage));
      },
    );

    testWidgets(
      'keeps the full chart height during the initial load even with no data',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            const DashboardChart(
              chart: Text('Chart'),
              chartHeader: Text('Header'),
              height: 240,
              isLoading: true,
              isEmpty: true,
              emptyMessage: 'No data',
            ),
          ),
        );

        // Loading wins over empty: the spinner sits where the chart will land,
        // so the card does not first collapse and then jump back open.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('No data'), findsNothing);

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(
          sizedBoxes.any((b) => b.height == 240),
          isTrue,
          reason: 'The initial load keeps the full chart height reserved',
        );
      },
    );
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
