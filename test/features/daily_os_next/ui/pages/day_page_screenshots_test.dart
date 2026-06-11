/// Screenshot harness for the Daily OS Day page — the agenda and the day
/// timeline (planned vs recorded lanes) plus the planner-knowledge
/// surfacing.
///
/// Renders a realistic "plan vs reality" day: a full day of planned blocks
/// and a full day of recorded sessions that diverge the way real days do
/// (late starts, an unplanned incident, a skipped block, one session still
/// running). PNGs land in `screenshots/daily_os_next/` (gitignored) for
/// design review. Not a golden test — assertions only guard that each
/// scenario renders.
///
/// Opt-in (real-font loading leaks process-wide — see the harness). Run:
/// `LOTTI_SCREENSHOT_DIR=/tmp/day_page fvm flutter test \
///   test/features/daily_os_next/ui/pages/day_page_screenshots_test.dart`
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/planner_knowledge_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../screenshot_harness.dart';

/// Mid-afternoon so the now-line sits inside the day and one recorded
/// session can be in progress.
final DateTime _now = DateTime(2026, 6, 8, 15, 55);
final DateTime _day = DateTime(2026, 6, 8);

const _deepWork = DayAgentCategory(
  id: 'cat-deep',
  name: 'Deep Work',
  colorHex: '8B5CF6',
);
const _client = DayAgentCategory(
  id: 'cat-client',
  name: 'Client Work',
  colorHex: '4F9DDE',
);
const _health = DayAgentCategory(
  id: 'cat-health',
  name: 'Health',
  colorHex: '34D399',
);
const _admin = DayAgentCategory(
  id: 'cat-admin',
  name: 'Admin',
  colorHex: 'E8A33D',
);

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 6, 8, hour, minute);

TimeBlock _planned(
  String id,
  String title,
  DateTime start,
  DateTime end,
  DayAgentCategory category, {
  String? reason,
  int? sessionIndex,
  int? sessionTotal,
}) => TimeBlock(
  id: id,
  title: title,
  start: start,
  end: end,
  type: TimeBlockType.ai,
  state: TimeBlockState.drafted,
  category: category,
  reason: reason,
  sessionIndex: sessionIndex,
  sessionTotal: sessionTotal,
);

TimeBlock _tracked(
  String id,
  String title,
  DateTime start,
  DateTime end,
  DayAgentCategory category, {
  TimeBlockState state = TimeBlockState.completed,
}) => TimeBlock(
  id: 'actual:$id',
  title: title,
  start: start,
  end: end,
  type: TimeBlockType.manual,
  state: state,
  category: category,
);

/// A full planned day: focus morning, client afternoon, health bookends.
DraftPlan _plan() {
  final blocks = [
    _planned('blk-review', 'Morning review', _at(8, 30), _at(9), _admin),
    _planned(
      'blk-deep',
      'Planner deep work',
      _at(9),
      _at(11),
      _deepWork,
      reason: 'Focus peak before meetings',
    ),
    TimeBlock(
      id: 'blk-buffer',
      title: 'Buffer',
      start: _at(11),
      end: _at(11, 15),
      type: TimeBlockType.buffer,
      state: TimeBlockState.drafted,
      category: _admin,
    ),
    _planned(
      'blk-design',
      'Design team check-in',
      _at(11, 15),
      _at(12),
      _client,
    ),
    _planned('blk-lunch', 'Lunch + walk', _at(12), _at(13), _health),
    _planned(
      'blk-followup',
      'Client follow-up + invoices',
      _at(13),
      _at(14, 30),
      _client,
    ),
    _planned(
      'blk-slides',
      'Workshop slides',
      _at(14, 30),
      _at(16),
      _deepWork,
      sessionIndex: 1,
      sessionTotal: 2,
    ),
    _planned('blk-email', 'Email triage', _at(16, 15), _at(17), _admin),
    _planned('blk-run', 'Short run', _at(17, 30), _at(18), _health),
  ];

  return DraftPlan(
    dayDate: _day,
    blocks: blocks,
    bands: [
      EnergyBand(
        start: _at(9),
        end: _at(12),
        level: EnergyLevel.high,
        label: 'HIGH ENERGY',
      ),
      EnergyBand(
        start: _at(13),
        end: _at(15),
        level: EnergyLevel.low,
        label: 'POST-LUNCH DIP',
      ),
      EnergyBand(
        start: _at(16),
        end: _at(18),
        level: EnergyLevel.secondWind,
        label: 'SECOND WIND',
      ),
    ],
    // Blocks sum to 525m (8h45m) — capacity leaves an honest 15m gap.
    capacityMinutes: 540,
    scheduledMinutes: 525,
    agendaItems: const [
      AgendaItem(
        id: 'ag-review',
        title: 'Morning review',
        category: _admin,
        linkedBlockIds: ['blk-review'],
        totalEstimateMinutes: 30,
        progress: 1,
        state: AgendaItemState.done,
      ),
      AgendaItem(
        id: 'ag-deep',
        title: 'Planner deep work',
        category: _deepWork,
        linkedBlockIds: ['blk-deep'],
        totalEstimateMinutes: 120,
        progress: 1,
        state: AgendaItemState.done,
        outcome: 'Anchored layout shipped to the branch',
      ),
      AgendaItem(
        id: 'ag-design',
        title: 'Design team check-in',
        category: _client,
        linkedBlockIds: ['blk-design'],
        totalEstimateMinutes: 45,
        progress: 1,
        state: AgendaItemState.done,
      ),
      AgendaItem(
        id: 'ag-lunch',
        title: 'Lunch + walk',
        category: _health,
        linkedBlockIds: ['blk-lunch'],
        totalEstimateMinutes: 60,
        progress: 1,
        state: AgendaItemState.done,
      ),
      // The 13:05–14:55 recording on the timeline closed this out — the
      // agenda must agree with the lane (no cross-view contradictions).
      AgendaItem(
        id: 'ag-followup',
        title: 'Client follow-up + invoices',
        category: _client,
        linkedBlockIds: ['blk-followup'],
        totalEstimateMinutes: 90,
        progress: 1,
        state: AgendaItemState.done,
        outcome: 'Invoices out, follow-up notes in the thread',
      ),
      AgendaItem(
        id: 'ag-slides',
        title: 'Workshop slides',
        category: _deepWork,
        linkedBlockIds: ['blk-slides'],
        totalEstimateMinutes: 180,
        progress: 0.4,
        state: AgendaItemState.inProgress,
        outcome: 'Deck ready for Thursday dry run',
      ),
      AgendaItem(
        id: 'ag-email',
        title: 'Email triage',
        category: _admin,
        linkedBlockIds: ['blk-email'],
        totalEstimateMinutes: 45,
      ),
      AgendaItem(
        id: 'ag-run',
        title: 'Short run',
        category: _health,
        linkedBlockIds: ['blk-run'],
        totalEstimateMinutes: 30,
      ),
    ],
  );
}

/// Recorded reality: late starts, a production incident nobody planned,
/// lunch without the walk, the afternoon running long, slides still in
/// progress under the now-line, email triage never happened (yet).
List<TimeBlock> _actuals() => [
  _tracked('review', 'Morning review', _at(8, 42), _at(9, 5), _admin),
  _tracked('deep', 'Planner deep work', _at(9, 5), _at(10, 38), _deepWork),
  _tracked(
    'incident',
    'Production incident triage',
    _at(10, 40),
    _at(11, 2),
    _client,
  ),
  _tracked(
    'design',
    'Design team check-in',
    _at(11, 18),
    _at(12, 5),
    _client,
  ),
  _tracked('lunch', 'Lunch', _at(12, 10), _at(12, 50), _health),
  _tracked(
    'followup',
    'Client follow-up + invoices',
    _at(13, 5),
    _at(14, 55),
    _client,
  ),
  _tracked(
    'slides',
    'Workshop slides',
    _at(15, 10),
    _at(15, 45),
    _deepWork,
    state: TimeBlockState.inProgress,
  ),
];

PlannerKnowledgeEntity _knowledge(
  String id,
  String key,
  String hook,
  String statement, {
  required KnowledgeStatus status,
  KnowledgeSource source = KnowledgeSource.agentInferred,
  List<String> tags = const [],
}) =>
    AgentDomainEntity.plannerKnowledge(
          id: id,
          agentId: 'planner-001',
          key: key,
          hook: hook,
          statementText: statement,
          source: source,
          status: status,
          createdAt: _now,
          updatedAt: _now,
          vectorClock: null,
          tags: tags,
        )
        as PlannerKnowledgeEntity;

PlannerKnowledgeView _knowledgeView() => PlannerKnowledgeView(
  proposed: [
    _knowledge(
      'kn-1',
      'deep-work-before-meetings',
      'Deep work lands before the first meeting',
      'Deep work sessions that start before the first meeting of the day '
          'run 30% longer before being interrupted.',
      status: KnowledgeStatus.proposed,
      tags: const ['focus', 'mornings'],
    ),
    _knowledge(
      'kn-2',
      'walks-skipped-after-incidents',
      'Walks get skipped on incident days',
      'On days with unplanned incident work, the planned walk is usually '
          'dropped — consider protecting it explicitly.',
      status: KnowledgeStatus.proposed,
      tags: const ['health'],
    ),
  ],
  confirmed: [
    _knowledge(
      'kn-3',
      'no-meetings-before-ten',
      'No meetings before 10:00',
      'Keep mornings meeting-free until 10:00 — stated preference.',
      status: KnowledgeStatus.confirmed,
      source: KnowledgeSource.userStated,
      tags: const ['mornings'],
    ),
  ],
);

CaptureController _stubCapture() {
  final recorder = MockAudioRecorderRepository();
  final transcriber = MockAudioTranscriptionService();
  final realtime = MockRealtimeTranscriptionService();
  when(realtime.dispose).thenAnswer((_) async {});
  when(realtime.resolveRealtimeConfig).thenAnswer((_) async => null);
  when(recorder.stopRecording).thenAnswer((_) async {});
  return CaptureController(
    recorder: recorder,
    transcriber: transcriber,
    realtimeService: realtime,
    docDir: Directory.systemTemp.createTempSync,
    persistAudio: (_) async => null,
    now: () => _now,
  );
}

Widget _app({
  required Widget home,
  required Brightness brightness,
  required List<Override> overrides,
  required Size size,
  double textScale = 1.0,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    ),
  );
}

Future<void> _pumpDayPage(
  WidgetTester tester, {
  required ScreenshotDevice device,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) async {
  applyScreenshotDevice(tester, device);
  await withClock(Clock.fixed(_now), () async {
    await tester.pumpWidget(
      _app(
        brightness: brightness,
        size: device.size,
        textScale: textScale,
        overrides: [
          capturesForDateProvider.overrideWith((ref, date) async => const []),
          dailyOsActualTimeBlocksProvider.overrideWith(
            (ref, date) async => _actuals(),
          ),
          captureControllerProvider.overrideWith(_stubCapture),
          plannerKnowledgeProvider.overrideWith(
            (ref) async => _knowledgeView(),
          ),
        ],
        // Stand-in bottom nav strip: DayPage reserves the app shell's nav
        // height, so without this the captures show a hollow band.
        home: Stack(
          children: [
            DayPage(draft: _plan()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Builder(
                builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
                  Widget item(
                    IconData icon,
                    String label, {
                    bool active = false,
                  }) {
                    final color = active
                        ? scheme.primary
                        : scheme.onSurfaceVariant;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 22, color: color),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: TextStyle(fontSize: 10, color: color),
                        ),
                      ],
                    );
                  }

                  return Container(
                    height: DesignSystemBottomNavigationBar.occupiedHeight(
                      context,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      border: Border(
                        top: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(top: 8),
                    alignment: Alignment.topCenter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final navItem in [
                          item(Icons.today_rounded, 'Daily OS', active: true),
                          item(Icons.check_circle_outline_rounded, 'Tasks'),
                          item(Icons.calendar_month_rounded, 'Calendar'),
                          item(Icons.settings_outlined, 'Settings'),
                        ])
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: navItem,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    await settleFrames(tester);
  });
}

AppLocalizations _messages(WidgetTester tester) =>
    tester.element(find.byType(DayPage)).messages;

Future<void> _switchToDayView(WidgetTester tester) async {
  await withClock(Clock.fixed(_now), () async {
    await tester.tap(find.text(_messages(tester).dailyOsNextPlanViewDay));
    await settleFrames(tester);
  });
}

/// Pages the phone timeline to the recorded lane via the controller — a
/// gesture drag is text-scale-dependent (at 2x the same offset no longer
/// crosses the snap threshold and silently leaves the planned lane in
/// frame, producing a duplicate shot).
Future<void> _showRecordedLane(WidgetTester tester) async {
  await withClock(Clock.fixed(_now), () async {
    final pageView = tester.widget<PageView>(find.byType(PageView));
    pageView.controller!.jumpToPage(1);
    await settleFrames(tester);
  });
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'day-page screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true) '
          'because the real-font loading leaks process-wide.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  for (final device in [miniDevice, proDevice, desktopDevice]) {
    testWidgets('${device.name} agenda — dark', (tester) async {
      await _pumpDayPage(tester, device: device);
      expect(find.byType(AgendaView), findsOneWidget);
      await captureScreenshot(tester, 'day_${device.name}_01_agenda_dark');
    });

    testWidgets('${device.name} timeline — dark', (tester) async {
      await _pumpDayPage(tester, device: device);
      await _switchToDayView(tester);
      expect(find.byType(DayTimeline), findsOneWidget);
      await captureScreenshot(tester, 'day_${device.name}_02_timeline_dark');
    });
  }

  testWidgets('mini timeline recorded lane — dark', (tester) async {
    await _pumpDayPage(tester, device: miniDevice);
    await _switchToDayView(tester);
    // Mobile timeline pages between planned and recorded lanes.
    await _showRecordedLane(tester);
    await captureScreenshot(tester, 'day_mini_03_timeline_recorded_dark');
  });

  testWidgets('mini agenda — light', (tester) async {
    await _pumpDayPage(
      tester,
      device: miniDevice,
      brightness: Brightness.light,
    );
    await captureScreenshot(tester, 'day_mini_04_agenda_light');
  });

  testWidgets('mini timeline — light', (tester) async {
    await _pumpDayPage(
      tester,
      device: miniDevice,
      brightness: Brightness.light,
    );
    await _switchToDayView(tester);
    await captureScreenshot(tester, 'day_mini_05_timeline_light');
  });

  testWidgets('mini agenda — dark, 1.3x text', (tester) async {
    await _pumpDayPage(tester, device: miniDevice, textScale: 1.3);
    await captureScreenshot(tester, 'day_mini_06_agenda_dark_ts13');
  });

  // 2.0x — the upper end of common accessibility text sizes.
  testWidgets('mini agenda — dark, 2.0x text', (tester) async {
    await _pumpDayPage(tester, device: miniDevice, textScale: 2);
    await captureScreenshot(tester, 'day_mini_07_agenda_dark_ts20');
  });

  testWidgets('mini timeline — dark, 2.0x text', (tester) async {
    await _pumpDayPage(tester, device: miniDevice, textScale: 2);
    await _switchToDayView(tester);
    await captureScreenshot(tester, 'day_mini_08_timeline_dark_ts20');
  });

  testWidgets('mini timeline recorded lane — dark, 2.0x text', (
    tester,
  ) async {
    await _pumpDayPage(tester, device: miniDevice, textScale: 2);
    await _switchToDayView(tester);
    await _showRecordedLane(tester);
    await captureScreenshot(tester, 'day_mini_09_timeline_recorded_ts20');
  });
}
