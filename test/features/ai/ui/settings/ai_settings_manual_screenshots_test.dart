/// Deterministic manual screenshots for the production AI settings surfaces.
///
/// The fixture uses the shared Intergalactic Penguin Logistics demo world so
/// provider, model, profile, picker, and usage views describe the same Project
/// Waddle workspace as Tasks, Daily OS, categories, and dashboards.
///
/// Desktop captures render the production Settings V2 tree/detail shell.
/// Mobile captures render the production full-screen pages. Generated PNGs
/// are staging inputs for `lotti-docs` and are never committed to this repo.
///
/// Opt in with:
/// `LOTTI_SCREENSHOT_DIR=/tmp/lotti_ai_manual fvm flutter test \
///   test/features/ai/ui/settings/ai_settings_manual_screenshots_test.dart`
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/inference_profile_detail_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_page.dart';
import 'package:lotti/features/ai/ui/widgets/profile_pinning_selector.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/impact_analysis_page.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/pages/settings_v2_page.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart'
    hide aiConfigRepositoryProvider;
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/manual_demo_world.dart';
import '../../../../helpers/target_platform.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';

const String _subdir = 'ai_settings';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);

enum _AiSurface {
  providers,
  models,
  profiles,
  usage,
  providerDetail,
  modelEditor,
  profileEditor,
  legacyProfiles,
}

final CategoryDefinition _missionControlCategory = CategoryDefinition(
  id: 'manual-mission-control',
  name: _t('Mission Control', 'Missionskontrolle'),
  color: '#4F9DDE',
  createdAt: manualDemoNow.subtract(const Duration(days: 120)),
  updatedAt: manualDemoNow,
  vectorClock: null,
  private: true,
  active: true,
  favorite: true,
);

final List<ConsumptionMetricRow> _usageRows = [
  _usageRow(
    day: 8,
    categoryId: manualDemoCategoryId,
    modelId: manualWaddleCommandModelId,
    providerModelId: 'meta-llama/llama-3.3-70b-instruct',
    credits: 0.42,
    energyKwh: 0.018,
    carbonGCo2: 3.4,
    totalTokens: 18400,
    dataCenter: 'FI-HEL1',
    renewablePercent: 100,
  ),
  _usageRow(
    day: 11,
    categoryId: 'manual-mission-control',
    modelId: manualEmperorReasoningModelId,
    providerModelId: 'anthropic/claude-sonnet-4.5',
    credits: 0.61,
    energyKwh: 0.026,
    carbonGCo2: 4.8,
    totalTokens: 9200,
    dataCenter: 'SE-STO1',
    renewablePercent: 92,
  ),
  _usageRow(
    day: 16,
    categoryId: manualDemoCategoryId,
    modelId: manualPenguinBriefingsModelId,
    providerModelId: 'voxtral-mini-latest',
    credits: 0.17,
    energyKwh: 0.009,
    carbonGCo2: 1.8,
    totalTokens: 6400,
    dataCenter: 'Habitat Audio Bay',
    renewablePercent: 100,
  ),
  // Prior-month baseline so the KPI row can render meaningful deltas.
  ConsumptionMetricRow(
    createdAt: DateTime(2026, 6, 14, 10),
    categoryId: manualDemoCategoryId,
    modelId: manualWaddleCommandModelId,
    providerModelId: 'meta-llama/llama-3.3-70b-instruct',
    metrics: const ConsumptionMetrics(
      callCount: 1,
      totalTokens: 14000,
      credits: 0.74,
      energyKwh: 0.03,
      carbonGCo2: 6.1,
    ),
    dataCenter: 'FI-HEL1',
    renewablePercent: 100,
  ),
];

ConsumptionMetricRow _usageRow({
  required int day,
  required String categoryId,
  required String modelId,
  required String providerModelId,
  required double credits,
  required double energyKwh,
  required double carbonGCo2,
  required int totalTokens,
  required String dataCenter,
  required double renewablePercent,
}) {
  return ConsumptionMetricRow(
    createdAt: DateTime(2026, 7, day, 10),
    categoryId: categoryId,
    modelId: modelId,
    providerModelId: providerModelId,
    metrics: ConsumptionMetrics(
      callCount: 1,
      totalTokens: totalTokens,
      credits: credits,
      energyKwh: energyKwh,
      carbonGCo2: carbonGCo2,
    ),
    dataCenter: dataCenter,
    renewablePercent: renewablePercent,
  );
}

Widget _app({
  required Widget home,
  required Brightness brightness,
  required ScreenshotDevice device,
  required List<Override> overrides,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(size: device.size),
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
            handlers: const <AppCommandId, AppCommandHandler>{},
            platform: device.isPhone
                ? TargetPlatform.android
                : TargetPlatform.linux,
            child: home,
          ),
        ),
      ),
    ),
  );
}

Widget _mobilePage(_AiSurface surface) => switch (surface) {
  _AiSurface.providers => const AiSettingsPage(
    initialTab: AiSettingsTab.providers,
  ),
  _AiSurface.models => const AiSettingsPage(initialTab: AiSettingsTab.models),
  _AiSurface.profiles => const AiSettingsPage(
    initialTab: AiSettingsTab.profiles,
  ),
  _AiSurface.usage => const ImpactAnalysisPage(),
  _AiSurface.providerDetail => const AiProviderDetailPage(
    providerId: manualMissionControlProviderId,
  ),
  _AiSurface.modelEditor => const InferenceModelEditPage(
    configId: manualWaddleCommandModelId,
  ),
  _AiSurface.profileEditor => const InferenceProfileDetailPage(
    profileId: manualProjectWaddleProfileId,
  ),
  _AiSurface.legacyProfiles => const InferenceProfilePage(),
};

Future<void> _selectDesktopSurface(
  WidgetTester tester, {
  required _AiSurface surface,
  required ValueNotifier<DesktopSettingsRoute?> route,
}) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SettingsV2Page)),
    listen: false,
  );
  final tree = container.read(settingsTreePathProvider.notifier)
    ..syncFromUrl('/settings/ai');

  switch (surface) {
    case _AiSurface.providers:
      tree.onNodeTap('ai/providers', depth: 1, hasChildren: false);
    case _AiSurface.models:
      tree.onNodeTap('ai/models', depth: 1, hasChildren: false);
    case _AiSurface.profiles:
      tree.onNodeTap('ai/profiles', depth: 1, hasChildren: false);
    case _AiSurface.usage:
      tree.onNodeTap('ai/usage', depth: 1, hasChildren: false);
    case _AiSurface.providerDetail:
      route.value = (
        path: '/settings/ai/provider/$manualMissionControlProviderId',
        pathParameters: const {
          'providerId': manualMissionControlProviderId,
        },
        queryParameters: const <String, String>{},
      );
    case _AiSurface.modelEditor:
      route.value = (
        path: '/settings/ai/model/$manualWaddleCommandModelId',
        pathParameters: const {'modelId': manualWaddleCommandModelId},
        queryParameters: const <String, String>{},
      );
    case _AiSurface.profileEditor:
      route.value = (
        path: '/settings/ai/profile/$manualProjectWaddleProfileId',
        pathParameters: const {'profileId': manualProjectWaddleProfileId},
        queryParameters: const <String, String>{},
      );
    case _AiSurface.legacyProfiles:
      throw StateError('Legacy profiles do not use the Settings V2 panel.');
  }
  await settleFrames(tester, 8);
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
      'AI settings manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  setUpAll(() async {
    registerAllFallbackValues();
    await loadScreenshotFonts();
  });

  late MockAiConfigRepository aiRepository;
  late MockConsumptionRepository consumptionRepository;
  late MockNavService navService;
  late TestGetItMocks mocks;
  late ValueNotifier<DesktopSettingsRoute?> desktopRoute;
  late bool desktopMode;

  setUp(() async {
    aiRepository = MockAiConfigRepository();
    consumptionRepository = MockConsumptionRepository();
    navService = MockNavService();
    desktopRoute = ValueNotifier<DesktopSettingsRoute?>(null);
    desktopMode = false;

    when(() => navService.desktopSelectedSettingsRoute).thenReturn(
      desktopRoute,
    );
    when(() => navService.isDesktopMode).thenAnswer((_) => desktopMode);
    when(() => navService.beamToNamed(any())).thenReturn(null);

    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(navService);
      },
    );

    when(() => mocks.journalDb.watchConfigFlag(any())).thenAnswer(
      (_) => Stream.value(false),
    );
    when(() => mocks.settingsDb.itemByKey(any())).thenAnswer(
      (_) async => '2',
    );

    when(
      () => aiRepository.watchConfigsByType(
        AiConfigType.inferenceProvider,
      ),
    ).thenAnswer((_) => Stream.value(manualDemoAiProviders));
    when(
      () => aiRepository.watchConfigsByType(AiConfigType.model),
    ).thenAnswer((_) => Stream.value(manualDemoAiModels));
    when(
      () => aiRepository.watchConfigsByType(AiConfigType.inferenceProfile),
    ).thenAnswer((_) => Stream.value(manualDemoAiProfiles));
    when(aiRepository.watchProfiles).thenAnswer(
      (_) => Stream.value(manualDemoAiProfiles),
    );
    when(
      () => aiRepository.getConfigsByType(AiConfigType.inferenceProvider),
    ).thenAnswer((_) async => manualDemoAiProviders);
    when(
      () => aiRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => manualDemoAiModels);
    when(
      () => aiRepository.getConfigsByType(AiConfigType.inferenceProfile),
    ).thenAnswer((_) async => manualDemoAiProfiles);
    when(() => aiRepository.getConfigById(any())).thenAnswer((
      invocation,
    ) async {
      final id = invocation.positionalArguments.single as String;
      return <AiConfig>[
        ...manualDemoAiProviders,
        ...manualDemoAiModels,
        ...manualDemoAiProfiles,
      ].where((config) => config.id == id).firstOrNull;
    });
    when(() => aiRepository.saveConfig(any())).thenAnswer((_) async {});

    when(
      () => consumptionRepository.metricRowsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => _usageRows);
    when(
      () => consumptionRepository.newestEventsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
  });

  tearDown(() async {
    desktopRoute.dispose();
    await tearDownTestGetIt();
  });

  List<Override> overrides(ManualDemoWorld world) => [
    journalDbProvider.overrideWithValue(mocks.journalDb),
    aiConfigRepositoryProvider.overrideWithValue(aiRepository),
    templatesPendingReviewProvider.overrideWith((ref) async => <String>{}),
    knownSyncNodesProvider.overrideWith((ref) => const Stream.empty()),
    localVectorClockHostIdProvider.overrideWith((ref) async => null),
    consumptionRepositoryProvider.overrideWithValue(consumptionRepository),
    consumptionRefetchThrottleProvider.overrideWithValue(null),
    maybeUpdateNotificationsProvider.overrideWith((ref) => null),
    categoriesStreamProvider.overrideWith(
      (ref) => Stream.value([world.category, _missionControlCategory]),
    ),
    firstDayOfWeekIndexProvider.overrideWith(
      (ref) => DateTime.monday % 7,
    ),
  ];

  Future<void> pumpSurface(
    WidgetTester tester, {
    required _AiSurface surface,
    required ScreenshotDevice device,
    required Brightness brightness,
    required ManualDemoWorld world,
  }) async {
    desktopMode = !device.isPhone;
    applyScreenshotDevice(tester, device);
    final directLegacy = surface == _AiSurface.legacyProfiles;
    await tester.pumpWidget(
      _app(
        home: device.isPhone || directLegacy
            ? _mobilePage(surface)
            : SettingsV2Page(beamToReplacementNamed: (_, _) {}),
        brightness: brightness,
        device: device,
        overrides: overrides(world),
      ),
    );
    await settleFrames(tester, 8);
    if (!device.isPhone && !directLegacy) {
      await _selectDesktopSurface(
        tester,
        surface: surface,
        route: desktopRoute,
      );
    }
  }

  for (final device in [proMaxDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('$viewport AI providers — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          final world = ManualDemoWorld.penguinLogistics();
          await pumpSurface(
            tester,
            surface: _AiSurface.providers,
            device: device,
            brightness: brightness,
            world: world,
          );
          expect(
            find.text(_t('Mission Control Router', 'Missionskontroll-Router')),
            findsOneWidget,
          );
          expect(
            find.text(_t('Habitat Local Lab', 'Lokales Habitat-Labor')),
            findsOneWidget,
          );
          expect(
            find.text(_t('Orbital Vision', 'Orbitaler Blick')),
            findsOneWidget,
          );
          expect(
            find.text(_t('Penguin Audio Bay', 'Pinguin-Audiobucht')),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'ai_providers_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport AI models — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          final world = ManualDemoWorld.penguinLogistics();
          await pumpSurface(
            tester,
            surface: _AiSurface.models,
            device: device,
            brightness: brightness,
            world: world,
          );
          expect(
            find.text(_t('Waddle Command 70B', 'Watschelkommando 70B')),
            findsOneWidget,
          );
          expect(
            find.text(_t('Sardine Logistics 14B', 'Sardinenlogistik 14B')),
            findsOneWidget,
          );
          expect(
            find.text(
              _t(
                'Project Waddle Cover Artist',
                'Project-Waddle-Titelkünstler',
              ),
            ),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'ai_models_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport AI profiles — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          final world = ManualDemoWorld.penguinLogistics();
          await pumpSurface(
            tester,
            surface: _AiSurface.profiles,
            device: device,
            brightness: brightness,
            world: world,
          );
          expect(
            find.text(
              _t('Project Waddle Command', 'Project-Waddle-Kommando'),
            ),
            findsOneWidget,
          );
          expect(
            find.text(_t('Habitat Local-First', 'Habitat zuerst lokal')),
            findsOneWidget,
          );
          expect(
            find.text(_t('Fish Diplomacy', 'Fischdiplomatie')),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'ai_profiles_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport AI provider detail and editor — $theme', (
        tester,
      ) async {
        await _withDevicePlatform(device, () async {
          final world = ManualDemoWorld.penguinLogistics();
          await pumpSurface(
            tester,
            surface: _AiSurface.providerDetail,
            device: device,
            brightness: brightness,
            world: world,
          );
          expect(
            find.text(_t('Mission Control Router', 'Missionskontroll-Router')),
            findsWidgets,
          );
          expect(find.text(_t('Connection', 'Verbindung')), findsOneWidget);
          expect(
            find.text(_t('Waddle Command 70B', 'Watschelkommando 70B')),
            findsAtLeastNWidgets(1),
          );
          expect(
            find.text(_t('Emperor Reasoning XL', 'Kaiserpinguin-Denken XL')),
            findsAtLeastNWidgets(1),
          );
          await captureScreenshot(
            tester,
            'ai_provider_detail_${viewport}_$theme',
            subdir: _subdir,
          );

          if (device.isPhone) {
            await tester.pumpWidget(
              _app(
                home: const InferenceProviderEditPage(
                  configId: manualMissionControlProviderId,
                ),
                brightness: brightness,
                device: device,
                overrides: overrides(world),
              ),
            );
          } else {
            await tester.tap(find.text(_t('Edit', 'Bearbeiten')).first);
          }
          await settleFrames(tester, 8);
          expect(
            find.text(_t('Mission Control Router', 'Missionskontroll-Router')),
            findsWidgets,
          );
          expect(
            find.text(_t('Provider Type', 'Anbietertyp')),
            findsOneWidget,
          );
          expect(find.text(_t('API Key', 'API-Schlüssel')), findsOneWidget);
          await captureScreenshot(
            tester,
            'ai_provider_editor_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport AI model editor — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          final world = ManualDemoWorld.penguinLogistics();
          await pumpSurface(
            tester,
            surface: _AiSurface.modelEditor,
            device: device,
            brightness: brightness,
            world: world,
          );
          expect(
            find.text(_t('Edit Model', 'Modell bearbeiten')),
            findsOneWidget,
          );
          expect(
            find.text(_t('Waddle Command 70B', 'Watschelkommando 70B')),
            findsWidgets,
          );
          expect(
            find.text(_t('Mission Control Router', 'Missionskontroll-Router')),
            findsWidgets,
          );
          expect(
            find.text(_t('Capabilities', 'Fähigkeiten')),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'ai_model_editor_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport AI profile editor and model picker — $theme', (
        tester,
      ) async {
        await _withDevicePlatform(device, () async {
          final world = ManualDemoWorld.penguinLogistics();
          await pumpSurface(
            tester,
            surface: _AiSurface.profileEditor,
            device: device,
            brightness: brightness,
            world: world,
          );
          expect(
            find.text(_t('Edit Profile', 'Profil bearbeiten')),
            findsOneWidget,
          );
          expect(
            find.text(
              _t('Project Waddle Command', 'Project-Waddle-Kommando'),
            ),
            findsOneWidget,
          );
          expect(
            find.text(_t('Waddle Command 70B', 'Watschelkommando 70B')),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'ai_profile_editor_${viewport}_$theme',
            subdir: _subdir,
          );

          final thinkingField = find.text(_t('Thinking *', 'Denken *'));
          expect(thinkingField, findsOneWidget);
          await tester.tap(
            find.text(_t('Waddle Command 70B', 'Watschelkommando 70B')),
          );
          await settleFrames(tester, 6);
          expect(
            find.text(_t('Choose a model', 'Modell auswählen')),
            findsOneWidget,
          );
          expect(
            find.text(_t('Waddle Command 70B', 'Watschelkommando 70B')),
            findsOneWidget,
          );
          expect(find.text('OpenRouter'), findsOneWidget);
          expect(find.text('Ollama'), findsOneWidget);
          await captureScreenshot(
            tester,
            'ai_model_picker_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });

      testWidgets('$viewport AI usage — $theme', (tester) async {
        await _withDevicePlatform(device, () async {
          await withClock(Clock.fixed(manualDemoNow), () async {
            final world = ManualDemoWorld.penguinLogistics();
            await pumpSurface(
              tester,
              surface: _AiSurface.usage,
              device: device,
              brightness: brightness,
              world: world,
            );
            expect(find.text(_t('AI Impact', 'KI-Impact')), findsOneWidget);
            expect(find.text(formatCredits(1.2)), findsOneWidget);
            expect(
              find.text(_t('Cost by category', 'Kosten nach Kategorie')),
              findsOneWidget,
            );
            await captureScreenshot(
              tester,
              'ai_usage_${viewport}_$theme',
              subdir: _subdir,
            );
          });
        });
      });

      testWidgets('$viewport legacy inference profiles — $theme', (
        tester,
      ) async {
        await _withDevicePlatform(device, () async {
          final world = ManualDemoWorld.penguinLogistics();
          await pumpSurface(
            tester,
            surface: _AiSurface.legacyProfiles,
            device: device,
            brightness: brightness,
            world: world,
          );
          expect(
            find.text(_t('Inference Profiles', 'Inferenz-Profile')),
            findsOneWidget,
          );
          expect(
            find.text(
              _t('Project Waddle Command', 'Project-Waddle-Kommando'),
            ),
            findsOneWidget,
          );
          expect(
            find.text(_t('Habitat Local-First', 'Habitat zuerst lokal')),
            findsOneWidget,
          );
          await captureScreenshot(
            tester,
            'ai_legacy_profiles_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      });
    }
  }
}
