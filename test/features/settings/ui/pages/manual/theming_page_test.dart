import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_utils/settings_header_harness.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  late MockSettingsDb mockSettingsDb;
  late MockJournalDb mockJournalDb;
  setUp(() async {
    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        GetIt.I.registerSingleton<UserActivityService>(
          MockUserActivityService(),
        );
      },
    );
    mockSettingsDb = mocks.settingsDb;
    mockJournalDb = mocks.journalDb;
    when(
      () => mockSettingsDb.itemByKey('THEME_MODE'),
    ).thenAnswer((_) async => 'system');
    when(
      () => mockJournalDb.watchConfigFlag(enableTooltipFlag),
    ).thenAnswer((_) => Stream.value(true));
  });

  tearDown(tearDownTestGetIt);

  /// The page under a `MaterialApp` whose theme mode follows the controller,
  /// as `beamer_app` wires it — so a mode picked on the page re-themes the
  /// very tree the page is rendered in.
  Widget createTestWidget({Locale? locale}) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: resolveTestTheme(ThemeData.light()),
          darkTheme: resolveTestTheme(ThemeData.dark()),
          themeMode: ref.watch(
            themingControllerProvider.select((state) => state.themeMode),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47),
            ),
            child: Scaffold(
              body: ThemingPage(),
            ),
          ),
        ),
      ),
    );
  }

  group('ThemingPage Widget Tests', () {
    testWidgets('theming page shows the title and the mode toggle only', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ThemingPage)),
      )!;

      // Verify the page title is displayed (localized)
      expect(find.text(l10n.settingsThemingTitle), findsOneWidget);

      // Verify the segmented button for theme mode is present
      expect(find.byType(DsSegmentedToggle<ThemeMode>), findsOneWidget);

      // The FlexColorScheme pickers are gone: mode is the only preference,
      // so no scheme-name fields may render.
      expect(find.byType(InputDecorator), findsNothing);
    });

    testWidgets('theme mode segmented button changes theme mode', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Find the segmented button
      final segmentedButton = find.byType(DsSegmentedToggle<ThemeMode>);
      expect(segmentedButton, findsOneWidget);

      // Tap on the light theme segment
      final lightThemeSegment = find.byIcon(LottiIcons.day);
      expect(lightThemeSegment, findsOneWidget);
      final editedAt = DateTime.utc(2026, 9, 26);
      await withClock(Clock.fixed(editedAt), () async {
        await tester.tap(lightThemeSegment);
        await tester.pumpAndSettle();
      });

      verify(
        () => mockSettingsDb.saveLocalSettingsGroup(
          {themeModeKey: 'light'},
          stampKey: themePrefsUpdatedAtKey,
          timestamp: editedAt.millisecondsSinceEpoch,
          retainedDefaults: {
            lightSchemeNameKey: kLegacyDefaultThemeName,
            darkSchemeNameKey: kLegacyDefaultThemeName,
          },
        ),
      ).called(1);
      expect(
        tester.widget<DsSegmentedToggle<ThemeMode>>(segmentedButton).selected,
        ThemeMode.light,
      );
    });

    testWidgets('theme mode segments show correct icons', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Verify that the segmented button contains icons
      final segmentedButton = find.byType(DsSegmentedToggle<ThemeMode>);
      expect(segmentedButton, findsOneWidget);

      // Verify icons are present within the segmented button
      expect(
        find.descendant(
          of: segmentedButton,
          matching: find.byType(Icon),
        ),
        findsNWidgets(3), // dark, system, light
      );
    });

    // The controller's first frame is ThemeMode.system, so the platform
    // brightness is pinned to the stored mode: the tap is then the only
    // theme switch the page goes through, and the header cannot go stale
    // on a hidden first switch instead.
    for (final (stored, platform, segment, brightness) in [
      ('light', Brightness.light, LottiIcons.night, Brightness.dark),
      ('dark', Brightness.dark, LottiIcons.day, Brightness.light),
    ]) {
      testWidgets(
        'picking ${brightness.name} re-themes the page header with the body',
        (tester) async {
          when(
            () => mockSettingsDb.itemByKey('THEME_MODE'),
          ).thenAnswer((_) async => stored);
          tester.platformDispatcher.platformBrightnessTestValue = platform;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await tester.pumpWidget(
            createTestWidget(locale: const Locale('en')),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(segment));
          await tester.pumpAndSettle();

          final body = tester.element(
            find.byType(DsSegmentedToggle<ThemeMode>),
          );
          expect(
            Theme.of(body).brightness,
            brightness,
            reason: 'the body must already wear the picked mode',
          );
          final surface = settingsHeaderSurface(tester);
          expect(surface.color, body.designTokens.colors.background.level01);
          expect(
            surface.border?.bottom.color,
            body.designTokens.colors.decorative.level01,
          );
        },
      );
    }
  });
}
