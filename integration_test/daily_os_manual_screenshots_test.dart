/// Real-renderer screenshot harness for Daily OS manual assets that depend on
/// fragment shaders.
///
/// Widget-test captures cover the complete state matrix, but fragment shader
/// fidelity must be verified on a Flutter device. Run on Linux with:
///
/// ```sh
/// fvm flutter test integration_test/daily_os_manual_screenshots_test.dart \
///   -d linux \
///   --dart-define=LOTTI_SCREENSHOT_DIR=/absolute/output/directory
/// ```
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/planner_knowledge_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_modal.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:lotti/l10n/app_localizations.dart';

import 'manual_screenshot_utils.dart';

const _captured = CaptureState(
  phase: CapturePhase.captured,
  transcript:
      'Inspect the orbital penguin habitat, run the emperor penguin roll '
      'call, negotiate the sardine futures contract, and protect lunch '
      'because coffee is not a vegetable.',
  amplitudes: [],
);

final _day = DateTime(2026, 6, 8);
final _now = DateTime(2026, 6, 8, 15, 55);

const _penguinOps = DayAgentCategory(
  id: 'cat-penguin',
  name: 'Penguin Operations',
  colorHex: '8B5CF6',
);
const _missionControl = DayAgentCategory(
  id: 'cat-mission',
  name: 'Mission Control',
  colorHex: '4F9DDE',
);
const _humanMaintenance = DayAgentCategory(
  id: 'cat-human',
  name: 'Human Maintenance',
  colorHex: '34D399',
);
const _fishDiplomacy = DayAgentCategory(
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
}) => TimeBlock(
  id: id,
  title: title,
  start: start,
  end: end,
  type: TimeBlockType.ai,
  state: TimeBlockState.drafted,
  category: category,
  reason: reason,
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

DraftPlan _busyDay() {
  final blocks = [
    _planned(
      'roll-call',
      'Emperor penguin roll call',
      _at(8, 30),
      _at(9),
      _fishDiplomacy,
    ),
    _planned(
      'habitat',
      'Inspect orbital penguin habitat',
      _at(9),
      _at(11),
      _penguinOps,
      reason: 'Best done before Mission Control and the penguins get chatty',
    ),
    _planned(
      'waddle',
      'Project Waddle launch review',
      _at(11, 15),
      _at(12),
      _missionControl,
    ),
    _planned(
      'lunch',
      'Lunch (coffee is not a vegetable)',
      _at(12),
      _at(13),
      _humanMaintenance,
    ),
    _planned(
      'sardines',
      'Negotiate sardine futures',
      _at(13),
      _at(14, 30),
      _missionControl,
    ),
    _planned(
      'feeder',
      'Zero-gravity fish feeder',
      _at(14, 30),
      _at(16),
      _penguinOps,
      reason: 'The fish are least suspicious immediately after lunch',
    ),
    _planned(
      'legal',
      'Legal: Is a penguin a passenger?',
      _at(16, 15),
      _at(17),
      _fishDiplomacy,
    ),
    _planned(
      'walk',
      'Walk without a headset',
      _at(17, 30),
      _at(18),
      _humanMaintenance,
    ),
  ];

  return DraftPlan(
    dayDate: _day,
    blocks: blocks,
    bands: const [],
    capacityMinutes: 540,
    scheduledMinutes: 495,
    agendaItems: [
      for (final (index, block) in blocks.indexed)
        AgendaItem(
          id: 'agenda-${block.id}',
          title: block.title,
          category: block.category,
          linkedBlockIds: [block.id],
          totalEstimateMinutes: block.duration.inMinutes,
          progress: index < 5 ? 1 : (index == 5 ? 0.4 : null),
          state: index < 5
              ? AgendaItemState.done
              : (index == 5
                    ? AgendaItemState.inProgress
                    : AgendaItemState.open),
          outcome: index == 5
              ? 'Prototype ready for the live habitat demo'
              : null,
        ),
    ],
  );
}

List<TimeBlock> _actuals() => [
  _tracked(
    'roll-call',
    'Emperor penguin roll call',
    _at(8, 42),
    _at(9, 5),
    _fishDiplomacy,
  ),
  _tracked(
    'habitat',
    'Inspect orbital penguin habitat',
    _at(9, 5),
    _at(10, 38),
    _penguinOps,
  ),
  _tracked(
    'escape',
    'Retrieve penguin from ventilation duct',
    _at(10, 40),
    _at(11, 2),
    _missionControl,
  ),
  _tracked(
    'waddle',
    'Project Waddle launch review',
    _at(11, 18),
    _at(12, 5),
    _missionControl,
  ),
  _tracked(
    'lunch',
    'Lunch, technically',
    _at(12, 10),
    _at(12, 50),
    _humanMaintenance,
  ),
  _tracked(
    'sardines',
    'Negotiate sardine futures',
    _at(13, 5),
    _at(14, 55),
    _missionControl,
  ),
  _tracked(
    'feeder',
    'Zero-gravity fish feeder',
    _at(15, 10),
    _at(15, 45),
    _penguinOps,
    state: TimeBlockState.inProgress,
  ),
];

class _CapturedController extends CaptureController {
  @override
  CaptureState build() => _captured;

  @override
  void reset() => state = const CaptureState.idle();

  @override
  Future<void> toggle({
    DateTime? forDate,
    AudioCaptureIntent intent = AudioCaptureIntent.dayPlan,
  }) async {}
}

class _PendingParseAgent extends MockDayAgent {
  _PendingParseAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

  final Completer<List<ParsedItem>> _items = Completer<List<ParsedItem>>();

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) => _items.future;
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 14; frame++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Widget _app(_PendingParseAgent agent) {
  return manualScreenshotBoundary(
    child: ProviderScope(
      overrides: [
        captureControllerProvider.overrideWith(_CapturedController.new),
        dailyOsActualTimeBlocksProvider.overrideWith(
          (ref, date) async => const <TimeBlock>[],
        ),
        agentIsRunningProvider.overrideWith(
          (ref, agentId) => Stream.value(false),
        ),
        dayAgentProvider.overrideWithValue(agent),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DesignSystemTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showDayPlanningModal(
                  context: context,
                  dayDate: DateTime(2026, 6, 8),
                  intent: const DayPlanningCreate(),
                ),
                child: const Text('Open Daily OS'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _desktopDayApp() {
  DesktopSidebarDestination destination(
    String label,
    IconData icon,
    IconData activeIcon,
  ) => DesktopSidebarDestination(
    label: label,
    iconBuilder: ({required active}) => Icon(active ? activeIcon : icon),
  );

  return manualScreenshotBoundary(
    child: ProviderScope(
      overrides: [
        capturesForDateProvider.overrideWith((ref, date) async => const []),
        dailyOsActualTimeBlocksProvider.overrideWith(
          (ref, date) async => _actuals(),
        ),
        captureControllerProvider.overrideWith(_CapturedController.new),
        dayAgentProvider.overrideWithValue(
          MockDayAgent(
            parseLatency: Duration.zero,
            pendingLatency: Duration.zero,
            triageLatency: Duration.zero,
            draftLatency: Duration.zero,
            summarizeLatency: Duration.zero,
          ),
        ),
        dailyOsSetupStatusProvider.overrideWith(
          (ref) async => const DailyOsSetupStatus(
            hasInferenceRoute: true,
            hasPreferredName: true,
          ),
        ),
        plannerKnowledgeProvider.overrideWith(
          (ref) async => const PlannerKnowledgeView(
            proposed: [],
            confirmed: [],
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DesignSystemTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Row(
          children: [
            DesktopNavigationSidebar(
              destinations: [
                destination(
                  'Tasks',
                  Icons.check_circle_outline_rounded,
                  Icons.check_circle_rounded,
                ),
                destination(
                  'Daily OS',
                  Icons.today_outlined,
                  Icons.today_rounded,
                ),
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
            Expanded(child: DayPage(draft: _busyDay())),
          ],
        ),
      ),
    ),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the first AI pass with the real shader renderer', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    for (final (name, logicalSize, pixelRatio) in [
      ('phone', const Size(402, 874), 2.0),
      ('desktop', const Size(1440, 900), 1.0),
    ]) {
      tester.view
        ..physicalSize = logicalSize * pixelRatio
        ..devicePixelRatio = pixelRatio;

      await tester.pumpWidget(_app(_PendingParseAgent()));
      await tester.tap(find.text('Open Daily OS'));
      await _settle(tester);

      final context = tester.element(find.byType(DayPlanningGlassActionBar));
      final messages = AppLocalizations.of(context)!;
      await tester.tap(
        find.widgetWithText(
          DsGlassPill,
          messages.dailyOsNextCaptureReconcileCta,
        ),
      );
      await _settle(tester);

      expect(
        find.text(messages.dailyOsNextReconcileProcessing),
        findsOneWidget,
      );
      await captureManualScreenshot(
        binding: binding,
        tester: tester,
        name: 'daily_os_shader_runtime_${name}_dark',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('captures the busy desktop day with the real renderer', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;

    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(_desktopDayApp());
      await _settle(tester);
      await captureManualScreenshot(
        binding: binding,
        tester: tester,
        name: 'day_desktop_01_agenda_dark',
      );

      final context = tester.element(find.byType(DayPage));
      final messages = AppLocalizations.of(context)!;
      await tester.tap(find.text(messages.dailyOsNextPlanViewDay).last);
      await _settle(tester);
      await captureManualScreenshot(
        binding: binding,
        tester: tester,
        name: 'day_desktop_02_timeline_dark',
      );
    });
  });
}
