/// What the two store-listing walks share: their dart-define configuration,
/// the wall-clock pumping helpers and the boot of the production shell on the
/// penguin demo world.
///
/// `store_screenshots_test.dart` hands still frames to the driver;
/// `store_preview_test.dart` moves through the same world for a screen
/// recording. Both wait on the wall clock — the app is the real thing on a
/// real device — and are exempt from the fake-time policy in `test/README.md`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../test/helpers/manual_demo_world.dart';
import 'manual_screenshot_utils.dart';
import 'tutorial/tutorial_harness.dart';

/// `dark` or `light`. Configuration arrives as dart-defines, not environment
/// variables: the walk runs on the device, whose environment is not the
/// host's.
const storeTheme = String.fromEnvironment(
  'LOTTI_STORE_THEME',
  defaultValue: 'dark',
);

const _localeTag = String.fromEnvironment(
  'LOTTI_MANUAL_LOCALE',
  defaultValue: 'en',
);

/// The fixture locale the walk renders in.
final Locale storeLocale = demoSeedLocaleFromEnvironment({
  'LOTTI_MANUAL_LOCALE': _localeTag,
});

/// One display frame. Everything that waits pumps at this cadence: a recording
/// takes real frames, and sparse pumping renders a page transition at a few
/// frames per second.
const storeWalkFrame = Duration(milliseconds: 16);

/// One frame every 16ms for up to [timeout], stopping early once [finder]
/// resolves. The app renders on real hardware here, so a fixed pump count
/// would be either wasteful or flaky depending on the emulator's mood.
Future<void> pumpUntilFound(
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
    await tester.pump(storeWalkFrame);
  }
}

/// Lets images decode and entrance animations finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 45; i++) {
    await tester.pump(storeWalkFrame);
  }
}

/// Generous: a cold CI runner can take well over ten seconds per frame.
const _hostAckTimeout = Duration(minutes: 2);

/// Where the walk and the host script hand files to each other: a directory
/// in the app's sandbox, which on a simulator is a plain directory on the
/// host. [holdForHost] names it on every line it prints, so the script needs
/// no other way of finding it.
Directory hostHandoffDirectory() => Directory(
  p.join(Directory.systemTemp.path, 'lotti-store-capture'),
)..createSync(recursive: true);

/// Hands the screen to the host script and waits until it hands it back.
///
/// On an iOS simulator the host owns the camera. A device-side screenshot is
/// the Flutter view alone (no status bar, a blank band under the notch), and
/// its bytes only reach the driver after the run; a screen recording exists
/// on the host and nowhere else. So the walk announces the moment on stdout —
/// `[marker] [name] <ack-dir>`, which the scripts in `tool/store_screenshots/`
/// watch the drive output for — and then **waits for the host's
/// acknowledgement** before moving on: a `[name].done` file in
/// [hostHandoffDirectory], the directory the line names. The script can
/// write there directly, and the handshake is a real signal rather than a
/// timing bet — a runner that takes ten seconds to screenshot and flatten a
/// frame, or to start its recorder, simply holds the screen for ten seconds.
/// Bounded by [_hostAckTimeout] so a script that never answers fails the run
/// instead of hanging it. A no-op on Android, where the device-side bytes
/// are the deliverable.
Future<void> holdForHost(String marker, String name) async {
  if (!Platform.isIOS) return;
  final ackDir = hostHandoffDirectory();
  final ack = File(p.join(ackDir.path, '$name.done'));
  if (ack.existsSync()) ack.deleteSync();
  debugPrint('$marker $name ${ackDir.path}');
  final deadline = DateTime.now().add(_hostAckTimeout);
  while (!ack.existsSync()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('the host never acknowledged $marker $name');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<Uint8List> _download(Uri uri) => http.readBytes(uri);

/// Boots the production app shell on the tutorial harness — in-memory
/// databases, a temp documents directory, the Intergalactic Penguin Logistics
/// world with its habits, time records and notes, and no demo-mode banner —
/// and returns once the task list has settled.
///
/// Registers its own teardowns, so a caller only walks.
Future<TutorialAppHarness> bootStoreWorld(WidgetTester tester) async {
  tester.platformDispatcher.localeTestValue = storeLocale;
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  final harness = await TutorialAppHarness.setUp(
    aiConfigs: manualDemoAiProviders,
    languageCode: storeLocale.languageCode,
    // Varies with --dart-define=LOTTI_STORE_THEME; the analyzer only sees
    // the default.
    // ignore: avoid_redundant_argument_values
    themeMode: storeTheme == 'light' ? ThemeMode.light : ThemeMode.dark,
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
  await pumpUntilFound(tester, find.byType(TasksTabPage));
  await settle(tester);
  return harness;
}
