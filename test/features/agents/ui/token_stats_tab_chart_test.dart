import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';
import 'token_stats_tab_test_helpers.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  /// Pumps [InteractiveWeeklyChart] alone, in a roomy surface so every bar
  /// lays out and is hit-testable. Returns the design tokens for colour
  /// assertions.
  Future<DsTokens> pumpChart(
    WidgetTester tester, {
    required List<DailyTokenUsage>? days,
    int? selectedIndex,
    bool todayIsAboveAverage = false,
    bool compact = false,
    ValueChanged<int>? onBarTap,
  }) async {
    late DsTokens tokens;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            tokens = context.designTokens;
            return Scaffold(
              body: InteractiveWeeklyChart(
                days: days,
                selectedIndex: selectedIndex,
                todayIsAboveAverage: todayIsAboveAverage,
                compact: compact,
                onBarTap: onBarTap ?? (_) {},
              ),
            );
          },
        ),
        mediaQueryData: hLargeChartMediaQueryData,
      ),
    );
    await tester.pump();
    return tokens;
  }

  group('InteractiveWeeklyChart placeholders', () {
    testWidgets('null days renders a chart-height placeholder and no bars', (
      tester,
    ) async {
      await pumpChart(tester, days: null);

      expect(hDayBarFinder(), findsNothing);
      // The placeholder reserves the hero chart height so the card does
      // not collapse and re-expand when data arrives.
      final box = tester.renderObject<RenderBox>(
        find.byType(InteractiveWeeklyChart),
      );
      expect(box.size.height, 120);
    });

    testWidgets('all-zero days show the localized no-usage message', (
      tester,
    ) async {
      await pumpChart(
        tester,
        days: [
          for (var i = 6; i >= 0; i--) hMakeDay(daysAgo: i, totalTokens: 0),
        ],
      );

      final context = tester.element(find.byType(InteractiveWeeklyChart));
      expect(find.text(context.messages.agentStatsNoUsage), findsOneWidget);
      expect(hDayBarFinder(), findsNothing);
    });

    testWidgets('compact placeholder reserves the compact height', (
      tester,
    ) async {
      await pumpChart(tester, days: null, compact: true);

      final box = tester.renderObject<RenderBox>(
        find.byType(InteractiveWeeklyChart),
      );
      expect(box.size.height, 56);
    });
  });

  group('InteractiveWeeklyChart bars', () {
    testWidgets('past bars are grey, today above average is the warning hue', (
      tester,
    ) async {
      final tokens = await pumpChart(
        tester,
        days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
        todayIsAboveAverage: true,
      );

      // Last bar is today (bars render oldest -> newest).
      expect(
        hDayBarColor(tester, 6),
        tokens.colors.alert.warning.defaultColor,
      );
      // A past bar carries no accent.
      expect(
        hDayBarColor(tester, 0),
        isNot(tokens.colors.alert.warning.defaultColor),
      );
      expect(
        hDayBarColor(tester, 0),
        isNot(tokens.colors.interactive.enabled),
      );
    });

    testWidgets('today below average takes the interactive teal, not amber', (
      tester,
    ) async {
      final tokens = await pumpChart(
        tester,
        days: hMakeWeek([9000, 9000, 9000, 9000, 9000, 9000, 1000]),
      );

      expect(hDayBarColor(tester, 6), tokens.colors.interactive.enabled);
    });

    testWidgets('the selected bar carries a hue-independent ring', (
      tester,
    ) async {
      final tokens = await pumpChart(
        tester,
        days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
        selectedIndex: 2,
      );

      final border =
          (hDayBarContainer(tester, 2).decoration! as BoxDecoration).border;
      expect(border, isNotNull);
      // High-emphasis, not the teal: the fill itself can be teal or amber
      // and a same-hue ring would vanish exactly where it matters.
      expect(
        (border! as Border).top.color,
        tokens.colors.text.highEmphasis,
      );

      expect(
        (hDayBarContainer(tester, 3).decoration! as BoxDecoration).border,
        isNull,
      );
    });

    testWidgets('tapping a bar reports its index', (tester) async {
      final taps = <int>[];
      await pumpChart(
        tester,
        days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
        onBarTap: taps.add,
      );

      await tester.tap(hDayBarFinder().at(3));
      expect(taps, [3]);
    });

    testWidgets('a zero day still renders a tappable full-height target', (
      tester,
    ) async {
      final taps = <int>[];
      await pumpChart(
        tester,
        days: hMakeWeek([1000, 0, 3000, 4000, 5000, 6000, 7000]),
        onBarTap: taps.add,
      );

      // Index 1 has no Container bar; its GestureDetector wraps a
      // SizedBox instead, so it is absent from the bar finder…
      expect(hDayBarFinder(), findsNWidgets(6));

      // …but tapping the empty column still selects the day. The empty
      // target spans the full chart height, so tap where its bar would be.
      await tester.tap(hZeroDayTargetFinder());
      expect(taps, [1]);
    });

    testWidgets('every bar shares the chart bottom baseline', (
      tester,
    ) async {
      // Varied totals including a stub: if any wrapper swallows the
      // bottom anchor again, centred bars diverge and this fails.
      await pumpChart(
        tester,
        days: hMakeWeek([1000, 7000, 250, 4000, 5000, 6000, 3000]),
      );

      final bottoms = <double>{};
      for (var i = 0; i < 7; i++) {
        bottoms.add(
          tester.getBottomLeft(find.byWidget(hDayBarContainer(tester, i))).dy,
        );
      }
      expect(bottoms, hasLength(1));
    });

    testWidgets('exposes each day as one selected token-usage button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpChart(
        tester,
        days: hMakeWeek([2000, 3000, 4000, 5000, 6000, 7000, 1000]),
        selectedIndex: 6,
      );

      // Today (Mar 15) is the selected last column.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Friday, Mar 15: 1K tokens')),
        matchesSemantics(
          label: 'Friday, Mar 15: 1K tokens',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('InteractiveWeeklyChart average line', () {
    testWidgets('hero chart paints the dashed average line', (tester) async {
      await pumpChart(
        tester,
        days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is AverageDashedLinePainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('compact chart paints no average line', (tester) async {
      await pumpChart(
        tester,
        days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
        compact: true,
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is AverageDashedLinePainter,
        ),
        findsNothing,
      );
    });

    testWidgets('no line when today is the only day with usage', (
      tester,
    ) async {
      // All past days zero -> average of past totals is 0 -> no line.
      await pumpChart(
        tester,
        days: hMakeWeek([0, 0, 0, 0, 0, 0, 7000]),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is AverageDashedLinePainter,
        ),
        findsNothing,
      );
    });
  });

  group('InteractiveWeeklyChart day labels', () {
    testWidgets(
      'a week labels every day, hero and compact alike',
      (tester) async {
        await pumpChart(
          tester,
          days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
        );
        // Fixed dates 2024-03-09..15 -> S S M T W T F.
        expect(find.text('F'), findsOneWidget);
        expect(find.text('M'), findsOneWidget);

        // Compact 7D labels every day too — a bar tap must be
        // predictable before tapping; sparse anchors are for dense
        // ranges only.
        await pumpChart(
          tester,
          days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
          compact: true,
        );
        expect(find.text('F'), findsOneWidget); // last (today)
        expect(find.text('M'), findsOneWidget); // interior day labeled
      },
    );

    testWidgets('30-day view shows sparse date numbers', (tester) async {
      final days = [
        for (var i = 29; i >= 0; i--) hMakeDay(daysAgo: i),
      ];
      await pumpChart(tester, days: days);

      // Every 7th day plus the last: indices 0,7,14,21,28,29 of the
      // 2024-02-15..2024-03-15 run.
      expect(find.text('15'), findsNWidgets(2)); // Feb 15 and Mar 15.
      expect(find.text('22'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);
      // A non-milestone day renders no label.
      expect(find.text('16'), findsNothing);
    });

    testWidgets("today's label mirrors the bar colour expression", (
      tester,
    ) async {
      final tokens = await pumpChart(
        tester,
        days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
        todayIsAboveAverage: true,
      );

      // Above average, light test theme: the label takes the darker
      // for-text step of the warning ramp, matching the stat pair.
      expect(
        tester.widget<Text>(find.text('F')).style?.color,
        tokens.colors.alert.warning.hover,
      );

      await pumpChart(
        tester,
        days: hMakeWeek([9000, 9000, 9000, 9000, 9000, 9000, 1000]),
      );
      expect(
        tester.widget<Text>(find.text('F')).style?.color,
        tokens.colors.interactive.enabled,
      );
    });

    testWidgets('tapping a day label reports the index', (tester) async {
      final taps = <int>[];
      await pumpChart(
        tester,
        days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
        onBarTap: taps.add,
      );

      await tester.tap(find.text('M'));
      expect(taps, [2]);
    });
  });

  group('pointer, keyboard, and scrub interaction', () {
    testWidgets('hovering an unselected past bar brightens it one step', (
      tester,
    ) async {
      await pumpChart(
        tester,
        days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
      );

      final restingAlpha = hDayBarColor(tester, 1).a;

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(hDayBarFinder().at(1)));
      await tester.pump();

      expect(hDayBarColor(tester, 1).a, greaterThan(restingAlpha));

      // Leaving restores the resting emphasis.
      await gesture.moveTo(Offset.zero);
      await tester.pump();
      expect(hDayBarColor(tester, 1).a, restingAlpha);
    });

    testWidgets('arrow keys step the selection once the chart is focused', (
      tester,
    ) async {
      // A stateful harness: each key press must act on the selection the
      // previous press produced, so right-then-left is a real round trip.
      final selections = <int>[];
      var selectedIndex = 3;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: InteractiveWeeklyChart(
                days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
                selectedIndex: selectedIndex,
                onBarTap: (i) {
                  selections.add(i);
                  setState(() => selectedIndex = i);
                },
              ),
            ),
          ),
          mediaQueryData: hLargeChartMediaQueryData,
        ),
      );
      await tester.pump();

      // Focus the chart via a context below its FocusableActionDetector.
      Focus.of(tester.element(hDayBarFinder().first)).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(selections, [4, 3]);
    });

    testWidgets('arrow keys clamp at the chart edges', (tester) async {
      final taps = <int>[];
      await pumpChart(
        tester,
        days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
        selectedIndex: 6,
        onBarTap: taps.add,
      );

      // Focus the chart via a context below its FocusableActionDetector.
      Focus.of(tester.element(hDayBarFinder().first)).requestFocus();
      await tester.pump();

      // Right at the last bar stays at the last bar.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(taps, [6]);
    });

    testWidgets('a horizontal scrub retargets the selection continuously', (
      tester,
    ) async {
      final taps = <int>[];
      await pumpChart(
        tester,
        days: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
        selectedIndex: 6,
        onBarTap: taps.add,
      );

      // Drag from the first column across to the middle in small steps:
      // the selection follows the pointer through every column it
      // crosses (the drag-slop consumes a few px before the first
      // report, so assert the sweep, not an exact start). The scrub area
      // is the width-capped chart body, narrower than the widget on wide
      // surfaces — start inside it, not at the widget edge.
      final chartBox = tester.getRect(find.byType(ChartScrubArea));
      final gesture = await tester.startGesture(
        Offset(chartBox.left + 10, chartBox.top + 40),
      );
      await tester.pump();
      for (var step = 0; step < 6; step++) {
        await gesture.moveBy(Offset(chartBox.width * 0.07, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();

      // Multiple distinct columns were visited, in pointer order, ending
      // in the third column ((10 + 0.42w) / w * 7 ≈ 3).
      expect(taps.toSet().length, greaterThan(1));
      expect(taps, orderedEquals([...taps]..sort()));
      expect(taps.last, 3);
    });
  });

  group('compact day echo', () {
    Future<void> pumpEcho(WidgetTester tester, DailyTokenUsage day) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(body: SelectedDayDetail(day: day, compact: true)),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders the stacked bar with a date-led caption line', (
      tester,
    ) async {
      await pumpEcho(
        tester,
        // The factory's default total (1000) equals the attributed sum,
        // so the day is fully accounted for and no remainder renders.
        hMakeDay(inputTokens: 600, outputTokens: 300, thoughtsTokens: 100),
      );

      // No full-treatment rows in the echo.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // One caption line carries the scope and every value.
      expect(
        find.textContaining('Fri, Mar 15', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Input\u00a0600', findRichText: true),
        findsOneWidget,
      );
      // Fully attributed day: no remainder segment, no 'Other'.
      final messages = tester.element(find.byType(SelectedDayDetail)).messages;
      expect(
        find.textContaining(messages.agentStatsOtherLabel, findRichText: true),
        findsNothing,
      );
    });

    testWidgets('names unattributed tokens as Other instead of hiding them', (
      tester,
    ) async {
      await pumpEcho(
        tester,
        hMakeDay(totalTokens: 1200, inputTokens: 500, outputTokens: 300),
      );

      // 400 tokens outside the split: the quiet bar segment gets a name
      // and a number so it can never read as "no data".
      final messages = tester.element(find.byType(SelectedDayDetail)).messages;
      expect(
        find.textContaining(
          '${messages.agentStatsOtherLabel}\u00a0400',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });
  });

  group('todayAccentColor', () {
    testWidgets('resolves warning above average, interactive otherwise', (
      tester,
    ) async {
      late DsTokens tokens;
      late Color above;
      late Color below;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              tokens = context.designTokens;
              above = todayAccentColor(context, aboveAverage: true);
              below = todayAccentColor(context, aboveAverage: false);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(above, tokens.colors.alert.warning.defaultColor);
      expect(below, tokens.colors.interactive.enabled);
    });
  });

  group('SelectedDayDetail', () {
    Future<DsTokens> pumpDetail(
      WidgetTester tester,
      DailyTokenUsage day,
    ) async {
      late DsTokens tokens;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              tokens = context.designTokens;
              return Scaffold(body: SelectedDayDetail(day: day));
            },
          ),
        ),
      );
      await tester.pump();
      return tokens;
    }

    testWidgets(
      'renders flat with a hairline divider — no nested card surface',
      (tester) async {
        final tokens = await pumpDetail(
          tester,
          hMakeDay(totalTokens: 26000, inputTokens: 20000, outputTokens: 6000),
        );

        final divider = tester.widget<Divider>(find.byType(Divider));
        expect(divider.color, tokens.colors.decorative.level01);
        // The old design nested a same-colour card here; the detail must
        // not paint a card-surface fill any more. Colour-keyed swatches
        // are the only decorated Containers left, and none may carry the
        // card surface.
        final surface = dsCardSurface(
          tester.element(find.byType(SelectedDayDetail)),
        );
        expect(
          find.descendant(
            of: find.byType(SelectedDayDetail),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).color == surface,
            ),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('stacked bar keeps every slice proportional to its tokens', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        hMakeDay(totalTokens: 26000, inputTokens: 13000, outputTokens: 6500),
      );

      // Today's detail names its identity, so the repeated total reads
      // as confirmation of the Today stat, not duplication.
      expect(find.text('Fri, Mar 15 · Today'), findsOneWidget);
      expect(find.text('26K'), findsOneWidget);
      // Caption items pair each label with its value (non-breaking space).
      expect(find.text('Input 13K'), findsOneWidget);
      expect(find.text('Output 6.5K'), findsOneWidget);
      // The 6.5K outside the input/output split is a named Other slice —
      // the parts must always sum to the headline total.
      expect(find.text('Other 6.5K'), findsOneWidget);

      // The bar's runs carry the same proportions as the numbers.
      final flexes = tester
          .widgetList<Expanded>(
            find.descendant(
              of: find.byType(ClipRRect),
              matching: find.byType(Expanded),
            ),
          )
          .map((e) => e.flex)
          .toList();
      expect(flexes, [13000, 6500, 6500]);
    });

    testWidgets('thoughts slice appears only when thoughts tokens exist', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        hMakeDay(inputTokens: 800, outputTokens: 200),
      );
      final messages = tester.element(find.byType(SelectedDayDetail)).messages;
      expect(
        find.textContaining(messages.agentStatsThoughtsLabel),
        findsNothing,
      );

      await pumpDetail(
        tester,
        hMakeDay(
          inputTokens: 600,
          outputTokens: 200,
          thoughtsTokens: 200,
        ),
      );
      expect(
        find.text('${messages.agentStatsThoughtsLabel} 200'),
        findsOneWidget,
      );
    });

    testWidgets(
      'breakdown slices step the interactive token ramp, not judged alphas',
      (tester) async {
        final tokens = await pumpDetail(
          tester,
          hMakeDay(
            inputTokens: 600,
            outputTokens: 200,
            thoughtsTokens: 200,
          ),
        );

        final runs = tester
            .widgetList<ColoredBox>(
              find.descendant(
                of: find.byType(ClipRRect),
                matching: find.byType(ColoredBox),
              ),
            )
            .map((b) => b.color)
            .toList();
        // Input → Output → Thoughts ride the ramp's real token steps, so
        // category identity never rests on judging alpha values by eye.
        // Input and Output — the two dominant adjacent slices — take the
        // ramp's extreme steps; Thoughts sits on the middle step.
        expect(runs, [
          tokens.colors.interactive.enabled,
          tokens.colors.interactive.pressed,
          tokens.colors.interactive.hover,
        ]);
      },
    );

    testWidgets('wake metrics render only the populated columns', (
      tester,
    ) async {
      // No wakes, no cache -> no metrics row at all.
      await pumpDetail(
        tester,
        hMakeDay(inputTokens: 800, outputTokens: 200),
      );
      final l10n = tester.element(find.byType(SelectedDayDetail)).messages;
      expect(find.text(l10n.agentStatsWakesLabel), findsNothing);
      expect(find.text(l10n.agentStatsCacheRateLabel), findsNothing);

      // Wakes -> wake count and tokens/wake appear.
      await pumpDetail(
        tester,
        hMakeDay(
          inputTokens: 800,
          outputTokens: 200,
          wakeCount: 4,
        ),
      );
      expect(find.text(l10n.agentStatsWakesLabel), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text(l10n.agentStatsTokensPerWakeLabel), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
      expect(find.text(l10n.agentStatsCacheRateLabel), findsNothing);

      // Cached input -> cache rate appears (60% of 800 input cached).
      await pumpDetail(
        tester,
        hMakeDay(
          inputTokens: 800,
          outputTokens: 200,
          cachedInputTokens: 480,
        ),
      );
      expect(find.text(l10n.agentStatsCacheRateLabel), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });
  });

  group('AverageDashedLinePainter', () {
    test('repaints only when fraction or colour change', () {
      final painter = AverageDashedLinePainter(
        fraction: 0.5,
        color: const Color(0xFF112233),
      );

      expect(
        painter.shouldRepaint(
          AverageDashedLinePainter(
            fraction: 0.5,
            color: const Color(0xFF112233),
          ),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          AverageDashedLinePainter(
            fraction: 0.6,
            color: const Color(0xFF112233),
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          AverageDashedLinePainter(
            fraction: 0.5,
            color: const Color(0xFF445566),
          ),
        ),
        isTrue,
      );
    });
  });
}
