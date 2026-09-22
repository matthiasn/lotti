/// Store listing screenshots — Play Store and App Store — captured on a real
/// Android device or emulator, or on an iOS simulator.
///
/// Boots the penguin demo world through [bootStoreWorld] — shared with the
/// App Preview walk in `store_preview_test.dart` — then walks the screens that
/// say what Lotti is and hands each one to the driver as a PNG. Run through
/// `tool/store_screenshots/android.sh`
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
/// [holdForHost].
///
/// Like the tutorial harness this waits on the wall clock — the app is the
/// real thing on real hardware, with real image decoding and real database
/// notifications — and is exempt from the fake-time policy in
/// `test/README.md`. It is not a verification suite and is not run by
/// `make integration_test`.
@Tags(['store-screenshots'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/insights/ui/time_analysis_page.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';

import 'manual_screenshot_utils.dart';
import 'store_walk.dart';

/// The line prefix the iOS script watches the drive output for.
const _hostCaptureMarker = 'LOTTI_STORE_CAPTURE';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the store listing screens', (tester) async {
    final harness = await bootStoreWorld(tester);

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
      await pumpUntilFound(tester, ready);
      await settle(tester);
      index += 1;
      final number = index.toString().padLeft(2, '0');
      final name =
          'store_${storeLocale.languageCode}_${storeTheme}_${number}_$screen';
      await holdForHost(_hostCaptureMarker, name);
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
