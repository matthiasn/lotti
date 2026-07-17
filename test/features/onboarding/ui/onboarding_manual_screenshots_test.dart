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
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
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
import '../../../helpers/target_platform.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';

String _t(String en, String de) => manualScreenshotText(en: en, de: de);

final String _typedMission = _t(
  'Inspect the Europa sardine relay before the emperor penguin roll call',
  'Europa-Sardinenrelais vor dem Zählappell der Kaiserpinguine inspizieren',
);
final String _createdTaskTitle = _t(
  'Inspect the Europa sardine relay',
  'Europa-Sardinenrelais inspizieren',
);

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
  late FakeCaptureController captureController;
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
        id: name == _t('Penguin Operations', 'Pinguinbetrieb')
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
        checklistItems: [
          _t('Verify relay pressure', 'Relaisdruck prüfen'),
          _t('Count all emperor penguins', 'Alle Kaiserpinguine zählen'),
          _t('Route the sardine cargo pods', 'Sardinen-Frachtkapseln routen'),
        ],
        isRealAha: true,
      ),
    );

    captureController = FakeCaptureController();
    captureController.onToggle = () {
      captureController.emit(
        const CaptureState(
          phase: CapturePhase.listening,
          transcript: '',
          amplitudes: [
            0.08,
            0.16,
            0.29,
            0.52,
            0.74,
            0.61,
            0.38,
            0.22,
            0.43,
            0.69,
            0.84,
            0.57,
            0.31,
            0.18,
            0.36,
            0.63,
            0.77,
            0.48,
          ],
          dbfs: -8,
        ),
      );
    };

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
    captureControllerProvider.overrideWith(() => captureController),
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
    await tapText(tester, _t('Choose your AI brain', 'KI-Gehirn wählen'));
    await tapText(tester, _t('More options', 'Mehr Optionen'));
    expect(find.text('Ollama'), findsOneWidget);
  }

  Future<void> driveToFirstTaskPrompt(WidgetTester tester) async {
    await driveToProviders(tester);
    await tapText(tester, 'Ollama');

    await tester.pump(const Duration(milliseconds: 1100));
    await settleFrames(tester, 4);
    expect(
      find.text(_t('Connection verified', 'Verbindung bestätigt')),
      findsOneWidget,
    );

    await tapText(tester, _t('Connect', 'Verbinden'));
    await tapText(tester, _t('Get started', "Los geht's"));
    expect(
      find.text(
        _t('How should recording feel?', 'Wie soll die Aufnahme wirken?'),
      ),
      findsOneWidget,
    );
    await tapText(tester, _t('Continue', 'Weiter'));

    expect(
      find.text(
        _t('Where should your AI work?', 'Wo soll deine KI arbeiten?'),
      ),
      findsOneWidget,
    );
    await tapText(tester, _t('Add your own', 'Eigene hinzufügen'), frames: 4);
    await tester.enterText(
      find.byType(TextField).last,
      _t('Penguin Operations', 'Pinguinbetrieb'),
    );
    await tapText(tester, 'OK');
    expect(
      find.text(_t('Penguin Operations', 'Pinguinbetrieb')),
      findsOneWidget,
    );

    await tapText(tester, _t('Add your own', 'Eigene hinzufügen'), frames: 4);
    await tester.enterText(
      find.byType(TextField).last,
      _t('Mission Control', 'Missionskontrolle'),
    );
    await tapText(tester, 'OK');
    expect(
      find.text(_t('Mission Control', 'Missionskontrolle')),
      findsOneWidget,
    );
    await tapText(tester, _t('Continue', 'Weiter'), frames: 12);

    expect(
      find.text(_t('Create your first task', 'Erstelle deine erste Aufgabe')),
      findsOneWidget,
    );
    expect(
      find.text(_t('Penguin Operations', 'Pinguinbetrieb')),
      findsOneWidget,
    );
    expect(
      find.text(_t('Mission Control', 'Missionskontrolle')),
      findsOneWidget,
    );
  }

  Future<void> driveToFirstTaskListening(WidgetTester tester) async {
    await driveToFirstTaskPrompt(tester);
    await tester.tap(
      find.bySemanticsLabel(
        _t('Record your thought', 'Deinen Gedanken aufnehmen'),
      ),
    );
    await settleFrames(tester, 6);
    expect(
      find.text(
        _t(
          "Listening… tap when you're done",
          'Ich höre zu … tippe, wenn du fertig bist',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(AiVoiceInputShader), findsOneWidget);
  }

  Future<void> driveToCreatedTask(WidgetTester tester) async {
    await driveToFirstTaskPrompt(tester);
    await tapText(tester, _t('Rather type?', 'Lieber tippen?'), frames: 4);
    await tester.enterText(find.byType(TextField).last, _typedMission);
    await tapText(tester, 'OK', frames: 10);
    await settleFrames(tester, 6);
    expect(
      find.text(
        _t('Your first task is ready', 'Deine erste Aufgabe ist fertig'),
      ),
      findsOneWidget,
    );
    expect(find.text(_createdTaskTitle), findsOneWidget);
  }

  Future<void> pumpCase(
    WidgetTester tester, {
    required _OnboardingCase scenario,
    required ScreenshotDevice device,
    required Brightness brightness,
  }) => withTargetPlatform(
    device.isPhone ? TargetPlatform.android : TargetPlatform.linux,
    () async {
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
          expect(
            find.text(
              _t(
                "You've created your first AI task",
                'Du hast deine erste KI-Aufgabe erstellt',
              ),
            ),
            findsOneWidget,
          );
        case _OnboardingCase.welcome:
          expect(
            find.text(
              _t(
                'Talk. Lotti turns it into a plan.',
                'Sprich. Lotti macht einen Plan daraus.',
              ),
            ),
            findsOneWidget,
          );
        case _OnboardingCase.providers:
          await driveToProviders(tester);
        case _OnboardingCase.firstTask:
          await driveToFirstTaskListening(tester);
        case _OnboardingCase.taskCreated:
          await driveToCreatedTask(tester);
      }
    },
  );

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
