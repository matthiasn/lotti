import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
    testWidgets('shows daily usage heading', (tester) async {
      await tester.pumpWidget(hBuildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsDailyUsageHeading),
        findsOneWidget,
      );
    });

    testWidgets('shows no-usage message when data is empty', (tester) async {
      await tester.pumpWidget(hBuildSubject());
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
        hBuildSubject(
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
        find.textContaining('more tokens than usual'),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentStatsTodayLabel),
        findsWidgets,
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
        hBuildSubject(
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
        find.textContaining('fewer tokens than usual'),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentStatsTodayLabel),
        findsWidgets,
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
        hBuildSubject(
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

    testWidgets('orders sections answer-first', (tester) async {
      // A tall real viewport so the lazy ListView builds every section;
      // a scoped MediaQuery alone would not stop the 600px surface from
      // culling the below-the-fold headings.
      tester.view
        ..physicalSize = const Size(1200, 2600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final days = hMakeWeek([1000, 1000, 1000, 1000, 1000, 1000, 2000]);
      await tester.pumpWidget(
        hBuildSubject(
          dailyUsage: days,
          byModel: {'model-a': days, 'model-b': days},
          breakdown: const [
            TokenSourceBreakdown(
              templateId: 'tpl-1',
              displayName: 'Research Agent',
              totalTokens: 8000,
              percentage: 80,
              wakeCount: 3,
              totalDuration: Duration(minutes: 30),
              isHighUsage: false,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Hero heading above the By Model heading, which is above the
      // source-activity heading — the answer leads, diagnostics follow.
      final context = tester.element(find.byType(TokenStatsTab));
      final heroY = tester
          .getTopLeft(find.text(context.messages.agentStatsDailyUsageHeading))
          .dy;
      final modelsY = tester
          .getTopLeft(find.text(context.messages.agentStatsByModelHeading))
          .dy;
      final sourcesY = tester
          .getTopLeft(
            find.text(context.messages.agentStatsSourceActivityHeading),
          )
          .dy;
      expect(heroY, lessThan(modelsY));
      expect(modelsY, lessThan(sourcesY));
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

      await tester.pumpWidget(hBuildSubject(breakdown: sources));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Research Agent'), findsOneWidget);
      expect(find.text('Summary Agent'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      // Both _formatDuration branches render: hours+minutes ('2h 7m') and
      // the minutes-only path ('15m').
      expect(find.textContaining('2h 7m'), findsOneWidget);
      expect(find.textContaining('15m'), findsOneWidget);
    });

    testWidgets('flags high-usage sources with a worded warning line', (
      tester,
    ) async {
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

      await tester.pumpWidget(hBuildSubject(breakdown: sources));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The warning is words, not a bare glyph: it names what is high
      // (the share of today's tokens) right on the row.
      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsSourceHighUsage),
        findsOneWidget,
      );
      // No wordless triangle remains.
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('normal-usage sources carry no warning line', (
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

      await tester.pumpWidget(hBuildSubject(breakdown: sources));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsSourceHighUsage),
        findsNothing,
      );
    });

    testWidgets('shows activity heading', (tester) async {
      await tester.pumpWidget(hBuildSubject());
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

      await tester.pumpWidget(hBuildSubject(breakdown: sources));
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

      await tester.pumpWidget(hBuildSubject(breakdown: sources));
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
        hBuildSubject(
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
      expect(find.textContaining('8K'), findsWidgets);
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
        hBuildSubject(
          byModel: {'models/only-one': singleModelDays},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('only-one'), findsNothing);
    });

    testWidgets('day range toggle moves the selection to 30D', (
      tester,
    ) async {
      await tester.pumpWidget(hBuildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The segmented toggle renders each label twice: an invisible bold
      // ghost (always at the selected style, declared first) that
      // reserves the selected width, then the visible text whose colour
      // tracks the selection — read the visible one.
      expect(find.text('7D'), findsNWidgets(2));
      expect(find.text('30D'), findsNWidgets(2));
      Color? labelColor(String label) => tester
          .widgetList<Text>(find.text(label))
          .map((t) => t.style?.color)
          .whereType<Color>()
          .last;
      final selectedColor = labelColor('7D');
      final unselectedColor = labelColor('30D');
      expect(selectedColor, isNot(unselectedColor));

      await tester.tap(find.text('30D').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Selection flipped: 30D now carries the selected colour.
      expect(labelColor('30D'), selectedColor);
      expect(labelColor('7D'), unselectedColor);
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

      // Today is pre-selected, so the detail panel should show.
      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.textContaining(context.messages.agentStatsInputLabel),
        findsOneWidget,
      );
      expect(
        find.textContaining(context.messages.agentStatsOutputLabel),
        findsOneWidget,
      );
      expect(
        find.textContaining(context.messages.agentStatsThoughtsLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentStatsWakesLabel),
        findsWidgets,
      );
    });

    testWidgets('hides the wake section when the last 24h had no wakes', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1200, 2600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // No wakes: the section and its gap disappear together.
      await tester.pumpWidget(hBuildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentPendingWakesActivityTitle),
        findsNothing,
      );
    });

    testWidgets('shows the wake section at the page tail when wakes exist', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1200, 2600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        hBuildSubject(
          wakeBuckets: [
            for (var h = 0; h < 24; h++)
              HourlyWakeActivity(
                hour: DateTime(2024, 3, 15, h),
                count: h == 9 ? 3 : 0,
                reasons: h == 9 ? const {'scheduled': 3} : const {},
              ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentPendingWakesActivityTitle),
        findsOneWidget,
      );
    });

    testWidgets('dark theme keeps the undarkened amber on the warning row', (
      tester,
    ) async {
      const sources = [
        TokenSourceBreakdown(
          templateId: 'tpl-1',
          displayName: 'Hot Agent',
          totalTokens: 8000,
          percentage: 80,
          wakeCount: 12,
          totalDuration: Duration(hours: 2),
          isHighUsage: true,
        ),
      ];

      await tester.pumpWidget(
        hBuildSubject(breakdown: sources, theme: ThemeData.dark()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Amber has exactly one voice per row — the worded warning line.
      // In dark mode it keeps the default step (the darker for-text step
      // is a light-mode-only accommodation), while the trailing share
      // stays neutral so the row does not double-encode the same fact.
      final context = tester.element(find.byType(TokenStatsTab));
      final tokens = context.designTokens;
      final share = tester.widget<Text>(find.text('80%'));
      expect(share.style?.color, Theme.of(context).colorScheme.onSurface);
      final line = tester.widget<Text>(
        find.text(context.messages.agentStatsSourceHighUsage),
      );
      expect(line.style?.color, tokens.colors.alert.warning.defaultColor);
      expect(line.style?.color, isNot(tokens.colors.alert.warning.hover));
    });

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

      expect(navigatedPath, '/settings/agents/instances/inst-1');
    });

    testWidgets(
      'day selection is shared: a hero bar tap refocuses every model card',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1200, 2600)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final days = hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]);
        await tester.pumpWidget(
          hBuildSubject(
            dailyUsage: days,
            byModel: {'model-a': days, 'model-b': days},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Today (Fri, Mar 15) is pre-selected: hero detail plus one
        // caption anchor per model card (rich spans in the echoes).
        expect(
          find.textContaining('Fri, Mar 15', findRichText: true),
          findsNWidgets(3),
        );

        // Tap Monday in the HERO chart (first chart's bars come first in
        // render order): every section retargets to Monday — the hero
        // detail, both model-card anchors, AND the Agent Activity scope
        // caption, which swaps its "Today" for the selected date.
        await tester.tap(hDayBarFinder().at(2));
        await tester.pump();

        expect(
          find.textContaining('Mon, Mar 11', findRichText: true),
          findsNWidgets(4),
        );
        expect(find.text('Mon, Mar 11 · % of tokens'), findsOneWidget);
        expect(
          find.textContaining('Fri, Mar 15', findRichText: true),
          findsNothing,
        );
      },
    );

    testWidgets('re-tapping the selected bar keeps the detail (no toggle)', (
      tester,
    ) async {
      final days = hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]);
      await tester.pumpWidget(hBuildSubject(dailyUsage: days));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Fri, Mar 15 · Today'), findsOneWidget);

      // Today's bar is index 6 and already selected — tapping it again
      // must not destroy the detail rows under the reader.
      await tester.tap(hDayBarFinder().at(6));
      await tester.pump();

      expect(find.text('Fri, Mar 15 · Today'), findsOneWidget);
    });

    testWidgets(
      'Agent Activity rides the day selection: day-scoped rows, dated '
      'caption, day-neutral warning — while the hero notice stays anchored '
      'to today',
      (tester) async {
        final week = hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]);
        const todaySources = [
          TokenSourceBreakdown(
            templateId: 'tpl-hot',
            displayName: 'Task Assistant',
            totalTokens: 900,
            percentage: 90,
            wakeCount: 9,
            totalDuration: Duration(minutes: 30),
            isHighUsage: true,
          ),
          TokenSourceBreakdown(
            templateId: 'tpl-cool',
            displayName: 'Daily Review',
            totalTokens: 100,
            percentage: 10,
            wakeCount: 2,
            totalDuration: Duration(minutes: 5),
            isHighUsage: false,
          ),
        ];
        const mondaySources = [
          TokenSourceBreakdown(
            templateId: 'tpl-night',
            displayName: 'Night Crawler',
            totalTokens: 500,
            percentage: 100,
            wakeCount: 3,
            totalDuration: Duration(minutes: 12),
            isHighUsage: true,
          ),
        ];
        await tester.pumpWidget(
          hBuildSubject(
            dailyUsage: week,
            comparison: const TokenUsageComparison(
              averageTokensByTimeOfDay: 500,
              todayTokens: 700,
            ),
            breakdownForDay: (day) =>
                day == DateTime(2024, 3, 15) ? todaySources : mondaySources,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final context = tester.element(find.byType(TokenStatsTab));
        final messages = context.messages;

        // Today pre-selected: today-register warning row and the hero
        // notice naming the hot source, in the shared amber.
        expect(find.text(messages.agentStatsSourceScopeLabel), findsOneWidget);
        expect(find.text(messages.agentStatsSourceHighUsage), findsOneWidget);
        final notice = tester.widget<Text>(
          find.text(messages.agentStatsHeroHighUsage('Task Assistant')),
        );
        expect(notice.style!.color, warningTextColor(context));

        // Retarget to Monday: rows swap to Monday's source, the caption
        // names the date, and the warning drops the word "today".
        await tester.tap(hDayBarFinder().at(2));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Night Crawler'), findsOneWidget);
        expect(find.text('Task Assistant'), findsNothing);
        expect(
          find.text(messages.agentStatsSourceScopeDayLabel('Mon, Mar 11')),
          findsOneWidget,
        );
        expect(
          find.text(messages.agentStatsSourceHighUsageDay),
          findsOneWidget,
        );
        expect(find.text(messages.agentStatsSourceHighUsage), findsNothing);
        // The hero notice still speaks about today — the page's one real
        // warning must not vanish while the reader studies a past day.
        expect(
          find.text(messages.agentStatsHeroHighUsage('Task Assistant')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the detail header grows a Today reset link on a past day; tapping '
      'it snaps every section back to today',
      (tester) async {
        final week = hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]);
        await tester.pumpWidget(hBuildSubject(dailyUsage: week));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final context = tester.element(find.byType(TokenStatsTab));
        final todayLabel = context.messages.agentStatsTodayLabel;

        // Today selected: no reset link (the header suffix says Today).
        expect(find.widgetWithText(InkWell, todayLabel), findsNothing);

        await tester.tap(hDayBarFinder().at(2));
        await tester.pump();
        expect(find.text('Mon, Mar 11'), findsOneWidget);

        // The teal return leg appears; tapping it restores today
        // everywhere without hunting the last chart column.
        final reset = find.widgetWithText(InkWell, todayLabel);
        expect(reset, findsOneWidget);
        await tester.tap(reset);
        await tester.pump();

        expect(find.text('Fri, Mar 15 · Today'), findsOneWidget);
        expect(find.text('Mon, Mar 11'), findsNothing);
      },
    );

    testWidgets('switching 7D->30D preserves the selected calendar day', (
      tester,
    ) async {
      final week = hMakeWeek([1000, 2000, 3000, 4000, 5000, 6000, 7000]);
      await tester.pumpWidget(hBuildSubject(dailyUsage: week));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select Monday (index 2 of 7 -> daysAgo 4).
      await tester.tap(hDayBarFinder().at(2));
      await tester.pump();
      expect(find.text('Mon, Mar 11'), findsOneWidget);

      await tester.tap(find.text('30D').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The selection is keyed by calendar date, not list index: whatever
      // list the new range resolves to (the override returns the same 7
      // entries), the SAME day stays selected — no index remapping, no
      // detail unmount, no exception.
      expect(tester.takeException(), isNull);
      expect(find.text('Mon, Mar 11'), findsOneWidget);

      // And it survives the round trip.
      await tester.tap(find.text('7D').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mon, Mar 11'), findsOneWidget);
    });

    testWidgets('source list shows no-usage message when empty', (
      tester,
    ) async {
      await tester.pumpWidget(hBuildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsNoUsage),
        findsWidgets,
      );
    });
  });
}
