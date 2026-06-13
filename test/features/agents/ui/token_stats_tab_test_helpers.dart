import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/token_stats_providers.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';

import '../../../widget_test_utils.dart';

/// A roomy logical surface used by the chart hit-testing tests so the bars
/// are fully laid out and tappable. Scoped to the widget tree via
/// [MediaQuery] (instead of mutating `tester.view.physicalSize` globally),
/// which is lighter and needs no `addTearDown(tester.view.reset)`.
const hLargeChartMediaQueryData = MediaQueryData(size: Size(1200, 2400));

Widget hBuildSubject({
  List<DailyTokenUsage> dailyUsage = const [],
  TokenUsageComparison comparison = const TokenUsageComparison(
    averageTokensByTimeOfDay: 0,
    todayTokens: 0,
  ),
  List<TokenSourceBreakdown> breakdown = const [],
  Map<String, List<DailyTokenUsage>> byModel = const {},
  List<Override> extraOverrides = const [],
  MediaQueryData? mediaQueryData,
}) {
  return makeTestableWidgetNoScroll(
    const Scaffold(body: TokenStatsTab()),
    mediaQueryData: mediaQueryData,
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

/// Finds the tappable [GestureDetector]s that wrap chart bars (`_DayBar`).
///
/// A bar's `GestureDetector` has a `SizedBox` as its direct child, whereas the
/// day-label `GestureDetector`s wrap a `Center`. This lets us tap a bar rather
/// than a label, exercising the bar's own `onTap` closure.
Finder hDayBarFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is GestureDetector &&
        widget.behavior == HitTestBehavior.opaque &&
        widget.child is SizedBox,
  );
}
