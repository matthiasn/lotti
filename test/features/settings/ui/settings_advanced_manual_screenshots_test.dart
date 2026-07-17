/// Production screenshot harness for the Advanced Settings manual.
///
/// Captures the real mobile route pages and the real desktop Settings V2
/// master/detail surface for the Advanced hub, flags, logging, maintenance,
/// onboarding metrics, and About Lotti. Every case is rendered at mobile and
/// desktop size in light and dark mode.
///
/// Opt in with:
/// `LOTTI_SCREENSHOT_DIR=/tmp/advanced-settings fvm flutter test \
///   test/features/settings/ui/settings_advanced_manual_screenshots_test.dart`
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/onboarding_metrics_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_branch_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../helpers/target_platform.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';

const Map<String, bool> _flagValues = {
  privateFlag: true,
  enableNotificationsFlag: true,
  recordLocationFlag: false,
  enableTooltipFlag: true,
  enableAiStreamingFlag: true,
  enableAiSummaryTtsFlag: true,
  enableLoggingFlag: true,
  enableMatrixFlag: true,
  resendAttachments: false,
  enableHabitsPageFlag: true,
  enableDashboardsPageFlag: true,
  enableEventsFlag: true,
  enableSessionRatingsFlag: true,
  enableProjectsFlag: true,
  enableEmbeddingsFlag: true,
  enableVectorSearchFlag: true,
  enableWhatsNewFlag: true,
  dailyOsOnboardingEnabledFlag: false,
  showSyncActivityIndicatorFlag: true,
  enableForkHealingFlag: false,
  logSlowQueriesFlag: false,
};

Set<ConfigFlag> get _manualFlags => {
  for (final name in FlagsBody.defaultDisplayedItems)
    ConfigFlag(
      name: name,
      description: 'Manual capture value for $name',
      status: _flagValues[name] ?? false,
    ),
};

final OnboardingFunnelState _manualFunnel = OnboardingFunnelState(
  installFirstSeen: DateTime.utc(2026, 7, 1, 8, 14),
  activeDayBuckets: [20635, 20636, 20638, 20641],
  isBaselineCohort: false,
  eventCounts: {
    'appFirstSeen': 1,
    'welcomeShown': 1,
    'providerConnected': 1,
    'firstAudioCaptured': 3,
    'makeTaskTapped': 2,
    'realAha': 1,
    'secondCaptureCompleted': 1,
    'returnSession': 2,
  },
);

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

typedef _AdvancedCase = ({
  String id,
  String route,
  Widget Function() mobilePage,
  String expectedText,
  String? desktopExpectedText,
  String? scrollTo,
});

final List<_AdvancedCase> _cases = [
  (
    id: 'hub',
    route: '/settings/advanced',
    mobilePage: () => const SettingsMobileBranchPage(branchId: 'advanced'),
    expectedText: 'Config Flags',
    desktopExpectedText: null,
    scrollTo: null,
  ),
  (
    id: 'flags',
    route: '/settings/flags',
    mobilePage: FlagsPage.new,
    expectedText: 'Show private entries?',
    desktopExpectedText: null,
    scrollTo: null,
  ),
  (
    id: 'logging',
    route: '/settings/advanced/logging_domains',
    mobilePage: LoggingSettingsPage.new,
    expectedText: 'Enable Logging',
    desktopExpectedText: null,
    scrollTo: null,
  ),
  (
    id: 'health_import',
    route: '/settings/advanced',
    mobilePage: HealthImportPage.new,
    expectedText: 'Import Activity Data',
    desktopExpectedText: 'Config Flags',
    scrollTo: null,
  ),
  (
    id: 'maintenance',
    route: '/settings/advanced/maintenance',
    mobilePage: MaintenancePage.new,
    expectedText: 'Purge deleted items',
    desktopExpectedText: null,
    scrollTo: 'Purge deleted items',
  ),
  (
    id: 'onboarding_metrics',
    route: '/settings/advanced/onboarding_metrics',
    mobilePage: OnboardingMetricsPage.new,
    expectedText: 'Reached real aha',
    desktopExpectedText: null,
    scrollTo: null,
  ),
  (
    id: 'about',
    route: '/settings/advanced/about',
    mobilePage: AboutPage.new,
    expectedText: '2604',
    desktopExpectedText: null,
    scrollTo: null,
  ),
];

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'advanced-settings screenshot harness (opt-in)',
      () {},
      skip:
          'Manual screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true).',
    );
    return;
  }

  setUpAll(() async {
    await loadScreenshotFonts();
    PackageInfo.setMockInitialValues(
      appName: 'Lotti',
      packageName: 'com.matthiasn.lotti',
      version: '0.9.1049',
      buildNumber: '4217',
      buildSignature: '',
    );
  });

  late TestGetItMocks mocks;
  late MockMaintenance maintenance;
  late MockOnboardingMetricsRepository metricsRepository;
  late NavService navService;

  setUp(() async {
    mocks = await setUpTestGetIt();
    maintenance = MockMaintenance();
    metricsRepository = MockOnboardingMetricsRepository();
    final persistenceLogic = MockPersistenceLogic();
    final healthImport = MockHealthImport();

    when(() => mocks.journalDb.watchConfigFlag(any())).thenAnswer(
      (invocation) => Stream.value(
        _flagValues[invocation.positionalArguments.single] ?? false,
      ),
    );
    when(
      () => mocks.journalDb.watchConfigFlags(),
    ).thenAnswer((_) => Stream.value(_manualFlags));
    when(() => mocks.journalDb.getJournalCount()).thenAnswer((_) async => 2604);
    when(
      () => mocks.journalDb.getCountImportFlagEntries(),
    ).thenAnswer((_) async => 11);
    when(
      () => mocks.journalDb.getTasksCount(
        statuses: any(named: 'statuses'),
      ),
    ).thenAnswer((invocation) async {
      final statuses = invocation.namedArguments[#statuses]! as List<String>;
      return switch (statuses.single) {
        'OPEN' => 17,
        'IN PROGRESS' => 3,
        'ON HOLD' => 2,
        'BLOCKED' => 1,
        'DONE' => 42,
        _ => 0,
      };
    });
    when(
      () => metricsRepository.funnelState(),
    ).thenAnswer((_) async => _manualFunnel);

    getIt
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<Maintenance>(maintenance)
      ..registerSingleton<HealthImport>(healthImport)
      ..registerSingleton<PersistenceLogic>(persistenceLogic)
      ..registerSingleton<OnboardingMetricsRepository>(metricsRepository);

    navService = NavService();
    getIt.registerSingleton<NavService>(navService);
    beamToNamedOverride = (_) {};
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await navService.dispose();
    await tearDownTestGetIt();
  });

  List<Override> overrides() {
    final flagNames = <String>{
      ..._flagValues.keys,
      ...LogDomain.values.map((domain) => domain.flagName),
    };
    return [
      for (final name in flagNames)
        configFlagProvider(name).overrideWith(
          (ref) => Stream.value(
            _flagValues[name] ??
                name == LogDomain.sync.flagName ||
                    name == LogDomain.ai.flagName ||
                    name == LogDomain.tasks.flagName,
          ),
        ),
      templatesPendingReviewProvider.overrideWith((ref) async => <String>{}),
    ];
  }

  Future<void> pumpCase(
    WidgetTester tester, {
    required _AdvancedCase scenario,
    required ScreenshotDevice device,
    required Brightness brightness,
  }) => withTargetPlatform(
    device.isPhone ? TargetPlatform.android : TargetPlatform.linux,
    () async {
      applyScreenshotDevice(tester, device);
      navService.isDesktopMode = !device.isPhone;
      navService.desktopSelectedSettingsRoute.value = device.isPhone
          ? null
          : (
              path: scenario.route,
              pathParameters: const <String, String>{},
              queryParameters: const <String, String>{},
            );

      await tester.pumpWidget(
        _app(
          home: device.isPhone
              ? scenario.mobilePage()
              : const SettingsRootPage(),
          brightness: brightness,
          size: device.size,
          overrides: overrides(),
        ),
      );
      await settleFrames(tester, 18);

      if (device.isPhone && scenario.id == 'health_import') {
        final fields = tester
            .widgetList<DateTimeField>(find.byType(DateTimeField))
            .toList(growable: false);
        fields[0].setDateTime(DateTime(2026, 7, 10));
        fields[1].setDateTime(DateTime(2026, 7, 17));
        await settleFrames(tester, 4);
      }

      final target = scenario.scrollTo;
      if (target != null) {
        await tester.ensureVisible(find.text(target).last);
        await tester.pump(const Duration(milliseconds: 300));
      }
    },
  );

  for (final (viewport, device) in [
    ('mobile', miniDevice),
    ('desktop', desktopDevice),
  ]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;
      for (final scenario in _cases) {
        testWidgets(
          '${scenario.id} $viewport manual — $theme',
          (tester) async {
            await pumpCase(
              tester,
              scenario: scenario,
              device: device,
              brightness: brightness,
            );

            final expectedText = device.isPhone
                ? scenario.expectedText
                : scenario.desktopExpectedText ?? scenario.expectedText;
            expect(find.text(expectedText), findsWidgets);
            expect(tester.takeException(), isNull);
            await captureScreenshot(
              tester,
              'advanced_settings_${scenario.id}_${viewport}_$theme',
              subdir: 'advanced_settings',
            );
          },
        );
      }
    }
  }
}
