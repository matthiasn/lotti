import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
import 'package:lotti/get_it.dart';

import '../../../widget_test_utils.dart';

void main() {
  late OnboardingMetricsDb db;
  late OnboardingMetricsRepository repo;
  var idSeq = 0;

  // Reduced motion so the looping constellation controller stops and
  // pumpAndSettle can complete.
  const mq = MediaQueryData(size: Size(390, 844), disableAnimations: true);

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
    await tester.tap(find.text('Look around first'));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    final state = await repo.funnelState();
    expect(state.reached(OnboardingEventName.welcomeSkipped), isTrue);
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
