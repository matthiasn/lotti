/// Store listing screenshots — Play Store and App Store — captured on a real
/// Android device or emulator, or on an iOS simulator.
///
/// Boots the production app shell on the tutorial harness — in-memory
/// databases, a temp documents directory, the Intergalactic Penguin
/// Logistics world with its habits, time records and notes, and no demo-mode
/// banner — then walks the screens that say what Lotti is and hands each one
/// to the driver as a PNG. Run through `tool/store_screenshots/android.sh`
/// (`make store_screenshots_android`), which pins the emulator window to a
/// ratio Play accepts, or `tool/store_screenshots/ios.sh`
/// (`make store_screenshots_ios`), which boots the simulators whose native
/// sizes are the App Store's listing sizes; both run this once per theme:
///
///   flutter drive --driver=test_driver/manual_screenshots_driver.dart \
///     --target=integration_test/store_screenshots_test.dart -d emulator-5554 \
///     --dart-define=LOTTI_STORE_THEME=dark --dart-define=LOTTI_MANUAL_LOCALE=en
///
/// Configuration arrives as dart-defines, not environment variables: the
/// test runs on the device, whose environment is not the host's. On a
/// simulator the PNGs are taken by the host, not the device — see
/// [_holdForHostCapture].
///
/// Like the tutorial harness this waits on the wall clock — the app is the
/// real thing on real hardware, with real image decoding and real database
/// notifications — and is exempt from the fake-time policy in
/// `test/README.md`. It is not a verification suite and is not run by
/// `make integration_test`.
@Tags(['store-screenshots'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/insights/ui/time_analysis_page.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/utils/consts.dart';
import 'package:path/path.dart' as p;

import '../test/helpers/manual_demo_world.dart';
import 'manual_screenshot_utils.dart';
import 'tutorial/tutorial_harness.dart';

const _theme = String.fromEnvironment(
  'LOTTI_STORE_THEME',
  defaultValue: 'dark',
);
const _localeTag = String.fromEnvironment(
  'LOTTI_MANUAL_LOCALE',
  defaultValue: 'en',
);

/// One frame every 16ms for up to [timeout], stopping early once [finder]
/// resolves. The app renders on real hardware here, so a fixed pump count
/// would be either wasteful or flaky depending on the emulator's mood.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out waiting for ${finder.describeMatch(Plurality.one)}',
      );
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Lets images decode and entrance animations finish before a capture.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 45; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<Uint8List> _download(Uri uri) => http.readBytes(uri);

/// On an iOS simulator the host owns the capture: the device-side screenshot
/// is the Flutter view alone (no status bar, a blank band under the notch),
/// and its bytes only reach the driver after the run, so a host-side capture
/// from the driver would show the last screen every time. Instead the test
/// announces each capture point on stdout — `tool/store_screenshots/ios.sh`
/// streams the drive output and takes the whole screen with `simctl` on the
/// marker — and then **waits for the host's acknowledgement** before moving
/// on: a `<name>.done` file in a directory the marker names. A simulator's
/// app sandbox is a directory on the host, so the script can write there
/// directly, and the handshake is a real signal rather than a timing bet — a
/// runner that takes ten seconds to screenshot and flatten a frame simply
/// holds the screen for ten seconds. Bounded by [_hostAckTimeout] so a script
/// that never answers fails the run instead of hanging it. A no-op on
/// Android, where the device-side bytes are the deliverable.
Future<void> _holdForHostCapture(String name) async {
  if (!Platform.isIOS) return;
  final ackDir = Directory(
    p.join(Directory.systemTemp.path, 'lotti-store-capture'),
  )..createSync(recursive: true);
  final ack = File(p.join(ackDir.path, '$name.done'));
  if (ack.existsSync()) ack.deleteSync();
  debugPrint('$_hostCaptureMarker $name ${ackDir.path}');
  final deadline = DateTime.now().add(_hostAckTimeout);
  while (!ack.existsSync()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('the host never acknowledged the capture of $name');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// The line prefix the iOS script watches the drive output for.
const _hostCaptureMarker = 'LOTTI_STORE_CAPTURE';

/// Generous: a cold CI runner can take well over ten seconds per frame.
const _hostAckTimeout = Duration(minutes: 2);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final locale = demoSeedLocaleFromEnvironment({
    'LOTTI_MANUAL_LOCALE': _localeTag,
  });
  const themeMode = _theme == 'light' ? ThemeMode.light : ThemeMode.dark;

  testWidgets('captures the store listing screens', (tester) async {
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final harness = await TutorialAppHarness.setUp(
      aiConfigs: manualDemoAiProviders,
      languageCode: locale.languageCode,
      // Varies with --dart-define=LOTTI_STORE_THEME; the analyzer only sees
      // the default.
      // ignore: avoid_redundant_argument_values
      themeMode: themeMode,
      seedHistory: true,
      configFlags: const {
        enableHabitsPageFlag: true,
        enableDailyOsPageFlag: true,
      },
      downloadMedia: (Platform.isAndroid || Platform.isIOS) ? _download : null,
      now: DateTime.now(),
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      manualScreenshotBoundary(
        child: ProviderScope(
          overrides: harness.providerOverrides(),
          child: MyBeamerApp(
            navService: harness.navService,
            userActivityService: harness.userActivityService,
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byType(TasksTabPage));
    await _settle(tester);

    // Android renders Flutter into a SurfaceView, which a screenshot cannot
    // read; this swaps in an ImageView for the rest of the run. iOS captures
    // the window as it is.
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
    }

    final nav = harness.navService;
    var index = 0;
    Future<void> capture(String screen, Finder ready) async {
      await _pumpUntilFound(tester, ready);
      await _settle(tester);
      index += 1;
      final number = index.toString().padLeft(2, '0');
      final name = 'store_${locale.languageCode}_${_theme}_${number}_$screen';
      await _holdForHostCapture(name);
      await captureManualScreenshot(
        binding: binding,
        tester: tester,
        name: name,
      );
    }

    // 1. The task list — what you meant to do.
    await capture('tasks', find.byType(TasksTabPage));

    // 2. One task with its cover art, checklist and logged time — what
    //    actually happened, attached to the intent.
    final task = harness.world.orbitalHabitatTask;
    nav.beamToNamed('/tasks/${task.meta.id}');
    await capture('task_detail', find.text(task.data.title));

    // 3. Habits, with four imperfect weeks behind them.
    nav.setIndex(nav.beamerDelegates.indexOf(nav.habitsDelegate));
    await capture('habits', find.byType(HabitsTabPage));

    // 4. Time analysis — where the tracked hours went.
    nav
      ..setIndex(nav.beamerDelegates.indexOf(nav.calendarDelegate))
      ..beamToNamed('/calendar/time');
    await capture('time_analysis', find.byType(TimeAnalysisPage));

    // 5. The logbook — notes, photos and time records in one stream.
    nav.setIndex(nav.beamerDelegates.indexOf(nav.journalDelegate));
    await capture('journal', find.byType(InfiniteJournalPage));
  });
}
