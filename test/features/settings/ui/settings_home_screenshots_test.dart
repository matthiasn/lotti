/// Baseline design-review screenshot harness for the settings entry point
/// `SettingsRootPage`. Renders the REAL current settings root at two device
/// sizes:
///
/// - Desktop (1440x900) → `SettingsRootPage` forks (width >= 960) to the
///   tree-nav master/detail `SettingsV2Page` (the "good" desktop UI).
/// - Mobile/narrow (375x812) → the legacy single-page `SettingsPage` with
///   the collapsing `SliverBoxAdapterPage` header (the UI we want to
///   replace).
///
/// Captures dark + light for each (4 PNGs). PNGs land in
/// `screenshots/settings_home/` (or `$LOTTI_SCREENSHOT_DIR`). Not a golden
/// test — assertions only guard that each scenario renders.
///
/// Opt-in (real-font loading leaks process-wide — see the harness). Run:
/// `LOTTI_SCREENSHOT_DIR=/tmp/settings_baseline fvm flutter test \
///   test/features/settings/ui/settings_home_screenshots_test.dart`
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';

const String _subdir = 'settings_home';

/// Config-flag values driving the rendered tree/list: a rich-but-quiet
/// surface (Matrix/Sync, Habits, Dashboards on; What's New off so the
/// indicator stays out). Everything not listed defaults to false.
const Map<String, bool> _flagValues = {
  enableMatrixFlag: true,
  enableHabitsPageFlag: true,
  enableDashboardsPageFlag: true,
  enableWhatsNewFlag: false,
};

Widget _app({
  required Widget home,
  required Brightness brightness,
  required Size size,
  List<Override> overrides = const [],
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

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Widget home,
  required ScreenshotDevice device,
  Brightness brightness = Brightness.dark,
  List<Override> overrides = const [],
}) async {
  applyScreenshotDevice(tester, device);
  await tester.pumpWidget(
    _app(
      home: home,
      brightness: brightness,
      size: device.size,
      overrides: overrides,
    ),
  );
  await settleFrames(tester);
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'settings-home screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true) '
          'because the real-font loading leaks process-wide.',
    );
    return;
  }

  // KNOWN CAPTURE ARTIFACT: the mobile `SettingsPageHeader` title uses a
  // null fontFamily, so the page title (`Settings`) paints with the test
  // environment's default family ('FlutterTest'), whose glyphs are solid
  // boxes. This is expected and unavoidable in the harness — production
  // is unaffected. All design-token text pins Inter and renders normally.
  setUpAll(loadScreenshotFonts);

  late TestGetItMocks mocks;
  late NavService navService;

  setUp(() async {
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        // Mobile path: SliverBoxAdapterPage's scroll listener resolves
        // getIt<UserActivityService>().updateActivity in initState.
        getIt.registerSingleton<UserActivityService>(UserActivityService());
      },
    );

    // Both the desktop tree (configFlagProvider → journalDbProvider →
    // getIt<JournalDb>) and NavService read gating flags through
    // watchConfigFlag; stub each one with its baseline value.
    when(() => mocks.journalDb.watchConfigFlag(any())).thenAnswer(
      (invocation) => Stream.value(
        _flagValues[invocation.positionalArguments.first] ?? false,
      ),
    );

    // NavService.initState (used by SettingsTreeUrlSync on the desktop
    // path) reads flags from getIt<JournalDb>; constructs cleanly with
    // the stub above. Register the real service.
    navService = NavService();
    getIt.registerSingleton<NavService>(navService);

    // Any tap handlers / build-time beam calls are inert.
    beamToNamedOverride = (_) {};
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await navService.dispose();
    await tearDownTestGetIt();
  });

  /// Overrides shared by every capture:
  /// - `journalDbProvider` so `configFlagProvider` resolves the gating
  ///   flags from the stubbed mock.
  /// - `templatesPendingReviewProvider` → empty so the agents-row
  ///   `RitualPendingIndicator` renders nothing (and never hits the
  ///   agents DB).
  List<Override> baseOverrides() => [
    journalDbProvider.overrideWithValue(mocks.journalDb),
    templatesPendingReviewProvider.overrideWith((ref) async => <String>{}),
  ];

  // -------------------------------------------------------------------------
  // Desktop (1440x900) → SettingsV2Page tree-nav master/detail.
  // -------------------------------------------------------------------------

  testWidgets('desktop settings root (tree) — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: desktopDevice,
      overrides: baseOverrides(),
      home: const SettingsRootPage(),
    );
    // Top-level tree leaves prove the V2 tree rendered.
    expect(find.text('Theming'), findsOneWidget);
    expect(find.text('Advanced Settings'), findsOneWidget);
    await captureScreenshot(
      tester,
      'desktop_settings_root_dark',
      subdir: _subdir,
    );
  });

  testWidgets('desktop settings root (tree) — light', (tester) async {
    await _pumpScreen(
      tester,
      device: desktopDevice,
      brightness: Brightness.light,
      overrides: baseOverrides(),
      home: const SettingsRootPage(),
    );
    expect(find.text('Theming'), findsOneWidget);
    expect(find.text('Advanced Settings'), findsOneWidget);
    await captureScreenshot(
      tester,
      'desktop_settings_root_light',
      subdir: _subdir,
    );
  });

  // -------------------------------------------------------------------------
  // Mobile (375x812) → legacy SettingsPage with collapsing header.
  // -------------------------------------------------------------------------

  testWidgets('mobile settings root (legacy list) — dark', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      overrides: baseOverrides(),
      home: const SettingsRootPage(),
    );
    // Legacy single-page list rows.
    expect(find.text('Theming'), findsOneWidget);
    expect(find.text('Advanced Settings'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mobile_settings_root_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mobile settings root (legacy list) — light', (tester) async {
    await _pumpScreen(
      tester,
      device: miniDevice,
      brightness: Brightness.light,
      overrides: baseOverrides(),
      home: const SettingsRootPage(),
    );
    expect(find.text('Theming'), findsOneWidget);
    expect(find.text('Advanced Settings'), findsOneWidget);
    await captureScreenshot(
      tester,
      'mobile_settings_root_light',
      subdir: _subdir,
    );
  });
}
