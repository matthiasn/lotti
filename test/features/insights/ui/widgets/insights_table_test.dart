import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_table.dart';

import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

void main() {
  const desktopMq = MediaQueryData(size: Size(1280, 900));

  final resolver = InsightsCategoryResolver(
    categoriesById: {
      'cat-client': CategoryTestUtils.createTestCategory(
        id: 'cat-client',
        name: 'Client Work',
        color: '#3B82F6',
      ),
    },
    uncategorizedLabel: 'Uncategorized',
    otherLabel: 'Other',
    deletedLabel: 'Deleted category',
  );

  Future<void> pumpTable(
    WidgetTester tester,
    List<InsightsTableRow> rows,
  ) {
    return tester.pumpWidget(
      makeTestableWidget(
        mediaQueryData: desktopMq,
        InsightsTable(rows: rows, resolver: resolver),
      ),
    );
  }

  testWidgets('renders one labeled row per category with formatted values', (
    tester,
  ) async {
    await pumpTable(tester, const [
      InsightsTableRow(
        categoryId: 'cat-client',
        seconds: 2 * 3600 + 15 * 60,
        share: 0.75,
        avgSecondsPerDay: 1158,
      ),
      InsightsTableRow(
        categoryId: null,
        seconds: 45 * 60,
        share: 0.25,
        avgSecondsPerDay: 386,
      ),
    ]);

    expect(find.text('Client Work'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);
    expect(find.text('2:15'), findsOneWidget);
    expect(find.text('0:45'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    // avg/day: 1158s → 0:19, 386s → 0:06.
    expect(find.text('0:19'), findsOneWidget);
    expect(find.text('0:06'), findsOneWidget);
    expect(find.byType(DesignSystemProgressBar), findsNWidgets(2));
  });

  testWidgets('data bars are normalized to the largest row', (tester) async {
    await pumpTable(tester, const [
      InsightsTableRow(
        categoryId: 'cat-client',
        seconds: 7200,
        share: 0.5,
        avgSecondsPerDay: 100,
      ),
      InsightsTableRow(
        categoryId: null,
        seconds: 3600,
        share: 0.25,
        avgSecondsPerDay: 50,
      ),
    ]);

    final bars = tester
        .widgetList<DesignSystemProgressBar>(
          find.byType(DesignSystemProgressBar),
        )
        .toList();
    expect(bars[0].value, 1.0); // top row fills the track
    expect(bars[1].value, 0.5); // half of the leader
  });

  testWidgets('unknown category ids render the deleted label, not a UUID', (
    tester,
  ) async {
    await pumpTable(tester, const [
      InsightsTableRow(
        categoryId: 'dead-beef-uuid',
        seconds: 3600,
        share: 1,
        avgSecondsPerDay: 514,
      ),
    ]);
    expect(find.text('Deleted category'), findsOneWidget);
    expect(find.textContaining('dead-beef'), findsNothing);
  });

  testWidgets('renders nothing for an empty row list', (tester) async {
    await pumpTable(tester, const []);
    expect(find.byType(DesignSystemProgressBar), findsNothing);
    expect(find.text('CATEGORY'), findsNothing);
  });

  testWidgets('showAvgPerDay: false hides the avg column entirely', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        mediaQueryData: desktopMq,
        InsightsTable(
          rows: const [
            InsightsTableRow(
              categoryId: 'cat-client',
              seconds: 3600,
              share: 1,
              avgSecondsPerDay: 3600,
            ),
          ],
          resolver: resolver,
          showAvgPerDay: false,
        ),
      ),
    );

    expect(find.text('AVG/DAY'), findsNothing);
    // The total still renders; the avg value (same 1:00 string would
    // otherwise appear twice) renders exactly once.
    expect(find.text('1:00'), findsOneWidget);
  });

  testWidgets(
    'degrades columns instead of overflowing at narrow pane widths',
    (tester) async {
      const rows = [
        InsightsTableRow(
          categoryId: 'cat-client',
          seconds: 3600,
          share: 0.75,
          avgSecondsPerDay: 514,
        ),
        InsightsTableRow(
          categoryId: null,
          seconds: 1200,
          share: 0.25,
          avgSecondsPerDay: 171,
        ),
      ];
      // The detail pane can be resized down to ~90px; every width tier
      // must lay out without a RenderFlex overflow.
      for (final width in [92.0, 200.0, 300.0, 420.0, 560.0]) {
        await tester.pumpWidget(
          makeTestableWidget(
            mediaQueryData: desktopMq,
            // Center loosens the otherwise-tight width constraint so the
            // SizedBox can actually impose [width].
            Center(
              child: SizedBox(
                width: width,
                child: InsightsTable(rows: rows, resolver: resolver),
              ),
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow at width $width',
        );
      }

      // At the widest tier everything is present...
      expect(find.text('AVG/DAY'), findsOneWidget);
      expect(find.byType(DesignSystemProgressBar), findsNWidgets(2));

      // ...and at the narrowest, only the category column remains.
      await tester.pumpWidget(
        makeTestableWidget(
          mediaQueryData: desktopMq,
          Center(
            child: SizedBox(
              width: 92,
              child: InsightsTable(rows: rows, resolver: resolver),
            ),
          ),
        ),
      );
      expect(find.text('TOTAL'), findsNothing);
      expect(find.text('SHARE'), findsNothing);
      expect(find.byType(DesignSystemProgressBar), findsNothing);
      expect(find.text('Client Work'), findsOneWidget);
    },
  );

  testWidgets('sub-minute averages render the <0:01 guard', (tester) async {
    await pumpTable(tester, const [
      InsightsTableRow(
        categoryId: 'cat-client',
        seconds: 1200,
        share: 1,
        avgSecondsPerDay: 40,
      ),
    ]);
    expect(find.text('<0:01'), findsOneWidget);
  });
}
