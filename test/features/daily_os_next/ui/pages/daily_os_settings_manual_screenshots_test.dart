/// Deterministic manual screenshots for the production Daily OS settings.
///
/// Desktop captures use the real Settings V2 tree/detail shell; mobile uses
/// the real drill-down page. The configured route is the same Project Waddle
/// inference stack used throughout the AI and Agents chapters.
///
/// Opt in with:
/// `LOTTI_SCREENSHOT_DIR=/tmp/lotti_daily_os_settings fvm flutter test \
///   test/features/daily_os_next/ui/pages/\
///   daily_os_settings_manual_screenshots_test.dart`
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_settings_page.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings_v2/ui/pages/settings_v2_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/manual_demo_world.dart';
import '../../../../helpers/target_platform.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';
import '../../screenshot_harness.dart';

const String _subdir = 'daily_os_settings';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

class _PreferencesController extends DailyOsPreferencesController {
  @override
  DailyOsPreferences build() => DailyOsPreferences(
    userName: 'Director Aurora',
    dayFooterHintRetired: true,
  );
}

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
          home: home,
        ),
      ),
    ),
  );
}

Future<void> _withDevicePlatform(
  ScreenshotDevice device,
  Future<void> Function() body,
) => withTargetPlatform(
  device.isPhone ? TargetPlatform.android : TargetPlatform.linux,
  body,
);

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'Daily OS settings manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  late TestGetItMocks mocks;
  late FakeSettingsNavService navService;
  late MockDayAgentService dayAgentService;

  setUp(() async {
    navService = FakeSettingsNavService();
    dayAgentService = MockDayAgentService();
    when(
      () => dayAgentService.updateDefaultInferenceProfile(any()),
    ).thenAnswer((_) async {});
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(navService);
      },
    );
    when(() => mocks.journalDb.watchConfigFlag(any())).thenAnswer(
      (_) => Stream.value(false),
    );
  });

  tearDown(() async {
    navService.desktopSelectedSettingsRoute.dispose();
    await tearDownTestGetIt();
  });

  List<Override> overrides() {
    final template = makeTestTemplate(
      id: dayAgentTemplateId,
      agentId: dayAgentTemplateId,
      displayName: _t(
        'Project Waddle Day Planner',
        'Project-Waddle-Tagesplaner',
      ),
      kind: AgentTemplateKind.dayAgent,
      modelId: _t('Waddle Command 70B', 'Watschelkommando 70B'),
      profileId: manualProjectWaddleProfileId,
      createdAt: manualDemoNow.subtract(const Duration(days: 36)),
      updatedAt: manualDemoNow.subtract(const Duration(hours: 5)),
    );
    return [
      journalDbProvider.overrideWithValue(mocks.journalDb),
      templatesPendingReviewProvider.overrideWith((ref) async => <String>{}),
      dayAgentServiceProvider.overrideWithValue(dayAgentService),
      agentTemplateProvider.overrideWith((ref, id) async => template),
      taskAgentSetupOptionsProvider.overrideWith(
        (ref) async => TaskAgentSetupOptions(
          profiles: manualDemoAiProfiles,
          models: manualDemoAiModels,
          providers: manualDemoAiProviders,
        ),
      ),
      dailyOsPreferencesControllerProvider.overrideWith(
        _PreferencesController.new,
      ),
    ];
  }

  for (final deviceCase in [
    (device: proDevice, viewport: 'mobile'),
    (device: desktopDevice, viewport: 'desktop'),
  ]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;
      testWidgets(
        '${deviceCase.viewport} Daily OS settings — $theme',
        (tester) => _withDevicePlatform(deviceCase.device, () async {
          applyScreenshotDevice(tester, deviceCase.device);
          await tester.pumpWidget(
            _app(
              home: deviceCase.device.isPhone
                  ? const DailyOsSettingsPage()
                  : const SettingsV2Page(),
              brightness: brightness,
              size: deviceCase.device.size,
              overrides: overrides(),
            ),
          );
          await settleFrames(tester, 6);

          if (!deviceCase.device.isPhone) {
            navService.desktopSelectedSettingsRoute.value = (
              path: '/settings/daily-os',
              pathParameters: const <String, String>{},
              queryParameters: const <String, String>{},
            );
            await settleFrames(tester, 6);
          }

          expect(find.byType(DailyOsSettingsBody), findsOneWidget);
          expect(
            find.text(
              _t('Project Waddle Command', 'Project-Waddle-Kommando'),
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              _t('Waddle Command 70B', 'Watschelkommando 70B'),
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              _t('Mission Control Router', 'Missionskontroll-Router'),
            ),
            findsWidgets,
          );
          expect(find.text('Director Aurora'), findsOneWidget);
          await captureScreenshot(
            tester,
            'daily_os_settings_${deviceCase.viewport}_$theme',
            subdir: _subdir,
          );
        }),
      );
    }
  }
}
