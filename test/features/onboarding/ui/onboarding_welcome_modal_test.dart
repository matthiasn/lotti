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
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
import 'package:lotti/get_it.dart';
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
    expect(find.text('Connect your brain'), findsOneWidget);

    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.welcomeShown), isTrue);
  });

  testWidgets('advancing to connect reveals the three providers and records '
      'providerModalShown', (tester) async {
    await openWelcome(tester);
    await tester.tap(find.text('Connect your brain'));
    await tester.pumpAndSettle();

    expect(find.text('Gemini'), findsOneWidget);
    expect(find.text('Mistral'), findsOneWidget);
    expect(find.text('Qwen'), findsOneWidget);

    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.providerModalShown), isTrue);
  });

  testWidgets('back from connect returns to the welcome', (tester) async {
    await openWelcome(tester);
    await tester.tap(find.text('Connect your brain'));
    await tester.pumpAndSettle();
    expect(find.text('Gemini'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Talk. Lotti turns it into a plan.'), findsOneWidget);
  });

  testWidgets('More options reveals OpenAI and Ollama', (tester) async {
    await openWelcome(tester);
    await tester.tap(find.text('Connect your brain'));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI'), findsNothing);
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Ollama'), findsOneWidget);
  });

  testWidgets('selecting a provider opens the API-key step', (tester) async {
    await openWelcome(tester);
    await tester.tap(find.text('Connect your brain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mistral'));
    await tester.pumpAndSettle();

    expect(find.text('Paste your API key'), findsOneWidget);
  });

  testWidgets('back from the API-key step returns to the providers', (
    tester,
  ) async {
    await openWelcome(tester);
    await tester.tap(find.text('Connect your brain'));
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
    await tester.tap(find.text('Connect your brain'));
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

    // Success leads into the category step; the "why areas?" disclosure opens
    // the per-category-AI explanation, then dismisses.
    expect(find.text('Where should your AI work?'), findsOneWidget);
    await tester.tap(find.text('Why areas?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('own AI'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Pick an area and continue.
    await tester.tap(find.text('Work'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Completing the category step pops the modal; provider creation + FTUE
    // setup ran; the chosen area became a category bound to the provider's
    // seeded inference profile; the connected event is recorded.
    expect(find.text('Connect your brain'), findsNothing);
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
}
