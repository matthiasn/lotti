/// Play Store listing screenshots, captured on a real Android device or
/// emulator.
///
/// Boots the production app shell on the tutorial harness — in-memory
/// databases, a temp documents directory, the Intergalactic Penguin
/// Logistics world with its habits, time records and notes, and no demo-mode
/// banner — then walks the screens that say what Lotti is and hands each one
/// to the driver as a PNG. Run through `tool/store_screenshots/android.sh`
/// (`make store_screenshots_android`), which pins the emulator window to a
/// ratio Play accepts and runs this once per theme:
///
///   flutter drive --driver=test_driver/manual_screenshots_driver.dart \
///     --target=integration_test/store_screenshots_test.dart -d emulator-5554 \
///     --dart-define=LOTTI_STORE_THEME=dark --dart-define=LOTTI_MANUAL_LOCALE=en
///
/// Configuration arrives as dart-defines, not environment variables: the
/// test runs on the device, whose environment is not the host's.
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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final locale = demoSeedLocaleFromEnvironment({
    'LOTTI_MANUAL_LOCALE': _localeTag,
  });
  const themeMode = _theme == 'light' ? ThemeMode.light : ThemeMode.dark;

  testWidgets('captures the Play Store listing screens', (tester) async {
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
    // read; this swaps in an ImageView for the rest of the run.
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
      await captureManualScreenshot(
        binding: binding,
        tester: tester,
        name: 'store_${locale.languageCode}_${_theme}_${number}_$screen',
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
