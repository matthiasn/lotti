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
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../screenshot_harness.dart';

/// Mid-afternoon so the now-line sits inside the day and one recorded
/// session can be in progress.
final DateTime _now = DateTime(2026, 6, 8, 15, 55);
final DateTime _day = DateTime(2026, 6, 8);

const _deepWork = DayAgentCategory(
  id: 'cat-penguin',
  name: 'Penguin Operations',
  colorHex: '8B5CF6',
);
const _client = DayAgentCategory(
  id: 'cat-mission',
  name: 'Mission Control',
  colorHex: '4F9DDE',
);
const _health = DayAgentCategory(
  id: 'cat-human',
  name: 'Human Maintenance',
  colorHex: '34D399',
);
const _admin = DayAgentCategory(
  id: 'cat-diplomacy',
  name: 'Fish Diplomacy',
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
  String? taskId,
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
  taskId: taskId,
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

/// A full planned day for the Director of Interplanetary Penguin Logistics.
DraftPlan _plan() {
  final blocks = [
    _planned(
      'blk-review',
      'Emperor penguin roll call',
      _at(8, 30),
      _at(9),
      _admin,
    ),
    _planned(
      'blk-deep',
      'Inspect orbital penguin habitat',
      _at(9),
      _at(11),
      _deepWork,
      reason: 'Best done before Mission Control and the penguins get chatty',
      taskId: 'task-orbital-habitat',
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
      'Project Waddle launch review',
      _at(11, 15),
      _at(12),
      _client,
    ),
    _planned(
      'blk-lunch',
      'Lunch (coffee is not a vegetable)',
      _at(12),
      _at(13),
      _health,
    ),
    _planned(
      'blk-followup',
      'Negotiate sardine futures',
      _at(13),
      _at(14, 30),
      _client,
    ),
    _planned(
      'blk-slides',
      'Zero-gravity fish feeder',
      _at(14, 30),
      _at(16),
      _deepWork,
      sessionIndex: 1,
      sessionTotal: 2,
      reason: 'The fish are least suspicious immediately after lunch',
    ),
    _planned(
      'blk-email',
      'Legal: Is a penguin a passenger?',
      _at(16, 15),
      _at(17),
      _admin,
    ),
    _planned(
      'blk-run',
      'Walk without a headset',
      _at(17, 30),
      _at(18),
      _health,
    ),
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
        title: 'Emperor penguin roll call',
        category: _admin,
        linkedBlockIds: ['blk-review'],
        totalEstimateMinutes: 30,
        progress: 1,
        state: AgendaItemState.done,
      ),
      AgendaItem(
        id: 'ag-deep',
        taskId: 'task-orbital-habitat',
        title: 'Inspect orbital penguin habitat',
        category: _deepWork,
        linkedBlockIds: ['blk-deep'],
        totalEstimateMinutes: 120,
        progress: 1,
        state: AgendaItemState.done,
        outcome: 'Habitat seals green; tiny helmets still pending',
      ),
      AgendaItem(
        id: 'ag-design',
        title: 'Project Waddle launch review',
        category: _client,
        linkedBlockIds: ['blk-design'],
        totalEstimateMinutes: 45,
        progress: 1,
        state: AgendaItemState.done,
      ),
      AgendaItem(
        id: 'ag-lunch',
        title: 'Lunch (coffee is not a vegetable)',
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
        title: 'Negotiate sardine futures',
        category: _client,
        linkedBlockIds: ['blk-followup'],
        totalEstimateMinutes: 90,
        progress: 1,
        state: AgendaItemState.done,
        outcome: 'Locked Q3 sardines below the emergency fish ceiling',
      ),
      AgendaItem(
        id: 'ag-slides',
        title: 'Zero-gravity fish feeder',
        category: _deepWork,
        linkedBlockIds: ['blk-slides'],
        totalEstimateMinutes: 180,
        progress: 0.4,
        state: AgendaItemState.inProgress,
        outcome: 'Prototype ready for the live habitat demo',
      ),
      AgendaItem(
        id: 'ag-email',
        title: 'Legal: Is a penguin a passenger?',
        category: _admin,
        linkedBlockIds: ['blk-email'],
        totalEstimateMinutes: 45,
      ),
      AgendaItem(
        id: 'ag-run',
        title: 'Walk without a headset',
        category: _health,
        linkedBlockIds: ['blk-run'],
        totalEstimateMinutes: 30,
      ),
    ],
  );
}

/// Recorded reality: late starts, an escaped penguin nobody planned,
/// lunch without the walk, the afternoon running long, slides still in
/// progress under the now-line, email triage never happened (yet).
List<TimeBlock> _actuals() => [
  _tracked(
    'review',
    'Emperor penguin roll call',
    _at(8, 42),
    _at(9, 5),
    _admin,
  ),
  _tracked(
    'deep',
    'Inspect orbital penguin habitat',
    _at(9, 5),
    _at(10, 38),
    _deepWork,
  ),
  _tracked(
    'incident',
    'Retrieve penguin from ventilation duct',
    _at(10, 40),
    _at(11, 2),
    _client,
  ),
  _tracked(
    'design',
    'Project Waddle launch review',
    _at(11, 18),
    _at(12, 5),
    _client,
  ),
  _tracked('lunch', 'Lunch, technically', _at(12, 10), _at(12, 50), _health),
  _tracked(
    'followup',
    'Negotiate sardine futures',
    _at(13, 5),
    _at(14, 55),
    _client,
  ),
  _tracked(
    'slides',
    'Zero-gravity fish feeder',
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
      'habitat-before-mission-control',
      'Habitat work lands before Mission Control wakes',
      'Habitat inspections started before the first call run 30% longer '
          'before a penguin or executive finds the red button.',
      status: KnowledgeStatus.proposed,
      tags: const ['penguins', 'mornings'],
    ),
    _knowledge(
      'kn-2',
      'walks-skipped-after-escapes',
      'Walks get skipped after penguin escapes',
      'When a penguin enters the ventilation system, the planned walk is '
          'usually dropped — protect it explicitly.',
      status: KnowledgeStatus.proposed,
      tags: const ['health'],
    ),
  ],
  confirmed: [
    _knowledge(
      'kn-3',
      'no-briefings-before-ten',
      'No briefings before 10:00',
      'Keep mornings briefing-free until 10:00 — stated preference.',
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

Widget _dayShell(ScreenshotDevice device) {
  final dayPage = DayPage(draft: _plan());
  if (!device.isPhone) {
    DesktopSidebarDestination destination(
      String label,
      IconData icon,
      IconData activeIcon,
    ) => DesktopSidebarDestination(
      label: label,
      iconBuilder: ({required active}) => Icon(active ? activeIcon : icon),
    );

    return Row(
      children: [
        DesktopNavigationSidebar(
          destinations: [
            destination(
              'Tasks',
              Icons.check_circle_outline_rounded,
              Icons.check_circle_rounded,
            ),
            destination('Daily OS', Icons.today_outlined, Icons.today_rounded),
            destination(
              'Logbook',
              Icons.menu_book_outlined,
              Icons.menu_book_rounded,
            ),
          ],
          activeIndex: 1,
          onDestinationSelected: (_) {},
          settingsDestination: destination(
            'Settings',
            Icons.settings_outlined,
            Icons.settings_rounded,
          ),
          onSettingsSelected: () {},
          onToggleCollapsed: () {},
        ),
        Expanded(child: dayPage),
      ],
    );
  }

  return Stack(
    children: [
      dayPage,
      const Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: DesignSystemBottomNavigationBar(
          items: [
            DesignSystemFiveSlotNavBarItem(
              label: 'Daily OS',
              icon: Icon(Icons.today_outlined),
              activeIcon: Icon(Icons.today_rounded),
              active: true,
            ),
            DesignSystemFiveSlotNavBarItem(
              label: 'Tasks',
              icon: Icon(Icons.check_circle_outline_rounded),
            ),
            DesignSystemFiveSlotNavBarItem(
              label: 'Calendar',
              icon: Icon(Icons.calendar_month_outlined),
            ),
            DesignSystemFiveSlotNavBarItem(
              label: 'Settings',
              icon: Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ),
    ],
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
        // DayPage lives inside the app shell in production. Reuse the real
        // design-system mobile bar / desktop sidebar so the captures reflect
        // each breakpoint instead of showing a hollow reserved band.
        home: _dayShell(device),
      ),
    );
    await settleFrames(tester);
  });
}

AppLocalizations _messages(WidgetTester tester) =>
    tester.element(find.byType(DayPage)).messages;

Future<void> _switchToDayView(WidgetTester tester) async {
  await withClock(Clock.fixed(_now), () async {
    // `.last` skips the toggle's invisible width-reserving ghost label.
    await tester.tap(
      find.text(_messages(tester).dailyOsNextPlanViewDay).last,
    );
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

Future<void> _openBlockEditor(
  WidgetTester tester, {
  required String blockId,
}) async {
  await withClock(Clock.fixed(_now), () async {
    final editButton = find.byKey(Key('daily_os_edit_block_$blockId'));
    final iconButton = tester.widget<IconButton>(editButton);
    expect(iconButton.onPressed, isNotNull);
    iconButton.onPressed!();
    await settleFrames(tester);
  });
  expect(
    find.text(_messages(tester).dailyOsNextBlockEditTitle),
    findsOneWidget,
  );
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

  testWidgets('pro timeline arrange mode — dark', (tester) async {
    await _pumpDayPage(tester, device: proDevice);
    await _switchToDayView(tester);
    await tester.tap(find.byKey(const Key('daily_os_timeline_arrange_toggle')));
    await settleFrames(tester);
    expect(
      find.byKey(const Key('daily_os_move_block_blk-review')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('daily_os_resize_end_blk-review')),
      findsOneWidget,
    );
    await captureScreenshot(tester, 'day_pro_03_timeline_arrange_dark');
  });

  testWidgets('pro block editor overview — dark', (tester) async {
    await _pumpDayPage(tester, device: proDevice);
    await _switchToDayView(tester);
    await _openBlockEditor(tester, blockId: 'blk-slides');
    expect(find.text('Zero-gravity fish feeder'), findsWidgets);
    expect(
      find.text(_messages(tester).dailyOsNextBlockEditTimeLabel),
      findsOneWidget,
    );
    await captureScreenshot(tester, 'day_pro_04_block_edit_overview_dark');
  });

  testWidgets('pro block editor start and end — dark', (tester) async {
    await _pumpDayPage(tester, device: proDevice);
    await _switchToDayView(tester);
    await _openBlockEditor(tester, blockId: 'blk-slides');
    final timeField = tester
        .widgetList<SettingsPickerField>(find.byType(SettingsPickerField))
        .singleWhere(
          (field) =>
              field.label == _messages(tester).dailyOsNextBlockEditTimeLabel,
        );
    timeField.onTap();
    await settleFrames(tester);
    expect(find.byType(DesignSystemTimeWheel), findsNWidgets(2));
    await captureScreenshot(tester, 'day_pro_05_block_edit_time_dark');
  });

  testWidgets('pro linked-task block editor — dark', (tester) async {
    await _pumpDayPage(tester, device: proDevice);
    await _switchToDayView(tester);
    await _openBlockEditor(tester, blockId: 'blk-deep');
    expect(
      find.text(_messages(tester).dailyOsNextBlockEditOpenTask),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    await captureScreenshot(tester, 'day_pro_06_block_edit_linked_dark');
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
