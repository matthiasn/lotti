import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_chart.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_per_model_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';
import 'token_stats_tab_test_helpers.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Future<void> pumpSection(
    WidgetTester tester, {
    required Map<String, List<DailyTokenUsage>> byModel,
    int? selectedIndex,
    ValueChanged<DateTime>? onDayTap,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: SingleChildScrollView(
            child: PerModelChartsSection(
              byModelAsync: AsyncValue.data(byModel),
              days: 7,
              selectedIndex: selectedIndex,
              onDayTap: onDayTap ?? (_) {},
            ),
          ),
        ),
        mediaQueryData: hLargeChartMediaQueryData,
      ),
    );
    await tester.pump();
  }

  List<DailyTokenUsage> week({int total = 1000}) =>
      hMakeWeek(List.filled(7, total));

  group('visibility', () {
    testWidgets('hides itself for a single model — the hero tells that story', (
      tester,
    ) async {
      await pumpSection(tester, byModel: {'only-model': week()});

      expect(find.byType(InteractiveWeeklyChart), findsNothing);
      final context = tester.element(find.byType(PerModelChartsSection));
      expect(
        find.text(context.messages.agentStatsByModelHeading),
        findsNothing,
      );
    });

    testWidgets('renders a heading and one card per model when several', (
      tester,
    ) async {
      await pumpSection(
        tester,
        byModel: {
          'model-alpha-large': week(total: 9000),
          'model-beta-mini': week(total: 500),
        },
      );

      final context = tester.element(find.byType(PerModelChartsSection));
      expect(
        find.text(context.messages.agentStatsByModelHeading),
        findsOneWidget,
      );
      expect(find.byType(InteractiveWeeklyChart), findsNWidgets(2));
    });
  });

  group('card content', () {
    testWidgets('shows each model name with its formatted period total', (
      tester,
    ) async {
      await pumpSection(
        tester,
        byModel: {
          'model-alpha': week(total: 9000), // 7 × 9000 = 63K
          'model-beta': week(total: 500), // 7 × 500 = 3.5K
        },
      );

      // The trailing total names its own 7-day window, so it cannot be
      // confused with the selected-day figure inside the same card.
      expect(find.textContaining('model-alpha'), findsOneWidget);
      expect(find.textContaining('63K tokens · last 7 days'), findsOneWidget);
      expect(find.textContaining('3.5K tokens · last 7 days'), findsOneWidget);
    });

    testWidgets('charts are compact echoes — no average line', (
      tester,
    ) async {
      await pumpSection(
        tester,
        byModel: {'model-a': week(), 'model-b': week()},
      );

      final charts = tester.widgetList<InteractiveWeeklyChart>(
        find.byType(InteractiveWeeklyChart),
      );
      expect(charts.every((c) => c.compact), isTrue);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is AverageDashedLinePainter,
        ),
        findsNothing,
      );
    });
  });

  group('shared day selection', () {
    testWidgets(
      'shows a compact detail for the shared selected day in every card',
      (tester) async {
        await pumpSection(
          tester,
          byModel: {
            'model-a': [
              for (var i = 6; i >= 1; i--) hMakeDay(daysAgo: i),
              hMakeDay(
                totalTokens: 9000,
                inputTokens: 6000,
                outputTokens: 3000,
              ),
            ],
            'model-b': week(),
          },
          selectedIndex: 6,
        );

        final details = tester
            .widgetList<SelectedDayDetail>(find.byType(SelectedDayDetail))
            .toList();
        expect(details, hasLength(2));
        // Compact form: the hero's header/metrics are not repeated, but a
        // caption date anchors the day-scoped rows against the period
        // total in the card header.
        expect(details.every((d) => d.compact), isTrue);
        // The date anchor leads each echo's caption line (a rich span).
        expect(
          find.textContaining('Fri, Mar 15', findRichText: true),
          findsNWidgets(2),
        );

        // The stacked bar actually paints: its segments must have the
        // bar's real height, not collapse to zero under a loose
        // cross-axis constraint (regression guard).
        final segmentSizes = find
            .descendant(
              of: find.byType(SelectedDayDetail),
              matching: find.byType(ColoredBox),
            )
            .evaluate()
            .map((e) => e.size!.height)
            .toSet();
        // Height is the spacing ramp's step3 token, not an invented value.
        expect(segmentSizes, {8.0});

        // The values stay readable as text — the merge into one bar
        // loses no information.
        expect(
          find.textContaining('Input\u00a06K', findRichText: true),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders no detail when nothing is selected', (tester) async {
      await pumpSection(
        tester,
        byModel: {'model-a': week(), 'model-b': week()},
      );

      expect(find.byType(SelectedDayDetail), findsNothing);
    });

    testWidgets('guards a selection index beyond a model list', (
      tester,
    ) async {
      await pumpSection(
        tester,
        byModel: {'model-a': week(), 'model-b': week()},
        selectedIndex: 29,
      );

      expect(find.byType(SelectedDayDetail), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports the tapped day as a date from the card own list', (
      tester,
    ) async {
      final taps = <DateTime>[];
      await pumpSection(
        tester,
        byModel: {'model-a': week(), 'model-b': week()},
        onDayTap: taps.add,
      );

      // Index 3 of the card's own week is Tue, Mar 12 — the callback
      // resolves the calendar date, never a hero-relative index.
      await tester.tap(hDayBarFinder().at(3));
      expect(taps, [DateTime(2024, 3, 12)]);
    });
  });
}
