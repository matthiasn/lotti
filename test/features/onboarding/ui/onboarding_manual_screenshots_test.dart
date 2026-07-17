/// Production screenshot harness for the Onboarding manual.
///
/// Captures the real Settings entry and drives the real welcome flow through
/// provider selection, creation of a Penguin Operations area, and the first
/// structured Project Waddle task. Every case is rendered at mobile and
/// desktop size in light and dark mode.
///
/// Opt in with:
/// `LOTTI_SCREENSHOT_DIR=/tmp/onboarding fvm flutter test \
///   test/features/onboarding/ui/onboarding_manual_screenshots_test.dart`
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_capture_to_task_service.dart';
import 'package:lotti/features/onboarding/ui/onboarding_settings_panel.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';

const _typedMission =
    'Inspect the Europa sardine relay before the emperor penguin roll call';
const _createdTaskTitle = 'Inspect the Europa sardine relay';

class _FakeProbe extends ConnectionProbe {
  _FakeProbe(this.result);

  final ConnectionCheckState result;

  @override
  Future<ConnectionCheckState> probe({
    required Uri baseUri,
    required String apiKey,
    required Duration timeout,
    required http.Client client,
  }) async => result;
}

class _OnboardingLaunchHost extends StatefulWidget {
  const _OnboardingLaunchHost();

  @override
  State<_OnboardingLaunchHost> createState() => _OnboardingLaunchHostState();
}

class _OnboardingLaunchHostState extends State<_OnboardingLaunchHost> {
  var _launched = false;

  @override
  Widget build(BuildContext context) {
    if (!_launched) {
      _launched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          OnboardingWelcomeModal.show(
            context,
            onDismiss: () {},
            onCompleted: () {},
          ),
        );
      });
    }
    return const SettingsRootPage();
  }
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
        data: MediaQueryData(size: size, disableAnimations: true),
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

enum _OnboardingCase { settings, welcome, providers, firstTask, taskCreated }

extension on _OnboardingCase {
  String get fileName => switch (this) {
    _OnboardingCase.settings => 'settings',
    _OnboardingCase.welcome => 'welcome',
    _OnboardingCase.providers => 'providers',
    _OnboardingCase.firstTask => 'first_task',
    _OnboardingCase.taskCreated => 'task_created',
  };
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'onboarding screenshot harness (opt-in)',
      () {},
      skip:
          'Manual screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true).',
    );
    return;
  }

  setUpAll(() async {
    registerAllFallbackValues();
    await loadScreenshotFonts();
  });

  late OnboardingMetricsDb metricsDb;
  late OnboardingMetricsRepository metricsRepository;
  late MockAiConfigRepository aiRepository;
  late MockCategoryRepository categoryRepository;
  late MockOnboardingCaptureToTaskService captureService;
  late NavService navService;

  setUp(() async {
    await setUpTestGetIt();

    metricsDb = OnboardingMetricsDb(inMemoryDatabase: true);
    var eventId = 0;
    metricsRepository = OnboardingMetricsRepository(
      db: metricsDb,
      clock: () => DateTime.utc(2026, 7, 17, 9, eventId),
      idGenerator: () => 'manual-event-${eventId++}',
      currentPlatform: () => 'manual',
    );
    await metricsRepository.recordEvent(OnboardingEventName.appFirstSeen);
    await metricsRepository.recordEvent(
      OnboardingEventName.providerConnected,
      provider: 'Ollama',
    );
    await metricsRepository.recordEvent(
      OnboardingEventName.realAha,
      provider: 'Ollama',
    );
    getIt
      ..registerSingleton<OnboardingMetricsRepository>(metricsRepository)
      ..registerSingleton<UserActivityService>(UserActivityService());

    aiRepository = MockAiConfigRepository();
    when(() => aiRepository.saveConfig(any())).thenAnswer((_) async {});

    categoryRepository = MockCategoryRepository();
    when(
      categoryRepository.getAllCategoriesIncludingHidden,
    ).thenAnswer((_) async => <CategoryDefinition>[]);
    when(() => categoryRepository.updateCategory(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.first as CategoryDefinition,
    );
    when(
      () => categoryRepository.createCategory(
        name: any(named: 'name'),
        color: any(named: 'color'),
        defaultProfileId: any(named: 'defaultProfileId'),
        defaultTemplateId: any(named: 'defaultTemplateId'),
      ),
    ).thenAnswer((invocation) async {
      final name = invocation.namedArguments[#name]! as String;
      return CategoryTestUtils.createTestCategory(
        id: name == 'Penguin Operations'
            ? 'penguin-operations'
            : 'mission-control',
        name: name,
      );
    });

    captureService = MockOnboardingCaptureToTaskService();
    when(
      () => captureService.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
        audioId: any(named: 'audioId'),
      ),
    ).thenAnswer(
      (_) async => OnboardingCaptureResult(
        task: MockTask(id: 'europa-sardine-relay'),
        title: _createdTaskTitle,
        checklistItems: const [
          'Verify relay pressure',
          'Count all emperor penguins',
          'Route the sardine cargo pods',
        ],
        isRealAha: true,
      ),
    );

    navService = NavService();
    getIt.registerSingleton<NavService>(navService);
    beamToNamedOverride = (_) {};
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await navService.dispose();
    await metricsDb.close();
    await tearDownTestGetIt();
  });

  List<Override> overrides() => [
    aiConfigRepositoryProvider.overrideWithValue(aiRepository),
    categoryRepositoryProvider.overrideWithValue(categoryRepository),
    captureControllerProvider.overrideWith(FakeCaptureController.new),
    onboardingCaptureToTaskServiceProvider.overrideWithValue(captureService),
    connectionVerifierClientProvider.overrideWith(
      (ref) =>
          () => MockClient((_) async => http.Response('', 200)),
    ),
    connectionProbeRegistryProvider.overrideWith(
      (ref) => {
        InferenceProviderType.ollama: _FakeProbe(
          const ConnectionCheckVerified(
            modelCount: 4,
            latency: Duration(milliseconds: 7),
          ),
        ),
      },
    ),
    for (final flag in [
      enableHabitsPageFlag,
      enableDashboardsPageFlag,
      enableMatrixFlag,
      enableWhatsNewFlag,
      enableAiSummaryTtsFlag,
    ])
      configFlagProvider(flag).overrideWith((ref) => Stream.value(false)),
  ];

  Future<void> tapText(
    WidgetTester tester,
    String text, {
    int frames = 8,
  }) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target, warnIfMissed: false);
    await settleFrames(tester, frames);
  }

  Future<void> driveToProviders(WidgetTester tester) async {
    await tapText(tester, 'Choose your AI brain');
    await tapText(tester, 'More options');
    expect(find.text('Ollama'), findsOneWidget);
  }

  Future<void> driveToFirstTask(WidgetTester tester) async {
    await driveToProviders(tester);
    await tapText(tester, 'Ollama');

    await tester.pump(const Duration(milliseconds: 1100));
    await settleFrames(tester, 4);
    expect(find.text('Connection verified'), findsOneWidget);

    await tapText(tester, 'Connect');
    await tapText(tester, 'Get started');
    expect(find.text('How should recording feel?'), findsOneWidget);
    await tapText(tester, 'Continue');

    expect(find.text('Where should your AI work?'), findsOneWidget);
    await tapText(tester, 'Add your own', frames: 4);
    await tester.enterText(find.byType(TextField).last, 'Penguin Operations');
    await tapText(tester, 'OK');
    expect(find.text('Penguin Operations'), findsOneWidget);

    await tapText(tester, 'Add your own', frames: 4);
    await tester.enterText(find.byType(TextField).last, 'Mission Control');
    await tapText(tester, 'OK');
    expect(find.text('Mission Control'), findsOneWidget);
    await tapText(tester, 'Continue', frames: 12);

    expect(find.text('Create your first task'), findsOneWidget);
    expect(find.text('Penguin Operations'), findsOneWidget);
    expect(find.text('Mission Control'), findsOneWidget);
  }

  Future<void> driveToCreatedTask(WidgetTester tester) async {
    await driveToFirstTask(tester);
    await tapText(tester, 'Rather type?', frames: 4);
    await tester.enterText(find.byType(TextField).last, _typedMission);
    await tapText(tester, 'OK', frames: 10);
    await settleFrames(tester, 6);
    expect(find.text('Your first task is ready'), findsOneWidget);
    expect(find.text(_createdTaskTitle), findsOneWidget);
  }

  Future<void> pumpCase(
    WidgetTester tester, {
    required _OnboardingCase scenario,
    required ScreenshotDevice device,
    required Brightness brightness,
  }) async {
    applyScreenshotDevice(tester, device);
    navService.isDesktopMode = !device.isPhone;
    navService.desktopSelectedSettingsRoute.value =
        scenario == _OnboardingCase.settings && !device.isPhone
        ? (
            path: '/settings/onboarding',
            pathParameters: const <String, String>{},
            queryParameters: const <String, String>{},
          )
        : null;

    final home = scenario == _OnboardingCase.settings
        ? (device.isPhone
              ? const OnboardingSettingsPage()
              : const SettingsRootPage())
        : const _OnboardingLaunchHost();

    await tester.pumpWidget(
      _app(
        home: home,
        brightness: brightness,
        size: device.size,
        overrides: overrides(),
      ),
    );
    await settleFrames(tester, 18);

    switch (scenario) {
      case _OnboardingCase.settings:
        expect(find.text("You've created your first AI task"), findsOneWidget);
      case _OnboardingCase.welcome:
        expect(
          find.text('Talk. Lotti turns it into a plan.'),
          findsOneWidget,
        );
      case _OnboardingCase.providers:
        await driveToProviders(tester);
      case _OnboardingCase.firstTask:
        await driveToFirstTask(tester);
      case _OnboardingCase.taskCreated:
        await driveToCreatedTask(tester);
    }
  }

  for (final (viewport, device) in [
    ('mobile', miniDevice),
    ('desktop', desktopDevice),
  ]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;
      for (final scenario in _OnboardingCase.values) {
        testWidgets(
          '${scenario.name} $viewport manual — $theme',
          (tester) async {
            await pumpCase(
              tester,
              scenario: scenario,
              device: device,
              brightness: brightness,
            );

            expect(tester.takeException(), isNull);
            await captureScreenshot(
              tester,
              'onboarding_${scenario.fileName}_${viewport}_$theme',
              subdir: 'onboarding',
            );
          },
        );
      }
    }
  }
}
