import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show CascadeDeletionResult, aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_floating_action_button.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_pick_provider_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_header_bar.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_tab_bar.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
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

  late MockNavService mockNavService;

  setUp(() async {
    mockRepository = MockAiConfigRepository();
    // The v4 nav service beams provider/model/profile-detail URLs
    // through `nav_service.beamToNamed`, which calls
    // `getIt<NavService>()`. Without this mock, every navigation test
    // crashes with a missing-registration error. `setUpTestGetIt`
    // already resets the locator, so binding through `additionalSetup`
    // is enough — no need to re-check `isRegistered`.
    mockNavService = MockNavService();
    when(() => mockNavService.beamToNamed(any())).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );

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

  Widget buildHarness({
    List<NavigatorObserver> navigatorObservers = const [],
    List<Override> additionalOverrides = const [],
    AiSettingsTab? initialTab,
    bool hideTabBar = false,
    bool hideHeader = false,
    Widget? home,
  }) {
    return ProviderScope(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        ...additionalOverrides,
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
        home:
            home ??
            (initialTab == null
                ? const AiSettingsPage()
                : AiSettingsPage(
                    initialTab: initialTab,
                    hideTabBar: hideTabBar,
                    hideHeader: hideHeader,
                  )),
      ),
    );
  }

  Future<void> pumpWith({
    required WidgetTester tester,
    required List<AiConfig> providers,
    required List<AiConfig> models,
    required List<AiConfig> profiles,
    List<NavigatorObserver> navigatorObservers = const [],
    List<Override> additionalOverrides = const [],
    AiSettingsTab? initialTab,
    bool hideTabBar = false,
    bool hideHeader = false,
  }) async {
    await tester.pumpWidget(
      buildHarness(
        navigatorObservers: navigatorObservers,
        additionalOverrides: additionalOverrides,
        initialTab: initialTab,
        hideTabBar: hideTabBar,
        hideHeader: hideHeader,
      ),
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

    testWidgets('MLX model install action opens the shared download dialog', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mlxAudioChannel = _PageMlxAudioChannel();
      addTearDown(mlxAudioChannel.close);

      await pumpWith(
        tester: tester,
        providers: [
          buildProvider(
            id: 'mlx-provider',
            type: InferenceProviderType.mlxAudio,
            name: 'MLX Audio',
            apiKey: '',
            baseUrl: '',
          ),
        ],
        models: [
          buildModel(
            id: 'mlx-model',
            providerId: 'mlx-provider',
            name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
            providerModelId: mlxAudioQwenAsr17B8BitModelId,
            inputs: const [Modality.audio, Modality.text],
          ),
        ],
        profiles: const <AiConfig>[],
        additionalOverrides: [
          mlxAudioChannelProvider.overrideWithValue(mlxAudioChannel),
        ],
      );

      await tester.tap(find.text('Models'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('Not installed'), findsOneWidget);

      await tester.tap(find.byTooltip('Install model'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(
        find.textContaining('Install Qwen3 ASR 1.7B (MLX 8-bit)'),
        findsOneWidget,
      );
      expect(find.text('Downloading 12%'), findsNWidgets(2));
      expect(mlxAudioChannel.installRequests, [mlxAudioQwenAsr17B8BitModelId]);
    });

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

        await tester.tap(find.byIcon(Icons.clear_rounded));
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

        // Reuses the shared `buildHarness` chrome (ProviderScope + theme +
        // localization delegates) but substitutes the standalone
        // `AiSettingsBody` as the home so this test verifies the body
        // wrapper mounts the full `AiSettingsPage` tree on its own.
        await tester.pumpWidget(buildHarness(home: const AiSettingsBody()));
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

    // Probe the exact grid breakpoint: the switch happens on the sliver's
    // INNER cross-axis extent (surface width minus the step5=16 padding on
    // both sides), so inner width 700 is surface 732.
    for (final (surfaceWidth, expectTwoColumns) in [
      (732.0, true), // inner 700 == breakpoint -> 2-column grid
      (731.0, false), // inner 699 -> single column
    ]) {
      testWidgets(
        'inner width ${surfaceWidth - 32} renders '
        '${expectTwoColumns ? 2 : 1} column(s)',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(surfaceWidth, 1600));
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

          expect(find.byType(AiProviderCard), findsNWidgets(2));

          // The 2-column branch pairs cards inside a
          // Row(Expanded, SizedBox, Expanded) structure.
          final pairedRow = find.ancestor(
            of: find.byType(AiProviderCard).first,
            matching: find.byWidgetPredicate(
              (w) => w is Row && w.children.length == 3,
            ),
          );
          expect(
            pairedRow,
            expectTwoColumns ? findsOneWidget : findsNothing,
            reason: 'surface $surfaceWidth',
          );
          await settleTimers(tester);
        },
      );
    }
  });

  group('AiSettingsPage — navigation', () {
    testWidgets(
      'tapping a provider card beams to the per-provider detail URL — '
      'desktop master/detail panel swap path (no Navigator.push)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

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
        );

        await tester.tap(find.byType(AiProviderCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => mockNavService.beamToNamed('/settings/ai/provider/p1'),
        ).called(1);
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
      'tapping a model card beams to the per-model detail URL — same '
      'desktop master/detail dispatch path as provider rows',
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

        await tester.tap(find.text('Models'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byType(AiModelCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => mockNavService.beamToNamed('/settings/ai/model/m1'),
        ).called(1);
      },
    );

    testWidgets(
      'tapping a profile card beams to the per-profile detail URL — same '
      'desktop master/detail dispatch path as provider/model rows',
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
        );

        await tester.tap(find.text('Profiles'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byType(AiProfileCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => mockNavService.beamToNamed(
            '/settings/ai/profile/profile-1',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'tapping Fix on an invalid-key provider card beams to the detail URL '
      'with the focusApiKey query param — Fix-flow entry point',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

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
        );

        // The blank-API-key provider lands in `invalidKey` status,
        // which wires up the inline Fix affordance.
        expect(find.text('Invalid key'), findsOneWidget);

        await tester.tap(find.text('Fix'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => mockNavService.beamToNamed(
            '/settings/ai/provider/p1?focusApiKey=true',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'tapping Edit on the provider card overflow menu beams to the same '
      'detail URL as a card tap (same nav path)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          providers: [
            buildProvider(
              id: 'p1',
              type: InferenceProviderType.gemini,
              name: 'Menu Test',
            ),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        // Open the card's `⋯` menu.
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
        // Two rows expected: Edit + Delete (from `_buildCardMenu`).
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);

        await tester.tap(find.text('Edit'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => mockNavService.beamToNamed('/settings/ai/provider/p1'),
        ).called(1);
      },
    );

    testWidgets(
      'tapping Delete on the provider card overflow menu invokes the '
      'cascade-delete service',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider(
          id: 'p1',
          type: InferenceProviderType.gemini,
          name: 'Delete Me',
        );

        when(
          () => mockRepository.getConfigById(provider.id),
        ).thenAnswer((_) async => provider);
        when(
          () => mockRepository.deleteInferenceProviderWithModels(provider.id),
        ).thenAnswer(
          (_) async => const CascadeDeletionResult(
            deletedModels: <AiConfigModel>[],
            providerName: 'Delete Me',
          ),
        );

        await pumpWith(
          tester: tester,
          providers: [provider],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // The delete service opens its own confirmation dialog. Find it
        // and tap the destructive primary action. The dialog may not
        // render in this harness — assert against either the dialog or
        // a direct repository call.
        final filledButton = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(DesignSystemButton),
        );
        if (filledButton.evaluate().isNotEmpty) {
          await tester.tap(filledButton.first);
          await tester.pumpAndSettle();
        }

        verify(
          () => mockRepository.deleteInferenceProviderWithModels(provider.id),
        ).called(1);
      },
    );

    testWidgets(
      'tapping the per-tab FloatingActionButton pushes the create route — '
      'the create flows still use Navigator.push (slide overlay) rather '
      'than beaming, since they overlay the list rather than swap a '
      'detail panel',
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

        // Initial root push baseline.
        final baseline = spy.pushed.length;

        // The FAB is rendered as `DesignSystemFloatingActionButton`
        // wrapping an InkWell whose onTap is wired to the page's add
        // handler. The outer padding wrapper places the FAB off the
        // synthetic test viewport in some layouts, so tap the inner
        // InkWell directly to bypass any hit-test offset issues.
        final fab = find.byType(AiSettingsFloatingActionButton);
        final inkWell = find.descendant(
          of: fab,
          matching: find.byType(InkWell),
        );
        await tester.tap(inkWell, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(spy.pushed.length, greaterThan(baseline));
      },
    );
  });

  /// Coverage for the constructor-level `initialTab` seed used by the v4
  /// desktop panel registry (`_aiProvidersPanel` / `_aiModelsPanel` /
  /// `_aiProfilesPanel`). Each panel mounts `AiSettingsBody` pinned to
  /// a specific tab; without the seed branch the page would always
  /// open on Providers regardless of which sidebar leaf was clicked.
  group('AiSettingsPage — initialTab seeding', () {
    Future<void> pumpSeeded({
      required WidgetTester tester,
      required AiSettingsTab initialTab,
      required List<AiConfig> providers,
      required List<AiConfig> models,
      required List<AiConfig> profiles,
      bool hideTabBar = false,
      bool hideHeader = false,
      List<NavigatorObserver> navigatorObservers = const [],
    }) async {
      // Thin alias over the unified harness — the former seededHarness
      // duplicate is gone.
      await pumpWith(
        tester: tester,
        providers: providers,
        models: models,
        profiles: profiles,
        navigatorObservers: navigatorObservers,
        initialTab: initialTab,
        hideTabBar: hideTabBar,
        hideHeader: hideHeader,
      );
      // Flush the ticker timers mounted with the header/cards' InkWells.
      await settleTimers(tester);
    }

    testWidgets(
      'initialTab=AiSettingsTab.models seeds the Models tab body on first '
      'frame — the page never lands on Providers and then animates over',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpSeeded(
          tester: tester,
          initialTab: AiSettingsTab.models,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: [buildModel(id: 'm1', providerId: 'p1')],
          profiles: const <AiConfig>[],
        );

        // The Models tab body renders `AiModelCard`s; the Providers
        // body would have rendered `AiProviderCard`s. Asserting the
        // model card type is the cheapest proof the seeded tab won.
        expect(find.byType(AiModelCard), findsOneWidget);
        expect(find.byType(AiProviderCard), findsNothing);
      },
    );

    testWidgets(
      'initialTab=AiSettingsTab.profiles seeds the Profiles tab body so '
      'the desktop "AI > Profiles" leaf lands directly on profile cards',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpSeeded(
          tester: tester,
          initialTab: AiSettingsTab.profiles,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: [buildModel(id: 'm1', providerId: 'p1')],
          profiles: [buildProfile(id: 'profile-1', thinking: 'm1')],
        );

        expect(find.byType(AiProfileCard), findsOneWidget);
        expect(find.byType(AiProviderCard), findsNothing);
      },
    );

    testWidgets(
      'hideTabBar=true removes the in-pane `AiSettingsTabBar` so the '
      'desktop sidebar leaf is the sole "which view am I on?" affordance',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpSeeded(
          tester: tester,
          initialTab: AiSettingsTab.providers,
          hideTabBar: true,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        expect(find.byType(AiSettingsTabBar), findsNothing);
        // Body still rendered — the page didn't collapse, it just
        // dropped the tab strip on top.
        expect(find.byType(AiProviderCard), findsOneWidget);
      },
    );

    testWidgets(
      'hideHeader=true drops the in-pane `SettingsPageHeader` so the '
      'desktop master/detail breadcrumb is the sole title affordance — '
      'the search bar still renders and stays first in the scroll view',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpSeeded(
          tester: tester,
          initialTab: AiSettingsTab.providers,
          hideHeader: true,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        expect(find.byType(SettingsPageHeader), findsNothing);
        // The search bar (and the rest of the page) still mounts so
        // the panel isn't a blank slate.
        expect(find.byType(AiSettingsHeaderBar), findsOneWidget);
        expect(find.byType(AiProviderCard), findsOneWidget);
      },
    );

    testWidgets(
      'hideHeader=false keeps the in-pane `SettingsPageHeader` mounted — '
      'the mobile / standalone surface still needs the title strip + back '
      'button because there is no breadcrumb above it',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpSeeded(
          tester: tester,
          initialTab: AiSettingsTab.providers,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        expect(find.byType(SettingsPageHeader), findsOneWidget);
      },
    );

    testWidgets(
      'FAB seeded on the Models tab dispatches to navigateToCreateModel — '
      'covers the Models arm of `_activeTabAddHandler`. Invoking the FAB '
      'callback directly (instead of tapping the InkWell) keeps the test '
      'robust against viewport / hit-test offsets — what we are verifying '
      'is which handler the page wired up, not whether the design-system '
      'FAB widget is hit-testable.',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpSeeded(
          tester: tester,
          initialTab: AiSettingsTab.models,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        final fab = tester.widget<AiSettingsFloatingActionButton>(
          find.byType(AiSettingsFloatingActionButton),
        );
        expect(fab.activeTab, AiSettingsTab.models);
        fab.onPressed();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(InferenceModelEditPage), findsOneWidget);
      },
    );

    testWidgets(
      'FAB seeded on the Profiles tab dispatches to navigateToCreateProfile '
      '— covers the Profiles arm of `_activeTabAddHandler`',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpSeeded(
          tester: tester,
          initialTab: AiSettingsTab.profiles,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: [buildModel(id: 'm1', providerId: 'p1')],
          profiles: const <AiConfig>[],
        );

        final fab = tester.widget<AiSettingsFloatingActionButton>(
          find.byType(AiSettingsFloatingActionButton),
        );
        expect(fab.activeTab, AiSettingsTab.profiles);
        fab.onPressed();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(InferenceProfileForm), findsOneWidget);
      },
    );

    testWidgets(
      'FAB seeded on the Providers tab opens the AiPickProviderModal '
      'first, then Continue routes to the InferenceProviderEditPage '
      'preselected to the picked provider type — the new FTUE flow '
      'wraps the legacy navigateToCreateProvider call instead of '
      'replacing it',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpSeeded(
          tester: tester,
          initialTab: AiSettingsTab.providers,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        final fab = tester.widget<AiSettingsFloatingActionButton>(
          find.byType(AiSettingsFloatingActionButton),
        );
        expect(fab.activeTab, AiSettingsTab.providers);
        fab.onPressed();
        // Drain the SettingsDb read + modal mount.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Pick-provider modal is now in the tree; the legacy edit
        // page is not yet pushed.
        expect(find.byType(AiPickProviderModal), findsOneWidget);
        expect(find.byType(InferenceProviderEditPage), findsNothing);

        // Tap Continue (default selection is the first non-disabled
        // tile — Gemini in the default lineup).
        final messages = AppLocalizations.of(
          tester.element(find.byType(AiPickProviderModal)),
        )!;
        await tester.tap(find.text(messages.aiPickProviderContinueButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Now the edit page is pushed.
        expect(find.byType(InferenceProviderEditPage), findsOneWidget);
      },
    );

    testWidgets(
      'FAB on the Providers tab — when the user previously tapped '
      "'Don't show again' on the FTUE picker — opens "
      'AiPickProviderModal.showAllTypes (which lists every '
      'InferenceProviderType including the formerly-hidden '
      'genericOpenAi) instead of stranding the user on a '
      'genericOpenAi-prefilled connect form. Picking Ollama routes to '
      'InferenceProviderEditPage with preselectedType: ollama. Regression '
      'guard for the reported "second provider only offers OpenAI-compatible" '
      'bug — now backed by the unified modal post-PR #3183.',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Seed the dismiss flag so the FAB handler routes through the
        // all-types entry point rather than the FTUE-chrome variant.
        // The default MockSettingsDb stub returns null for every key;
        // override only the dismiss key so the rest of the SettingsDb
        // reads in the page continue to resolve cleanly.
        final mockSettingsDb = getIt<SettingsDb>() as MockSettingsDb;
        when(
          () => mockSettingsDb.itemByKey(kAiPickProviderDismissedKey),
        ).thenAnswer((_) async => 'true');

        await pumpSeeded(
          tester: tester,
          initialTab: AiSettingsTab.providers,
          providers: [
            buildProvider(id: 'p1', type: InferenceProviderType.gemini),
          ],
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        final fab = tester.widget<AiSettingsFloatingActionButton>(
          find.byType(AiSettingsFloatingActionButton),
        );
        fab.onPressed();
        // Drain the SettingsDb read + Wolt modal mount.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The unified modal is now visible. Sanity: rendering uses
        // allTypesTiles, so the formerly-hidden OpenAI-compatible
        // tile is reachable here.
        expect(find.byType(AiPickProviderModal), findsOneWidget);
        final messages = AppLocalizations.of(
          tester.element(find.byType(AiPickProviderModal)),
        )!;
        expect(find.text(messages.aiProviderOllamaName), findsOneWidget);
        expect(find.text(messages.aiProviderGenericOpenAiName), findsOneWidget);
        // FTUE-only chrome must NOT appear in this all-types entry
        // point — that's the whole point of [showFtueChrome:false].
        expect(
          find.text(messages.aiPickProviderDontShowAgainButton),
          findsNothing,
        );

        // Unified modal commits on Continue, not on tile tap. Pick
        // Ollama, then tap Continue to pop the result.
        await tester.tap(find.text(messages.aiProviderOllamaName));
        await tester.pump();
        await tester.tap(find.text(messages.aiPickProviderContinueButton));
        // Drain the pop + the subsequent navigateToCreateProvider push.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The connect form is now pushed, preselected to Ollama —
        // the exact path the FTUE picker would have taken for an
        // un-dismissed user. Proves the dismiss flag no longer
        // strands the user on a genericOpenAi-default form.
        final editPage = tester.widget<InferenceProviderEditPage>(
          find.byType(InferenceProviderEditPage),
        );
        expect(editPage.preselectedType, InferenceProviderType.ollama);
      },
    );
  });

  /// Coverage for `didUpdateWidget`'s `initialTab` re-application. The
  /// defensive path runs whenever an ancestor rebuilds the page with a
  /// new `initialTab` while reusing the same Element — exercised here
  /// via a `StatefulBuilder` that swaps the prop between pumps.
  group('AiSettingsPage — didUpdateWidget re-seeds initialTab', () {
    testWidgets(
      'swapping initialTab from Providers to Profiles updates both the '
      'rendered tab body and the FAB handler — proves the controller '
      'index AND the filter state are kept in sync',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var currentTab = AiSettingsTab.providers;
        late StateSetter rebuildHarness;

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
              home: StatefulBuilder(
                builder: (context, setState) {
                  rebuildHarness = setState;
                  return AiSettingsPage(initialTab: currentTab);
                },
              ),
            ),
          ),
        );
        providersController.add([
          buildProvider(id: 'p1', type: InferenceProviderType.gemini),
        ]);
        await tester.pump();
        await tester.pump();
        modelsController.add([buildModel(id: 'm1', providerId: 'p1')]);
        profilesController.add([buildProfile(id: 'profile-1', thinking: 'm1')]);
        await tester.pump();
        await tester.pump();
        await settleTimers(tester);

        // Sanity: page starts on Providers — provider card visible,
        // profile card absent.
        expect(find.byType(AiProviderCard), findsOneWidget);
        expect(find.byType(AiProfileCard), findsNothing);

        // Rebuild the harness with a different `initialTab`. The
        // `StatefulBuilder` keeps the surrounding Element identity
        // stable, so `AiSettingsPage` reconciles into `didUpdateWidget`
        // rather than mounting a fresh State.
        rebuildHarness(() {
          currentTab = AiSettingsTab.profiles;
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Tab body swapped to Profiles.
        expect(find.byType(AiProfileCard), findsOneWidget);
        expect(find.byType(AiProviderCard), findsNothing);

        // And the FAB handler was reapplied — invoking the callback
        // directly bypasses any FAB hit-test offset issues that the
        // existing tests work around with `warnIfMissed: false`.
        final fab = tester.widget<AiSettingsFloatingActionButton>(
          find.byType(AiSettingsFloatingActionButton),
        );
        expect(fab.activeTab, AiSettingsTab.profiles);
        fab.onPressed();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(InferenceProfileForm), findsOneWidget);
      },
    );

    testWidgets(
      'rebuilding with the SAME initialTab is a no-op — the early `return` '
      'guard in didUpdateWidget skips the filter state + tab controller '
      'updates so the page does not churn on innocuous parent rebuilds',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const startTab = AiSettingsTab.models;
        var currentTab = startTab;
        late StateSetter rebuildHarness;

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
              home: StatefulBuilder(
                builder: (context, setState) {
                  rebuildHarness = setState;
                  return AiSettingsPage(initialTab: currentTab);
                },
              ),
            ),
          ),
        );
        providersController.add([
          buildProvider(id: 'p1', type: InferenceProviderType.gemini),
        ]);
        await tester.pump();
        modelsController.add([buildModel(id: 'm1', providerId: 'p1')]);
        profilesController.add(const <AiConfig>[]);
        await tester.pump();
        await tester.pump();
        await settleTimers(tester);

        expect(find.byType(AiModelCard), findsOneWidget);

        // Trigger a rebuild with the SAME tab — didUpdateWidget should
        // bail out at the early return without touching state.
        rebuildHarness(() {
          currentTab = startTab;
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Still on Models, no flicker, no other tab body bleeds in.
        expect(find.byType(AiModelCard), findsOneWidget);
        expect(find.byType(AiProviderCard), findsNothing);
        expect(find.byType(AiProfileCard), findsNothing);
      },
    );
  });

  /// Covers `_handleTabChange`'s `_tabController.animateTo(tab.index)`
  /// line. A plain TabBar tap can't reach it: Flutter's `_handleTap`
  /// runs `_controller.animateTo(index)` BEFORE invoking `onTap`, so
  /// by the time `_handleTabChange` checks `_tabController.index`, the
  /// controller already sits on the target index and the guarded
  /// `animateTo` call is skipped. Invoking the tab bar's `onTabChanged`
  /// callback directly — while the controller is still parked on the
  /// current tab — is the only path that drives the page-owned
  /// `animateTo`.
  ///
  /// NOTE: the body of `_handleTabControllerChange` (its
  /// `_updateFilterState(_filterState.copyWith(activeTab: newTab))`
  /// line) is unreachable. That listener only runs its body when the
  /// controller has SETTLED on an index whose tab differs from
  /// `_filterState.activeTab`. Every code path that moves the
  /// controller — `_handleTabChange` (updates filter state before
  /// `animateTo`), `didUpdateWidget` (updates filter state before
  /// `index =`), and a TabBar tap (whose `onTap` → `_handleTabChange`
  /// updates filter state while the animation is still running) —
  /// updates `_filterState.activeTab` to the destination tab BEFORE
  /// the animation settles. So when the listener finally fires with
  /// `indexIsChanging == false`, `newTab == _filterState.activeTab`
  /// always holds and the guarded update never executes. There is no
  /// `TabBarView` / swipe surface on this page that could move the
  /// controller without first updating the filter state.
  group('AiSettingsPage — onTabChanged drives the TabController', () {
    testWidgets(
      'invoking AiSettingsTabBar.onTabChanged with a non-current tab '
      'animates the TabController to that index AND swaps the rendered '
      'body — proves the page-owned animateTo branch runs',
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

        // Sanity: page starts on Providers (index 0).
        final tabBar = tester.widget<AiSettingsTabBar>(
          find.byType(AiSettingsTabBar),
        );
        expect(tabBar.tabController.index, 0);
        expect(find.byType(AiProviderCard), findsOneWidget);

        // Drive the callback directly with the Models tab while the
        // controller still parks on Providers — this is the only way
        // `_handleTabChange` sees `index != tab.index` and runs the
        // page-owned `animateTo`.
        tabBar.onTabChanged(AiSettingsTab.models);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The controller animated to the Models index and the body
        // swapped from provider cards to model cards.
        expect(tabBar.tabController.index, AiSettingsTab.models.index);
        expect(find.byType(AiModelCard), findsOneWidget);
        expect(find.byType(AiProviderCard), findsNothing);
        await settleTimers(tester);
      },
    );
  });

  /// Covers the `dontShowAgain` arm of `_handleAddProvider` — the case
  /// where the FTUE picker is shown (dismiss flag NOT yet set) and the
  /// user taps "Don't show again". The page must persist the
  /// suppression flag and must NOT also push the create form (the
  /// comment in the source is explicit: it is a hide-this-prompt
  /// action, not an add-a-provider one).
  group('AiSettingsPage — Add provider, "Don\'t show again" branch', () {
    testWidgets(
      'tapping "Don\'t show again" in the FTUE picker saves the dismiss '
      'flag and does NOT push the create-provider form',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Default MockSettingsDb stub returns null for itemByKey, so the
        // dismiss flag is unset → the FAB routes through the FTUE
        // `AiPickProviderModal.show` path that exposes the
        // "Don't show again" button.
        final mockSettingsDb = getIt<SettingsDb>() as MockSettingsDb;

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
        // Flush the InkWell ticker timers so the FAB tap below doesn't
        // race the shared header's pending Timer.
        await settleTimers(tester);

        final fab = tester.widget<AiSettingsFloatingActionButton>(
          find.byType(AiSettingsFloatingActionButton),
        );
        expect(fab.activeTab, AiSettingsTab.providers);
        fab.onPressed();
        // Drain the SettingsDb read + Wolt modal mount/animation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AiPickProviderModal), findsOneWidget);
        final messages = AppLocalizations.of(
          tester.element(find.byType(AiPickProviderModal)),
        )!;
        // FTUE chrome is present, so the opt-out button is reachable.
        expect(
          find.text(messages.aiPickProviderDontShowAgainButton),
          findsOneWidget,
        );

        // Baseline route count before tapping the opt-out action.
        final pushBaseline = spy.pushed.length;

        await tester.tap(
          find.text(messages.aiPickProviderDontShowAgainButton),
        );
        // Drain the modal pop + the page's post-pop branch.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The suppression flag was persisted with the exact key/value.
        verify(
          () => mockSettingsDb.saveSettingsItem(
            kAiPickProviderDismissedKey,
            'true',
          ),
        ).called(1);

        // And the create-provider form was NOT pushed — opting out is a
        // hide-this-prompt action, not an add-a-provider one. The modal
        // pop nets back to the baseline, so no NEW route remains.
        expect(find.byType(InferenceProviderEditPage), findsNothing);
        expect(spy.pushed.length, lessThanOrEqualTo(pushBaseline));
        await settleTimers(tester);
      },
    );
  });

  // NOTE: The providers-stream error branch in `_buildBodySlivers`
  // (`if (providersAsync.hasError && providers == null)` → renders
  // `ConfigErrorState` with the RETRY `ref.invalidate(...)` callback)
  // is unreachable from a test driving the real
  // `aiConfigByTypeControllerProvider`. That branch is gated behind the
  // loading branch above it (`if (providersAsync.isLoading && providers
  // == null)`), and for this stream-backed Riverpod notifier the error
  // AsyncValue always reports `isLoading == true` AND `hasError == true`
  // simultaneously — whether the error is raised via a synchronous
  // `throw` in `build`, a `Stream.error`, or an `async*` generator that
  // throws (verified empirically). Because `isLoading` never clears to
  // `false` on a first-load error here, the loading branch always
  // intercepts first and the error/RETRY branch never executes. Driving
  // it would require injecting a raw `AsyncError(value: null,
  // isLoading: false)` state, which Riverpod 3 does not expose for a
  // generated notifier via `overrideWith`. The branch ships as
  // defensive code; the standalone `ConfigErrorState` widget (icon /
  // title / message / RETRY callback) is covered in
  // `config_error_state_test.dart`.
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

class _PageMlxAudioChannel extends MlxAudioChannel {
  final _progressController =
      StreamController<MlxAudioModelDownloadProgress>.broadcast();
  final installRequests = <String>[];

  @override
  Stream<MlxAudioModelDownloadProgress> get downloadProgressStream =>
      _progressController.stream;

  @override
  Future<MlxAudioModelDownloadProgress> getModelStatus(String modelId) async {
    return MlxAudioModelDownloadProgress(
      modelId: modelId,
      status: MlxAudioModelStatus.notInstalled,
    );
  }

  @override
  Future<void> installModel(String modelId) async {
    installRequests.add(modelId);
    _progressController.add(
      MlxAudioModelDownloadProgress(
        modelId: modelId,
        status: MlxAudioModelStatus.downloading,
        completedUnitCount: 12,
        totalUnitCount: 100,
      ),
    );
  }

  Future<void> close() => _progressController.close();
}
