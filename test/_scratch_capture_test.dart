import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/token_stats_providers.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';

import 'test_utils/screenshot_harness.dart';
import 'widget_test_utils.dart';

/// Frozen "now": Friday 2024-03-15 14:30 — matches the helpers' fixed today.
final _now = DateTime(2024, 3, 15, 14, 30);

DailyTokenUsage _day(
  int daysAgo,
  int total, {
  int? byTime,
  int input = 0,
  int output = 0,
  int thoughts = 0,
  int cached = 0,
  int wakes = 0,
}) {
  return DailyTokenUsage(
    date: DateTime(2024, 3, 15 - daysAgo),
    totalTokens: total,
    tokensByTimeOfDay: byTime ?? total,
    isToday: daysAgo == 0,
    inputTokens: input,
    outputTokens: output,
    thoughtsTokens: thoughts,
    cachedInputTokens: cached,
    wakeCount: wakes,
  );
}

/// A realistic week ending today: varied totals, today partially elapsed.
List<DailyTokenUsage> _week() => [
  _day(
    6,
    412000,
    byTime: 236000,
    input: 180000,
    output: 160000,
    thoughts: 42000,
    cached: 96000,
    wakes: 9,
  ),
  _day(
    5,
    1180000,
    byTime: 664000,
    input: 520000,
    output: 430000,
    thoughts: 130000,
    cached: 310000,
    wakes: 21,
  ),
  _day(
    4,
    236000,
    byTime: 141000,
    input: 98000,
    output: 96000,
    thoughts: 22000,
    cached: 51000,
    wakes: 6,
  ),
  _day(
    3,
    668000,
    byTime: 355000,
    input: 290000,
    output: 260000,
    thoughts: 58000,
    cached: 155000,
    wakes: 12,
  ),
  _day(
    2,
    1520000,
    byTime: 830000,
    input: 660000,
    output: 590000,
    thoughts: 145000,
    cached: 420000,
    wakes: 24,
  ),
  _day(
    1,
    890000,
    byTime: 470000,
    input: 380000,
    output: 350000,
    thoughts: 76000,
    cached: 205000,
    wakes: 15,
  ),
  _day(
    0,
    742000,
    input: 310000,
    output: 292000,
    thoughts: 92000,
    cached: 168000,
    wakes: 14,
  ),
];

/// Per-model slices of the same week (two models → section renders).
Map<String, List<DailyTokenUsage>> _byModel() => {
  'Claude Sonnet 4.5': [
    _day(6, 300000, byTime: 170000),
    _day(5, 860000, byTime: 480000),
    _day(4, 170000, byTime: 101000),
    _day(3, 480000, byTime: 255000),
    _day(2, 1090000, byTime: 590000),
    _day(1, 640000, byTime: 340000),
    _day(
      0,
      530000,
      input: 220000,
      output: 210000,
      thoughts: 62000,
      cached: 120000,
    ),
  ],
  'Claude Haiku 4.5': [
    _day(6, 112000, byTime: 66000),
    _day(5, 320000, byTime: 184000),
    _day(4, 66000, byTime: 40000),
    _day(3, 188000, byTime: 100000),
    _day(2, 430000, byTime: 240000),
    _day(1, 250000, byTime: 130000),
    _day(
      0,
      212000,
      input: 90000,
      output: 82000,
      thoughts: 30000,
      cached: 48000,
    ),
  ],
};

List<TokenSourceBreakdown> _breakdown() => const [
  TokenSourceBreakdown(
    templateId: 'tmpl-task',
    displayName: 'Task Assistant',
    totalTokens: 341000,
    percentage: 46,
    wakeCount: 26,
    totalDuration: Duration(hours: 3, minutes: 20),
    isHighUsage: true,
  ),
  TokenSourceBreakdown(
    templateId: 'tmpl-review',
    displayName: 'Daily Review',
    totalTokens: 178000,
    percentage: 24,
    wakeCount: 8,
    totalDuration: Duration(hours: 1, minutes: 5),
    isHighUsage: false,
  ),
  TokenSourceBreakdown(
    templateId: 'tmpl-inbox',
    displayName: 'Inbox Triage',
    totalTokens: 134000,
    percentage: 18,
    wakeCount: 11,
    totalDuration: Duration(minutes: 40),
    isHighUsage: false,
  ),
  TokenSourceBreakdown(
    templateId: 'tmpl-transcribe',
    displayName: 'Transcription Fixer',
    totalTokens: 89000,
    percentage: 12,
    wakeCount: 4,
    totalDuration: Duration(minutes: 25),
    isHighUsage: false,
  ),
];

/// A plausible rolling-24h wake histogram: quiet night, active afternoon.
List<HourlyWakeActivity> _wakeBuckets() {
  const counts = [
    0, 0, 0, 0, 0, 1, 2, 4, 6, 5, 3, 7, //
    9, 6, 8, 4, 2, 3, 5, 2, 1, 0, 0, 0,
  ];
  return [
    for (var h = 0; h < 24; h++)
      HourlyWakeActivity(
        hour: DateTime(2024, 3, 15, h),
        count: counts[h],
        reasons: {
          if (counts[h] > 0) 'scheduled': (counts[h] / 2).ceil(),
          if (counts[h] > 1) 'subscription': counts[h] ~/ 2,
        },
      ),
  ];
}

List<Override> _overrides({required bool aboveAverage}) => [
  hourlyWakeActivityProvider.overrideWith((ref) async => _wakeBuckets()),
  dailyTokenUsageProvider.overrideWith((ref, days) async => _week()),
  tokenUsageComparisonProvider.overrideWith(
    (ref, days) async => TokenUsageComparison(
      averageTokensByTimeOfDay: aboveAverage ? 452000 : 820000,
      todayTokens: 742000,
    ),
  ),
  dailyTokenUsageByModelProvider.overrideWith((ref, days) async => _byModel()),
  tokenSourceBreakdownProvider.overrideWith((ref, day) async => _breakdown()),
];

/// The tab on the page surface, as `AgentSettingsPage` hosts it (shell
/// chrome — app bar, tab strip, bottom nav — intentionally absent).
Widget _statsSurface() => Builder(
  builder: (context) => Scaffold(
    backgroundColor: dsPageSurface(context),
    body: const TokenStatsTab(),
  ),
);

void main() {
  setUpAll(loadAppFonts);
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  testWidgets('stats phone dark', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await captureInApp(
        tester,
        child: _statsSurface(),
        name: 'stats_phone',
        overrides: _overrides(aboveAverage: false),
      );
    });
  });

  testWidgets('stats phone dark — above average', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await captureInApp(
        tester,
        child: _statsSurface(),
        name: 'stats_phone_above_average',
        overrides: _overrides(aboveAverage: true),
      );
    });
  });

  testWidgets('stats desktop dark', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await captureInApp(
        tester,
        child: _statsSurface(),
        name: 'stats_desktop',
        size: ScreenshotViewport.desktop,
        overrides: _overrides(aboveAverage: false),
      );
    });
  });

  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.fling(find.byType(ListView), const Offset(0, -4000), 8000);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('stats phone dark — bottom', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await captureInApp(
        tester,
        child: _statsSurface(),
        name: 'stats_phone_bottom',
        overrides: _overrides(aboveAverage: false),
        interaction: scrollToBottom,
      );
    });
  });

  testWidgets('stats desktop dark — bottom', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await captureInApp(
        tester,
        child: _statsSurface(),
        name: 'stats_desktop_bottom',
        size: ScreenshotViewport.desktop,
        overrides: _overrides(aboveAverage: false),
        interaction: scrollToBottom,
      );
    });
  });
}
