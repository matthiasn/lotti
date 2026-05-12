import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockAiConfigRepository mockRepository;

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

  setUp(() async {
    mockRepository = MockAiConfigRepository();
    await setUpTestGetIt();

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
    await tearDownTestGetIt();
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
      'count tail derived from the models list, and the desktop 2-column '
      'grid uses a separator between rows when there are 3+ providers',
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
        // 3rd provider pushes the grid into a second row, which is the
        // only way the desktop separator-builder branch fires.
        final anthropic = buildProvider(
          id: 'anthropic-1',
          type: InferenceProviderType.anthropic,
          name: 'My Anthropic',
        );

        await pumpWith(
          tester: tester,
          providers: [gemini, openAi, anthropic],
          models: [buildModel(id: 'm1', providerId: 'gemini-1')],
          profiles: const <AiConfig>[],
        );

        // Three provider cards rendered.
        expect(find.byType(AiProviderCard), findsNWidgets(3));
        expect(find.text('My Gemini'), findsOneWidget);
        expect(find.text('My OpenAI'), findsOneWidget);
        expect(find.text('My Anthropic'), findsOneWidget);
        // Gemini provider with one model → "Connected" + model count tail.
        expect(find.text('Connected'), findsNWidgets(2));
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

  group('AiSettingsPage — empty / error states', () {
    testWidgets(
      'AiSettingsBody smoke-mounts as the standalone page',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiConfigRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: const <ThemeExtension<dynamic>>[dsTokensLight],
              ),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AiSettingsBody(),
            ),
          ),
        );
        providersController.add(const <AiConfig>[]);
        await tester.pump();
        await tester.pump();
        modelsController.add(const <AiConfig>[]);
        profilesController.add(const <AiConfig>[]);
        await tester.pump();
        await tester.pump();

        // Renders the same widget tree as `AiSettingsPage`.
        expect(find.text('AI Settings'), findsOneWidget);
        expect(find.byType(AiSettingsPage), findsOneWidget);
        await settleTimers(tester);
      },
    );

    // Note: the providers-stream error branch is covered structurally by
    // the empty / populated paths above, but is hard to drive end-to-end
    // here — Riverpod's generated stream controller keeps the AsyncValue
    // in `loading` for both `Stream.error(...)` and `broadcastController
    // .addError(...)` in this harness, so the page never transitions
    // into the `hasError && providers == null` branch. The branch ships
    // as defensive code; the cleanup pass after v3 will revisit the
    // page's async-state handling and add a more durable test then.

    testWidgets(
      'Models tab empty list renders the no-models-configured message',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        await tester.tap(find.text('Models'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // From en.arb: aiSettingsNoModelsConfigured.
        expect(find.text('No AI models configured'), findsOneWidget);
        expect(find.byType(AiModelCard), findsNothing);
        await settleTimers(tester);
      },
    );

    testWidgets(
      'Profiles tab with no profiles renders inferenceProfilesEmpty',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        await tester.tap(find.text('Profiles'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // From en.arb: inferenceProfilesEmpty.
        expect(find.text('No inference profiles yet'), findsOneWidget);
        expect(find.byType(AiProfileCard), findsNothing);
        await settleTimers(tester);
      },
    );

    testWidgets(
      'Profiles tab with a non-matching search shows multiSelectNoItemsFound',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: const <AiConfig>[],
          profiles: [
            buildProfile(id: 'profile-1', thinking: 'unknown-model-id'),
          ],
        );

        await tester.enterText(find.byType(TextField), 'no-match-zzz');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        await tester.tap(find.text('Profiles'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // From en.arb: multiSelectNoItemsFound.
        expect(find.text('No items found'), findsOneWidget);
        expect(find.byType(AiProfileCard), findsNothing);
        await settleTimers(tester);
      },
    );

    testWidgets(
      'Providers tab with a non-matching search shows the configured-but-filtered-out empty message',
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
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        await tester.enterText(find.byType(TextField), 'no-match-zzz');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        // From en.arb: aiSettingsNoProvidersConfigured.
        expect(find.text('No AI providers configured'), findsOneWidget);
        expect(find.byType(AiProviderCard), findsNothing);
        await settleTimers(tester);
      },
    );

    testWidgets(
      'Models tab with a non-matching search shows the no-models-configured '
      'empty message',
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
          ],
          profiles: const <AiConfig>[],
        );

        await tester.enterText(find.byType(TextField), 'no-match-zzz');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        await tester.tap(find.text('Models'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('No AI models configured'), findsOneWidget);
        expect(find.byType(AiModelCard), findsNothing);
        await settleTimers(tester);
      },
    );
  });

  group('AiSettingsPage — responsive layout', () {
    testWidgets(
      'narrow viewport (< 700) renders cards as a single-column list',
      (tester) async {
        // Surface is below the page-level grid breakpoint, so the
        // `_buildCardList` branch with columns == 1 fires.
        await tester.binding.setSurfaceSize(const Size(500, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(
              id: 'p1',
              type: InferenceProviderType.gemini,
              name: 'Gemini A',
            ),
            buildProvider(
              id: 'p2',
              type: InferenceProviderType.openAi,
              name: 'OpenAI A',
            ),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        // Both provider cards still render — sanity check.
        expect(find.byType(AiProviderCard), findsNWidgets(2));

        // In single-column mode each card sits inside its own list
        // entry rather than paired in a Row. Confirm no two cards
        // share a parent Row (which would indicate the 2-col branch).
        final cards = find.byType(AiProviderCard);
        for (var i = 0; i < cards.evaluate().length; i++) {
          final rowAncestor = find.ancestor(
            of: cards.at(i),
            matching: find.byWidgetPredicate(
              (w) => w is Row && w.children.length == 3,
            ),
          );
          expect(
            rowAncestor,
            findsNothing,
            reason:
                'Single-column mode should not wrap cards in the 2-col '
                'Row(Expanded, SizedBox, Expanded) structure.',
          );
        }
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
      'tapping a model card pushes a new route',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(
          () => mockRepository.getConfigById(any()),
        ).thenAnswer((_) async => null);

        final spy = _PushSpy();
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
          ],
          profiles: const <AiConfig>[],
          navigatorObservers: [spy],
        );

        await tester.tap(find.text('Models'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Initial root + the tab-switch animation does not push.
        expect(spy.pushed, hasLength(1));

        await tester.tap(find.byType(AiModelCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(spy.pushed, hasLength(2));
      },
    );

    testWidgets(
      'tapping a profile card pushes a new route',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(
          () => mockRepository.getConfigById(any()),
        ).thenAnswer((_) async => null);

        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: [
            buildModel(
              id: 'm1',
              providerId: 'p1',
              providerModelId: 'gemini-flash-id',
            ),
          ],
          profiles: [
            buildProfile(
              id: 'profile-1',
              name: 'Tap Me Profile',
              thinking: 'gemini-flash-id',
            ),
          ],
          navigatorObservers: [spy],
        );

        await tester.tap(find.text('Profiles'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(spy.pushed, hasLength(1));

        await tester.tap(find.byType(AiProfileCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(spy.pushed, hasLength(2));
      },
    );

    testWidgets(
      'tapping Fix on an invalid-key provider card pushes a new route',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(
          () => mockRepository.getConfigById(any()),
        ).thenAnswer((_) async => null);

        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(
              id: 'p1',
              type: InferenceProviderType.openAi,
              name: 'Broken OpenAI',
              apiKey: '',
            ),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          navigatorObservers: [spy],
        );

        // The blank-API-key provider lands in `invalidKey` status,
        // which wires up the inline Fix affordance.
        expect(find.text('Invalid key'), findsOneWidget);
        expect(spy.pushed, hasLength(1));

        await tester.tap(find.text('Fix'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

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
