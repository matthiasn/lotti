import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/onboarding/ui/onboarding_settings_panel.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Canned probe so the API-key step's live verification resolves without a
/// network call (mirrors the onboarding welcome modal test).
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
  setUpAll(registerAllFallbackValues);

  // Reduced motion so the welcome hero's looping controller stops and
  // pumpAndSettle can complete once the modal is opened.
  const mq = MediaQueryData(size: Size(390, 1000), disableAnimations: true);

  // Pumps without pumpAndSettle: the loading-state FutureBuilder never
  // settles on its own frame, so bound the number of pumps until the async
  // funnel read resolves.
  Future<void> pumpUntilLoaded(WidgetTester tester, Finder finder) async {
    await tester.pumpWidget(
      makeTestableWidget(const OnboardingSettingsBody(), mediaQueryData: mq),
    );
    for (var i = 0; i < 10 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  group('OnboardingSettingsBody — status row', () {
    setUp(() async {
      await getIt.reset();
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets(
      'shows "Not started yet" when no metrics repository is registered',
      (tester) async {
        // Defensive branch: the metrics substrate might not be
        // registered at all (e.g. a build where it failed to
        // initialize) — the row must still render, just as "not yet".
        await pumpUntilLoaded(tester, find.text('Not started yet'));
        expect(find.text('Not started yet'), findsOneWidget);
        expect(find.text('Start onboarding'), findsOneWidget);
      },
    );

    testWidgets(
      'shows "Not started yet" when the funnel has not reached realAha',
      (tester) async {
        final db = OnboardingMetricsDb(inMemoryDatabase: true);
        addTearDown(db.close);
        final repo = OnboardingMetricsRepository(
          db: db,
          clock: () => DateTime.utc(2026, 7, 1, 9),
          idGenerator: () => 'id-0',
          currentPlatform: () => 'testos',
        );
        await repo.recordAppFirstSeenIfAbsent();
        getIt.registerSingleton<OnboardingMetricsRepository>(repo);

        await pumpUntilLoaded(tester, find.text('Not started yet'));
        expect(find.text('Not started yet'), findsOneWidget);
        expect(find.text('Start onboarding'), findsOneWidget);
        expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'shows the activated status + "Replay onboarding" once the funnel '
      'has reached realAha',
      (tester) async {
        final db = OnboardingMetricsDb(inMemoryDatabase: true);
        addTearDown(db.close);
        final repo = OnboardingMetricsRepository(
          db: db,
          clock: () => DateTime.utc(2026, 7, 1, 9),
          idGenerator: () => 'id-0',
          currentPlatform: () => 'testos',
        );
        await repo.recordEvent(OnboardingEventName.realAha);
        getIt.registerSingleton<OnboardingMetricsRepository>(repo);

        await pumpUntilLoaded(
          tester,
          find.text("You've created your first AI task"),
        );
        expect(
          find.text("You've created your first AI task"),
          findsOneWidget,
        );
        expect(find.text('Replay onboarding'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'falls back to "Not started yet" when the metrics repository throws',
      (tester) async {
        final mockRepo = MockOnboardingMetricsRepository();
        when(
          mockRepo.funnelState,
        ).thenAnswer((_) async => throw Exception('boom'));
        getIt.registerSingleton<OnboardingMetricsRepository>(mockRepo);

        await pumpUntilLoaded(tester, find.text('Not started yet'));
        expect(find.text('Not started yet'), findsOneWidget);

        // FutureBuilder records the handled future error on the test
        // binding; drain the expected one so the end-of-test invariant
        // doesn't flag it.
        for (
          var ex = tester.takeException();
          ex != null;
          ex = tester.takeException()
        ) {
          expect(ex.toString(), contains('boom'));
        }
      },
    );

    testWidgets('shows the loading subtitle before the funnel read resolves', (
      tester,
    ) async {
      final mockRepo = MockOnboardingMetricsRepository();
      when(mockRepo.funnelState).thenAnswer((_) async {
        await Future<void>.delayed(Duration.zero);
        return const OnboardingFunnelState.empty();
      });
      getIt.registerSingleton<OnboardingMetricsRepository>(mockRepo);

      await tester.pumpWidget(
        makeTestableWidget(const OnboardingSettingsBody(), mediaQueryData: mq),
      );
      // First frame, before the microtask resolves: the loading copy shows.
      expect(find.text('Loading…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
    });
  });

  group('OnboardingSettingsBody — replay action', () {
    setUp(() async {
      await getIt.reset();
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('tapping the action row opens the FTUE welcome flow', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpUntilLoaded(tester, find.text('Start onboarding'));
      await tester.tap(find.text('Start onboarding'));
      await tester.pumpAndSettle();

      // Both welcome CTAs are present — the FTUE welcome step, not some
      // other surface.
      expect(find.text('Choose your AI brain'), findsOneWidget);
      expect(find.text('Look around first'), findsOneWidget);
    });

    testWidgets(
      'connecting a provider during a replay retires the auto-show gate '
      '(persists welcome_completed) so the welcome is not auto-shown again',
      (tester) async {
        final settingsDb = SettingsDb(inMemoryDatabase: true);
        addTearDown(settingsDb.close);
        getIt
          ..registerSingleton<SettingsDb>(settingsDb)
          ..registerSingleton<LoggingService>(LoggingService());

        final aiRepo = MockAiConfigRepository();
        when(() => aiRepo.saveConfig(any())).thenAnswer((_) async {});
        final catRepo = MockCategoryRepository();
        when(
          catRepo.getAllCategoriesIncludingHidden,
        ).thenAnswer((_) async => []);

        tester.view
          ..physicalSize = const Size(390, 1000)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          makeTestableWidget(
            const OnboardingSettingsBody(),
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
        for (
          var i = 0;
          i < 10 && find.text('Start onboarding').evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        // Replay → connect an Ollama provider (needs no API key) → success.
        await tester.tap(find.text('Start onboarding'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose your AI brain'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ollama'));
        await tester.pumpAndSettle();
        // Ollama probes reachability on open; let the ≥1s dwell elapse.
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pumpAndSettle();
        expect(find.text('Connection verified'), findsOneWidget);
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();
        expect(find.text('Get started'), findsOneWidget);

        // The gate is not retired until the modal actually closes.
        expect(
          await settingsDb.itemByKey(onboardingWelcomeCompletedKey),
          isNull,
        );

        // Close the modal by tapping outside the panel: the flow ends with a
        // connected provider, so `onCompleted` fires and persists the flag.
        final panelTop = tester
            .getTopLeft(find.byKey(const ValueKey('onboarding-success')))
            .dy;
        await tester.tapAt(Offset(195, panelTop - 20));
        await tester.pumpAndSettle();

        expect(
          await settingsDb.itemByKey(onboardingWelcomeCompletedKey),
          'true',
        );
      },
    );

    testWidgets(
      'reloads the funnel status after the welcome flow closes — the '
      'row must reflect a newly-reached realAha without re-mounting',
      (tester) async {
        final mockRepo = MockOnboardingMetricsRepository();
        when(
          mockRepo.funnelState,
        ).thenAnswer((_) async => const OnboardingFunnelState.empty());
        // The welcome flow records `welcomeShown` on open and
        // `welcomeSkipped` on the skip-out path exercised below.
        when(
          () => mockRepo.recordEvent(any()),
        ).thenAnswer((_) async {});
        getIt.registerSingleton<OnboardingMetricsRepository>(mockRepo);

        tester.view
          ..physicalSize = const Size(390, 1000)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpUntilLoaded(tester, find.text('Start onboarding'));
        verify(mockRepo.funnelState).called(1);

        await tester.tap(find.text('Start onboarding'));
        await tester.pumpAndSettle();
        // Close the welcome via the skip CTA — the modal pops and the
        // action's await resolves.
        await tester.tap(find.text('Look around first'));
        await tester.pumpAndSettle();

        // A second funnel read fired once the modal closed.
        verify(mockRepo.funnelState).called(1);
      },
    );
  });

  group('OnboardingSettingsPage', () {
    setUp(() async {
      await getIt.reset();
      getIt.registerSingleton<UserActivityService>(UserActivityService());
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('renders the body inside the titled page chrome', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 1000, maxWidth: 1000),
            child: const OnboardingSettingsPage(),
          ),
          mediaQueryData: mq,
        ),
      );
      for (
        var i = 0;
        i < 10 && find.text('Not started yet').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.byType(OnboardingSettingsBody), findsOneWidget);
      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('Not started yet'), findsOneWidget);
    });
  });
}
