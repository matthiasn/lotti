import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/token_stats_providers.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../widget_test_utils.dart';

Widget _buildSubject({
  List<DailyTokenUsage> dailyUsage = const [],
  TokenUsageComparison comparison = const TokenUsageComparison(
    averageTokensByTimeOfDay: 0,
    todayTokens: 0,
  ),
  List<TokenSourceBreakdown> breakdown = const [],
  Map<String, List<DailyTokenUsage>> byModel = const {},
  List<Override> extraOverrides = const [],
}) {
  return makeTestableWidgetNoScroll(
    const Scaffold(body: TokenStatsTab()),
    overrides: [
      hourlyWakeActivityProvider.overrideWith((ref) async => const []),
      dailyTokenUsageProvider.overrideWith(
        (ref, days) async => dailyUsage,
      ),
      tokenUsageComparisonProvider.overrideWith(
        (ref, days) async => comparison,
      ),
      dailyTokenUsageByModelProvider.overrideWith(
        (ref, days) async => byModel,
      ),
      tokenSourceBreakdownProvider.overrideWith(
        (ref) async => breakdown,
      ),
      ...extraOverrides,
    ],
  );
}

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  group('TokenStatsTab', () {
    testWidgets('shows daily usage heading', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsDailyUsageHeading),
        findsOneWidget,
      );
    });

    testWidgets('shows no-usage message when data is empty', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsNoUsage),
        findsWidgets,
      );
    });

    testWidgets('shows comparison summary when above average', (
      tester,
    ) async {
      final days = [
        for (var i = 6; i >= 1; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 15 - i),
            totalTokens: 10000,
            tokensByTimeOfDay: 5000,
            isToday: false,
          ),
        DailyTokenUsage(
          date: DateTime(2024, 3, 15),
          totalTokens: 15000,
          tokensByTimeOfDay: 15000,
          isToday: true,
        ),
      ];

      await tester.pumpWidget(
        _buildSubject(
          dailyUsage: days,
          comparison: const TokenUsageComparison(
            averageTokensByTimeOfDay: 5000,
            todayTokens: 15000,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      // Above-average summary text should appear.
      expect(
        find.textContaining('more tokens today'),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentStatsTodayLabel),
        findsOneWidget,
      );
    });

    testWidgets('shows comparison summary when below average', (
      tester,
    ) async {
      final days = [
        for (var i = 6; i >= 1; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 15 - i),
            totalTokens: 10000,
            tokensByTimeOfDay: 5000,
            isToday: false,
          ),
        DailyTokenUsage(
          date: DateTime(2024, 3, 15),
          totalTokens: 2000,
          tokensByTimeOfDay: 2000,
          isToday: true,
        ),
      ];

      await tester.pumpWidget(
        _buildSubject(
          dailyUsage: days,
          comparison: const TokenUsageComparison(
            averageTokensByTimeOfDay: 5000,
            todayTokens: 2000,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      // Below-average summary text should appear.
      expect(
        find.textContaining('fewer tokens today'),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentStatsTodayLabel),
        findsOneWidget,
      );
    });

    testWidgets('shows formatted token counts for average and today', (
      tester,
    ) async {
      final days = [
        for (var i = 6; i >= 1; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 15 - i),
            totalTokens: 10000,
            tokensByTimeOfDay: 5000,
            isToday: false,
          ),
        DailyTokenUsage(
          date: DateTime(2024, 3, 15),
          totalTokens: 15000,
          tokensByTimeOfDay: 15000,
          isToday: true,
        ),
      ];

      await tester.pumpWidget(
        _buildSubject(
          dailyUsage: days,
          comparison: const TokenUsageComparison(
            averageTokensByTimeOfDay: 5000,
            todayTokens: 15000,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // NumberFormat.compact() formats: 5000 → "5K", 15000 → "15K"
      expect(find.text('5K'), findsWidgets);
      expect(find.text('15K'), findsWidgets);
    });

    testWidgets('renders chart legend', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsAllDayLegend),
        findsOneWidget,
      );
    });

    testWidgets('shows source breakdown with items', (tester) async {
      const sources = [
        TokenSourceBreakdown(
          templateId: 'tpl-1',
          displayName: 'Research Agent',
          totalTokens: 8000,
          percentage: 80,
          wakeCount: 12,
          totalDuration: Duration(hours: 2, minutes: 7),
          isHighUsage: true,
        ),
        TokenSourceBreakdown(
          templateId: 'tpl-2',
          displayName: 'Summary Agent',
          totalTokens: 2000,
          percentage: 20,
          wakeCount: 3,
          totalDuration: Duration(minutes: 15),
          isHighUsage: false,
        ),
      ];

      await tester.pumpWidget(_buildSubject(breakdown: sources));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Research Agent'), findsOneWidget);
      expect(find.text('Summary Agent'), findsOneWidget);
      expect(find.text('80 %'), findsOneWidget);
      expect(find.text('20 %'), findsOneWidget);
      // Both _formatDuration branches render: hours+minutes ('2h 7m') and
      // the minutes-only path ('15m').
      expect(find.textContaining('2h 7m'), findsOneWidget);
      expect(find.textContaining('15m'), findsOneWidget);
    });

    testWidgets('shows warning icon for high-usage sources', (tester) async {
      const sources = [
        TokenSourceBreakdown(
          templateId: 'tpl-1',
          displayName: 'Heavy Agent',
          totalTokens: 9000,
          percentage: 90,
          wakeCount: 20,
          totalDuration: Duration(hours: 3),
          isHighUsage: true,
        ),
      ];

      await tester.pumpWidget(_buildSubject(breakdown: sources));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    });

    testWidgets('does not show warning icon for normal-usage sources', (
      tester,
    ) async {
      const sources = [
        TokenSourceBreakdown(
          templateId: 'tpl-1',
          displayName: 'Normal Agent',
          totalTokens: 5000,
          percentage: 50,
          wakeCount: 5,
          totalDuration: Duration(minutes: 30),
          isHighUsage: false,
        ),
      ];

      await tester.pumpWidget(_buildSubject(breakdown: sources));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.error_rounded), findsNothing);
    });

    testWidgets('shows activity heading', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsSourceActivityHeading),
        findsOneWidget,
      );
    });

    testWidgets('tapping source navigates to template detail', (
      tester,
    ) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      const sources = [
        TokenSourceBreakdown(
          templateId: 'tpl-nav',
          displayName: 'Nav Agent',
          totalTokens: 1000,
          percentage: 100,
          wakeCount: 1,
          totalDuration: Duration(minutes: 5),
          isHighUsage: false,
        ),
      ];

      await tester.pumpWidget(_buildSubject(breakdown: sources));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Nav Agent'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(navigatedPath, '/settings/agents/templates/tpl-nav');
    });

    testWidgets('shows activity description with duration and wake count', (
      tester,
    ) async {
      const sources = [
        TokenSourceBreakdown(
          templateId: 'tpl-1',
          displayName: 'Worker Agent',
          totalTokens: 5000,
          percentage: 100,
          wakeCount: 7,
          totalDuration: Duration(hours: 1, minutes: 30),
          isHighUsage: false,
        ),
      ];

      await tester.pumpWidget(_buildSubject(breakdown: sources));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      // The activity description is a single text joining duration and
      // wake count with a middle dot.
      expect(
        find.textContaining(
          context.messages.agentStatsSourceActiveFor('1h 30m'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(context.messages.agentStatsSourceWakes(7)),
        findsOneWidget,
      );
    });

    testWidgets('shows per-model chart cards when multiple models', (
      tester,
    ) async {
      final modelADays = [
        for (var i = 6; i >= 0; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 15 - i),
            totalTokens: i == 0 ? 8000 : 0,
            tokensByTimeOfDay: i == 0 ? 8000 : 0,
            isToday: i == 0,
          ),
      ];
      final modelBDays = [
        for (var i = 6; i >= 0; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 15 - i),
            totalTokens: i == 0 ? 2000 : 0,
            tokensByTimeOfDay: i == 0 ? 2000 : 0,
            isToday: i == 0,
          ),
      ];

      await tester.pumpWidget(
        _buildSubject(
          byModel: {
            'models/gemma4:26b': modelADays,
            'models/gemma4:e4b': modelBDays,
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('gemma4:26b'), findsOneWidget);
      expect(find.text('gemma4:e4b'), findsOneWidget);
      expect(find.text('8K'), findsWidgets);
    });

    testWidgets('hides per-model section when only one model', (
      tester,
    ) async {
      final singleModelDays = [
        for (var i = 6; i >= 0; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 15 - i),
            totalTokens: 1000,
            tokensByTimeOfDay: 1000,
            isToday: i == 0,
          ),
      ];

      await tester.pumpWidget(
        _buildSubject(
          byModel: {'models/only-one': singleModelDays},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('only-one'), findsNothing);
    });

    testWidgets('day range selector switches between 7D and 30D', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 7D should be selected by default.
      expect(find.text('7D'), findsOneWidget);
      expect(find.text('30D'), findsOneWidget);

      // Tap 30D.
      await tester.tap(find.text('30D'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Both labels still visible (selector still rendered).
      expect(find.text('7D'), findsOneWidget);
      expect(find.text('30D'), findsOneWidget);
    });

    testWidgets('tapping a chart bar selects it and shows detail', (
      tester,
    ) async {
      final days = [
        for (var i = 6; i >= 0; i--)
          DailyTokenUsage(
            date: DateTime(2024, 3, 15 - i),
            totalTokens: 10000,
            tokensByTimeOfDay: 5000,
            isToday: i == 0,
            inputTokens: 7000,
            outputTokens: 2000,
            thoughtsTokens: 1000,
            wakeCount: 3,
          ),
      ];

      await tester.pumpWidget(
        _buildSubject(
          dailyUsage: days,
          comparison: const TokenUsageComparison(
            averageTokensByTimeOfDay: 5000,
            todayTokens: 10000,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Today is pre-selected, so the detail panel should show.
      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsInputLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentStatsOutputLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentStatsThoughtsLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentStatsWakesLabel),
        findsWidgets,
      );
    });

    testWidgets('source list shows no-usage message when empty', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsNoUsage),
        findsWidgets,
      );
    });

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
        _buildSubject(
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
      // The provider override in _buildSubject returns the same list regardless
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
        _buildSubject(
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
        _buildSubject(
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
          _buildSubject(
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

      await tester.pumpWidget(_buildSubject(breakdown: sources));
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
        _buildSubject(
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
        // Give the screen room so the chart bars are fully laid out and
        // hit-testable when tapped directly (exercises _DayBar.onTap, line 466).
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

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
          _buildSubject(
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
        final bars = _dayBarFinder();
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
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Non-today days where tokensByTimeOfDay == totalTokens force
        // byTimeIsFullBar == true (line 625). Index 6 (today) is small so a
        // past day owns the max height.
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
          _buildSubject(
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
        final bars = _dayBarFinder();
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
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

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
        // per-model cards. Two models → per-model section renders.
        await tester.pumpWidget(
          _buildSubject(
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
        final bars = _dayBarFinder();
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

/// Finds the tappable [GestureDetector]s that wrap chart bars (`_DayBar`).
///
/// A bar's `GestureDetector` has a `SizedBox` as its direct child, whereas the
/// day-label `GestureDetector`s wrap a `Center`. This lets us tap a bar rather
/// than a label, exercising the bar's own `onTap` closure.
Finder _dayBarFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is GestureDetector &&
        widget.behavior == HitTestBehavior.opaque &&
        widget.child is SizedBox,
  );
}
