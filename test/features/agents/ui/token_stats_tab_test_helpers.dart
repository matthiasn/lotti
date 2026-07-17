import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/token_stats_providers.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';

import '../../../widget_test_utils.dart';

/// A roomy logical surface used by the chart hit-testing tests so the bars
/// are fully laid out and tappable. Scoped to the widget tree via
/// [MediaQuery] (instead of mutating `tester.view.physicalSize` globally),
/// which is lighter and needs no `addTearDown(tester.view.reset)`.
const hLargeChartMediaQueryData = MediaQueryData(size: Size(1200, 2400));

/// One day of usage with every field defaulted, so tests state only what
/// they assert on. Dates are deterministic: [daysAgo] back from the fixed
/// "today" of Friday 2024-03-15.
DailyTokenUsage hMakeDay({
  int daysAgo = 0,
  int totalTokens = 1000,
  int? tokensByTimeOfDay,
  int inputTokens = 0,
  int outputTokens = 0,
  int thoughtsTokens = 0,
  int cachedInputTokens = 0,
  int wakeCount = 0,
}) {
  return DailyTokenUsage(
    date: DateTime(2024, 3, 15 - daysAgo),
    totalTokens: totalTokens,
    tokensByTimeOfDay: tokensByTimeOfDay ?? totalTokens,
    isToday: daysAgo == 0,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    thoughtsTokens: thoughtsTokens,
    cachedInputTokens: cachedInputTokens,
    wakeCount: wakeCount,
  );
}

/// A week of days ending today, oldest first, with [totalsOldestFirst]
/// as each day's total.
List<DailyTokenUsage> hMakeWeek(List<int> totalsOldestFirst) => [
  for (final (i, total) in totalsOldestFirst.indexed)
    hMakeDay(daysAgo: totalsOldestFirst.length - 1 - i, totalTokens: total),
];

Widget hBuildSubject({
  List<DailyTokenUsage> dailyUsage = const [],
  TokenUsageComparison comparison = const TokenUsageComparison(
    averageTokensByTimeOfDay: 0,
    todayTokens: 0,
  ),
  List<TokenSourceBreakdown> breakdown = const [],
  List<TokenSourceBreakdown> Function(DateTime day)? breakdownForDay,
  Map<String, List<DailyTokenUsage>> byModel = const {},
  List<HourlyWakeActivity> wakeBuckets = const [],
  List<Override> extraOverrides = const [],
  MediaQueryData? mediaQueryData,
  ThemeData? theme,
}) {
  return makeTestableWidgetNoScroll(
    const Scaffold(body: TokenStatsTab()),
    mediaQueryData: mediaQueryData,
    theme: theme,
    overrides: [
      hourlyWakeActivityProvider.overrideWith((ref) async => wakeBuckets),
      dailyTokenUsageProvider.overrideWith(
        (ref, days) async => dailyUsage,
      ),
      tokenUsageComparisonProvider.overrideWith(
        (ref, days) async => comparison,
      ),
      dailyTokenUsageByModelProvider.overrideWith(
        (ref, days) async => byModel,
      ),
      // Day-aware when a test needs per-day rows; one fixed list otherwise.
      tokenSourceBreakdownProvider.overrideWith(
        (ref, day) async => breakdownForDay?.call(day) ?? breakdown,
      ),
      ...extraOverrides,
    ],
  );
}

/// Finds the tappable [GestureDetector]s that wrap chart bars (`_DayBar`).
///
/// A non-empty bar's `GestureDetector` wraps a full-column [SizedBox]
/// holding a bottom-anchored [FractionallySizedBox] with the painted
/// [Container] — the tap target spans the whole column while only the
/// bar is painted. The
/// day-label `GestureDetector`s wrap a `Center`, and an empty day's wraps
/// a bare `SizedBox.expand` with no child; this predicate matches only
/// the painted bars, in render order.
Finder hDayBarFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is GestureDetector &&
        widget.behavior == HitTestBehavior.opaque &&
        widget.child is SizedBox &&
        (widget.child! as SizedBox).child is FractionallySizedBox,
  );
}

/// Finds an empty day's tap target: the full-height opaque
/// `SizedBox.expand` with nothing painted inside.
Finder hZeroDayTargetFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is GestureDetector &&
        widget.behavior == HitTestBehavior.opaque &&
        widget.child is SizedBox &&
        (widget.child! as SizedBox).child == null,
  );
}

/// The painted [Container] of the [index]-th chart bar matched by
/// [hDayBarFinder] (in render order).
Container hDayBarContainer(WidgetTester tester, int index) {
  final sizedBox =
      tester.widget<GestureDetector>(hDayBarFinder().at(index)).child!
          as SizedBox;
  final fractional = sizedBox.child! as FractionallySizedBox;
  return (fractional.child! as Center).child! as Container;
}

/// The rendered colour of the [index]-th chart bar.
Color hDayBarColor(WidgetTester tester, int index) =>
    (hDayBarContainer(tester, index).decoration! as BoxDecoration).color!;
