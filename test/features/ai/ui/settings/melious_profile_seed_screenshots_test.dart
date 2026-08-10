/// Review evidence for the bundled `Melious.ai` inference profile.
///
/// Unlike `ai_settings_manual_screenshots_test.dart`, which renders the
/// Intergalactic Penguin Logistics demo world, this capture renders the
/// profile `ProfileSeedingService` actually creates — the seeder is run for
/// real against an in-memory repository holding a usable Melious provider and
/// its prepopulated model rows. A change to the seed template therefore shows
/// up in the image; a demo fixture would render identically before and after
/// and prove nothing.
///
/// Opt in with:
/// `LOTTI_SCREENSHOT_DIR=/tmp/lotti-pr-screenshots/melious-kimi-k3/after \
///   fvm flutter test \
///   test/features/ai/ui/settings/melious_profile_seed_screenshots_test.dart`
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/inference_profile_detail_page.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart'
    hide aiConfigRepositoryProvider;
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/target_platform.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';

const String _subdir = 'melious_profile';
const String _meliousProviderId = 'melious-provider-seed-capture';

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

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'Melious seeded profile screenshot harness (opt-in)',
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
  late MockNavService navService;
  late TestGetItMocks mocks;

  /// Every config the capture's repository holds, keyed by id. The seeder
  /// writes into this, so the rendered profile is the seeder's own output.
  late Map<String, AiConfig> store;

  List<AiConfig> ofType(AiConfigType type) {
    return store.values
        .where((config) {
          return switch (type) {
            AiConfigType.inferenceProvider =>
              config is AiConfigInferenceProvider,
            AiConfigType.model => config is AiConfigModel,
            AiConfigType.inferenceProfile => config is AiConfigInferenceProfile,
            _ => false,
          };
        })
        .toList(growable: false);
  }

  setUp(() async {
    aiRepository = MockAiConfigRepository();
    navService = MockNavService();
    store = <String, AiConfig>{};

    when(() => navService.isDesktopMode).thenAnswer((_) => false);
    when(() => navService.beamToNamed(any())).thenReturn(null);

    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(navService);
      },
    );
    when(() => mocks.journalDb.watchConfigFlag(any())).thenAnswer(
      (_) => Stream.value(false),
    );

    // A usable Melious provider — the gate `seedDefaults()` checks.
    final provider =
        AiConfig.inferenceProvider(
              id: _meliousProviderId,
              name: 'Melious.ai',
              apiKey: 'capture-key',
              baseUrl: 'https://api.melious.ai/v1',
              inferenceProviderType: InferenceProviderType.melious,
              createdAt: DateTime(2026),
            )
            as AiConfigInferenceProvider;
    store[provider.id] = provider;

    // The rows model prepopulation would have created for that provider,
    // using the same catalog the app ships.
    for (final known in meliousModels) {
      final model = known.toAiConfigModel(
        id: 'melious_${known.providerModelId}',
        inferenceProviderId: _meliousProviderId,
      );
      store[model.id] = model;
    }

    when(() => aiRepository.saveConfig(any())).thenAnswer((invocation) async {
      final config = invocation.positionalArguments.first as AiConfig;
      store[config.id] = config;
    });
    when(
      () => aiRepository.getConfigById(
        any(),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer(
      (invocation) async => store[invocation.positionalArguments.single],
    );
    when(() => aiRepository.getConfigById(any())).thenAnswer(
      (invocation) async => store[invocation.positionalArguments.single],
    );
    for (final type in [
      AiConfigType.inferenceProvider,
      AiConfigType.model,
      AiConfigType.inferenceProfile,
    ]) {
      when(() => aiRepository.getConfigsByType(type)).thenAnswer(
        (_) async => ofType(type),
      );
      when(() => aiRepository.watchConfigsByType(type)).thenAnswer(
        (_) => Stream.value(ofType(type)),
      );
    }
  });

  tearDown(tearDownTestGetIt);

  for (final device in [proMaxDevice, desktopDevice]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final viewport = device.name;
      final theme = brightness == Brightness.dark ? 'dark' : 'light';

      testWidgets('$viewport seeded Melious profile — $theme', (tester) async {
        await withTargetPlatform(
          device.isPhone ? TargetPlatform.android : TargetPlatform.linux,
          () async {
            // Produce the profile the way the app does, rather than writing a
            // fixture that could drift from the seed template.
            await ProfileSeedingService(
              aiConfigRepository: aiRepository,
            ).seedDefaults();

            final seeded = store[profileMeliousId];
            expect(
              seeded,
              isA<AiConfigInferenceProfile>(),
              reason: 'the capture must render a genuinely seeded profile',
            );

            applyScreenshotDevice(tester, device);
            await tester.pumpWidget(
              _app(
                home: const InferenceProfileDetailPage(
                  profileId: profileMeliousId,
                ),
                brightness: brightness,
                device: device,
                overrides: [
                  journalDbProvider.overrideWithValue(mocks.journalDb),
                  aiConfigRepositoryProvider.overrideWithValue(aiRepository),
                ],
              ),
            );
            await settleFrames(tester, 8);

            // Guard the capture: an empty or error shell would still produce
            // a PNG, and a reviewer comparing two of those learns nothing.
            final messages = AppLocalizations.of(
              tester.element(find.byType(Scaffold).first),
            )!;
            expect(
              find.text(messages.inferenceProfileEditTitle),
              findsOneWidget,
            );
            expect(find.text('Melious.ai'), findsWidgets);
            expect(
              find.text('${messages.inferenceProfileThinking} *'),
              findsOneWidget,
            );

            await captureScreenshot(
              tester,
              'melious_profile_${viewport}_$theme',
              subdir: _subdir,
            );
          },
        );
      });
    }
  }
}
