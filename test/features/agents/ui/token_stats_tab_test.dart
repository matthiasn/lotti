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
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TokenStatsTab));
      expect(
        find.text(context.messages.agentStatsDailyUsageHeading),
        findsOneWidget,
      );
    });

    testWidgets('shows no-usage message when data is empty', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TokenStatsTab));
      // "Average" and "Today" labels should appear.
      expect(
        find.text(context.messages.agentStatsAverageLabel),
        findsWidgets,
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
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TokenStatsTab));
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
      await tester.pumpAndSettle();

      // 5000 → "5.0K", 15000 → "15.0K" (may appear in both the
      // comparison metrics and the selected day detail panel).
      expect(find.text('5.0K'), findsWidgets);
      expect(find.text('15.0K'), findsWidgets);
    });

    testWidgets('renders chart legend', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      expect(find.text('Research Agent'), findsOneWidget);
      expect(find.text('Summary Agent'), findsOneWidget);
      expect(find.text('80 %'), findsOneWidget);
      expect(find.text('20 %'), findsOneWidget);
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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_rounded), findsNothing);
    });

    testWidgets('shows activity heading', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nav Agent'));
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
  });
}
