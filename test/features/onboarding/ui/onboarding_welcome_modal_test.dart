import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/onboarding_event.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/services/onboarding_capture_to_task_service.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_companion.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_words.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/repositories/onboarding_metrics_repository.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';

/// Canned probe so the API-key step's live verification resolves without a
/// network call.
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

void main() {
  late OnboardingMetricsDb db;
  late OnboardingMetricsRepository repo;
  var idSeq = 0;

  // Reduced motion so the looping constellation controller stops and
  // pumpAndSettle can complete.
  const mq = MediaQueryData(size: Size(390, 844), disableAnimations: true);

  setUpAll(registerAllFallbackValues);

  setUp(() {
    idSeq = 0;
    db = OnboardingMetricsDb(inMemoryDatabase: true);
    repo = OnboardingMetricsRepository(
      db: db,
      clock: () => DateTime.utc(2026, 7, 1, 9),
      idGenerator: () => 'id-${idSeq++}',
      currentPlatform: () => 'testos',
    );
    // The category step logs a write failure via getIt<LoggingService> before
    // toasting; production registers it at startup, so mirror that here.
    if (!getIt.isRegistered<LoggingService>()) {
      getIt.registerSingleton<LoggingService>(LoggingService());
    }
  });

  tearDown(() async {
    await db.close();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  Widget host({
    VoidCallback? onDismiss,
    VoidCallback? onCompleted,
    DemoModeGateway? demoGateway,
  }) {
    return Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => OnboardingWelcomeModal.show(
          context,
          metrics: repo,
          onDismiss: onDismiss ?? () {},
          onCompleted: onCompleted,
          demoGateway: demoGateway,
        ),
        child: const Text('open'),
      ),
    );
  }

  test('onboardingSeededProfileId maps surfaced providers to profiles', () {
    expect(
      onboardingSeededProfileId(InferenceProviderType.melious),
      profileMeliousId,
    );
    expect(
      onboardingSeededProfileId(InferenceProviderType.mistral),
      profileMistralEuId,
    );
    expect(
      onboardingSeededProfileId(InferenceProviderType.gemini),
      profileGeminiFlashId,
    );
    expect(
      onboardingSeededProfileId(InferenceProviderType.alibaba),
      profileAlibabaId,
    );
    expect(onboardingSeededProfileId(InferenceProviderType.whisper), isNull);
  });

  Future<void> openWelcome(
    WidgetTester tester, {
    Widget? child,
    ThemeData? theme,
  }) async {
    // The fixed-height modal panel (~680) is taller than the default 800x600
    // render surface; size the surface to the 844-tall MediaQuery so the lower
    // controls are on-screen and hit-testable.
    tester.view
      ..physicalSize = const Size(390, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final launchHost = child ?? host();
    await tester.pumpWidget(
      theme == null
          ? makeTestableWidget(launchHost, mediaQueryData: mq)
          : makeTestableWidgetNoScroll(
              launchHost,
              mediaQueryData: mq,
              theme: theme,
            ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// From the welcome to the one-key step, past the two optional steps:
  /// "make me yours", skipped, and the voices, left unplayed.
  Future<void> toConnect(WidgetTester tester) async {
    await tester.tap(find.text('Get started with one key'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Skip for now'));
    await tapVisible(tester, find.text('Next: your key'));
  }

  testWidgets('shows the welcome promise and records welcomeShown', (
    tester,
  ) async {
    await openWelcome(tester);

    expect(find.text("Hi, I'm Lotti."), findsOneWidget);
    expect(find.text('Get started with one key'), findsOneWidget);
    // She leads onboarding whatever her flag says elsewhere.
    expect(
      tester.widget<OnboardingCompanion>(find.byType(OnboardingCompanion)).beat,
      OnboardingCompanionBeat.welcome,
    );

    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.welcomeShown), isTrue);
  });

  for (final theme in [
    (
      name: 'light',
      data: DesignSystemTheme.light(),
      tokens: dsTokensLight,
    ),
    (
      name: 'dark',
      data: DesignSystemTheme.dark(),
      tokens: dsTokensDark,
    ),
  ]) {
    testWidgets('welcome and provider steps follow the ${theme.name} theme', (
      tester,
    ) async {
      await openWelcome(tester, theme: theme.data);

      final welcomeTitle = tester.widget<Text>(
        find.text("Hi, I'm Lotti."),
      );
      final welcomeSurface = tester.widget<ColoredBox>(
        find.ancestor(
          of: find.text("Hi, I'm Lotti."),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(
        welcomeSurface.color,
        theme.tokens.colors.background.level01,
      );
      expect(
        welcomeTitle.style?.color,
        theme.tokens.colors.text.highEmphasis,
      );
      // She stands in the hero frame in place of the artwork, in either theme.
      expect(find.byType(OnboardingCompanion), findsOneWidget);
      expect(find.byType(OnboardingThinkingBarsHero), findsNothing);

      await toConnect(tester);

      final providerTitle = tester.widget<Text>(
        find.text('One key is all it takes'),
      );
      final providerBackdrop = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(OnboardingBackdrop),
          matching: find.byType(ColoredBox),
        ),
      );

      expect(
        providerTitle.style?.color,
        theme.tokens.colors.text.highEmphasis,
      );
      expect(
        providerBackdrop.color,
        theme.tokens.colors.background.level01,
      );
    });
  }

  testWidgets('advancing to connect reveals the primary providers and records '
      'providerModalShown', (tester) async {
    await openWelcome(tester);
    await toConnect(tester);

    // One recommended card; the rest wait behind the disclosure.
    expect(find.text('Mistral'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Gemini'), findsNothing);
    expect(find.text('Other providers'), findsOneWidget);

    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.providerModalShown), isTrue);
  });

  testWidgets(
    'swapping steps crossfades rather than snapping instantly',
    (tester) async {
      await openWelcome(tester);

      await tester.tap(find.text('Get started with one key'));
      await tester.pump(); // start the crossfade (t=0)
      await tester.pump(const Duration(milliseconds: 200)); // mid-fade

      // Mid-transition at least one child sits at a partial opacity — proof
      // the AnimatedSwitcher is actually easing between steps rather than
      // hard-cutting from one to the next.
      final opacities = tester
          .widgetList<FadeTransition>(find.byType(FadeTransition))
          .map((f) => f.opacity.value)
          .toList();
      expect(
        opacities.any((o) => o > 0.0 && o < 1.0),
        isTrue,
        reason: 'expected an in-progress crossfade, got $opacities',
      );

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'the outgoing step freezes its animations during the crossfade (so two '
    'animated backdrops never paint at once) and unfreezes once settled',
    (tester) async {
      await openWelcome(tester);

      await tester.tap(find.text('Get started with one key'));
      await tester.pump(); // start the crossfade
      await tester.pump(const Duration(milliseconds: 200)); // mid-fade

      // The outgoing welcome step is still mounted (fading out) and wrapped in
      // a disabled TickerMode, halting its looping constellation controller so
      // it stops repainting while the incoming connect backdrop animates in.
      final outgoingWelcome = find.text("Hi, I'm Lotti.");
      expect(outgoingWelcome, findsOneWidget);
      expect(
        find.ancestor(
          of: outgoingWelcome,
          matching: find.byWidgetPredicate(
            (w) => w is TickerMode && !w.enabled,
          ),
        ),
        findsOneWidget,
      );

      // The incoming step is NOT frozen — its animations run.
      final incomingConnect = find.text('Make me yours');
      expect(incomingConnect, findsOneWidget);
      expect(
        find.ancestor(
          of: incomingConnect,
          matching: find.byWidgetPredicate(
            (w) => w is TickerMode && !w.enabled,
          ),
        ),
        findsNothing,
      );

      // Once the transition settles the outgoing step (and its disabled
      // TickerMode) are gone, so nothing is left frozen.
      await tester.pumpAndSettle();
      expect(outgoingWelcome, findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is TickerMode && !w.enabled),
        findsNothing,
      );
    },
  );

  testWidgets('back from connect returns to the voices, then "make me '
      'yours", then the welcome', (tester) async {
    await openWelcome(tester);
    await toConnect(tester);
    expect(find.text('Mistral'), findsOneWidget);

    await tester.tap(find.byIcon(LottiIcons.back));
    await tester.pumpAndSettle();
    expect(find.text('Hear how I can sound'), findsOneWidget);

    await tester.ensureVisible(find.byIcon(LottiIcons.back));
    await tester.tap(find.byIcon(LottiIcons.back));
    await tester.pumpAndSettle();
    expect(find.text('Make me yours'), findsOneWidget);

    await tester.ensureVisible(find.byIcon(LottiIcons.back));
    await tester.tap(find.byIcon(LottiIcons.back));
    await tester.pumpAndSettle();
    expect(find.text("Hi, I'm Lotti."), findsOneWidget);
  });

  testWidgets('the welcome leads to "make me yours" and records it shown; '
      'skipping it records the skip and reaches the voices', (tester) async {
    await openWelcome(tester);
    await tester.tap(find.text('Get started with one key'));
    await tester.pumpAndSettle();

    expect(find.text('Make me yours'), findsOneWidget);
    var state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.companionCustomizeShown), isTrue);
    expect(state.reached(OnboardingEventName.providerModalShown), isFalse);

    await tester.ensureVisible(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('Hear how I can sound'), findsOneWidget);
    state = await repo.funnelState();
    expect(
      state.reached(OnboardingEventName.companionCustomizeSkipped),
      isTrue,
    );
    expect(state.reached(OnboardingEventName.voiceSamplesShown), isTrue);
    expect(state.reached(OnboardingEventName.providerModalShown), isFalse);

    // The voices lead on to the one key.
    await tapVisible(tester, find.text('Next: your key'));
    expect(find.text('One key is all it takes'), findsOneWidget);
    state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.providerModalShown), isTrue);
  });

  testWidgets('a pick on "make me yours" records the customisation', (
    tester,
  ) async {
    await openWelcome(tester);
    await tester.tap(find.text('Get started with one key'));
    await tester.pumpAndSettle();
    expect(
      (await repo.funnelState()).reached(
        OnboardingEventName.companionCustomized,
      ),
      isFalse,
    );

    await tester.ensureVisible(find.text('Bob'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(
      (await repo.funnelState()).reached(
        OnboardingEventName.companionCustomized,
      ),
      isTrue,
    );
  });

  testWidgets('"Looks good" reaches the voices without recording a skip', (
    tester,
  ) async {
    await openWelcome(tester);
    await tester.tap(find.text('Get started with one key'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Looks good'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks good'));
    await tester.pumpAndSettle();

    expect(find.text('Hear how I can sound'), findsOneWidget);
    final state = await repo.funnelState();
    expect(
      state.reached(OnboardingEventName.companionCustomizeSkipped),
      isFalse,
    );
    expect(state.reached(OnboardingEventName.voiceSamplesShown), isTrue);
  });

  testWidgets('playing a voice records which one', (tester) async {
    await openWelcome(tester);
    await tester.tap(find.text('Get started with one key'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Skip for now'));

    await tester.tap(find.byKey(const ValueKey('onboarding-voice-voxtral')));
    await tester.pump();

    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.voiceSamplePlayed), isTrue);
    final events = await db.allOnboardingEvents().get();
    expect(
      events
          .where(
            (e) => e.eventName == OnboardingEventName.voiceSamplePlayed.name,
          )
          .map((e) => e.provider),
      ['voxtral'],
    );
    await tester.pumpAndSettle();
  });

  testWidgets('Other providers reveals OpenAI and Ollama', (tester) async {
    await openWelcome(tester);
    await toConnect(tester);

    expect(find.text('OpenAI'), findsNothing);
    await tester.tap(find.text('Other providers'));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Ollama'), findsOneWidget);
  });

  testWidgets('selecting a provider opens the API-key step', (tester) async {
    await openWelcome(tester);
    await toConnect(tester);
    await tester.tap(find.text('Mistral'));
    await tester.pumpAndSettle();

    expect(find.text('Paste your API key'), findsOneWidget);
  });

  testWidgets('back from the API-key step returns to the providers', (
    tester,
  ) async {
    await openWelcome(tester);
    await toConnect(tester);
    await tester.tap(find.text('Mistral'));
    await tester.pumpAndSettle();
    expect(find.text('Paste your API key'), findsOneWidget);

    // The key step's back arrow returns to the provider list.
    await tester.tap(find.byIcon(LottiIcons.back));
    await tester.pumpAndSettle();

    expect(find.text('Paste your API key'), findsNothing);
    expect(find.text('Recommended'), findsOneWidget);
  });

  testWidgets('skipping invokes onDismiss and records welcomeSkipped', (
    tester,
  ) async {
    var dismissed = false;
    await openWelcome(tester, child: host(onDismiss: () => dismissed = true));
    // Scroll the skip link into the render surface — the display hero title
    // pushes it below the fold in the bare test viewport.
    await tester.ensureVisible(find.text('Look around first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Look around first'));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.welcomeSkipped), isTrue);
  });

  testWidgets('Escape skips like a tap outside the panel, even with a '
      'control inside it focused', (tester) async {
    var dismissed = false;
    await openWelcome(tester, child: host(onDismiss: () => dismissed = true));
    // Tab into the panel, below its own Scaffold.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<Scaffold>(),
      isNotNull,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.welcomeSkipped), isTrue);
  });

  testWidgets('Explore with sample data pops the modal, enters the demo, '
      'and records NEITHER completed nor skipped', (tester) async {
    var dismissed = false;
    var completed = false;
    final gateway = MockDemoModeGateway();
    when(gateway.demoMediaBytesAwaitingChoice).thenAnswer((_) async => 0);
    when(
      () => gateway.enterDemo(
        locale: any(named: 'locale'),
        downloadMedia: any(named: 'downloadMedia'),
      ),
    ).thenAnswer((_) async {});

    await openWelcome(
      tester,
      child: host(
        onDismiss: () => dismissed = true,
        onCompleted: () => completed = true,
        demoGateway: gateway,
      ),
    );
    await tester.ensureVisible(find.text('Explore with sample data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore with sample data'));
    // Bounded pumps: the demo-entry progress route's spinner never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => gateway.enterDemo(
        locale: any(named: 'locale'),
        downloadMedia: any(named: 'downloadMedia'),
      ),
    ).called(1);
    expect(dismissed, isFalse, reason: 'demo entry is not a skip');
    expect(completed, isFalse, reason: 'demo entry is not a completion');
    final state = await repo.funnelState();
    expect(
      state.reached(OnboardingEventName.welcomeSkipped),
      isFalse,
      reason: 'the FTUE auto-show budget must survive a demo detour',
    );
  });

  testWidgets('first-launch demo entry asks before downloading its photos, '
      'showing the size (App Store guideline 4.2.3(ii))', (tester) async {
    final gateway = MockDemoModeGateway();
    when(
      gateway.demoMediaBytesAwaitingChoice,
    ).thenAnswer((_) async => 26544434);
    when(
      () => gateway.enterDemo(
        locale: any(named: 'locale'),
        downloadMedia: any(named: 'downloadMedia'),
      ),
    ).thenAnswer((_) async {});

    await openWelcome(
      tester,
      child: host(onDismiss: () {}, demoGateway: gateway),
    );
    await tester.ensureVisible(find.text('Explore with sample data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore with sample data'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Download the demo photos?'), findsOneWidget);
    expect(find.textContaining('a 26.6 MB download'), findsOneWidget);
    verifyNever(
      () => gateway.enterDemo(
        locale: any(named: 'locale'),
        downloadMedia: any(named: 'downloadMedia'),
      ),
    );

    await tester.tap(find.text('Download (26.6 MB)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => gateway.enterDemo(
        locale: any(named: 'locale'),
        downloadMedia: true,
      ),
    ).called(1);
  });

  testWidgets(
    'tapping outside the panel closes the flow (tap-outside-to-dismiss)',
    (tester) async {
      var dismissed = false;
      await openWelcome(tester, child: host(onDismiss: () => dismissed = true));
      expect(find.text('Get started with one key'), findsOneWidget);

      // The sheet shrink-wraps to its content at the bottom, leaving empty
      // space above it. A tap there must close the flow — the route's modal
      // barrier alone never received the tap (the full-screen scroll view sat
      // on top of it), so the scaffold dismisses explicitly.
      final panelTop = tester
          .getTopLeft(find.byKey(const ValueKey('onboarding-welcome')))
          .dy;
      expect(panelTop, greaterThan(30));
      await tester.tapAt(Offset(195, panelTop - 20));
      await tester.pumpAndSettle();

      expect(find.text('Get started with one key'), findsNothing);
      expect(dismissed, isTrue);
      final state = await repo.funnelState();
      expect(state.reached(OnboardingEventName.welcomeSkipped), isTrue);
    },
  );

  /// Drives the full flow welcome → connect → Ollama → verified → Connect →
  /// success → recording style → category → Continue, landing on the in-panel
  /// first-task step. Ollama needs no key and its FTUE setup only touches the
  /// category repository, so it's the cheapest provider to drive. Returns the
  /// mocks the caller asserts against.
  Future<
    ({
      MockAiConfigRepository aiRepo,
      MockCategoryRepository catRepo,
      MockOnboardingCaptureToTaskService captureService,
    })
  >
  driveToFirstTaskStep(
    WidgetTester tester, {
    List<CategoryDefinition> existingCategories = const [],
    bool failCategoryWrites = false,
    VoidCallback? onCompleted,
  }) async {
    final aiRepo = MockAiConfigRepository();
    when(() => aiRepo.saveConfig(any())).thenAnswer((_) async {});
    // The key step un-deletes this provider's bundled profile before the
    // FTUE setup seeds.
    when(() => aiRepo.restoreConfig(any())).thenAnswer((_) async {});
    final catRepo = MockCategoryRepository();
    // The duplicate check consults the unfiltered set (deleted/hidden rows
    // still trip the UNIQUE(name) constraint).
    when(
      catRepo.getAllCategoriesIncludingHidden,
    ).thenAnswer((_) async => existingCategories);
    // Reused categories are resurrected/rebound through updateCategory;
    // echo back the updated definition like the real repository does.
    when(() => catRepo.updateCategory(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.first as CategoryDefinition,
    );
    if (failCategoryWrites) {
      when(
        () => catRepo.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          defaultProfileId: any(named: 'defaultProfileId'),
          defaultTemplateId: any(named: 'defaultTemplateId'),
          automaticInferenceEnabled: any(named: 'automaticInferenceEnabled'),
        ),
      ).thenThrow(Exception('category db down'));
    } else {
      when(
        () => catRepo.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          defaultProfileId: any(named: 'defaultProfileId'),
          defaultTemplateId: any(named: 'defaultTemplateId'),
          automaticInferenceEnabled: any(named: 'automaticInferenceEnabled'),
        ),
      ).thenAnswer(
        (_) async => CategoryTestUtils.createTestCategory(id: 'c1', name: 'AI'),
      );
    }
    final captureService = MockOnboardingCaptureToTaskService();

    // Match the render surface to the 844-tall MediaQuery so the lower tiles /
    // Connect button are on-screen and hit-testable.
    tester.view
      ..physicalSize = const Size(390, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      makeTestableWidget(
        host(onCompleted: onCompleted),
        mediaQueryData: mq,
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(aiRepo),
          categoryRepositoryProvider.overrideWithValue(catRepo),
          // The category step now advances to the in-panel first-task step;
          // override its providers so the step renders without the real mic
          // pipeline or a live structuring round-trip.
          captureControllerProvider.overrideWith(FakeCaptureController.new),
          onboardingCaptureToTaskServiceProvider.overrideWithValue(
            captureService,
          ),
          connectionVerifierClientProvider.overrideWith(
            (ref) =>
                () => MockClient((_) async => http.Response('', 200)),
          ),
          connectionProbeRegistryProvider.overrideWith(
            (ref) => {
              InferenceProviderType.ollama: _FakeProbe(
                const ConnectionCheckVerified(
                  modelCount: 2,
                  latency: Duration(milliseconds: 5),
                ),
              ),
            },
          ),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await toConnect(tester);
    await tester.tap(find.text('Other providers'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ollama'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ollama'));
    await tester.pumpAndSettle();

    // Ollama probes reachability on open; let the ≥1s checking dwell elapse.
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text('Connection verified'), findsOneWidget);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    // Connect now reveals the success beat instead of dropping silently.
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Success leads straight into the category step — the recording style is
    // no longer asked here; it stays a Settings preference. The "why areas?"
    // disclosure opens the per-category-AI explanation, then dismisses.
    expect(find.text('Where should your AI work?'), findsOneWidget);
    await tester.tap(find.text('Why areas?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('own AI'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // "Add your own" opens a dialog. Cancelling adds nothing…
    await tester.tap(find.text('Add your own'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Hobbies'), findsNothing);

    // …while a typed name becomes a selected custom area.
    await tester.tap(find.text('Add your own'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hobbies');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Hobbies'), findsOneWidget);

    // Pick a preset area too, then continue with both selected. The flow
    // advances in place — the first-task finale stays inside the panel. Its
    // recording visual's tickers never settle, so step the crossfade with
    // bounded pumps rather than pumpAndSettle.
    await tester.tap(find.text('Work'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    return (aiRepo: aiRepo, catRepo: catRepo, captureService: captureService);
  }

  testWidgets('she reacts to the key check, speaks her first words for the '
      "connected provider's profile, and introduces the areas", (
    tester,
  ) async {
    final aiRepo = MockAiConfigRepository();
    when(() => aiRepo.saveConfig(any())).thenAnswer((_) async {});
    when(() => aiRepo.restoreConfig(any())).thenAnswer((_) async {});
    final catRepo = MockCategoryRepository();
    when(catRepo.getAllCategories).thenAnswer((_) async => []);
    tester.view
      ..physicalSize = const Size(390, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      makeTestableWidget(
        host(),
        mediaQueryData: mq,
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(aiRepo),
          categoryRepositoryProvider.overrideWithValue(catRepo),
          connectionVerifierClientProvider.overrideWith(
            (ref) =>
                () => MockClient((_) async => http.Response('', 200)),
          ),
          connectionProbeRegistryProvider.overrideWith(
            (ref) => {
              InferenceProviderType.ollama: _FakeProbe(
                const ConnectionCheckVerified(
                  modelCount: 2,
                  latency: Duration(milliseconds: 5),
                ),
              ),
            },
          ),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await toConnect(tester);
    await tapVisible(tester, find.text('Other providers'));
    await tapVisible(tester, find.text('Ollama'));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    OnboardingCompanion her() =>
        tester.widget<OnboardingCompanion>(find.byType(OnboardingCompanion));
    expect(her().beat, OnboardingCompanionBeat.keyVerified);
    expect(her().framing, CompanionFraming.bust);

    await tapVisible(tester, find.text('Connect'));
    final words = tester.widget<OnboardingFirstWords>(
      find.byType(OnboardingFirstWords),
    );
    expect(words.profileId, profileLocalId);

    await tapVisible(tester, find.text('Get started'));
    expect(her().beat, OnboardingCompanionBeat.areas);
    expect(
      her().line,
      tester
          .widget<OnboardingSpeechBubble>(find.byType(OnboardingSpeechBubble))
          .text,
    );
  });

  testWidgets('the category step advances to the in-panel first-task step and '
      'a landed task pops the modal onto the task page', (tester) async {
    final beamed = <String>[];
    beamToNamedOverride = beamed.add;
    addTearDown(() => beamToNamedOverride = null);

    var completedCount = 0;
    final mocks = await driveToFirstTaskStep(
      tester,
      onCompleted: () => completedCount++,
    );

    // The finale renders inside the panel: guided suggestions over the same
    // modal surface, no full-screen takeover. Provider creation + FTUE setup
    // ran; both chosen areas became categories bound to the provider's seeded
    // inference profile.
    expect(find.text('Create your first task'), findsOneWidget);
    expect(find.text('Plan my week'), findsOneWidget);
    verify(() => mocks.aiRepo.saveConfig(any())).called(1);
    verify(
      () => mocks.catRepo.createCategory(
        name: 'Work',
        color: any(named: 'color'),
        defaultProfileId: profileLocalId,
        defaultTemplateId: lauraTemplateId,
        // Onboarding is the one caller that opts new areas into automation.
        automaticInferenceEnabled: true,
      ),
    ).called(1);
    verify(
      () => mocks.catRepo.createCategory(
        name: 'Hobbies',
        color: any(named: 'color'),
        defaultProfileId: profileLocalId,
        defaultTemplateId: lauraTemplateId,
        automaticInferenceEnabled: true,
      ),
    ).called(1);

    // A tapped starter suggestion rides the typed path through structuring;
    // the landed task is revealed inside the panel as a tappable card.
    when(
      () => mocks.captureService.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
        audioId: any(named: 'audioId'),
      ),
    ).thenAnswer(
      (_) async => OnboardingCaptureResult(
        task: MockTask(id: 'task-1'),
        title: 'Plan the week',
      ),
    );
    await tester.tap(find.text('Plan my week'), warnIfMissed: false);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The created beat stays inside the dialogue: the card shows the task and
    // the modal is still up until the user taps it.
    expect(find.text('Your first task is ready'), findsOneWidget);
    expect(find.text('Plan the week'), findsOneWidget);
    // The checklist is deliberately NOT previewed on the created card — it
    // lands on the task page as confirmable proposals instead.
    expect(find.text('Monday'), findsNothing);
    expect(beamed, isEmpty);

    // Tapping the hint line (part of the card's tap target) pops the modal
    // and deep-links to the real task page.
    await tester.tap(
      find.text('Tap your task to open it'),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Create your first task'), findsNothing);
    expect(beamed, ['/tasks/task-1']);
    verify(
      () => mocks.captureService.createTaskFromTranscript(
        transcript: 'Plan my week',
        categoryId: 'c1',
        providerName: 'Ollama',
        // ignore: avoid_redundant_argument_values
        audioId: null,
      ),
    ).called(1);
    // Connecting a provider drove the flow to completion: onCompleted fires
    // exactly once when the modal pops, so the caller can retire the welcome.
    expect(completedCount, 1);
    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.providerConnected), isTrue);
  });

  testWidgets('a total structuring failure finishes onboarding without '
      'navigating anywhere', (tester) async {
    final beamed = <String>[];
    beamToNamedOverride = beamed.add;
    addTearDown(() => beamToNamedOverride = null);

    final mocks = await driveToFirstTaskStep(tester);
    expect(find.text('Create your first task'), findsOneWidget);

    // The orchestrator couldn't land even a floor task — the step finishes
    // onboarding (the modal pops); connected is still recorded, but there is
    // no task page to open.
    when(
      () => mocks.captureService.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
        audioId: any(named: 'audioId'),
      ),
    ).thenAnswer(
      (_) async => const OnboardingCaptureResult(
        task: null,
        title: '',
      ),
    );
    await tester.tap(find.text('Plan my week'), warnIfMissed: false);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Create your first task'), findsNothing);
    expect(beamed, isEmpty);
    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.providerConnected), isTrue);
  });

  testWidgets('the category step reuses an existing category with the same '
      'name (case-insensitively) instead of tripping the unique constraint', (
    tester,
  ) async {
    // The user once had a "work" category, since archived and soft-deleted,
    // still bound to a stale profile. Its row keeps the UNIQUE name, so a
    // blind create would throw and Continue used to die silently. The reuse
    // must resurrect it (undelete + reactivate) and rebind the just-seeded
    // profile so first-task structuring can actually run.
    final mocks = await driveToFirstTaskStep(
      tester,
      existingCategories: [
        CategoryTestUtils.createTestCategory(
          id: 'existing-work',
          name: 'work',
          active: false,
          deletedAt: DateTime(2025),
          defaultProfileId: 'stale-profile',
        ),
      ],
    );

    // The flow still advanced into the first-task step…
    expect(find.text('Create your first task'), findsOneWidget);
    // …"Work" was reused, only the custom "Hobbies" area was created…
    verifyNever(
      () => mocks.catRepo.createCategory(
        name: 'Work',
        color: any(named: 'color'),
        defaultProfileId: any(named: 'defaultProfileId'),
        defaultTemplateId: any(named: 'defaultTemplateId'),
        automaticInferenceEnabled: any(named: 'automaticInferenceEnabled'),
      ),
    );
    verify(
      () => mocks.catRepo.createCategory(
        name: 'Hobbies',
        color: any(named: 'color'),
        defaultProfileId: profileLocalId,
        defaultTemplateId: lauraTemplateId,
        automaticInferenceEnabled: true,
      ),
    ).called(1);

    // …resurrected, reactivated, rebound to the seeded profile, and given
    // Laura as the default task-agent template (it had none of its own).
    final updated =
        verify(
              () => mocks.catRepo.updateCategory(captureAny()),
            ).captured.single
            as CategoryDefinition;
    expect(updated.id, 'existing-work');
    expect(updated.deletedAt, isNull);
    expect(updated.active, isTrue);
    expect(updated.defaultProfileId, profileLocalId);
    expect(updated.defaultTemplateId, lauraTemplateId);
    // A category that never decided gets automation on, like a fresh one.
    expect(updated.automaticInferenceEnabled, isTrue);

    // …and the reused category is the pre-selected destination, so the
    // structured task lands in the user's real existing area.
    when(
      () => mocks.captureService.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
        audioId: any(named: 'audioId'),
      ),
    ).thenAnswer(
      (_) async => OnboardingCaptureResult(
        task: MockTask(id: 'task-2'),
        title: 'Planned',
      ),
    );
    await tester.tap(find.text('Plan my week'), warnIfMissed: false);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => mocks.captureService.createTaskFromTranscript(
        transcript: 'Plan my week',
        categoryId: 'existing-work',
        providerName: 'Ollama',
        // ignore: avoid_redundant_argument_values
        audioId: null,
      ),
    ).called(1);
  });

  // Automation is opt-in per category, and onboarding turns it on for the
  // areas it creates. Reuse is the one case where the user may already have
  // answered — and an explicit "off" must survive, or onboarding becomes a
  // back door around the switch.
  testWidgets('reusing a category respects an explicit automation opt-out', (
    tester,
  ) async {
    final mocks = await driveToFirstTaskStep(
      tester,
      existingCategories: [
        CategoryTestUtils.createTestCategory(
          id: 'existing-work',
          name: 'work',
          automaticInferenceEnabled: false,
        ),
      ],
    );

    final updated =
        verify(
              () => mocks.catRepo.updateCategory(captureAny()),
            ).captured.single
            as CategoryDefinition;
    expect(updated.id, 'existing-work');
    // Rebound to the seeded profile like any reused area…
    expect(updated.defaultProfileId, profileLocalId);
    // …but the user's "no" is left standing.
    expect(updated.automaticInferenceEnabled, isFalse);
  });

  testWidgets('reusing a category preserves a user-chosen default agent '
      'template instead of overwriting it with Laura', (tester) async {
    final mocks = await driveToFirstTaskStep(
      tester,
      existingCategories: [
        CategoryTestUtils.createTestCategory(
          id: 'existing-work',
          name: 'work',
          defaultTemplateId: 'template-tom-001',
        ),
      ],
    );

    final updated =
        verify(
              () => mocks.catRepo.updateCategory(captureAny()),
            ).captured.single
            as CategoryDefinition;
    expect(updated.id, 'existing-work');
    // The profile is rebound (structuring must run), but the user's own
    // template choice survives the reuse.
    expect(updated.defaultProfileId, profileLocalId);
    expect(updated.defaultTemplateId, 'template-tom-001');
  });

  testWidgets('a category write failure surfaces an error toast and keeps '
      'the category step usable', (tester) async {
    await driveToFirstTaskStep(tester, failCategoryWrites: true);

    // Continue failed: the flow did NOT advance to the first-task step, the
    // category step is still up for a retry, and the failure surfaced as an
    // error toast instead of dying silently under the button.
    expect(find.text('Create your first task'), findsNothing);
    expect(find.text('Where should your AI work?'), findsOneWidget);
    expect(find.byType(DesignSystemToast), findsOneWidget);
    expect(
      tester.widget<DesignSystemToast>(find.byType(DesignSystemToast)).tone,
      DesignSystemToastTone.error,
    );

    // Let the toast's display timer expire so the test tears down cleanly.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('falls back to the getIt-registered metrics repo', (
    tester,
  ) async {
    // No `metrics:` argument → show() resolves the repo from getIt.
    getIt.registerSingleton<OnboardingMetricsRepository>(repo);
    addTearDown(() => getIt.unregister<OnboardingMetricsRepository>());

    await tester.pumpWidget(
      makeTestableWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                OnboardingWelcomeModal.show(context, onDismiss: () {}),
            child: const Text('open'),
          ),
        ),
        mediaQueryData: mq,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text("Hi, I'm Lotti."), findsOneWidget);
    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.welcomeShown), isTrue);
  });

  testWidgets('renders the desktop (centred) layout on a wide viewport', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1000, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      makeTestableWidget(
        host(),
        mediaQueryData: const MediaQueryData(
          size: Size(1000, 800),
          disableAnimations: true,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The wide branch of the scaffold renders the centred panel.
    expect(find.text("Hi, I'm Lotti."), findsOneWidget);

    // Tapping a non-interactive area of the panel is swallowed (the panel's
    // opaque no-op tap), so the flow stays open — not dismissed.
    await tester.tap(find.text("Hi, I'm Lotti."));
    await tester.pumpAndSettle();
    expect(find.text("Hi, I'm Lotti."), findsOneWidget);
  });

  test(
    'openOnboardingCreatedTask deep-links through the canonical task route',
    () {
      // The deep link (rather than a bare detail-stack push) also switches to
      // the Tasks destination, so the task is visible even when onboarding was
      // launched from another tab (e.g. Settings → Maintenance).
      final beamed = <String>[];
      beamToNamedOverride = beamed.add;
      addTearDown(() => beamToNamedOverride = null);

      openOnboardingCreatedTask('task-9');

      expect(beamed, ['/tasks/task-9']);
    },
  );

  testWidgets('she is the welcome hero with her greeting as her line, '
      'recommends the one key on connect, and greets only once', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      makeTestableWidget(
        host(),
        mediaQueryData: mq,
        overrides: [
          // Her own flag off: onboarding has her regardless.
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(false),
          ),
          ttsPlaybackControllerProvider.overrideWith(
            () => TtsPlaybackController(logger: MockDomainLogger()),
          ),
          spokenTrackLoaderProvider.overrideWithValue(
            (clip, text) => Completer<MouthTrack>().future,
          ),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    // Her ticker never settles: pump frames rather than settle.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    OnboardingCompanion her() =>
        tester.widget<OnboardingCompanion>(find.byType(OnboardingCompanion));
    expect(her().beat, OnboardingCompanionBeat.welcome);
    expect(
      her().line,
      "Hi, I'm Lotti. Tell me what's on your mind and I'll turn it into a "
      'plan. All I need to get going is one API key, and '
      "I'll help you set it up.",
    );

    Future<void> frames() async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await tester.tap(find.text('Get started with one key'));
    await frames();
    // On "make me yours" she opens her arms to be dressed, full length.
    expect(her().beat, OnboardingCompanionBeat.dressUp);
    expect(
      her().line,
      'Pick how I look. You can change all of this any time in '
      'Settings › Companion.',
    );
    expect(her().framing, CompanionFraming.full);

    await tester.ensureVisible(find.text('Skip for now'));
    await frames();
    await tester.tap(find.text('Skip for now'));
    await frames();
    // On the voices she is a bust beside the cards.
    expect(her().beat, OnboardingCompanionBeat.voices);
    expect(
      her().line,
      'I can speak in different voices. Tap one to hear it. You can switch '
      'any time in Settings › Speech.',
    );
    expect(her().framing, CompanionFraming.bust);

    await tester.ensureVisible(find.text('Next: your key'));
    await frames();
    await tester.tap(find.text('Next: your key'));
    await frames();
    // On the one-key step she recommends Mistral, as a bust by her bubble.
    expect(her().beat, OnboardingCompanionBeat.recommend);
    expect(
      her().line,
      "I'd go with Mistral: with its one key I can think, transcribe what you "
      'say and read aloud to you.',
    );
    expect(her().framing, CompanionFraming.bust);

    // Back on the welcome she waves again, but says the promise only once.
    await tester.tap(find.byIcon(LottiIcons.back));
    await frames();
    await tester.ensureVisible(find.byIcon(LottiIcons.back));
    await frames();
    await tester.tap(find.byIcon(LottiIcons.back));
    await frames();
    await tester.ensureVisible(find.byIcon(LottiIcons.back));
    await frames();
    await tester.tap(find.byIcon(LottiIcons.back));
    await frames();
    expect(her().beat, OnboardingCompanionBeat.welcome);
    expect(her().line, isNull);
  });
}
