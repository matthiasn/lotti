/// Tutorial-video driver: "your first minutes with Lotti".
///
/// Drives the REAL first-run flow in
/// `tools/tutorial_videos/config/scenarios/onboarding_first_run.yaml`, in an
/// app that starts empty (no demo world, no provider), exactly as a fresh
/// install does:
///
///  1. the welcome opens by itself,
///  2. choose an AI brain → Melious,
///  3. the API key is typed into the obscured field (read from
///     `MELIOUS_API_KEY`, never revealed, never spoken) and verified live,
///  4. the success beat and the first life area,
///  5. the first task is dictated through the virtual microphone,
///  6. Lotti structures it, and the created card opens the real task page.
@Tags(['tutorial-video'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/helpers/manual_screenshot_locale.dart';
import '../manual_screenshot_utils.dart';
import 'tutorial_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final manifest = TutorialManifest.fromEnvironment();
  final locale = manualScreenshotLocaleFromEnvironment(Platform.environment);
  // The onboarding panels render their labels from the catalogue, so the
  // finders read the very same strings instead of a hand-kept copy.
  final l10n = lookupAppLocalizations(locale);

  testWidgets(
    'drives the first-run onboarding tutorial flow',
    (tester) async {
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final apiKey = Platform.environment['MELIOUS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        fail('MELIOUS_API_KEY is not set — the build exports it from .env');
      }

      final harness = await TutorialAppHarness.setUp(
        aiConfigs: const [],
        languageCode: locale.languageCode,
        // A genuinely empty first run: nothing seeded, no provider, and the
        // welcome opens on its own as it does for a new user.
        seedDemoWorld: false,
        autoShowOnboarding: true,
      );
      addTearDown(harness.dispose);

      final cursor = TutorialCursorController();
      final hudClock = ValueNotifier<Duration>(Duration.zero);
      addTearDown(hudClock.dispose);
      await tester.pumpWidget(
        manualScreenshotBoundary(
          child: TutorialCursorLayer(
            controller: cursor,
            elapsed: hudClock,
            child: ProviderScope(
              overrides: harness.providerOverrides(),
              child: MyBeamerApp(
                navService: harness.navService,
                userActivityService: harness.userActivityService,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Let startup settle before timeline zero; the welcome's auto-show
      // listener fires in this window too.
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final driver =
          TutorialDriver(
              tester: tester,
              manifest: manifest,
              cursor: cursor,
              hud: hudClock,
            )
            ..diagnostics = () {
              final nav = harness.navService;
              final keys = tester.allWidgets
                  .map((widget) => widget.key)
                  .whereType<ValueKey<String>>()
                  .map((key) => key.value)
                  .where((value) => value.startsWith('onboarding-'))
                  .toSet();
              return 'currentPath=${nav.currentPath} '
                  'onboardingPanels=$keys '
                  'textFields=${find.byType(TextField).evaluate().length}';
            }
            ..onTimeout = (context) => captureManualScreenshot(
              binding: binding,
              tester: tester,
              name: 'failure_$context',
            );

      Finder panel(String step) => find.byKey(ValueKey('onboarding-$step'));

      // [hitTestable] is off for the category chips: a full-size invisible
      // InkWell lies over each chip, so its label never hit-tests itself, but
      // a tap at the label's centre lands on that layer.
      Future<void> tapLabel(
        String label, {
        Finder? within,
        bool hitTestable = true,
      }) async {
        var target = find.text(label);
        if (within != null) {
          target = find.descendant(of: within, matching: target);
        }
        if (hitTestable) target = target.hitTestable();
        await driver.pumpUntilFound(target);
        await driver.tapLikeUser(target.first);
      }

      await driver.step('welcome', () async {
        await driver.pumpUntilFound(panel('welcome'));
        await driver.holdUntil(const Duration(seconds: 3));
      });

      await driver.step('choose_brain', () async {
        await tapLabel(l10n.onboardingWelcomeConnectButton);
        await driver.pumpUntilFound(panel('connect'));
      });

      await driver.step('pick_melious', () async {
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(milliseconds: 1500),
        );
        await tapLabel(l10n.aiProviderMeliousName, within: panel('connect'));
        await driver.pumpUntilFound(panel('apikey-melious'));
      });

      await driver.step('paste_key', () async {
        final keyField = find
            .descendant(
              of: panel('apikey-melious'),
              matching: find.byType(TextField),
            )
            .hitTestable();
        await driver.pumpUntilFound(keyField);
        // The video is public: the key must only ever render as dots. The
        // reveal toggle is never touched; this asserts it before and after.
        expect(
          tester.widget<TextField>(keyField.first).obscureText,
          isTrue,
          reason: 'the API key field must be obscured before typing',
        );
        await driver.tapLikeUser(keyField.first);
        // Pasted in one go, as a user would; the live probe runs as soon as
        // typing pauses.
        await tester.enterText(keyField.first, apiKey);
        await tester.pump();
        // Network waits go through pumpUntil so they are recorded as wait
        // spans and fast-forwarded; pumpUntilFound records nothing.
        final verified = find.text(l10n.aiProviderConnectionVerifiedTitle);
        await driver.pumpUntil(
          () => verified.evaluate().isNotEmpty,
          description: 'the key verified against Melious',
        );
        expect(
          tester.widget<TextField>(keyField.first).obscureText,
          isTrue,
          reason: 'the API key field must still be obscured after typing',
        );
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(milliseconds: 800),
        );
        await tapLabel(
          l10n.onboardingApiKeyConnect,
          within: panel('apikey-melious'),
        );
        // Connecting saves the provider and runs the FTUE model seeding
        // against Melious — a network round-trip, recorded as a wait.
        await driver.pumpUntil(
          () => panel('success').evaluate().isNotEmpty,
          description: 'the provider connected and its models seeded',
          timeout: const Duration(minutes: 2),
        );
      });

      await driver.step('connected', () async {
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(milliseconds: 1500),
        );
        await tapLabel(
          l10n.onboardingSuccessContinue,
          within: panel('success'),
        );
        await driver.pumpUntilFound(panel('category'));
      });

      await driver.step('choose_areas', () async {
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(milliseconds: 1200),
        );
        await tapLabel(
          l10n.onboardingCategoryWork,
          within: panel('category'),
          hitTestable: false,
        );
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(milliseconds: 800),
        );
        await tapLabel(
          l10n.onboardingCategoryContinue,
          within: panel('category'),
        );
        await driver.pumpUntilFound(panel('first-task'));
      });

      await driver.step('first_task', () async {
        final orb = find
            .descendant(
              of: panel('first-task'),
              matching: find.byType(VoiceOrbZone),
            )
            .hitTestable();
        await driver.pumpUntilFound(orb);
        // The narrator dictates in their own voice — let the step's narration
        // finish so they never talk over themselves.
        await driver.waitForNarration();
        await driver.tapLikeUser(orb.first);
        await tester.pump(const Duration(milliseconds: 500));
        await driver.speakIntoMic(manifest.step('first_task').dictation!);
        // Tapping the orb again stops the recording and starts transcribing.
        await driver.pumpUntilFound(orb);
        await driver.tapLikeUser(orb.first);
        await tester.pump(const Duration(milliseconds: 500));
      });

      await driver.step('task_appears', () async {
        // Transcription, then structuring on the thinking model: several
        // cloud round-trips, recorded as a wait and fast-forwarded.
        final created = find.text(l10n.onboardingFirstTaskCreatedTitle);
        await driver.pumpUntil(
          () => created.evaluate().isNotEmpty,
          description: 'the dictation structured into a task',
          timeout: const Duration(minutes: 4),
        );
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 2),
        );
        // The hint line shares the created card's tap target.
        await tapLabel(
          l10n.onboardingFirstTaskCreatedHint,
          within: panel('first-task'),
        );
        await driver.pumpUntilFound(
          find.byType(TaskDetailsPage),
          timeout: const Duration(seconds: 20),
        );
      });

      await driver.step('outro', () async {});

      driver.timeline.write();
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
