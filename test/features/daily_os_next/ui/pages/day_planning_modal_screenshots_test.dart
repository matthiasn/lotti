/// Screenshot harness for the day-planning modal.
///
/// Drives the real Wolt multi-page sheet ([showDayPlanningModal]) through its
/// Capture → Reconcile → Drafting → Refine steps (plus the standalone
/// `CaptureModalContent` "Today so far" variant) and writes PNGs to
/// `screenshots/daily_os_next/` (gitignored) for design review. Not a golden
/// test — there are no stored baselines; the assertions only guard that each
/// scenario renders without exceptions.
///
/// The "AI is thinking" decoder-bars use a fragment shader that does not
/// compile under headless `flutter test`, so the shader paints nothing in
/// these captures — review the bar layout/clearance, not the shader itself.
///
/// Opt-in (real-font loading leaks process-wide — see `main`). Run:
/// `LOTTI_SCREENSHOT_DIR=/tmp/day_planning fvm flutter test \
///   test/features/daily_os_next/ui/pages/day_planning_modal_screenshots_test.dart`
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
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
}) {
  return RepaintBoundary(
    key: _boundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(size: size),
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
  CaptureState capture = const CaptureState.idle(),
  MockDayAgent? agent,
  Brightness brightness = Brightness.dark,
  Size size = const Size(420, 900),
}) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await withClock(Clock.fixed(_now), () async {
    await tester.pumpWidget(
      _app(
        brightness: brightness,
        size: size,
        overrides: [
          captureControllerProvider.overrideWith(
            () => _FakeCaptureController(capture),
          ),
          dailyOsActualTimeBlocksProvider.overrideWith(
            (ref, date) async => const <TimeBlock>[],
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
  });

  testWidgets('capture idle — dark', (tester) async {
    await _openModal(tester, intent: const DayPlanningCreate());
    expect(find.byType(CaptureModalContent), findsOneWidget);
    await _capture(tester, '01_capture_idle_dark');
  });

  testWidgets('capture idle — light', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      brightness: Brightness.light,
    );
    expect(find.byType(CaptureModalContent), findsOneWidget);
    await _capture(tester, '02_capture_idle_light');
  });

  testWidgets('capture captured (re-record + continue) — dark', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      capture: _captured,
    );
    expect(find.byType(DsGlassPill), findsNWidgets(2));
    await _capture(tester, '03_capture_captured_dark');
  });

  testWidgets('reconcile (narrow) — dark', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      capture: _captured,
      agent: _fastAgent(),
    );
    await _tapPill(tester, _messages(tester).dailyOsNextCaptureReconcileCta);
    await _capture(tester, '04_reconcile_narrow_dark');
  });

  testWidgets('reconcile (wide two-column) — dark', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      capture: _captured,
      agent: _fastAgent(),
      size: const Size(1100, 900),
    );
    await _tapPill(tester, _messages(tester).dailyOsNextCaptureReconcileCta);
    await _capture(tester, '05_reconcile_wide_dark');
  });

  testWidgets('drafting — dark', (tester) async {
    await _openModal(
      tester,
      intent: const DayPlanningCreate(),
      capture: _captured,
      agent: _PendingDraftAgent(),
    );
    await _tapPill(tester, _messages(tester).dailyOsNextCaptureReconcileCta);
    await _tapPill(tester, _messages(tester).dailyOsNextReconcileBuildDayCta);
    await _capture(tester, '06_drafting_dark');
  });

  testWidgets('refine — dark', (tester) async {
    await _openModal(
      tester,
      intent: DayPlanningAdapt(DraftPlan.emptyForDay(DateTime(2026, 6, 8))),
      agent: _fastAgent(),
    );
    await _capture(tester, '07_refine_dark');
  });

  testWidgets('capture with "Today so far" card — dark', (tester) async {
    // The modal does NOT currently pass actualBlocks; this renders
    // CaptureModalContent directly to evaluate the dropped card.
    final block = TimeBlock(
      id: 'actual:entry-1',
      title: 'Client follow-up',
      start: DateTime(2026, 6, 8, 8),
      end: DateTime(2026, 6, 8, 9, 30),
      type: TimeBlockType.manual,
      state: TimeBlockState.completed,
      category: _category,
    );
    const size = Size(420, 900);
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(
        _app(
          brightness: Brightness.dark,
          size: size,
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
    await _capture(tester, '08_capture_today_so_far_dark');
  });
}
