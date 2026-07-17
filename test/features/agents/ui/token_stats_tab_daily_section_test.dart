import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_chart.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_daily_section.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../widget_test_utils.dart';
import 'token_stats_tab_test_helpers.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  /// Pumps [DailyUsageSection] standalone. The section is stateless — the
  /// tab owns days/selection — so tests drive it through these parameters
  /// and observe the callbacks.
  Future<DsTokens> pumpSection(
    WidgetTester tester, {
    List<DailyTokenUsage>? dailyUsage,
    TokenUsageComparison? comparison,
    bool comparisonLoading = false,
    int days = 7,
    int? selectedIndex,
    ValueChanged<int>? onDaysChanged,
    ValueChanged<int>? onBarTap,
    VoidCallback? onResetToToday,
    TokenSourceBreakdown? highUsageSource,
  }) async {
    late DsTokens tokens;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            tokens = context.designTokens;
            return Scaffold(
              body: SingleChildScrollView(
                child: DailyUsageSection(
                  days: days,
                  dailyAsync: dailyUsage == null
                      ? const AsyncValue.loading()
                      : AsyncValue.data(dailyUsage),
                  comparisonAsync: comparisonLoading
                      ? const AsyncValue.loading()
                      : AsyncValue.data(
                          comparison ??
                              const TokenUsageComparison(
                                averageTokensByTimeOfDay: 0,
                                todayTokens: 0,
                              ),
                        ),
                  onDaysChanged: onDaysChanged ?? (_) {},
                  selectedIndex: selectedIndex,
                  onBarTap: onBarTap ?? (_) {},
                  onResetToToday: onResetToToday ?? () {},
                  highUsageSource: highUsageSource,
                ),
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

  group('hero heading', () {
    testWidgets('scopes the focal number to the selected range', (
      tester,
    ) async {
      await pumpSection(
        tester,
        dailyUsage: hMakeWeek([
          10000,
          10000,
          10000,
          10000,
          10000,
          10000,
          10000,
        ]),
      );

      // 7 × 10K = 70K, scoped by the range so the biggest number on the
      // page cannot be misread as today's usage.
      expect(find.text('70K'), findsOneWidget);
      expect(find.textContaining('last 7 days'), findsOneWidget);
    });

    testWidgets('includes the wake count only when there are wakes', (
      tester,
    ) async {
      await pumpSection(
        tester,
        dailyUsage: [hMakeDay(totalTokens: 5000, wakeCount: 4)],
      );
      expect(find.textContaining('4 wakes'), findsOneWidget);

      await pumpSection(
        tester,
        dailyUsage: [hMakeDay(totalTokens: 5000)],
      );
      expect(find.textContaining('wakes'), findsNothing);
    });

    testWidgets('hides the focal number entirely at zero usage', (
      tester,
    ) async {
      await pumpSection(tester, dailyUsage: const []);

      expect(find.textContaining('last 7 days'), findsNothing);
    });

    testWidgets('forwards toggle taps as onDaysChanged', (tester) async {
      final changes = <int>[];
      await pumpSection(
        tester,
        dailyUsage: hMakeWeek([1000, 1000, 1000, 1000, 1000, 1000, 1000]),
        onDaysChanged: changes.add,
      );

      // The segmented toggle renders each label twice (visible + ghost).
      await tester.tap(find.text('30D').first);
      expect(changes, [30]);
    });
  });

  group('comparison summary', () {
    testWidgets('states above vs below average from the comparison', (
      tester,
    ) async {
      await pumpSection(
        tester,
        dailyUsage: hMakeWeek([1000, 1000, 1000, 1000, 1000, 1000, 9000]),
        comparison: const TokenUsageComparison(
          averageTokensByTimeOfDay: 1000,
          todayTokens: 9000,
        ),
      );
      expect(find.textContaining('more tokens than usual'), findsOneWidget);

      await pumpSection(
        tester,
        dailyUsage: hMakeWeek([9000, 9000, 9000, 9000, 9000, 9000, 1000]),
        comparison: const TokenUsageComparison(
          averageTokensByTimeOfDay: 9000,
          todayTokens: 1000,
        ),
      );
      expect(find.textContaining('fewer tokens than usual'), findsOneWidget);
    });

    testWidgets('says nothing when exactly at average', (tester) async {
      await pumpSection(
        tester,
        dailyUsage: hMakeWeek([5000, 5000, 5000, 5000, 5000, 5000, 5000]),
        comparison: const TokenUsageComparison(
          averageTokensByTimeOfDay: 5000,
          todayTokens: 5000,
        ),
      );

      expect(find.textContaining('tokens than usual'), findsNothing);
    });

    testWidgets(
      'the high-usage notice chip names the source in amber, routes to '
      'the agent on tap, and survives a missing baseline',
      (tester) async {
        String? navigatedPath;
        beamToNamedOverride = (path) => navigatedPath = path;
        final days = hMakeWeek([1000, 1000, 1000, 1000, 1000, 1000, 9000]);
        const hotSource = TokenSourceBreakdown(
          templateId: 'tpl-hot',
          displayName: 'Task Assistant',
          totalTokens: 900,
          percentage: 90,
          wakeCount: 9,
          totalDuration: Duration(minutes: 30),
          isHighUsage: true,
        );

        // With a baseline: sentence + notice chip stack.
        await pumpSection(
          tester,
          dailyUsage: days,
          comparison: const TokenUsageComparison(
            averageTokensByTimeOfDay: 1000,
            todayTokens: 9000,
          ),
          highUsageSource: hotSource,
        );
        final context = tester.element(find.byType(DailyUsageSection));
        final noticeText = context.messages.agentStatsHeroHighUsage(
          'Task Assistant',
        );
        expect(find.textContaining('more tokens than usual'), findsOneWidget);
        final notice = tester.widget<Text>(find.text(noticeText));
        expect(notice.style!.color, warningTextColor(context));

        // The notice names an agent, so it routes to it.
        await tester.tap(find.text(noticeText));
        expect(navigatedPath, '/settings/agents/templates/tpl-hot');

        // Without a baseline (first week): the reserve renders instead of
        // the sentence, but the warning must still be visible.
        await pumpSection(
          tester,
          dailyUsage: days,
          comparisonLoading: true,
          highUsageSource: hotSource,
        );
        expect(find.text(noticeText), findsOneWidget);
      },
    );

    testWidgets('the chart does not move when the sentence resolves', (
      tester,
    ) async {
      // While the comparison loads, the placeholder renders both possible
      // messages invisibly and takes the taller one's height…
      final days = hMakeWeek([1000, 1000, 1000, 1000, 1000, 1000, 9000]);
      await pumpSection(
        tester,
        dailyUsage: days,
        comparisonLoading: true,
      );
      final chartTopWhileLoading = tester
          .getTopLeft(find.byType(InteractiveWeeklyChart))
          .dy;

      // …so when the real sentence lands, everything below it stays put.
      await pumpSection(
        tester,
        dailyUsage: days,
        comparison: const TokenUsageComparison(
          averageTokensByTimeOfDay: 1000,
          todayTokens: 9000,
        ),
      );
      expect(find.textContaining('more tokens than usual'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(InteractiveWeeklyChart)).dy,
        chartTopWhileLoading,
      );
    });
  });

  group('Average/Today stat pair', () {
    testWidgets('today goes amber above average, teal below', (tester) async {
      final tokens = await pumpSection(
        tester,
        dailyUsage: hMakeWeek([1000, 1000, 1000, 1000, 1000, 1000, 9000]),
        comparison: const TokenUsageComparison(
          averageTokensByTimeOfDay: 1000,
          todayTokens: 9000,
        ),
      );

      // Light test theme: for-text darkening picks the warning hover step.
      expect(
        tester.widget<Text>(find.text('9K')).style?.color,
        tokens.colors.alert.warning.hover,
      );

      await pumpSection(
        tester,
        dailyUsage: hMakeWeek([9000, 9000, 9000, 9000, 9000, 9000, 1000]),
        comparison: const TokenUsageComparison(
          averageTokensByTimeOfDay: 9000,
          todayTokens: 1000,
        ),
      );
      expect(
        tester.widget<Text>(find.text('1K')).style?.color,
        tokens.colors.interactive.enabled,
      );
    });

    testWidgets("the chart's today bar resolves from the same comparison", (
      tester,
    ) async {
      final tokens = await pumpSection(
        tester,
        dailyUsage: hMakeWeek([1000, 1000, 1000, 1000, 1000, 1000, 9000]),
        comparison: const TokenUsageComparison(
          averageTokensByTimeOfDay: 1000,
          todayTokens: 9000,
        ),
      );

      // Bar fill keeps the undarkened amber; the point is that the bar
      // and the stat agree on WHICH ramp fires, so they can never
      // contradict each other about today running hot.
      expect(
        hDayBarColor(tester, 6),
        tokens.colors.alert.warning.defaultColor,
      );
    });
  });

  group('selected day detail', () {
    testWidgets('shows the detail rows for the selected index', (
      tester,
    ) async {
      await pumpSection(
        tester,
        dailyUsage: [
          for (var i = 6; i >= 1; i--) hMakeDay(daysAgo: i),
          hMakeDay(totalTokens: 9000, inputTokens: 6000, outputTokens: 3000),
        ],
        selectedIndex: 6,
      );

      expect(find.byType(SelectedDayDetail), findsOneWidget);
      expect(find.text('Fri, Mar 15 · Today'), findsOneWidget);
    });

    testWidgets('renders no detail without a selection', (tester) async {
      await pumpSection(
        tester,
        dailyUsage: hMakeWeek([1000, 1000, 1000, 1000, 1000, 1000, 1000]),
      );

      expect(find.byType(SelectedDayDetail), findsNothing);
    });

    testWidgets('guards an index beyond the loaded list', (tester) async {
      // 30D selection index while only 7 days have loaded — the section
      // must render the chart without a detail block instead of throwing.
      await pumpSection(
        tester,
        dailyUsage: hMakeWeek([1000, 1000, 1000, 1000, 1000, 1000, 1000]),
        selectedIndex: 29,
      );

      expect(find.byType(SelectedDayDetail), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('forwards bar taps to the tab', (tester) async {
      final taps = <int>[];
      await pumpSection(
        tester,
        dailyUsage: hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]),
        onBarTap: taps.add,
      );

      await tester.tap(hDayBarFinder().at(2));
      expect(taps, [2]);
    });
  });
}
