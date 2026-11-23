/// Screenshot harness for settings that shape Lotti's appearance and
/// interaction: theming, speech, keyboard shortcuts, and
/// completion celebrations.
///
/// Desktop captures render the production desktop settings tree/detail shell.
/// Mobile captures render the production drill-down page wrapper for the same
/// body. Every manual case therefore shows the UI users actually reach rather
/// than a reconstructed documentation-only scaffold.
///
/// Opt in with an external output directory:
/// `LOTTI_SCREENSHOT_DIR=/tmp/settings_preferences fvm flutter test \
///   test/features/settings/ui/settings_preferences_screenshots_test.dart`
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/domain/palette_jump.dart';
import 'package:lotti/features/keyboard/service/palette_jumps.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/command_catalog_view.dart';
import 'package:lotti/features/keyboard/ui/command_palette.dart';
import 'package:lotti/features/keyboard/ui/keyboard_shortcuts_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_playground_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_desktop_page.dart';
import 'package:lotti/features/theming/ui/theming_page.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/ui/speech_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/theming_settings_keys.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/manual_demo_world.dart';
import '../../../helpers/service_overrides.dart';
import '../../../helpers/target_platform.dart';
import '../../../mocks/mocks.dart';
import '../../../test_utils/material_ui_finders.dart';
import '../../../widget_test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';

const String _subdir = 'settings_preferences';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

AppLocalizations _messages(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

enum _PreferenceSurface {
  theming('/settings/theming'),
  speech('/settings/speech'),
  keyboardShortcuts('/settings/keyboard-shortcuts'),
  celebrations('/settings/advanced/animations');

  const _PreferenceSurface(this.route);

  final String route;
}

Widget _mobilePage(_PreferenceSurface surface) => switch (surface) {
  _PreferenceSurface.theming => const ThemingPage(),
  _PreferenceSurface.speech => const SpeechSettingsPage(),
  _PreferenceSurface.keyboardShortcuts => const KeyboardShortcutsPage(),
  _PreferenceSurface.celebrations => const CelebrationSettingsPage(),
};

Widget _app({
  required Widget home,
  required Brightness brightness,
  required Size size,
  required List<Override> overrides,
  PaletteJumpSearch? jumpSearch,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: withServiceOverrides(overrides),
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          builder: LegacyMaterialBridge.builder,
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: manualScreenshotLocale,
          home: AppCommandHost(
            platform: TargetPlatform.linux,
            handlers: _manualCommandHandlers(jumpSearch: jumpSearch),
            child: home,
          ),
        ),
      ),
    ),
  );
}

/// The app's command handlers, with the palette opened the way the app opens
/// it: searching titles through [jumpSearch] as well as commands.
Map<AppCommandId, AppCommandHandler> _manualCommandHandlers({
  PaletteJumpSearch? jumpSearch,
}) => {
  AppCommandId.openCommandPalette: AppCommandHandler(
    invoke: (invocation) => showAppCommandPalette(
      invocation.context,
      invocation.snapshot,
      jumpSearch: jumpSearch,
    ),
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
  PaletteJumpSearch? jumpSearch,
}) async {
  applyScreenshotDevice(tester, device);
  await tester.pumpWidget(
    _app(
      home: device.isPhone ? _mobilePage(surface) : const SettingsDesktopPage(),
      brightness: brightness,
      size: device.size,
      overrides: withServiceOverrides(overrides),
      jumpSearch: jumpSearch,
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

/// A query for the palette capture that finds both a command and a demo
/// task: the longest leading part (at least three letters) of a word in one
/// of [commandLabels] that also occurs in one of [titles], or else the first
/// word of the first title, so the capture works in every manual locale.
String _paletteQuery(List<String> commandLabels, List<String> titles) {
  final lowerTitles = titles.map((title) => title.toLowerCase()).toList();
  for (final label in commandLabels) {
    for (final word in label.toLowerCase().split(' ')) {
      for (var length = word.length; length >= 3; length--) {
        final prefix = word.substring(0, length);
        if (lowerTitles.any((title) => title.contains(prefix))) return prefix;
      }
    }
  }
  return titles.first.split(' ').first;
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
  late bool speechEnabled;

  setUp(() async {
    navService = FakeSettingsNavService();
    speechEnabled = false;
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

  List<Override> overrides() => withServiceOverrides([
    journalDbProvider.overrideWithValue(mocks.journalDb),
    templatesPendingReviewProvider.overrideWith((ref) async => <String>{}),
  ]);

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
            overrides: withServiceOverrides(overrides()),
          );
          final messages = _messages(tester);
          expect(find.text(messages.settingsThemingTitle), findsWidgets);
          // The mode segments render icons; their localized labels ride the
          // tooltip + semantics, so find them by tooltip rather than text.
          expect(
            findMaterialTooltip(messages.settingsThemingDark),
            findsOneWidget,
          );
          expect(
            findMaterialTooltip(messages.settingsThemingAutomatic),
            findsOneWidget,
          );
          expect(
            findMaterialTooltip(messages.settingsThemingLight),
            findsOneWidget,
          );
          final toggle = tester.widget<DsSegmentedToggle<ThemeMode>>(
            find.byType(DsSegmentedToggle<ThemeMode>),
          );
          expect(toggle.selected, ThemeMode.system);
          await captureScreenshot(
            tester,
            'theming_preferences_${viewport}_$theme',
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
            overrides: withServiceOverrides(overrides()),
          );
          final messages = _messages(tester);
          expect(find.text(messages.settingsSpeechTitle), findsWidgets);
          expect(
            find.text('${messages.speechVoiceGenderMale} 3'),
            findsOneWidget,
          );
          expect(find.text(messages.speechSettingsVoiceLabel), findsOneWidget);
          await captureScreenshot(
            tester,
            'speech_voice_${viewport}_$theme',
            subdir: _subdir,
          );

          await tester.tap(find.text(messages.speechVoiceGenderFemale).last);
          await settleFrames(tester, 4);
          expect(
            find.text('${messages.speechVoiceGenderFemale} 1'),
            findsOneWidget,
          );
          expect(
            find.text('${messages.speechVoiceGenderFemale} 5'),
            findsOneWidget,
          );
          expect(
            find.text('${messages.speechVoiceGenderMale} 3'),
            findsNothing,
          );
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
          // The palette searches the penguin demo world's task titles through
          // the production title search, over a real in-memory index.
          final world = ManualDemoWorld.penguinLogistics();
          final index = Fts5Db(inMemoryDatabase: true);
          addTearDown(index.close);
          await index.indexEntities(world.tasks);
          when(
            () => mocks.journalDb.getConfigFlag(privateFlag),
          ).thenAnswer((_) async => false);
          await _pumpSurface(
            tester,
            surface: _PreferenceSurface.keyboardShortcuts,
            device: device,
            brightness: brightness,
            navService: navService,
            overrides: withServiceOverrides(overrides()),
            jumpSearch: paletteJumpSearch(
              fts5Db: () => index,
              journalDb: mocks.journalDb,
              categoryIds: () => null,
            ),
          );
          final messages = _messages(tester);
          expect(
            find.text(messages.keyboardShortcutsTitle),
            findsWidgets,
          );
          expect(
            find.text(messages.keyboardCommandOpenPalette),
            findsOneWidget,
          );
          expect(
            find.text(messages.keyboardCommandCategoryGeneral),
            findsOneWidget,
          );
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
            find.text(messages.commandPaletteTitle),
            findsOneWidget,
          );
          final paletteSearch = find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(TextField),
          );
          // The hint the app's palette shows, which names what it can find.
          expect(
            tester
                .widget<DesignSystemSearch>(
                  find.descendant(
                    of: find.byType(Dialog),
                    matching: find.byType(DesignSystemSearch),
                  ),
                )
                .hintText,
            messages.commandPaletteSearchEverythingHint,
          );

          final titles = [for (final task in world.tasks) task.data.title];
          final creationLabels = [
            messages.fileMenuNewEntry,
            messages.fileMenuNewTask,
          ];
          final query = _paletteQuery(creationLabels, titles);
          await tester.enterText(paletteSearch, query);
          await tester.pump(CommandCatalogView.jumpSearchDebounce);
          await settleFrames(tester, 4);
          final jumpRows = find.descendant(
            of: find.byType(Dialog),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'jump-task-',
                  ),
            ),
          );
          expect(jumpRows, findsWidgets);
          // Where the query came from a command, that command is listed
          // above the titles it found.
          for (final label in creationLabels) {
            if (label.toLowerCase().contains(query)) {
              expect(
                find.descendant(
                  of: find.byType(Dialog),
                  matching: find.text(label),
                ),
                findsOneWidget,
              );
            }
          }
          await captureScreenshot(
            tester,
            'command_palette_${viewport}_$theme',
            subdir: _subdir,
          );

          Navigator.of(
            tester.element(find.text(messages.commandPaletteTitle)),
          ).pop();
          await settleFrames(tester, 4);
          expect(
            find.text(messages.commandPaletteTitle),
            findsNothing,
          );

          await tester.enterText(
            find.byType(TextField),
            messages.keyboardCommandRename,
          );
          await settleFrames(tester, 4);
          expect(
            find.text(messages.keyboardCommandRename).last,
            findsOneWidget,
          );
          expect(find.text(messages.fileMenuNewTask), findsNothing);
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
            overrides: withServiceOverrides(overrides()),
          );
          final messages = _messages(tester);
          expect(find.text(messages.settingsCelebrationsTitle), findsWidgets);
          expect(
            find.text(messages.settingsCelebrationsEnabledTitle),
            findsOneWidget,
          );
          expect(
            find.text(messages.settingsCelebrationsHapticsTitle),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'celebrations_controls_${viewport}_$theme',
            subdir: _subdir,
          );

          final style = find.text(messages.settingsCelebrationsStyleTitle);
          expect(style, findsOneWidget);
          _alignInOuterScrollView(tester, style);
          await settleFrames(tester, 4);
          expect(
            find.text(messages.settingsCelebrationsVariantSparks),
            findsOneWidget,
          );
          expect(
            find.text(messages.settingsCelebrationsVariantCombine),
            findsOneWidget,
          );
          expect(
            find.text(messages.settingsCelebrationsPreviewTitle),
            findsOneWidget,
          );
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
              overrides: withServiceOverrides(overrides()),
            ),
          );
          await settleFrames(tester, 6);
          final messages = _messages(tester);
          expect(
            find.text(messages.settingsCelebrationsVariantSparks),
            findsOneWidget,
          );
          expect(
            find.text(messages.settingsCelebrationsPlaygroundLiveNote),
            findsOneWidget,
          );
          expect(
            find.text(messages.settingsCelebrationsGroupShape),
            findsOneWidget,
          );
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
