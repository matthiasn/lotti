/// Screenshot harness for settings that shape Lotti's appearance and
/// interaction: theming, recording style, speech, keyboard shortcuts, and
/// completion celebrations.
///
/// Desktop captures render the production Settings V2 tree/detail shell.
/// Mobile captures render the production drill-down page wrapper for the same
/// body. Every manual case therefore shows the UI users actually reach rather
/// than a reconstructed documentation-only scaffold.
///
/// Opt in with an external output directory:
/// `LOTTI_SCREENSHOT_DIR=/tmp/settings_preferences fvm flutter test \
///   test/features/settings/ui/settings_preferences_screenshots_test.dart`
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/keyboard/ui/keyboard_shortcuts_page.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_playground_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/recording_style_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/settings_v2/ui/pages/settings_v2_page.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/ui/speech_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/target_platform.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';
import '../../onboarding/state/recording_style_test_utils.dart';

const String _subdir = 'settings_preferences';

enum _PreferenceSurface {
  theming('/settings/theming'),
  recordingStyle('/settings/recording-style'),
  speech('/settings/speech'),
  keyboardShortcuts('/settings/keyboard-shortcuts'),
  celebrations('/settings/advanced/animations');

  const _PreferenceSurface(this.route);

  final String route;
}

Widget _mobilePage(_PreferenceSurface surface) => switch (surface) {
  _PreferenceSurface.theming => const ThemingPage(),
  _PreferenceSurface.recordingStyle => const RecordingStyleSettingsPage(),
  _PreferenceSurface.speech => const SpeechSettingsPage(),
  _PreferenceSurface.keyboardShortcuts => const KeyboardShortcutsPage(),
  _PreferenceSurface.celebrations => const CelebrationSettingsPage(),
};

Widget _app({
  required Widget home,
  required Brightness brightness,
  required Size size,
  required List<Override> overrides,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
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

Future<void> _pumpSurface(
  WidgetTester tester, {
  required _PreferenceSurface surface,
  required ScreenshotDevice device,
  required Brightness brightness,
  required FakeSettingsNavService navService,
  required List<Override> overrides,
}) async {
  applyScreenshotDevice(tester, device);
  await tester.pumpWidget(
    _app(
      home: device.isPhone ? _mobilePage(surface) : const SettingsV2Page(),
      brightness: brightness,
      size: device.size,
      overrides: overrides,
    ),
  );
  await settleFrames(tester);

  if (!device.isPhone) {
    navService.desktopSelectedSettingsRoute.value = (
      path: surface.route,
      pathParameters: const <String, String>{},
      queryParameters: const <String, String>{},
    );
    await settleFrames(tester);
  }
}

Future<void> _withDevicePlatform(
  ScreenshotDevice device,
  Future<void> Function() body,
) => withTargetPlatform(
  device.isPhone ? TargetPlatform.android : TargetPlatform.linux,
  body,
);

void _alignInOuterScrollView(
  WidgetTester tester,
  Finder target, {
  double top = 72,
}) {
  final scrollablePositions = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .map((state) => state.position)
      .where((position) => position.maxScrollExtent > 0)
      .toList();
  if (scrollablePositions.isEmpty) return;

  final position = scrollablePositions.reduce(
    (largest, candidate) => candidate.maxScrollExtent > largest.maxScrollExtent
        ? candidate
        : largest,
  );
  final targetTop = tester.getTopLeft(target).dy;
  position.jumpTo(
    (position.pixels + targetTop - top).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ),
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'settings-preferences screenshot harness (opt-in)',
      () {},
      skip:
          'Set LOTTI_SCREENSHOT_DIR=<external-dir> to opt into real-font '
          'manual screenshot capture.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  late TestGetItMocks mocks;
  late FakeSettingsNavService navService;
  late Map<String, String> recordingPrefs;
  late bool speechEnabled;

  setUp(() async {
    navService = FakeSettingsNavService();
    speechEnabled = false;
    recordingPrefs = <String, String>{
      recordingStylePrefsKey: RecordingStyle.modern.name,
    };
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<UserActivityService>(UserActivityService())
          ..registerSingleton<NavService>(navService);
      },
    );

    when(() => mocks.journalDb.watchConfigFlag(any())).thenAnswer(
      (invocation) => Stream.value(
        speechEnabled &&
            invocation.positionalArguments.single == enableAiSummaryTtsFlag,
      ),
    );
    when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer((invocation) {
      final keys = invocation.positionalArguments.first as Set<String>;
      const values = <String, String>{
        lightSchemeNameKey: 'Sakura',
        darkSchemeNameKey: 'Outer Space',
        themeModeKey: 'system',
        ttsVoiceIdKey: 'M3',
        ttsSpeedKey: '1.25',
      };
      return Future.value(<String, String?>{
        for (final key in keys) key: values[key],
      });
    });
  });

  tearDown(() async {
    navService.desktopSelectedSettingsRoute.dispose();
    await tearDownTestGetIt();
  });

  List<Override> overrides() => [
    journalDbProvider.overrideWithValue(mocks.journalDb),
    templatesPendingReviewProvider.overrideWith((ref) async => <String>{}),
    recordingStyleAppPrefsProvider.overrideWithValue(
      fakeRecordingStylePrefs(recordingPrefs),
    ),
  ];

  // The 402 dp phone matches the manual's canonical mobile viewport and gives
  // the three celebration-surface labels enough room to remain legible.
  for (final device in [proDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets(
        '$viewport theming controls — $theme',
        (tester) => _withDevicePlatform(device, () async {
          await _pumpSurface(
            tester,
            surface: _PreferenceSurface.theming,
            device: device,
            brightness: brightness,
            navService: navService,
            overrides: overrides(),
          );
          expect(find.text('Theming'), findsWidgets);
          expect(find.text('Sakura'), findsOneWidget);
          expect(find.text('Outer Space'), findsOneWidget);
          await captureScreenshot(
            tester,
            'theming_preferences_${viewport}_$theme',
            subdir: _subdir,
          );

          final selectedLightTheme = find.text('Sakura');
          expect(selectedLightTheme, findsOneWidget);
          await tester.tap(selectedLightTheme);
          await settleFrames(tester);
          expect(find.text('Material'), findsOneWidget);
          expect(find.text('Outer Space'), findsWidgets);
          await captureScreenshot(
            tester,
            'theming_picker_${viewport}_$theme',
            subdir: _subdir,
          );
        }),
      );

      testWidgets(
        '$viewport recording-style preview — $theme',
        (tester) => _withDevicePlatform(device, () async {
          await _pumpSurface(
            tester,
            surface: _PreferenceSurface.recordingStyle,
            device: device,
            brightness: brightness,
            navService: navService,
            overrides: overrides(),
          );
          expect(find.text('Recording Style'), findsWidgets);
          expect(find.text('Modern — energy orb'), findsOneWidget);
          expect(find.text('Analogue — VU meter'), findsOneWidget);
          expect(
            find.byIcon(Icons.radio_button_checked_rounded),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'recording_style_preview_${viewport}_$theme',
            subdir: _subdir,
          );
        }),
      );

      testWidgets(
        '$viewport speech controls — $theme',
        (tester) => _withDevicePlatform(device, () async {
          speechEnabled = true;
          await _pumpSurface(
            tester,
            surface: _PreferenceSurface.speech,
            device: device,
            brightness: brightness,
            navService: navService,
            overrides: overrides(),
          );
          expect(find.text('Speech'), findsWidgets);
          expect(find.text('Male 3'), findsOneWidget);
          expect(find.text('Voice'), findsOneWidget);
          await captureScreenshot(
            tester,
            'speech_voice_${viewport}_$theme',
            subdir: _subdir,
          );

          await tester.tap(find.text('Female').last);
          await settleFrames(tester, 4);
          expect(find.text('Female 1'), findsOneWidget);
          expect(find.text('Female 5'), findsOneWidget);
          expect(find.text('Male 3'), findsNothing);
          await captureScreenshot(
            tester,
            'speech_voice_options_${viewport}_$theme',
            subdir: _subdir,
          );
        }),
      );

      testWidgets(
        '$viewport shortcut catalog — $theme',
        (tester) => _withDevicePlatform(device, () async {
          await _pumpSurface(
            tester,
            surface: _PreferenceSurface.keyboardShortcuts,
            device: device,
            brightness: brightness,
            navService: navService,
            overrides: overrides(),
          );
          expect(find.text('Keyboard shortcuts'), findsWidgets);
          expect(find.text('Open command palette'), findsOneWidget);
          expect(find.text('General'), findsOneWidget);
          await captureScreenshot(
            tester,
            'keyboard_shortcuts_catalog_${viewport}_$theme',
            subdir: _subdir,
          );

          await tester.enterText(find.byType(TextField), 'rename');
          await settleFrames(tester, 4);
          expect(find.text('Rename focused item'), findsOneWidget);
          expect(find.text('Task'), findsNothing);
          await captureScreenshot(
            tester,
            'keyboard_shortcuts_search_${viewport}_$theme',
            subdir: _subdir,
          );
        }),
      );

      testWidgets(
        '$viewport celebration controls — $theme',
        (tester) => _withDevicePlatform(device, () async {
          await _pumpSurface(
            tester,
            surface: _PreferenceSurface.celebrations,
            device: device,
            brightness: brightness,
            navService: navService,
            overrides: overrides(),
          );
          expect(find.text('Animations'), findsWidgets);
          expect(find.text('Celebration animations'), findsOneWidget);
          expect(find.text('Completion haptics'), findsOneWidget);
          await captureScreenshot(
            tester,
            'celebrations_controls_${viewport}_$theme',
            subdir: _subdir,
          );

          final style = find.text('Style');
          expect(style, findsOneWidget);
          _alignInOuterScrollView(tester, style);
          await settleFrames(tester, 4);
          expect(find.text('Sparks'), findsOneWidget);
          expect(find.text('Combine two'), findsOneWidget);
          expect(find.text('Try it'), findsOneWidget);
          await captureScreenshot(
            tester,
            'celebrations_styles_${viewport}_$theme',
            subdir: _subdir,
          );
        }),
      );

      testWidgets(
        '$viewport celebration playground — $theme',
        (tester) => _withDevicePlatform(device, () async {
          applyScreenshotDevice(tester, device);
          await tester.pumpWidget(
            _app(
              home: const CelebrationPlaygroundPage(
                variant: CelebrationVariant.sparks,
              ),
              brightness: brightness,
              size: device.size,
              overrides: overrides(),
            ),
          );
          await settleFrames(tester, 6);
          expect(find.text('Sparks'), findsOneWidget);
          expect(
            find.text('Changes save and apply everywhere instantly'),
            findsOneWidget,
          );
          expect(find.text('Shape'), findsOneWidget);
          await captureScreenshot(
            tester,
            'celebrations_playground_${viewport}_$theme',
            subdir: _subdir,
          );
        }),
      );
    }
  }
}
