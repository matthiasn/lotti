/// Deterministic design-review captures of the goal check-in sheet, opened as
/// the app opens it: already recording from the page's Speak bar, at rest
/// from a banner, with the text field up from the create menu — and the two
/// ways a recorder has nothing to hand back, a refused microphone and a take
/// already running elsewhere.
///
/// PNGs are written to `LOTTI_SCREENSHOT_DIR`, or
/// `screenshots/goal_checkin` when only `LOTTI_CAPTURE_SCREENSHOTS=true` is
/// set. Run with:
///
/// ```sh
/// LOTTI_SCREENSHOT_DIR=/tmp/lotti-goal-checkin-screenshots \
///   fvm flutter test \
///   test/features/goals/ui/checkins/goal_checkin_composer_screenshots_test.dart
/// ```
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';
import '../../../relationships/helpers/check_in_speech_fakes.dart';

const _subdir = 'goal_checkin';
const _agentId = 'goal-1';

Future<void> _capture(
  WidgetTester tester,
  String name, {
  required GoalCheckInStart start,
  required Brightness brightness,
  ScreenshotDevice device = proDevice,
  FakeAudioRecorderController? recorder,
}) async {
  applyScreenshotDevice(tester, device);
  await tester.pumpWidget(
    RepaintBoundary(
      key: screenshotBoundaryKey,
      child: makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => GoalCheckInComposer.show(
                  context,
                  agentId: _agentId,
                  goalTitle: 'Stretch three times a week',
                  start: start,
                  preparedLine:
                      'Two of four sessions so far. What got in the way on '
                      'Tuesday?',
                  personaName: 'Stretch coach',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        theme: brightness == Brightness.dark
            ? DesignSystemTheme.dark()
            : DesignSystemTheme.light(),
        mediaQueryData: MediaQueryData(size: device.size),
        overrides: [
          goalCaptureTargetProvider(
            _agentId,
          ).overrideWith((ref) async => 'goal-row-1'),
          goalCategoryIdProvider(_agentId).overrideWith((ref) async => null),
          audioRecorderControllerProvider.overrideWith(
            () => recorder ?? FakeAudioRecorderController(),
          ),
        ],
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // A live take never settles: pump frames by hand.
  await settleFrames(tester, 30);
  final theme = brightness == Brightness.dark ? 'dark' : 'light';
  await captureScreenshot(
    tester,
    'goal_checkin_${name}_${device.name}_$theme',
    subdir: _subdir,
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'goal check-in screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true).',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  for (final brightness in [Brightness.dark, Brightness.light]) {
    final theme = brightness == Brightness.dark ? 'dark' : 'light';
    testWidgets('speaking $theme', (tester) async {
      await _capture(
        tester,
        'speaking',
        start: GoalCheckInStart.speaking,
        brightness: brightness,
      );
    });
    testWidgets('at rest $theme', (tester) async {
      await _capture(
        tester,
        'at_rest',
        start: GoalCheckInStart.idle,
        brightness: brightness,
      );
    });
    testWidgets('writing $theme', (tester) async {
      await _capture(
        tester,
        'writing',
        start: GoalCheckInStart.writing,
        brightness: brightness,
      );
    });
    testWidgets('microphone refused $theme', (tester) async {
      await _capture(
        tester,
        'mic_denied',
        start: GoalCheckInStart.speaking,
        brightness: brightness,
        recorder: FakeAudioRecorderController(
          recordFailure: AudioRecordingFailure.permissionDenied,
        ),
      );
    });
    testWidgets('another recording running $theme', (tester) async {
      await _capture(
        tester,
        'recorder_busy',
        start: GoalCheckInStart.speaking,
        brightness: brightness,
        recorder: FakeAudioRecorderController(runningFor: 'another-goal'),
      );
    });
  }

  testWidgets('speaking on a wide window', (tester) async {
    await _capture(
      tester,
      'speaking',
      start: GoalCheckInStart.speaking,
      brightness: Brightness.dark,
      device: desktopDevice,
    );
  });
}
