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
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:path/path.dart' as p;

const ValueKey<String> _boundaryKey = ValueKey<String>('day-planning-shot');
final DateTime _now = DateTime(2026, 6, 7, 9, 41);

/// Review-design device matrix. Logical sizes of real hardware so layout
/// verdicts transfer to devices; capture stays at pixelRatio 2 for sane
/// file sizes.
class _Device {
  const _Device(this.name, this.size, this.devicePixelRatio);

  final String name;
  final Size size;
  final double devicePixelRatio;

  bool get isPhone => size.width < 560;
}

const _mini = _Device('mini', Size(375, 812), 3);
const _pro = _Device('pro', Size(402, 874), 3);
const _proMax = _Device('promax', Size(440, 956), 3);
const _desktop = _Device('desktop', Size(1440, 900), 2);

const List<_Device> _allDevices = [_mini, _pro, _proMax, _desktop];

const String _shortUtterance = 'Tomorrow I want to start with deep work';

const String _longUtterance =
    'Tomorrow I want to start with two hours of deep work on the planner '
    'before any meetings, then a check-in with the design team about the '
    'new layout, lunch with Anna, and in the afternoon I need to prepare '
    'the workshop slides, review the open pull requests, and if there is '
    'time left, go for a short run before dinner.';

/// Deterministic rolling amplitude window for the live waveform.
List<double> _amplitudes(int count) => [
  for (var i = 0; i < count; i++)
    0.18 + 0.62 * (0.5 + 0.5 * math.sin(i / 2.4)) * (i.isEven ? 1.0 : 0.72),
];

// Loud simulated speech level: with the widget's default −80 dBFS floor the
// normalized drive is ≈0.9, so the tension-loop shader renders near its full
// extent in the stills.
CaptureState _listening({required String partial}) => CaptureState(
  phase: CapturePhase.listening,
  transcript: '',
  partialTranscript: partial,
  amplitudes: _amplitudes(48),
  dbfs: -7,
);

final _transcribing = CaptureState(
  phase: CapturePhase.transcribing,
  transcript: '',
  partialTranscript: _shortUtterance,
  amplitudes: _amplitudes(48),
);

const _captured = CaptureState(
  phase: CapturePhase.captured,
  transcript:
      'Plan tomorrow morning: two hours of deep work on the planner, '
      'then a check-in with the design team and a short walk.',
  amplitudes: [],
);

const _category = DayAgentCategory(
  id: 'cat-client',
  name: 'Client Work',
  colorHex: '4F9DDE',
);

const _deepWork = DayAgentCategory(
  id: 'cat-deep',
  name: 'Deep Work',
  colorHex: '8B5CF6',
);

const _health = DayAgentCategory(
  id: 'cat-health',
  name: 'Health',
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
      block('blk-1', 'Planner deep work', 9, 11, _deepWork),
      block('blk-2', 'Design team check-in', 11, 11, _category, endMinute: 45),
      block('blk-3', 'Client follow-up', 13, 14, _category, endMinute: 30),
      block('blk-4', 'Short run', 17, 18, _health, startMinute: 30),
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
  Future<void> toggle() async {}
}

/// Drafting agent whose draft never resolves — keeps the Drafting step on
/// screen in its "drafting" phase for a stable capture.
class _PendingDraftAgent extends MockDayAgent {
  _PendingDraftAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

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

MockDayAgent _fastAgent() => MockDayAgent(
  parseLatency: Duration.zero,
  pendingLatency: Duration.zero,
  triageLatency: Duration.zero,
  draftLatency: Duration.zero,
  summarizeLatency: Duration.zero,
  clock: () => _now,
);

Widget _app({
  required Widget home,
  required Brightness brightness,
  required List<Override> overrides,
  required Size size,
  double textScale = 1.0,
}) {
  return RepaintBoundary(
    key: _boundaryKey,
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

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      tester.element(find.byKey(_boundaryKey)).findRenderObject()!
          as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir =
        Platform.environment['LOTTI_SCREENSHOT_DIR'] ??
        p.join('screenshots', 'daily_os_next');
    final file = File(p.join(dir, '$name.png'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      byteData!.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      flush: true,
    );
    stdout.writeln('wrote screenshot: ${file.path}');
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

AppLocalizations _messages(WidgetTester tester) =>
    tester.element(find.byType(DayPlanningGlassActionBar)).messages;

/// Pumps an app whose single button opens the day-planning modal, taps it,
/// and settles the entry animation. Returns once the modal is on screen.
Future<void> _openModal(
  WidgetTester tester, {
  required DayPlanningIntent intent,
  required _Device device,
  CaptureState capture = const CaptureState.idle(),
  MockDayAgent? agent,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) async {
  tester.view
    ..physicalSize = device.size * device.devicePixelRatio
    ..devicePixelRatio = device.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
  });
}

Future<void> _tapPill(WidgetTester tester, String label) async {
  await withClock(Clock.fixed(_now), () async {
    await tester.tap(find.widgetWithText(DsGlassPill, label));
    await _settle(tester);
  });
}

void main() {
  // OPT-IN ONLY. The harness loads real fonts via FontLoader, which
  // registers them process-wide with no way to unload — under very_good's
  // single-isolate optimizer that changes text metrics for unrelated tests.
  // So it only runs when explicitly requested for design review.
  final captureEnabled =
      Platform.environment['LOTTI_CAPTURE_SCREENSHOTS'] == 'true' ||
      Platform.environment.containsKey('LOTTI_SCREENSHOT_DIR');
  if (!captureEnabled) {
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

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Future<ByteData> fontBytes(String path) async {
      final bytes = await File(path).readAsBytes();
      return ByteData.view(bytes.buffer);
    }

    final inter = FontLoader('Inter')
      ..addFont(
        fontBytes('assets/fonts/Inter/Inter-VariableFont_opsz,wght.ttf'),
      );
    final inconsolata = FontLoader('Inconsolata')
      ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Regular.ttf'))
      ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Medium.ttf'));
    await inter.load();
    await inconsolata.load();

    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ?? '.fvm/flutter_sdk';
    final iconFont = File(
      p.join(
        flutterRoot,
        'bin',
        'cache',
        'artifacts',
        'material_fonts',
        'MaterialIcons-Regular.otf',
      ),
    );
    if (iconFont.existsSync()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(fontBytes(iconFont.path));
      await icons.load();
    }

    // The voice orb's mic glyph comes from the MDI webfont (package font →
    // prefixed family). Without it the orb renders a tofu box.
    final mdiFont = _findMdiFont(
      Directory(
        p.join(
          Platform.environment['HOME'] ?? '',
          '.pub-cache',
          'hosted',
          'pub.dev',
        ),
      ),
    );
    if (mdiFont != null) {
      final mdi = FontLoader(
        'packages/flutter_material_design_icons/Material Design Icons',
      )..addFont(fontBytes(mdiFont.path));
      await mdi.load();
    }
  });

  // ───────────────────────── Create ritual, per device ─────────────────────

  for (final device in _allDevices) {
    testWidgets('${device.name} capture idle — dark', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
      );
      expect(find.byType(CaptureModalContent), findsOneWidget);
      await _capture(tester, '${device.name}_01_capture_idle_dark');
    });

    testWidgets('${device.name} capture listening (short) — dark', (
      tester,
    ) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _listening(partial: _shortUtterance),
      );
      await _capture(tester, '${device.name}_02_listening_short_dark');
    });

    testWidgets('${device.name} capture listening (long) — dark', (
      tester,
    ) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _listening(partial: _longUtterance),
      );
      await _capture(tester, '${device.name}_03_listening_long_dark');
    });

    testWidgets('${device.name} capture transcribing — dark', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _transcribing,
      );
      await _capture(tester, '${device.name}_04_transcribing_dark');
    });

    testWidgets('${device.name} capture captured — dark', (tester) async {
      await _openModal(
        tester,
        intent: const DayPlanningCreate(),
        device: device,
        capture: _captured,
      );
      expect(find.byType(DsGlassPill), findsNWidgets(2));
      await _capture(tester, '${device.name}_05_captured_dark');
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
      await _capture(tester, '${device.name}_06_reconcile_dark');
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
      await _capture(tester, '${device.name}_07_drafting_dark');
    });

    testWidgets('${device.name} refine — dark', (tester) async {
      await _openModal(
        tester,
        intent: DayPlanningAdapt(_refineDraft()),
        device: device,
        agent: _fastAgent(),
      );
      await _capture(tester, '${device.name}_08_refine_dark');
    });
  }

  // ─────────────────────── Light theme + large text ────────────────────────

  testWidgets('mini capture idle — light', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: _mini,
      brightness: Brightness.light,
    );
    await _capture(tester, 'mini_09_capture_idle_light');
  });

  testWidgets('mini captured — light', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: _mini,
      capture: _captured,
      brightness: Brightness.light,
    );
    await _capture(tester, 'mini_10_captured_light');
  });

  testWidgets('mini capture idle — dark, 1.3x text', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: _mini,
      textScale: 1.3,
    );
    await _capture(tester, 'mini_11_capture_idle_dark_ts13');
  });

  testWidgets('mini listening (long) — dark, 1.3x text', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: _mini,
      capture: _listening(partial: _longUtterance),
      textScale: 1.3,
    );
    await _capture(tester, 'mini_12_listening_long_dark_ts13');
  });

  testWidgets('mini captured — dark, 1.3x text', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      device: _mini,
      capture: _captured,
      textScale: 1.3,
    );
    await _capture(tester, 'mini_13_captured_dark_ts13');
  });

  testWidgets('capture with "Today so far" card — mini dark', (tester) async {
    final block = TimeBlock(
      id: 'actual:entry-1',
      title: 'Client follow-up',
      start: DateTime(2026, 6, 8, 8),
      end: DateTime(2026, 6, 8, 9, 30),
      type: TimeBlockType.manual,
      state: TimeBlockState.completed,
      category: _category,
    );
    tester.view
      ..physicalSize = _mini.size * _mini.devicePixelRatio
      ..devicePixelRatio = _mini.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(
        _app(
          brightness: Brightness.dark,
          size: _mini.size,
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
      await _settle(tester);
    });
    expect(find.text('Client follow-up'), findsOneWidget);
    await _capture(tester, 'mini_14_capture_today_so_far_dark');
  });
}

/// Locates the Material Design Icons webfont inside the pub cache without
/// hard-coding the package version.
File? _findMdiFont(Directory pubHosted) {
  if (!pubHosted.existsSync()) return null;
  final dirs =
      pubHosted
          .listSync()
          .whereType<Directory>()
          .where(
            (d) =>
                p.basename(d.path).startsWith('flutter_material_design_icons-'),
          )
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
  for (final dir in dirs) {
    final font = File(
      p.join(dir.path, 'assets', 'materialdesignicons-webfont.ttf'),
    );
    if (font.existsSync()) return font;
  }
  return null;
}
