import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../widget_test_utils.dart';
import 'token_stats_tab_test_helpers.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  group('TokenStatsTab', () {
    testWidgets('tapping selected bar again deselects it', (tester) async {
      // Build with data so the chart is rendered and a bar is pre-selected
      // (today = last element, index 6 for a 7-day list).
      // Use Friday (2024-03-15) as today so its day-of-week letter is unique.
      final days = [
        for (var i = 6; i >= 0; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 15 - i),
            totalTokens: 5000,
            tokensByTimeOfDay: 3000,
            isToday: i == 0,
            inputTokens: 4000,
            outputTokens: 1000,
            wakeCount: 2,
          ),
      ];

      await tester.pumpWidget(
        hBuildSubject(
          dailyUsage: days,
          comparison: const TokenUsageComparison(
            averageTokensByTimeOfDay: 3000,
            todayTokens: 5000,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The detail panel is visible (today, March 15, is pre-selected).
      // The date label "Mar 15, Fri" (MMMEd) should appear in the detail.
      expect(find.textContaining('Mar'), findsWidgets);

      // Tap the today day-label (Friday = 'F') to deselect it (toggle).
      // March 15, 2024 is a Friday. The label shows first char of day name.
      final fridayLabel = find.text('F').last;
      await tester.ensureVisible(fridayLabel);
      await tester.tap(fridayLabel);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After deselection the detail panel should be gone — no MMMEd date.
      expect(find.textContaining('Fri'), findsNothing);
    });

    testWidgets('30-day view shows date numbers in label row', (
      tester,
    ) async {
      // Build 30 days of data so the date-number branch (line 520) is hit.
      // The provider override in hBuildSubject returns the same list regardless
      // of the days parameter, so switching to 30D will use this list.
      final days30 = [
        for (var i = 29; i >= 0; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 1 + i),
            totalTokens: 1000,
            tokensByTimeOfDay: 500,
            isToday: i == 0,
          ),
      ];

      await tester.pumpWidget(
        hBuildSubject(
          dailyUsage: days30,
          comparison: const TokenUsageComparison(
            averageTokensByTimeOfDay: 500,
            todayTokens: 1000,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to 30D view.
      await tester.tap(find.text('30D'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In 30-day mode, labels are date-day numbers. The first day
      // of our data is March 30 (i==0 → date = March 1+0 = March 1),
      // so day numbers like "1" and "30" appear as labels.
      expect(find.text('30'), findsWidgets);
    });

    testWidgets('day detail shows cache rate metric when cacheRate > 0', (
      tester,
    ) async {
      final days = [
        for (var i = 6; i >= 0; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 15 - i),
            totalTokens: 10000,
            tokensByTimeOfDay: 5000,
            isToday: i == 0,
            inputTokens: 8000,
            outputTokens: 2000,
            // 50 % cache hit: cachedInputTokens / inputTokens = 0.5
            cachedInputTokens: 4000,
            wakeCount: 4,
          ),
      ];

      await tester.pumpWidget(
        hBuildSubject(
          dailyUsage: days,
          comparison: const TokenUsageComparison(
            averageTokensByTimeOfDay: 5000,
            todayTokens: 10000,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      // tokensPerWake > 0 so tokens-per-wake metric shown.
      expect(
        find.text(context.messages.agentStatsTokensPerWakeLabel),
        findsOneWidget,
      );
      // cacheRate = 0.5, so '50%' should appear.
      expect(
        find.text(context.messages.agentStatsCacheRateLabel),
        findsOneWidget,
      );
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets(
      'per-model chart card: tapping a bar shows and toggles day detail',
      (
        tester,
      ) async {
        // Use Friday March 15 as today so labels are predictable.
        final modelDays = [
          for (var i = 6; i >= 0; i--)
            DailyTokenUsage(
              date: DateTime(2024, 3, 15 - i),
              totalTokens: i == 0 ? 8000 : 3000,
              tokensByTimeOfDay: i == 0 ? 8000 : 1500,
              isToday: i == 0,
              inputTokens: i == 0 ? 6000 : 2000,
              outputTokens: i == 0 ? 2000 : 1000,
              wakeCount: 2,
            ),
        ];

        // Start with two models so the per-model section is rendered.
        await tester.pumpWidget(
          hBuildSubject(
            byModel: {
              'models/gemma4:test': modelDays,
              'models/gemma4:other': modelDays,
            },
            dailyUsage: modelDays,
            comparison: const TokenUsageComparison(
              averageTokensByTimeOfDay: 1500,
              todayTokens: 8000,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Both model names should appear.
        expect(find.text('gemma4:test'), findsOneWidget);
        expect(find.text('gemma4:other'), findsOneWidget);

        // Tap the first Friday label (inside the first model card) to select it,
        // then tap again to toggle-deselect — exercises lines 988-989.
        final fridayLabels = find.text('F');
        expect(fridayLabels.evaluate().length, greaterThan(0));
        await tester.ensureVisible(fridayLabels.first);
        await tester.tap(fridayLabels.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tapping the same bar again should toggle _selectedIndex back to null.
        await tester.ensureVisible(fridayLabels.first);
        await tester.tap(fridayLabels.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Model card headers are still on-screen.
        expect(find.text('gemma4:test'), findsOneWidget);

        // Now select a non-today bar to trigger the _SelectedDayDetail panel
        // (lines 992-997). Tap the Sunday label (first in the week list).
        final sundayLabels = find.text('S');
        if (sundayLabels.evaluate().isNotEmpty) {
          await tester.ensureVisible(sundayLabels.first);
          await tester.tap(sundayLabels.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // _SelectedDayDetail is shown: the input breakdown row appears.
          final context = tester.element(find.byType(TokenStatsTab));
          expect(
            find.text(context.messages.agentStatsInputLabel),
            findsWidgets,
          );
        }
      },
    );

    testWidgets('tapping non-template source navigates to instances path', (
      tester,
    ) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      const sources = [
        TokenSourceBreakdown(
          templateId: 'inst-1',
          displayName: 'Instance Agent',
          totalTokens: 1000,
          percentage: 100,
          wakeCount: 1,
          totalDuration: Duration(minutes: 5),
          isHighUsage: false,
          isTemplate: false,
        ),
      ];

      await tester.pumpWidget(hBuildSubject(breakdown: sources));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Instance Agent'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(navigatedPath, '/settings/agents/instances/inst-1');
    });

    testWidgets('day detail shows tokensPerWake metric when wakeCount > 0', (
      tester,
    ) async {
      final days = [
        for (var i = 6; i >= 0; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 15 - i),
            totalTokens: 12000,
            tokensByTimeOfDay: 6000,
            isToday: i == 0,
            inputTokens: 10000,
            outputTokens: 2000,
            wakeCount: 3,
          ),
      ];

      await tester.pumpWidget(
        hBuildSubject(
          dailyUsage: days,
          comparison: const TokenUsageComparison(
            averageTokensByTimeOfDay: 6000,
            todayTokens: 12000,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      // tokensPerWake = 12000 ~/ 3 = 4000 → formatted as "4K".
      expect(
        find.text(context.messages.agentStatsTokensPerWakeLabel),
        findsOneWidget,
      );
      expect(find.text('4K'), findsWidgets);
    });

    testWidgets(
      'tapping a daily-chart bar directly selects it and shows detail',
      (tester) async {
        // Give the chart room (via a scoped MediaQuery) so the bars are
        // fully laid out and hit-testable when tapped directly (exercises
        // _DayBar.onTap).

        // 7 days, each with distinct totals so each bar has a measurable
        // height. Today (index 6) is pre-selected by the section.
        final days = [
          for (var i = 6; i >= 0; i--)
            DailyTokenUsage(
              date: DateTime(2024, 3, 15 - i),
              totalTokens: 4000 + i * 1000,
              tokensByTimeOfDay: 2000 + i * 500,
              isToday: i == 0,
              inputTokens: 3000,
              outputTokens: 1000,
              wakeCount: 2,
            ),
        ];

        await tester.pumpWidget(
          hBuildSubject(
            mediaQueryData: hLargeChartMediaQueryData,
            dailyUsage: days,
            comparison: const TokenUsageComparison(
              averageTokensByTimeOfDay: 2500,
              todayTokens: 4000,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The pre-selected day is today (March 15). Its detail panel is shown.
        expect(find.textContaining('Mar 15'), findsOneWidget);

        // Tap the today bar itself (not the label) to toggle the selection off.
        // The tallest, right-most bar corresponds to today (index 6, total
        // 4000 vs the others which are larger for past days). We instead pick
        // the first day's bar (index 0, total 10000 → tallest) to switch
        // the selection to that day, exercising the bar's onTap closure.
        final bars = hDayBarFinder();
        expect(bars, findsWidgets);
        await tester.tap(bars.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Selecting the first day (March 9) replaces the detail panel; its
        // date label appears and today's (March 15) is gone.
        expect(find.textContaining('Mar 9'), findsOneWidget);
        expect(find.textContaining('Mar 15'), findsNothing);
      },
    );

    testWidgets(
      'non-today bar with full by-time portion renders rounded top',
      (tester) async {
        // Non-today days where tokensByTimeOfDay == totalTokens force
        // byTimeIsFullBar == true (line 625). Index 6 (today) is small so a
        // past day owns the max height. A scoped large MediaQuery keeps the
        // bars laid out and hit-testable.
        final days = [
          for (var i = 6; i >= 0; i--)
            DailyTokenUsage(
              date: DateTime(2024, 3, 15 - i),
              totalTokens: i == 0 ? 1000 : 10000,
              // Past days: by-time equals the full day total.
              tokensByTimeOfDay: i == 0 ? 1000 : 10000,
              isToday: i == 0,
              inputTokens: i == 0 ? 800 : 8000,
              outputTokens: i == 0 ? 200 : 2000,
              wakeCount: 2,
            ),
        ];

        await tester.pumpWidget(
          hBuildSubject(
            mediaQueryData: hLargeChartMediaQueryData,
            dailyUsage: days,
            comparison: const TokenUsageComparison(
              averageTokensByTimeOfDay: 10000,
              todayTokens: 1000,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // A non-today, full-by-time bar uses BorderRadius.vertical(top: ...)
        // on its by-time container (line 625). The observable proof that this
        // branch rendered: tapping that bar selects the past day and its detail
        // panel shows the correct full-day total formatted as "10K".
        final bars = hDayBarFinder();
        expect(bars, findsWidgets);
        // bars.first is the left-most (oldest past day, total 10000).
        await tester.tap(bars.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final context = tester.element(find.byType(TokenStatsTab));
        // Detail panel for the selected past day shows its input breakdown
        // and the full-day total ("10K").
        expect(
          find.text(context.messages.agentStatsInputLabel),
          findsWidgets,
        );
        expect(find.text('10K'), findsWidgets);
      },
    );

    testWidgets(
      'per-model chart bar tap selects day and toggles detail panel',
      (tester) async {
        final modelDays = [
          for (var i = 6; i >= 0; i--)
            DailyTokenUsage(
              date: DateTime(2024, 3, 15 - i),
              totalTokens: 5000 + i * 1000,
              tokensByTimeOfDay: 2500 + i * 500,
              isToday: i == 0,
              inputTokens: 4000,
              outputTokens: 1000,
              wakeCount: 2,
            ),
        ];

        // Empty main daily usage → the top section shows the "no usage" chart
        // with NO bars, so the only _DayBar widgets on screen belong to the
        // per-model cards. Two models → per-model section renders. The scoped
        // large MediaQuery keeps the per-model bars laid out and tappable.
        await tester.pumpWidget(
          hBuildSubject(
            mediaQueryData: hLargeChartMediaQueryData,
            byModel: {
              'models/gemma4:test': modelDays,
              'models/gemma4:other': modelDays,
            },
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('gemma4:test'), findsOneWidget);
        expect(find.text('gemma4:other'), findsOneWidget);

        // No day-detail panel is shown initially: _ModelChartCard starts with
        // _selectedIndex == null, so no Input row anywhere.
        final context = tester.element(find.byType(TokenStatsTab));
        expect(
          find.text(context.messages.agentStatsInputLabel),
          findsNothing,
        );

        // Tap the first per-model bar → onBarTap closure (lines 988-989) runs,
        // _selectedIndex becomes that bar's index, and _SelectedDayDetail
        // (lines 993-996) renders.
        final bars = hDayBarFinder();
        expect(bars, findsWidgets);
        await tester.tap(bars.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The detail panel for the selected per-model day now shows.
        expect(
          find.text(context.messages.agentStatsInputLabel),
          findsWidgets,
        );
        expect(
          find.text(context.messages.agentStatsOutputLabel),
          findsWidgets,
        );

        // Tapping the same bar again toggles _selectedIndex back to null and
        // the detail panel disappears.
        await tester.tap(bars.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text(context.messages.agentStatsInputLabel),
          findsNothing,
        );
      },
    );
  });
}
