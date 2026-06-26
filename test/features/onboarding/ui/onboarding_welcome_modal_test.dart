import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_capture_to_task_service.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';

/// Inert [CaptureController] so the live first-capture page (pushed after the
/// category step) renders without touching the real mic / realtime services.
class _FakeCaptureController extends CaptureController {
  @override
  CaptureState build() => const CaptureState.idle();

  @override
  Future<void> toggle() async {}
}

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
  });

  tearDown(() async {
    await db.close();
  });

  Widget host({VoidCallback? onDismiss}) {
    return Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => OnboardingWelcomeModal.show(
          context,
          metrics: repo,
          onDismiss: onDismiss ?? () {},
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

  Future<void> openWelcome(WidgetTester tester, {Widget? child}) async {
    // The fixed-height modal panel (~680) is taller than the default 800x600
    // render surface; size the surface to the 844-tall MediaQuery so the lower
    // controls are on-screen and hit-testable.
    tester.view
      ..physicalSize = const Size(390, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      makeTestableWidget(child ?? host(), mediaQueryData: mq),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the welcome promise and records welcomeShown', (
    tester,
  ) async {
    await openWelcome(tester);

    expect(find.text('Talk. Lotti turns it into a plan.'), findsOneWidget);
    expect(find.text('Choose your AI brain'), findsOneWidget);

    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.welcomeShown), isTrue);
  });

  testWidgets('advancing to connect reveals the primary providers and records '
      'providerModalShown', (tester) async {
    await openWelcome(tester);
    await tester.tap(find.text('Choose your AI brain'));
    await tester.pumpAndSettle();

    expect(find.text('Melious.ai'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
    expect(find.text('Mistral'), findsOneWidget);
    expect(find.text('Qwen'), findsOneWidget);

    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.providerModalShown), isTrue);
  });

  testWidgets('back from connect returns to the welcome', (tester) async {
    await openWelcome(tester);
    await tester.tap(find.text('Choose your AI brain'));
    await tester.pumpAndSettle();
    expect(find.text('Gemini'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Talk. Lotti turns it into a plan.'), findsOneWidget);
  });

  testWidgets('More options reveals OpenAI and Ollama', (tester) async {
    await openWelcome(tester);
    await tester.tap(find.text('Choose your AI brain'));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI'), findsNothing);
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Ollama'), findsOneWidget);
  });

  testWidgets('selecting a provider opens the API-key step', (tester) async {
    await openWelcome(tester);
    await tester.tap(find.text('Choose your AI brain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mistral'));
    await tester.pumpAndSettle();

    expect(find.text('Paste your API key'), findsOneWidget);
  });

  testWidgets('back from the API-key step returns to the providers', (
    tester,
  ) async {
    await openWelcome(tester);
    await tester.tap(find.text('Choose your AI brain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mistral'));
    await tester.pumpAndSettle();
    expect(find.text('Paste your API key'), findsOneWidget);

    // The key step's back arrow returns to the provider list.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Paste your API key'), findsNothing);
    expect(find.text('Gemini'), findsOneWidget);
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

  testWidgets(
    'tapping outside the panel closes the flow (tap-outside-to-dismiss)',
    (tester) async {
      var dismissed = false;
      await openWelcome(tester, child: host(onDismiss: () => dismissed = true));
      expect(find.text('Choose your AI brain'), findsOneWidget);

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

      expect(find.text('Choose your AI brain'), findsNothing);
      expect(dismissed, isTrue);
      final state = await repo.funnelState();
      expect(state.reached(OnboardingEventName.welcomeSkipped), isTrue);
    },
  );

  testWidgets('connecting reveals the success beat, then completing pops and '
      'records providerConnected', (tester) async {
    // Drive the full flow welcome → connect → Ollama → verified → Connect →
    // success → Get started, exercising the modal's onConnected glue
    // (connectedType + the providerConnected event). Ollama needs no key and
    // its FTUE setup only touches the category repository, so it's the cheapest
    // provider to drive.
    final aiRepo = MockAiConfigRepository();
    when(() => aiRepo.saveConfig(any())).thenAnswer((_) async {});
    final catRepo = MockCategoryRepository();
    when(catRepo.getAllCategories).thenAnswer((_) async => []);
    when(
      () => catRepo.createCategory(
        name: any(named: 'name'),
        color: any(named: 'color'),
        defaultProfileId: any(named: 'defaultProfileId'),
        defaultTemplateId: any(named: 'defaultTemplateId'),
      ),
    ).thenAnswer(
      (_) async => CategoryTestUtils.createTestCategory(id: 'c1', name: 'AI'),
    );

    // Match the render surface to the 844-tall MediaQuery so the lower tiles /
    // Connect button are on-screen and hit-testable.
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
          // The category step now hands off to the live first-capture page;
          // override its providers so the page renders without the real mic
          // pipeline or a live structuring round-trip.
          captureControllerProvider.overrideWith(_FakeCaptureController.new),
          onboardingCaptureToTaskServiceProvider.overrideWithValue(
            MockOnboardingCaptureToTaskService(),
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
    await tester.tap(find.text('Choose your AI brain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More options'));
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

    // Success leads into the recording-style step. Its previews loop, so step
    // it with bounded pumps and continue with the default style.
    expect(find.text('How should recording feel?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Then the category step; the "why areas?" disclosure opens the
    // per-category-AI explanation, then dismisses.
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

    // Pick a preset area too, then continue with both selected.
    await tester.tap(find.text('Work'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    // The modal pops and the live first-capture page is pushed in its place.
    // The capture page's orb tickers never settle, so step the route
    // transition with bounded pumps rather than pumpAndSettle.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Completing the category step pops the modal and reveals the live
    // first-capture page; provider creation + FTUE setup ran; the chosen area
    // became a category bound to the provider's seeded inference profile; the
    // connected event is recorded.
    expect(find.text('Choose your AI brain'), findsNothing);
    expect(find.text("What's on your mind?"), findsOneWidget);
    verify(() => aiRepo.saveConfig(any())).called(1);
    verify(
      () => catRepo.createCategory(
        name: 'Work',
        color: any(named: 'color'),
        defaultProfileId: profileLocalId,
      ),
    ).called(1);
    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.providerConnected), isTrue);

    // The capture page's close affordance finishes onboarding (pops the page).
    await tester.tap(find.byIcon(Icons.close_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text("What's on your mind?"), findsNothing);
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

    expect(find.text('Talk. Lotti turns it into a plan.'), findsOneWidget);
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
    expect(find.text('Talk. Lotti turns it into a plan.'), findsOneWidget);

    // Tapping a non-interactive area of the panel is swallowed (the panel's
    // opaque no-op tap), so the flow stays open — not dismissed.
    await tester.tap(find.text('Talk. Lotti turns it into a plan.'));
    await tester.pumpAndSettle();
    expect(find.text('Talk. Lotti turns it into a plan.'), findsOneWidget);
  });

  testWidgets(
    'openOnboardingCreatedTask (desktop) opens the task and pops the capture '
    'route',
    (tester) async {
      final nav = MockNavService();
      when(() => nav.isDesktopMode).thenReturn(true);
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt.registerSingleton<NavService>(nav);
      addTearDown(() => getIt.unregister<NavService>());

      late BuildContext captureContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (rootContext) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(rootContext).push(
                    MaterialPageRoute<void>(
                      builder: (capCtx) {
                        captureContext = capCtx;
                        return const Scaffold(body: Text('capture'));
                      },
                    ),
                  ),
                  child: const Text('push'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(find.text('capture'), findsOneWidget);

      openOnboardingCreatedTask(captureContext, 'task-9');
      await tester.pumpAndSettle();

      // Desktop: hands the task to the detail stack and pops the capture route
      // (back to the app), without pushing a TaskDetailsPage route here.
      verify(() => nav.pushDesktopTaskDetail('task-9')).called(1);
      expect(find.text('capture'), findsNothing);
      expect(find.text('push'), findsOneWidget);
    },
  );
}
