/// Screenshot harness for the day-planning modal.
///
/// Drives the real Wolt multi-page sheet ([showDayPlanningModal]) through its
/// Capture → Reconcile → Drafting → Refine steps across a device matrix —
/// iPhone 12 mini (375×812@3x), iPhone 17 Pro (402×874@3x), iPhone 17 Pro
/// Max (440×956@3x), and a desktop window (1440×900@2x) — plus large-text
/// variants, and writes PNGs to `screenshots/daily_os_next/` (gitignored)
/// for design review. Not a golden test — there are no stored baselines; the
/// assertions only guard that each scenario renders without exceptions.
///
/// The "AI is thinking" decoder-bars use a fragment shader that does not
/// compile under headless `flutter test`, so the shader paints nothing in
/// these captures — review the bar layout/clearance, not the shader itself.
/// The 👋 emoji in the greeting renders as tofu for the same reason (no
/// emoji font in the test harness); it is correct on devices.
///
/// Opt-in (real-font loading leaks process-wide — see `main`). Run:
/// `LOTTI_SCREENSHOT_DIR=/tmp/day_planning fvm flutter test \
///   test/features/daily_os_next/ui/pages/day_planning_modal_screenshots_test.dart`
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_modal.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../screenshot_harness.dart';

final DateTime _now = DateTime(2026, 6, 7, 9, 41);
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

final String _longUtterance = _t(
  'Tomorrow I need to inspect the orbital penguin habitat before Mission '
      'Control wakes up, run the emperor penguin roll call, and negotiate the '
      'sardine futures contract with Reykjavik. At eleven we have the Project '
      'Waddle launch review. Please protect lunch because apparently coffee is '
      'not a vegetable. In the afternoon I need ninety minutes for the '
      'zero-gravity fish feeder, a legal review called Is a penguin a '
      'passenger, and the board briefing. Add a buffer before the live habitat '
      'demo, then leave thirty minutes for a walk and a debrief with Sir '
      'Flaps-a-Lot. Nothing important should begin after five.',
  'Morgen muss ich das Pinguin-Habitat im Orbit inspizieren, bevor die '
      'Missionskontrolle aufwacht, den Zählappell der Kaiserpinguine '
      'durchführen und den Sardinen-Terminkontrakt mit Reykjavík verhandeln. '
      'Um elf ist die Startprüfung für Project Waddle. Bitte halte die '
      'Mittagspause frei, denn Kaffee ist offenbar kein Gemüse. Am Nachmittag '
      'brauche ich neunzig Minuten für den Schwerelos-Futterautomaten, eine '
      'Rechtsprüfung mit dem Titel Ist ein Pinguin ein Passagier und das '
      'Vorstandsbriefing. Plane vor der Live-Demo des Habitats einen Puffer '
      'ein und danach dreißig Minuten für einen Spaziergang und die '
      'Nachbesprechung mit Sir Flaps-a-Lot. Nach fünf soll nichts Wichtiges '
      'mehr beginnen.',
);

/// Deterministic rolling amplitude window for the live waveform.
List<double> _amplitudes(int count) => [
  for (var i = 0; i < count; i++)
    0.18 + 0.62 * (0.5 + 0.5 * math.sin(i / 2.4)) * (i.isEven ? 1.0 : 0.72),
];

// Loud simulated speech level: with the widget's default −80 dBFS floor the
// normalized drive is ≈0.9, so the tension-loop shader renders near its full
// extent in the stills.
CaptureState _listening() => CaptureState(
  phase: CapturePhase.listening,
  transcript: '',
  amplitudes: _amplitudes(48),
  dbfs: -7,
);

final _transcribing = CaptureState(
  phase: CapturePhase.transcribing,
  transcript: '',
  amplitudes: _amplitudes(48),
);

final _captured = CaptureState(
  phase: CapturePhase.captured,
  transcript: _longUtterance,
  amplitudes: const [],
);

final _category = DayAgentCategory(
  id: 'cat-mission',
  name: _t('Mission Control', 'Missionskontrolle'),
  colorHex: '4F9DDE',
);

final _deepWork = DayAgentCategory(
  id: 'cat-penguin',
  name: _t('Penguin Operations', 'Pinguinbetrieb'),
  colorHex: '8B5CF6',
);

final _health = DayAgentCategory(
  id: 'cat-human',
  name: _t('Human Maintenance', 'Menschenwartung'),
  colorHex: '34D399',
);

/// A populated draft so the Refine step's "current plan" zone has real
/// rows to show.
DraftPlan _refineDraft() {
  TimeBlock block(
    String id,
    String title,
    int startHour,
    int endHour,
    DayAgentCategory category, {
    int startMinute = 0,
    int endMinute = 0,
  }) => TimeBlock(
    id: id,
    title: title,
    start: DateTime(2026, 6, 8, startHour, startMinute),
    end: DateTime(2026, 6, 8, endHour, endMinute),
    type: TimeBlockType.ai,
    state: TimeBlockState.drafted,
    category: category,
  );

  return DraftPlan(
    dayDate: DateTime(2026, 6, 8),
    blocks: [
      block(
        'blk-1',
        _t('Orbital habitat inspection', 'Inspektion des Orbital-Habitats'),
        8,
        10,
        _deepWork,
      ),
      block(
        'blk-2',
        _t('Project Waddle launch review', 'Startprüfung für Project Waddle'),
        10,
        11,
        _category,
      ),
      block(
        'blk-3',
        _t('Zero-gravity fish feeder', 'Schwerelos-Futterautomat'),
        13,
        14,
        _deepWork,
        endMinute: 30,
      ),
      block(
        'blk-4',
        _t('Walk without a headset', 'Spaziergang ohne Headset'),
        17,
        18,
        _health,
        startMinute: 30,
      ),
    ],
    bands: const [],
    capacityMinutes: 480,
    scheduledMinutes: 315,
  );
}

/// Pins a fixed [CaptureState] so the modal renders deterministically
/// without the recorder/transcription stack.
class _FakeCaptureController extends CaptureController {
  _FakeCaptureController(this._initial);

  final CaptureState _initial;

  @override
  CaptureState build() => _initial;

  @override
  void reset() => state = const CaptureState.idle();

  @override
  void startTyping() => state = const CaptureState(
    phase: CapturePhase.captured,
    transcript: '',
    amplitudes: [],
  );

  @override
  Future<void> toggle({
    DateTime? forDate,
    AudioCaptureIntent intent = AudioCaptureIntent.dayPlan,
  }) async {}
}

/// Realistic, deterministic corpus for the manual's fictional Director of
/// Interplanetary Penguin Logistics.
class _ReviewAgent extends MockDayAgent {
  _ReviewAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => _now,
      );

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => [
    ParsedItem(
      id: 'p_waddle_briefing',
      kind: ParsedItemKind.matched,
      title: _t(
        'Send Project Waddle briefing',
        'Project-Waddle-Briefing senden',
      ),
      category: _category,
      confidence: ParsedItemConfidence.high,
      spokenPhrase: _t(
        'the Project Waddle launch review',
        'die Startprüfung für Project Waddle',
      ),
      matchedTaskId: 't_waddle_briefing',
      matchedTaskTitle: _t(
        'Project Waddle launch briefing',
        'Startbriefing für Project Waddle',
      ),
      matchedTaskState: _t(
        'In progress · 2 sessions',
        'In Arbeit · 2 Sitzungen',
      ),
      estimateMinutes: 60,
    ),
    ParsedItem(
      id: 'p_habitat',
      kind: ParsedItemKind.newTask,
      title: _t(
        'Inspect orbital penguin habitat',
        'Pinguin-Habitat im Orbit inspizieren',
      ),
      category: _deepWork,
      confidence: ParsedItemConfidence.high,
      estimateMinutes: 120,
      timeAnchor: _t(
        'before Mission Control wakes up',
        'bevor die Missionskontrolle aufwacht',
      ),
    ),
    ParsedItem(
      id: 'p_sardines',
      kind: ParsedItemKind.newTask,
      title: _t('Negotiate sardine futures', 'Sardinen-Futures verhandeln'),
      category: _category,
      confidence: ParsedItemConfidence.medium,
      estimateMinutes: 90,
    ),
    ParsedItem(
      id: 'p_roll_call',
      kind: ParsedItemKind.update,
      title: _t('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
      category: _deepWork,
      confidence: ParsedItemConfidence.high,
      spokenPhrase: _t(
        'run the emperor penguin roll call',
        'den Zählappell der Kaiserpinguine durchführen',
      ),
      matchedTaskId: 't_roll_call',
      matchedTaskTitle: _t(
        'Emperor penguin roll call',
        'Kaiserpinguine durchzählen',
      ),
      matchedTaskState: _t('Recurring · weekdays', 'Wiederkehrend · werktags'),
      proposedUpdate: _t(
        'Mark complete after all 37 answer',
        'Als erledigt markieren, wenn alle 37 geantwortet haben',
      ),
    ),
  ];

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async => [
    PendingItem(
      taskId: 't_fish_bucket',
      title: _t(
        'Replace the diplomatic fish bucket',
        'Diplomatischen Fischeimer ersetzen',
      ),
      category: _category,
      reason: PendingItemReason.inProgress,
      note: _t(
        'Started Friday, dignity not included',
        'Freitag begonnen, Würde nicht inbegriffen',
      ),
      sessionCount: 1,
    ),
    PendingItem(
      taskId: 't_orbital_permit',
      title: _t(
        'Renew orbital wildlife permit',
        'Orbitale Wildtiergenehmigung erneuern',
      ),
      category: _deepWork,
      reason: PendingItemReason.overdue,
      note: _t(
        'The penguins are currently technically cargo',
        'Die Pinguine gelten derzeit technisch als Fracht',
      ),
      overdueByDays: 3,
    ),
    PendingItem(
      taskId: 't_calm_flapping',
      title: _t(
        'Practice calm during surprise flapping',
        'Ruhe bei überraschendem Flattern üben',
      ),
      category: _health,
      reason: PendingItemReason.missedRecurring,
      note: _t('Last skipped Thursday', 'Zuletzt am Donnerstag ausgelassen'),
    ),
  ];
}

/// Parsing agent whose first AI pass never resolves — keeps the Reconcile
/// step on its first-frame processing state for a stable capture.
class _PendingParseAgent extends _ReviewAgent {
  final Completer<List<ParsedItem>> _parse = Completer<List<ParsedItem>>();

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) => _parse.future;
}

/// Drafting agent whose draft never resolves — keeps the Drafting step on
/// screen in its "drafting" phase for a stable capture.
class _PendingDraftAgent extends _ReviewAgent {
  final Completer<DraftPlan> _draft = Completer<DraftPlan>();

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) => _draft.future;
}

MockDayAgent _fastAgent() => _ReviewAgent();

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
          locale: manualScreenshotLocale,
          home: home,
        ),
      ),
    ),
  );
}

AppLocalizations _messages(WidgetTester tester) =>
    tester.element(find.byType(DayPlanningGlassActionBar)).messages;

/// Pumps an app whose single button opens the day-planning modal, taps it,
/// and settles the entry animation. Returns once the modal is on screen.
Future<void> _openModal(
  WidgetTester tester, {
  required DayPlanningIntent intent,
  required ScreenshotDevice device,
  CaptureState capture = const CaptureState.idle(),
  MockDayAgent? agent,
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
          captureControllerProvider.overrideWith(
            () => _FakeCaptureController(capture),
          ),
          dailyOsActualTimeBlocksProvider.overrideWith(
            (ref, date) async => const <TimeBlock>[],
          ),
          agentIsRunningProvider.overrideWith(
            (ref, agentId) => Stream.value(false),
          ),
          if (agent != null) dayAgentProvider.overrideWithValue(agent),
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDayPlanningModal(
                  context: context,
                  dayDate: DateTime(2026, 6, 8),
                  intent: intent,
                ),
                child: Text(_t('open', 'öffnen')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(_t('open', 'öffnen')));
    await settleFrames(tester);
  });
}

Future<void> _tapPill(WidgetTester tester, String label) async {
  await withClock(Clock.fixed(_now), () async {
    await tester.tap(find.widgetWithText(DsGlassPill, label));
    await settleFrames(tester);
  });
}

void main() {
  // OPT-IN ONLY. The harness loads real fonts via FontLoader, which
  // registers them process-wide with no way to unload — under very_good's
  // single-isolate optimizer that changes text metrics for unrelated tests.
  // So it only runs when explicitly requested for design review.
  if (!screenshotCaptureEnabled) {
    test(
      'day-planning screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true) '
          'because the real-font loading leaks process-wide.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  // ───────────────────────── Create ritual, per device ─────────────────────

  for (final device in allScreenshotDevices) {
    testWidgets('${device.name} capture idle — dark', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
      );
      expect(find.byType(CaptureModalContent), findsOneWidget);
      await captureScreenshot(tester, '${device.name}_01_capture_idle_dark');
    });

    testWidgets('${device.name} capture listening (short) — dark', (
      tester,
    ) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _listening(),
      );
      await captureScreenshot(tester, '${device.name}_02_listening_short_dark');
    });

    testWidgets('${device.name} capture listening (long) — dark', (
      tester,
    ) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _listening(),
      );
      await captureScreenshot(tester, '${device.name}_03_listening_long_dark');
    });

    testWidgets('${device.name} capture transcribing — dark', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _transcribing,
      );
      await captureScreenshot(tester, '${device.name}_04_transcribing_dark');
    });

    testWidgets('${device.name} capture captured — dark', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _captured,
      );
      expect(find.byType(DsGlassPill), findsNWidgets(2));
      await captureScreenshot(tester, '${device.name}_05_captured_dark');
    });

    testWidgets('${device.name} first processing frame — dark', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _captured,
        agent: _PendingParseAgent(),
      );
      await _tapPill(tester, _messages(tester).dailyOsNextCaptureReconcileCta);
      expect(
        find.text(_messages(tester).dailyOsNextReconcileProcessing),
        findsOneWidget,
      );
      await captureScreenshot(tester, '${device.name}_06_processing_dark');
    });

    testWidgets('${device.name} reconcile — dark', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _captured,
        agent: _fastAgent(),
      );
      await _tapPill(tester, _messages(tester).dailyOsNextCaptureReconcileCta);
      expect(find.byType(ReconcileModalContent), findsOneWidget);
      await captureScreenshot(tester, '${device.name}_07_reconcile_dark');
    });

    testWidgets('${device.name} drafting — dark', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _captured,
        agent: _PendingDraftAgent(),
      );
      await _tapPill(tester, _messages(tester).dailyOsNextCaptureReconcileCta);
      await _tapPill(tester, _messages(tester).dailyOsNextReconcileBuildDayCta);
      await captureScreenshot(tester, '${device.name}_08_drafting_dark');
    });

    testWidgets('${device.name} refine — dark', (tester) async {
      await _openModal(
        tester,
        intent: DayPlanningAdapt(_refineDraft()),
        device: device,
        agent: _fastAgent(),
      );
      await captureScreenshot(tester, '${device.name}_09_refine_dark');
    });
  }

  // ─────────────────────── Light theme + large text ────────────────────────

  testWidgets('mini capture idle — light', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: miniDevice,
      brightness: Brightness.light,
    );
    await captureScreenshot(tester, 'mini_09_capture_idle_light');
  });

  testWidgets('mini captured — light', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: miniDevice,
      capture: _captured,
      brightness: Brightness.light,
    );
    expect(find.byType(DsGlassPill), findsNWidgets(2));
    await captureScreenshot(tester, 'mini_10_captured_light');
  });

  testWidgets('desktop captured — light', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: desktopDevice,
      capture: _captured,
      brightness: Brightness.light,
    );
    expect(find.byType(DsGlassPill), findsNWidgets(2));
    await captureScreenshot(tester, 'desktop_10_captured_light');
  });

  for (final device in [miniDevice, desktopDevice]) {
    testWidgets('${device.name} reconcile — light', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _captured,
        agent: _fastAgent(),
        brightness: Brightness.light,
      );
      await _tapPill(tester, _messages(tester).dailyOsNextCaptureReconcileCta);
      expect(find.byType(ReconcileModalContent), findsOneWidget);
      await captureScreenshot(tester, '${device.name}_15_reconcile_light');
    });
  }

  testWidgets('mini capture idle — dark, 1.3x text', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: miniDevice,
      textScale: 1.3,
    );
    await captureScreenshot(tester, 'mini_11_capture_idle_dark_ts13');
  });

  testWidgets('mini listening (long) — dark, 1.3x text', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: miniDevice,
      capture: _listening(),
      textScale: 1.3,
    );
    await captureScreenshot(tester, 'mini_12_listening_long_dark_ts13');
  });

  testWidgets('mini captured — dark, 1.3x text', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: miniDevice,
      capture: _captured,
      textScale: 1.3,
    );
    await captureScreenshot(tester, 'mini_13_captured_dark_ts13');
  });

  // 2.0x — the upper end of common accessibility text sizes. The layout
  // may fall back to scrolling here; the bar actions and orb must stay
  // reachable and no text may clip.
  for (final (name, capture) in <(String, CaptureState)>[
    ('idle', const CaptureState.idle()),
    ('listening', _listening()),
    ('captured', _captured),
  ]) {
    testWidgets('mini $name — dark, 2.0x text', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: miniDevice,
        capture: capture,
        textScale: 2,
      );
      await captureScreenshot(tester, 'mini_20_${name}_dark_ts20');
    });
  }

  testWidgets('mini reconcile — dark, 2.0x text', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: miniDevice,
      capture: _captured,
      agent: _fastAgent(),
      textScale: 2,
    );
    await _tapPill(tester, _messages(tester).dailyOsNextCaptureReconcileCta);
    await captureScreenshot(tester, 'mini_21_reconcile_dark_ts20');
  });

  testWidgets('mini refine — dark, 2.0x text', (tester) async {
    await _openModal(
      tester,
      intent: DayPlanningAdapt(_refineDraft()),
      device: miniDevice,
      agent: _fastAgent(),
      textScale: 2,
    );
    await captureScreenshot(tester, 'mini_22_refine_dark_ts20');
  });

  testWidgets('capture with "Today so far" card — mini dark', (tester) async {
    final block = TimeBlock(
      id: 'actual:entry-1',
      title: _t(
        'Retrieve penguin from ventilation duct',
        'Pinguin aus dem Lüftungsschacht holen',
      ),
      start: DateTime(2026, 6, 8, 8),
      end: DateTime(2026, 6, 8, 9, 30),
      type: TimeBlockType.manual,
      state: TimeBlockState.completed,
      category: _category,
    );
    applyScreenshotDevice(tester, miniDevice);

    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(
        _app(
          brightness: Brightness.dark,
          size: miniDevice.size,
          overrides: [
            captureControllerProvider.overrideWith(
              () => _FakeCaptureController(const CaptureState.idle()),
            ),
          ],
          home: Scaffold(
            body: CaptureModalContent(
              forDate: DateTime(2026, 6, 8),
              actualBlocks: [block],
            ),
          ),
        ),
      );
      await settleFrames(tester);
    });
    expect(
      find.text(
        _t(
          'Retrieve penguin from ventilation duct',
          'Pinguin aus dem Lüftungsschacht holen',
        ),
      ),
      findsOneWidget,
    );
    await captureScreenshot(tester, 'mini_14_capture_today_so_far_dark');
  });
}
