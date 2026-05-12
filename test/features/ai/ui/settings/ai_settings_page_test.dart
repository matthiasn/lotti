import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  late MockAiConfigRepository mockRepository;
  late SettingsDb settingsDb;

  // Bus-style stream controllers per AiConfigType so individual tests
  // can push fresh snapshots without re-wiring the whole stub.
  late StreamController<List<AiConfig>> providersController;
  late StreamController<List<AiConfig>> modelsController;
  late StreamController<List<AiConfig>> profilesController;

  AiConfigInferenceProvider buildProvider({
    required String id,
    required InferenceProviderType type,
    String name = 'Test Provider',
    String apiKey = 'sk-test',
    String baseUrl = 'https://api.example.com',
  }) {
    return AiConfigInferenceProvider(
      id: id,
      name: name,
      inferenceProviderType: type,
      apiKey: apiKey,
      baseUrl: baseUrl,
      createdAt: DateTime(2024, 3, 15),
    );
  }

  AiConfigModel buildModel({
    required String id,
    required String providerId,
    String name = 'Test Model',
    String providerModelId = 'test-model-id',
    bool isReasoning = false,
    List<Modality> inputs = const [Modality.text],
    List<Modality> outputs = const [Modality.text],
  }) {
    return AiConfigModel(
      id: id,
      name: name,
      providerModelId: providerModelId,
      inferenceProviderId: providerId,
      createdAt: DateTime(2024, 3, 15),
      inputModalities: inputs,
      outputModalities: outputs,
      isReasoningModel: isReasoning,
    );
  }

  AiConfigInferenceProfile buildProfile({
    required String id,
    required String thinking,
    String name = 'Test Profile',
    String? imageRecognition,
    String? transcription,
    String? imageGeneration,
    bool isDefault = false,
    String? description,
  }) {
    return AiConfigInferenceProfile(
      id: id,
      name: name,
      description: description,
      thinkingModelId: thinking,
      imageRecognitionModelId: imageRecognition,
      transcriptionModelId: transcription,
      imageGenerationModelId: imageGeneration,
      isDefault: isDefault,
      createdAt: DateTime(2024, 3, 15),
    );
  }

  setUpAll(() {
    registerFallbackValue(AiConfigType.inferenceProvider);
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();
    settingsDb = SettingsDb(inMemoryDatabase: true);
    if (getIt.isRegistered<SettingsDb>()) {
      getIt.unregister<SettingsDb>();
    }
    getIt.registerSingleton<SettingsDb>(settingsDb);

    providersController = StreamController<List<AiConfig>>.broadcast();
    modelsController = StreamController<List<AiConfig>>.broadcast();
    profilesController = StreamController<List<AiConfig>>.broadcast();

    when(
      () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
    ).thenAnswer((_) => providersController.stream);
    when(
      () => mockRepository.watchConfigsByType(AiConfigType.model),
    ).thenAnswer((_) => modelsController.stream);
    when(
      () => mockRepository.watchConfigsByType(AiConfigType.inferenceProfile),
    ).thenAnswer((_) => profilesController.stream);
    when(() => mockRepository.watchProfiles()).thenAnswer(
      (_) => profilesController.stream.map(
        (xs) => xs.whereType<AiConfigInferenceProfile>().toList(),
      ),
    );
  });

  tearDown(() async {
    await providersController.close();
    await modelsController.close();
    await profilesController.close();
    await settingsDb.close();
    await getIt.reset();
  });

  Widget buildHarness({List<NavigatorObserver> navigatorObservers = const []}) {
    return ProviderScope(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: MaterialApp(
        navigatorObservers: navigatorObservers,
        theme: ThemeData(
          useMaterial3: true,
          extensions: const <ThemeExtension<dynamic>>[dsTokensLight],
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          extensions: const <ThemeExtension<dynamic>>[dsTokensDark],
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AiSettingsPage(),
      ),
    );
  }

  Future<void> pumpWith({
    required WidgetTester tester,
    required List<AiConfig> providers,
    required List<AiConfig> models,
    required List<AiConfig> profiles,
    List<NavigatorObserver> navigatorObservers = const [],
  }) async {
    await tester.pumpWidget(
      buildHarness(navigatorObservers: navigatorObservers),
    );
    // First pump: providers stream emits. The page rebuilds out of
    // the loading branch and only THEN subscribes to the models +
    // profiles streams (they're not read inside the loading branch).
    providersController.add(providers);
    await tester.pump();
    await tester.pump();
    // Second pump: with subscriptions in place, push the rest. Without
    // this two-phase push the broadcast streams' events for models +
    // profiles would land before the page had a chance to listen.
    modelsController.add(models);
    profilesController.add(profiles);
    await tester.pump();
    await tester.pump();
  }

  // The shared header / cards mount Material InkWells whose tickers
  // schedule a Timer once the surface paints. Advance simulated time
  // so the timer fires before the test ends; otherwise Flutter's
  // "no pending Timer" guard trips on teardown.
  Future<void> settleTimers(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  group('AiSettingsPage — empty state', () {
    testWidgets(
      'renders the FTUE banner + the No-providers card with four quick-add '
      'chips when the providers stream emits an empty list',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          providers: const <AiConfig>[],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        // FTUE banner + the No-providers card render in the empty branch.
        expect(find.text('Add your first AI provider'), findsOneWidget);
        expect(find.text('No providers yet'), findsOneWidget);
        // Four first-class quick-add chips inside the empty card.
        expect(find.text('Google Gemini'), findsOneWidget);
        expect(find.text('OpenAI'), findsOneWidget);
        expect(find.text('Anthropic Claude'), findsOneWidget);
        expect(find.text('Ollama'), findsOneWidget);
        await settleTimers(tester);
      },
    );
  });

  group('AiSettingsPage — populated', () {
    testWidgets(
      'Providers tab shows one AiProviderCard per provider with the model '
      'count tail derived from the models list',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final gemini = buildProvider(
          id: 'gemini-1',
          type: InferenceProviderType.gemini,
          name: 'My Gemini',
        );
        final openAi = buildProvider(
          id: 'openai-1',
          type: InferenceProviderType.openAi,
          name: 'My OpenAI',
          apiKey: '',
        );

        await pumpWith(
          tester: tester,
          providers: [gemini, openAi],
          models: [buildModel(id: 'm1', providerId: 'gemini-1')],
          profiles: const <AiConfig>[],
        );

        // Two provider cards rendered.
        expect(find.byType(AiProviderCard), findsNWidgets(2));
        // Tab counter reflects the provider count.
        expect(find.text('My Gemini'), findsOneWidget);
        expect(find.text('My OpenAI'), findsOneWidget);
        // Gemini provider with one model → "Connected" + model count tail.
        expect(find.text('Connected'), findsOneWidget);
        // OpenAI provider with a blank API key → Invalid key status.
        expect(find.text('Invalid key'), findsOneWidget);
        await settleTimers(tester);
      },
    );

    testWidgets(
      'switching to the Models tab renders one AiModelCard per model and '
      'omits the provider cards',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: [
            buildModel(
              id: 'm1',
              providerId: 'p1',
              name: 'Gemini Flash',
              providerModelId: 'gemini-flash-id',
            ),
            buildModel(
              id: 'm2',
              providerId: 'p1',
              name: 'Gemini Pro',
              providerModelId: 'gemini-pro-id',
              isReasoning: true,
            ),
          ],
          profiles: const <AiConfig>[],
        );

        await tester.tap(find.text('Models'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AiModelCard), findsNWidgets(2));
        expect(find.byType(AiProviderCard), findsNothing);
        expect(find.text('Gemini Flash'), findsOneWidget);
        expect(find.text('Gemini Pro'), findsOneWidget);
        expect(find.text('gemini-flash-id'), findsOneWidget);
        await settleTimers(tester);
      },
    );

    testWidgets(
      'switching to the Profiles tab renders one AiProfileCard per profile '
      'and the Active badge for `isDefault: true` profiles',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.anthropic),
          ],
          models: [
            buildModel(
              id: 'm-thinking',
              providerId: 'p1',
              name: 'Claude Sonnet',
              providerModelId: 'claude-sonnet-id',
            ),
          ],
          profiles: [
            buildProfile(
              id: 'profile-1',
              name: 'Anthropic Claude',
              thinking: 'claude-sonnet-id',
              isDefault: true,
            ),
            buildProfile(
              id: 'profile-2',
              name: 'Custom Profile',
              thinking: 'unknown-model-id',
            ),
          ],
        );

        await tester.tap(find.text('Profiles'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AiProfileCard), findsNWidgets(2));
        expect(find.text('Anthropic Claude'), findsOneWidget);
        expect(find.text('Custom Profile'), findsOneWidget);
        // Default profile renders the Active badge.
        expect(find.text('Active'), findsOneWidget);
        // The thinking slot resolves on profile 1 (model name shown) and
        // misses on profile 2 (warning placeholder).
        expect(find.text('Claude Sonnet'), findsOneWidget);
        expect(find.text('missing'), findsOneWidget);
        await settleTimers(tester);
      },
    );
  });

  group('AiSettingsPage — search filter', () {
    testWidgets(
      'typing into the search field filters the providers list',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(
              id: 'p1',
              type: InferenceProviderType.gemini,
              name: 'My Gemini',
            ),
            buildProvider(
              id: 'p2',
              type: InferenceProviderType.openAi,
              name: 'My OpenAI',
            ),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        expect(find.byType(AiProviderCard), findsNWidgets(2));

        await tester.enterText(find.byType(TextField), 'openai');
        // The page's debounce is 300ms — pump past it.
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        expect(find.text('My OpenAI'), findsOneWidget);
        expect(find.text('My Gemini'), findsNothing);
        await settleTimers(tester);
      },
    );

    testWidgets(
      'clearing the search via the trailing clear icon restores the full '
      'list',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(
              id: 'p1',
              type: InferenceProviderType.gemini,
              name: 'My Gemini',
            ),
            buildProvider(
              id: 'p2',
              type: InferenceProviderType.openAi,
              name: 'My OpenAI',
            ),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        await tester.enterText(find.byType(TextField), 'gemini');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        expect(find.byType(AiProviderCard), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        expect(find.byType(AiProviderCard), findsNWidgets(2));
        await settleTimers(tester);
      },
    );
  });

  group('AiSettingsPage — navigation', () {
    testWidgets(
      'tapping a provider card pushes a new route through the navigator',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigById(any())).thenAnswer(
          (_) async => null,
        );

        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(
              id: 'p1',
              type: InferenceProviderType.gemini,
              name: 'Tap Me',
            ),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          navigatorObservers: [spy],
        );

        // Initial root push is the AiSettingsPage itself.
        expect(spy.pushed, hasLength(1));

        await tester.tap(find.byType(AiProviderCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The card tap should have pushed exactly one new route.
        expect(spy.pushed, hasLength(2));
      },
    );

    testWidgets(
      'tapping a quick-add chip on the empty state pushes the add-provider '
      'route',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          providers: const <AiConfig>[],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          navigatorObservers: [spy],
        );

        await tester.tap(find.text('Anthropic Claude'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Initial root + one quick-add push.
        expect(spy.pushed, hasLength(2));
      },
    );

    testWidgets(
      'tapping the Add provider CTA pushes a new route',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          navigatorObservers: [spy],
        );

        await tester.tap(find.text('Add provider'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(spy.pushed, hasLength(2));
      },
    );
  });
}

/// NavigatorObserver that captures every `push` so a test can assert
/// "tapping X pushed a new route" without depending on which exact
/// widget the destination page renders.
class _PushSpy extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}
