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
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/command_palette.dart';
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
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

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
          locale: manualScreenshotLocale,
          home: AppCommandHost(
            platform: TargetPlatform.linux,
            handlers: _manualCommandHandlers(),
            child: home,
          ),
        ),
      ),
    ),
  );
}

Map<AppCommandId, AppCommandHandler> _manualCommandHandlers() => {
  AppCommandId.openCommandPalette: AppCommandHandler(
    invoke: (invocation) =>
        showAppCommandPalette(invocation.context, invocation.snapshot),
  ),
  for (final id in [
    AppCommandId.openShortcutHelp,
    AppCommandId.createTextEntry,
    AppCommandId.createTask,
    AppCommandId.captureScreenshot,
    AppCommandId.navigateTasks,
    AppCommandId.navigateDailyOs,
    AppCommandId.navigateProjects,
    AppCommandId.navigateHabits,
    AppCommandId.navigateDashboards,
    AppCommandId.navigateJournal,
    AppCommandId.navigateEvents,
    AppCommandId.navigateSettings,
    AppCommandId.zoomIn,
    AppCommandId.zoomOut,
    AppCommandId.resetZoom,
    AppCommandId.refresh,
    AppCommandId.focusSearch,
    AppCommandId.createInContext,
    AppCommandId.rename,
    AppCommandId.delete,
  ])
    id: AppCommandHandler(invoke: (_) {}),
};

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
          expect(find.text(_t('Theming', 'Farbschema')), findsWidgets);
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
          final messages = AppLocalizations.of(
            tester.element(find.byType(Scaffold).first),
          )!;
          expect(
            find.text(messages.settingsRecordingStyleTitle),
            findsWidgets,
          );
          expect(
            find.text(_t('Modern — energy orb', 'Modern — Energie-Orb')),
            findsOneWidget,
          );
          expect(
            find.text(_t('Analogue — VU meter', 'Analog — VU-Meter')),
            findsOneWidget,
          );
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
          expect(find.text(_t('Speech', 'Sprache')), findsWidgets);
          expect(find.text(_t('Male 3', 'Männlich 3')), findsOneWidget);
          expect(find.text(_t('Voice', 'Stimme')), findsOneWidget);
          await captureScreenshot(
            tester,
            'speech_voice_${viewport}_$theme',
            subdir: _subdir,
          );

          await tester.tap(find.text(_t('Female', 'Weiblich')).last);
          await settleFrames(tester, 4);
          expect(find.text(_t('Female 1', 'Weiblich 1')), findsOneWidget);
          expect(find.text(_t('Female 5', 'Weiblich 5')), findsOneWidget);
          expect(find.text(_t('Male 3', 'Männlich 3')), findsNothing);
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
          expect(
            find.text(_t('Keyboard shortcuts', 'Tastaturkurzbefehle')),
            findsWidgets,
          );
          expect(
            find.text(
              _t('Open command palette', 'Befehlspalette öffnen'),
            ),
            findsOneWidget,
          );
          expect(find.text(_t('General', 'Allgemein')), findsOneWidget);
          await captureScreenshot(
            tester,
            'keyboard_shortcuts_catalog_${viewport}_$theme',
            subdir: _subdir,
          );

          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await settleFrames(tester, 4);
          expect(
            find.text(_t('Command palette', 'Befehlspalette')),
            findsOneWidget,
          );
          expect(find.text(_t('Task', 'Aufgabe')), findsWidgets);
          expect(
            find.text(_t('Go to Tasks', 'Zu Aufgaben wechseln')),
            findsWidgets,
          );
          await captureScreenshot(
            tester,
            'command_palette_${viewport}_$theme',
            subdir: _subdir,
          );

          Navigator.of(
            tester.element(find.text(_t('Command palette', 'Befehlspalette'))),
          ).pop();
          await settleFrames(tester, 4);
          expect(
            find.text(_t('Command palette', 'Befehlspalette')),
            findsNothing,
          );

          await tester.enterText(
            find.byType(TextField),
            _t('rename', 'umbenennen'),
          );
          await settleFrames(tester, 4);
          expect(
            find.text(
              _t(
                'Rename focused item',
                'Fokussiertes Element umbenennen',
              ),
            ),
            findsOneWidget,
          );
          expect(find.text(_t('Task', 'Aufgabe')), findsNothing);
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
          expect(find.text(_t('Animations', 'Animationen')), findsWidgets);
          expect(
            find.text(
              _t('Celebration animations', 'Abschluss-Animationen'),
            ),
            findsOneWidget,
          );
          expect(
            find.text(_t('Completion haptics', 'Abschluss-Haptik')),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'celebrations_controls_${viewport}_$theme',
            subdir: _subdir,
          );

          final style = find.text(_t('Style', 'Stil'));
          expect(style, findsOneWidget);
          _alignInOuterScrollView(tester, style);
          await settleFrames(tester, 4);
          expect(find.text(_t('Sparks', 'Funken')), findsOneWidget);
          expect(
            find.text(_t('Combine two', 'Zwei kombinieren')),
            findsOneWidget,
          );
          expect(find.text(_t('Try it', 'Ausprobieren')), findsOneWidget);
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
              home: CelebrationPlaygroundPage(
                variant: CelebrationVariant.sparks,
                previewSampleTitles: [
                  _t('Count emperor penguins', 'Kaiserpinguine zählen'),
                  _t('Route sardine cargo', 'Sardinenfracht routen'),
                  _t('Brief Mission Control', 'Missionskontrolle briefen'),
                ],
              ),
              brightness: brightness,
              size: device.size,
              overrides: overrides(),
            ),
          );
          await settleFrames(tester, 6);
          expect(find.text(_t('Sparks', 'Funken')), findsOneWidget);
          expect(
            find.text(
              _t(
                'Changes save and apply everywhere instantly',
                'Änderungen werden sofort überall gespeichert und angewendet',
              ),
            ),
            findsOneWidget,
          );
          expect(find.text(_t('Shape', 'Form')), findsOneWidget);
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
