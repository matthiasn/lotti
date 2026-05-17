import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show CascadeDeletionResult, aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_page.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  late MockAiConfigRepository mockRepository;
  late StreamController<List<AiConfig>> modelsController;
  late StreamController<List<AiConfig>> profilesController;
  late StreamController<List<AiConfig>> providersController;

  AiConfigInferenceProvider buildProvider({
    String id = 'provider-1',
    InferenceProviderType type = InferenceProviderType.gemini,
    String name = 'Gemini',
    String apiKey = 'sk-test-1234abcd',
    String baseUrl = 'https://generativelanguage.googleapis.com',
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
    String providerModelId = 'gemini-pro',
    bool isReasoning = false,
  }) {
    return AiConfigModel(
      id: id,
      name: name,
      providerModelId: providerModelId,
      inferenceProviderId: providerId,
      createdAt: DateTime(2024, 3, 15),
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: isReasoning,
    );
  }

  AiConfigInferenceProfile buildProfile({
    String id = 'profile-1',
    String name = 'Default profile',
    String? description = 'Routes thinking to gemini-pro',
    bool isDefault = false,
    String thinking = 'gemini-pro',
    String? imageRecognition,
    String? transcription,
    String? imageGeneration,
  }) {
    return AiConfigInferenceProfile(
      id: id,
      name: name,
      description: description,
      isDefault: isDefault,
      thinkingModelId: thinking,
      imageRecognitionModelId: imageRecognition,
      transcriptionModelId: transcription,
      imageGenerationModelId: imageGeneration,
      createdAt: DateTime(2024, 3, 15),
    );
  }

  setUpAll(registerAllFallbackValues);

  late MockNavService mockNavService;

  setUp(() async {
    mockRepository = MockAiConfigRepository();
    await setUpTestGetIt();

    // The detail page reads `getIt<NavService>().desktopSelectedSettingsRoute`
    // when the focus-flow fires (to decide whether to clean
    // `?focusApiKey=true` from the URL); the model/profile-card taps
    // also route through `nav_service.beamToNamed` for the desktop
    // master/detail panel swap. Both call into the singleton, so we
    // mock it here with a no-op `beamToNamed` and a notifier whose
    // value is null (i.e. "not URL-mounted, no query to clean").
    mockNavService = MockNavService();
    when(
      () => mockNavService.desktopSelectedSettingsRoute,
    ).thenReturn(ValueNotifier<DesktopSettingsRoute?>(null));
    when(() => mockNavService.beamToNamed(any())).thenReturn(null);
    getIt.registerSingleton<NavService>(mockNavService);

    modelsController = StreamController<List<AiConfig>>.broadcast();
    profilesController = StreamController<List<AiConfig>>.broadcast();
    providersController = StreamController<List<AiConfig>>.broadcast();

    when(
      () => mockRepository.watchConfigsByType(AiConfigType.model),
    ).thenAnswer((_) => modelsController.stream);
    when(
      () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
    ).thenAnswer((_) => providersController.stream);
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
    await modelsController.close();
    await profilesController.close();
    await providersController.close();
    await tearDownTestGetIt();
  });

  Widget buildHarness({
    required String providerId,
    bool focusApiKey = false,
    List<NavigatorObserver> navigatorObservers = const [],
  }) {
    return ProviderScope(
      overrides: [aiConfigRepositoryProvider.overrideWithValue(mockRepository)],
      child: MaterialApp(
        navigatorObservers: navigatorObservers,
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
        home: AiProviderDetailPage(
          providerId: providerId,
          focusApiKey: focusApiKey,
        ),
      ),
    );
  }

  Future<void> pumpWith({
    required WidgetTester tester,
    required AiConfigInferenceProvider? provider,
    required List<AiConfig> models,
    required List<AiConfig> profiles,
    bool focusApiKey = false,
    List<NavigatorObserver> navigatorObservers = const [],
  }) async {
    when(
      () => mockRepository.getConfigById(provider?.id ?? 'provider-1'),
    ).thenAnswer((_) async => provider);

    await tester.pumpWidget(
      buildHarness(
        providerId: provider?.id ?? 'provider-1',
        focusApiKey: focusApiKey,
        navigatorObservers: navigatorObservers,
      ),
    );
    await tester.pump();
    // Drain the async getConfigById Future before pushing stream events.
    await tester.pump(const Duration(milliseconds: 50));
    modelsController.add(models);
    profilesController.add(profiles);
    await tester.pump();
    await tester.pump();
  }

  // The page mounts InkWells; advance time so their tickers settle and
  // Flutter's pending-timer guard doesn't trip on teardown.
  Future<void> settleTimers(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  group('AiProviderDetailPage', () {
    testWidgets('renders loading indicator while config future is pending', (
      tester,
    ) async {
      final completer = Completer<AiConfig?>();
      when(
        () => mockRepository.getConfigById('provider-1'),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildHarness(providerId: 'provider-1'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Complete the future so the page's pending work flushes before teardown.
      completer.complete(buildProvider());
      await tester.pumpAndSettle();
    });

    testWidgets('renders the load-error message when getConfigById throws', (
      tester,
    ) async {
      when(
        () => mockRepository.getConfigById('provider-1'),
      ).thenThrow(Exception('boom'));

      await tester.pumpWidget(buildHarness(providerId: 'provider-1'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not load this provider. Try again from the AI Settings list.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders the missing-provider message when the config is not an '
      'AiConfigInferenceProvider (e.g. row deleted)',
      (tester) async {
        await pumpWith(
          tester: tester,
          provider: null,
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        expect(
          find.text('This provider is no longer available.'),
          findsOneWidget,
        );
        // No edit pencil in the AppBar when there is no provider to edit.
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
      },
    );

    testWidgets(
      'header strip renders the provider display name and connection sections',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider(name: 'My Gemini');
        await pumpWith(
          tester: tester,
          provider: provider,
          models: [buildModel(id: 'm1', providerId: provider.id)],
          profiles: const <AiConfig>[],
        );

        expect(find.text('Provider details'), findsOneWidget);
        // Header strip + connection row both show the configured name.
        expect(find.text('My Gemini'), findsNWidgets(2));
        // Connection section labels.
        expect(find.text('Connection'), findsOneWidget);
        expect(find.text('API key'), findsOneWidget);
        expect(find.text('Base URL'), findsOneWidget);
        // Mask preserves the last four characters of the API key.
        expect(find.text('•••• abcd'), findsOneWidget);
        // The configured base URL renders verbatim.
        expect(
          find.text('https://generativelanguage.googleapis.com'),
          findsOneWidget,
        );
        // AppBar edit pencil exists for a valid provider.
        expect(find.byIcon(Icons.edit_outlined), findsAtLeastNWidgets(1));

        await settleTimers(tester);
      },
    );

    testWidgets(
      'hides the API key row for providers that do not require a key (Ollama)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final ollama = buildProvider(
          id: 'ollama-1',
          type: InferenceProviderType.ollama,
          name: 'Local Ollama',
          apiKey: '',
          baseUrl: 'http://localhost:11434',
        );
        await pumpWith(
          tester: tester,
          provider: ollama,
          models: [buildModel(id: 'm1', providerId: ollama.id)],
          profiles: const <AiConfig>[],
        );

        // Connection section is still present but skips the API key row.
        expect(find.text('Connection'), findsOneWidget);
        expect(find.text('API key'), findsNothing);
        expect(find.text('Base URL'), findsOneWidget);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'connection rows show short masked keys (≤4 chars) entirely as dots',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final shortKey = buildProvider(apiKey: 'abc');
        await pumpWith(
          tester: tester,
          provider: shortKey,
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        expect(find.text('•••'), findsOneWidget);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'models section shows the empty-state card when the provider owns no '
      'models',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpWith(
          tester: tester,
          provider: buildProvider(),
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        expect(find.text('Models'), findsOneWidget);
        expect(
          find.text('No models yet. Add one to start using this provider.'),
          findsOneWidget,
        );
        // No model cards are rendered.
        expect(find.byType(AiModelCard), findsNothing);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'models section renders one AiModelCard per owned model and a count tail',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        await pumpWith(
          tester: tester,
          provider: provider,
          models: [
            buildModel(
              id: 'm1',
              providerId: provider.id,
              name: 'Model One',
              providerModelId: 'm-one',
            ),
            buildModel(
              id: 'm2',
              providerId: provider.id,
              name: 'Model Two',
              providerModelId: 'm-two',
            ),
            // A model that belongs to a different provider must not appear.
            buildModel(
              id: 'm3',
              providerId: 'other-provider',
              name: 'Model Three',
              providerModelId: 'm-three',
            ),
          ],
          profiles: const <AiConfig>[],
        );

        expect(find.byType(AiModelCard), findsNWidgets(2));
        expect(find.text('Model One'), findsOneWidget);
        expect(find.text('Model Two'), findsOneWidget);
        expect(find.text('Model Three'), findsNothing);
        // Section heading shows the count for non-zero variants.
        expect(find.text('Models · 2'), findsOneWidget);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'active profile section appears when a default profile references one '
      "of the provider's models",
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        // `buildModel` and `buildProfile` both default the providerModelId /
        // thinking slot to 'gemini-pro' — the goal here is for the profile's
        // thinking slot to resolve to one of the provider's models.
        final model = buildModel(id: 'm1', providerId: provider.id);
        final defaultProfile = buildProfile(
          id: 'p-default',
          isDefault: true,
        );

        await pumpWith(
          tester: tester,
          provider: provider,
          models: [model],
          profiles: [defaultProfile],
        );

        expect(find.text('Active profile'), findsOneWidget);
        expect(find.text('Default profile'), findsOneWidget);
        expect(find.byType(AiProfileCard), findsOneWidget);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'active profile summary resolves slots against every configured model',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mlxProvider = buildProvider(
          type: InferenceProviderType.mlxAudio,
          name: 'MLX Audio',
          apiKey: '',
          baseUrl: '',
        );
        final transcriptionModel = buildModel(
          id: 'm-stt',
          providerId: mlxProvider.id,
          name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
          providerModelId: 'mlx-community/Qwen3-ASR-1.7B-8bit',
        );
        final thinkingModel = buildModel(
          id: 'm-thinking',
          providerId: 'provider-ollama',
          name: 'Qwen 3.6 35B-A3B Coding (NVFP4)',
          providerModelId: 'qwen3.6:35b-a3b-coding',
        );
        final profile = buildProfile(
          id: 'p-local',
          name: 'Local (Ollama)',
          isDefault: true,
          thinking: thinkingModel.providerModelId,
          transcription: transcriptionModel.providerModelId,
        );

        await pumpWith(
          tester: tester,
          provider: mlxProvider,
          models: [transcriptionModel, thinkingModel],
          profiles: [profile],
        );

        expect(find.text('Active profile'), findsOneWidget);
        expect(find.text('Local (Ollama)'), findsOneWidget);
        expect(find.text('Qwen 3.6 35B-A3B Coding (NVFP4)'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AiProfileCard),
            matching: find.text('Qwen3 ASR 1.7B (MLX 8-bit)'),
          ),
          findsOneWidget,
        );
        expect(find.text('missing'), findsNothing);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'active profile section is omitted when no profile references any of '
      "the provider's models",
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        final orphanedProfile = buildProfile(
          id: 'p-other',
          name: 'Other profile',
          isDefault: true,
          thinking: 'some-other-model-id',
        );

        await pumpWith(
          tester: tester,
          provider: provider,
          models: [buildModel(id: 'm1', providerId: provider.id)],
          profiles: [orphanedProfile],
        );

        expect(find.text('Active profile'), findsNothing);
        expect(find.text('Other profile'), findsNothing);
        expect(find.byType(AiProfileCard), findsNothing);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'active profile picker falls back to the first matching profile when '
      'no default profile touches the provider',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        // Both builders default the providerModelId / thinking slot to
        // 'gemini-pro', so the non-default profile naturally targets one of
        // the provider's models.
        final ownedModel = buildModel(id: 'm1', providerId: provider.id);
        final defaultButOrphaned = buildProfile(
          id: 'p-default',
          name: 'Default elsewhere',
          isDefault: true,
          thinking: 'unrelated-model',
        );
        final nonDefaultButMatches = buildProfile(
          id: 'p-match',
          name: 'Touches Gemini',
        );

        await pumpWith(
          tester: tester,
          provider: provider,
          models: [ownedModel],
          profiles: [defaultButOrphaned, nonDefaultButMatches],
        );

        // The non-default profile wins because it actually references one
        // of the provider's models.
        expect(find.text('Touches Gemini'), findsOneWidget);
        expect(find.text('Default elsewhere'), findsNothing);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'danger zone removes the provider via the delete service and pops the '
      'page',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        when(
          () => mockRepository.deleteInferenceProviderWithModels(provider.id),
        ).thenAnswer(
          (_) async => const CascadeDeletionResult(
            deletedModels: <AiConfigModel>[],
            providerName: 'Gemini',
          ),
        );

        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          provider: provider,
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          navigatorObservers: [spy],
        );

        // The remove button lives in the Danger zone card.
        expect(find.text('Remove provider'), findsOneWidget);
        await tester.ensureVisible(find.text('Remove provider'));
        await tester.tap(find.text('Remove provider'));
        await tester.pumpAndSettle();

        // Delete service shows its own confirmation dialog. Tap through it
        // by finding the dialog's destructive action. The button text comes
        // from AiConfigDeleteService — guard the path with a robust matcher.
        final confirmButton = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(FilledButton),
        );
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton.first);
          await tester.pumpAndSettle();
        }

        verify(
          () => mockRepository.deleteInferenceProviderWithModels(provider.id),
        ).called(1);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'AppBar edit pencil pushes the InferenceProviderEditPage',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          provider: provider,
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          navigatorObservers: [spy],
        );

        // Initial push is the detail page itself.
        expect(spy.pushed, hasLength(1));

        // Two `edit_outlined` icons exist on the page (AppBar pencil and the
        // Connection section's `Edit` button); target the AppBar entry by
        // its tooltip.
        await tester.tap(find.byTooltip('Edit provider'));
        // Don't pumpAndSettle — the destination page may be busy fetching;
        // a single pump is enough for the push to register with the
        // observer.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(spy.pushed.length, greaterThanOrEqualTo(2));
        await settleTimers(tester);
      },
    );

    testWidgets(
      'focusApiKey=true auto-pushes the edit form after the config resolves',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          provider: provider,
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          focusApiKey: true,
          navigatorObservers: [spy],
        );

        // Initial push (detail page) + automatic Fix-flow push (edit page).
        expect(spy.pushed.length, greaterThanOrEqualTo(2));
        await settleTimers(tester);
      },
    );

    testWidgets(
      'focusApiKey=true with the desktop URL still carrying the '
      '?focusApiKey=true query beams to the same path WITHOUT the query — '
      'so a later remount (panel swap, back-nav, hot reload) does not '
      're-open the edit form unprompted',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Stand the desktop route notifier on the URL the page would
        // have been mounted from in production (with the Fix-flow query
        // present). The detail page reads this to decide whether to
        // beam the cleaned URL.
        when(() => mockNavService.desktopSelectedSettingsRoute).thenReturn(
          ValueNotifier<DesktopSettingsRoute?>(
            (
              path: '/settings/ai/provider/provider-1',
              pathParameters: const <String, String>{
                'providerId': 'provider-1',
              },
              queryParameters: const <String, String>{'focusApiKey': 'true'},
            ),
          ),
        );

        final provider = buildProvider();
        await pumpWith(
          tester: tester,
          provider: provider,
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          focusApiKey: true,
        );
        await settleTimers(tester);

        verify(
          () => mockNavService.beamToNamed(
            '/settings/ai/provider/provider-1',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'focusApiKey=true with no desktop URL state (mobile or test direct '
      'mount) still pushes the edit form but does NOT beam — there is no '
      'URL to clean in that case, so the URL-cleanup branch is skipped',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          provider: provider,
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          focusApiKey: true,
          navigatorObservers: [spy],
        );
        await settleTimers(tester);

        // Detail page push + edit form push.
        expect(spy.pushed.length, greaterThanOrEqualTo(2));
        // No beam fired — the desktop route notifier value was null
        // (the default in setUp), so the URL-clean branch is a no-op.
        verifyNever(() => mockNavService.beamToNamed(any()));
      },
    );

    testWidgets(
      'focusApiKey=true with the desktop URL present but WITHOUT the '
      '?focusApiKey=true query also skips the beam — the cleanup is gated '
      'on the query actually being there, not on URL presence alone',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockNavService.desktopSelectedSettingsRoute).thenReturn(
          ValueNotifier<DesktopSettingsRoute?>(
            (
              path: '/settings/ai/provider/provider-1',
              pathParameters: const <String, String>{
                'providerId': 'provider-1',
              },
              queryParameters: const <String, String>{},
            ),
          ),
        );

        final provider = buildProvider();
        await pumpWith(
          tester: tester,
          provider: provider,
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          focusApiKey: true,
        );
        await settleTimers(tester);

        verifyNever(() => mockNavService.beamToNamed(any()));
      },
    );

    testWidgets(
      'tapping the "Add model" button pushes a new route',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          provider: buildProvider(),
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          navigatorObservers: [spy],
        );

        expect(spy.pushed, hasLength(1));

        await tester.tap(find.text('Add model'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(spy.pushed.length, greaterThanOrEqualTo(2));
        await settleTimers(tester);
      },
    );

    testWidgets(
      'tapping a model card beams to the per-model URL — model rows go '
      'through the desktop master/detail panel swap, not Navigator.push',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        await pumpWith(
          tester: tester,
          provider: provider,
          models: [
            buildModel(
              id: 'm1',
              providerId: provider.id,
            ),
          ],
          profiles: const <AiConfig>[],
        );

        await tester.tap(find.byType(AiModelCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => mockNavService.beamToNamed('/settings/ai/model/m1'),
        ).called(1);
        await settleTimers(tester);
      },
    );

    testWidgets(
      'tapping the active-profile card beams to the per-profile URL — '
      'profile rows go through the desktop master/detail panel swap, not '
      'Navigator.push',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        await pumpWith(
          tester: tester,
          provider: provider,
          models: [buildModel(id: 'm1', providerId: provider.id)],
          profiles: [buildProfile(isDefault: true)],
        );

        await tester.ensureVisible(find.byType(AiProfileCard));
        await tester.tap(find.byType(AiProfileCard));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => mockNavService.beamToNamed('/settings/ai/profile/profile-1'),
        ).called(1);
        await settleTimers(tester);
      },
    );

    testWidgets(
      'tapping the Connection card Edit button pushes the edit form',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final spy = _PushSpy();
        await pumpWith(
          tester: tester,
          provider: buildProvider(),
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
          navigatorObservers: [spy],
        );

        expect(spy.pushed, hasLength(1));

        // The Edit button on the Connection card renders the "Edit"
        // label; the AppBar pencil is icon-only. Tap by text to avoid
        // hitting the pencil.
        await tester.tap(find.text('Edit'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(spy.pushed.length, greaterThanOrEqualTo(2));
        await settleTimers(tester);
      },
    );

    testWidgets(
      'header strip status pill renders "Invalid key" for a cloud '
      'provider with an empty API key',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Cloud provider with blank API key → invalidKey status, which
        // drives the header strip pill into the alert/error branch.
        await pumpWith(
          tester: tester,
          provider: buildProvider(
            type: InferenceProviderType.openAi,
            name: 'OpenAI',
            apiKey: '',
          ),
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        expect(find.text('Invalid key'), findsOneWidget);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'connection rows substitute the "Not set" placeholder when the '
      'base URL and display name are empty',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Provider with present API key but empty baseUrl + empty name.
        // Tests the `_ConnectionRow` "Not set" branch for both fields
        // and the header strip's fallback to the localized provider
        // display name (`visual.displayName`).
        final provider = buildProvider(
          name: '',
          baseUrl: '',
        );

        await pumpWith(
          tester: tester,
          provider: provider,
          models: const <AiConfig>[],
          profiles: const <AiConfig>[],
        );

        // Both unset rows show the localized placeholder.
        expect(find.text('Not set'), findsNWidgets(2));
        // Header strip falls back to the Gemini provider display name.
        expect(find.text('Google Gemini'), findsOneWidget);

        await settleTimers(tester);
      },
    );

    testWidgets(
      'AppBar back arrow routes through popAiSettingsDetail — when the '
      'page is pushed onto a navigator, tapping the arrow pops the route '
      'and the outer launcher button is visible again (proves the leading '
      "IconButton is wired to the shared back affordance, not Material's "
      'default `Navigator.maybePop()` which would no-op on desktop '
      'master/detail).',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final provider = buildProvider();
        when(
          () => mockRepository.getConfigById('provider-1'),
        ).thenAnswer((_) async => provider);

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
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AiProviderDetailPage(
                            providerId: 'provider-1',
                          ),
                        ),
                      ),
                      child: const Text('open-provider-detail'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open-provider-detail'));
        await tester.pumpAndSettle();
        // Drain the async getConfigById future + the stream-fed model
        // and profile lists.
        modelsController.add(const <AiConfig>[]);
        profilesController.add(const <AiConfig>[]);
        await tester.pumpAndSettle();

        // The detail page is now mounted.
        expect(find.byType(AiProviderDetailPage), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // After back-tap the route should have popped: outer button
        // visible again, detail page gone.
        expect(find.text('open-provider-detail'), findsOneWidget);
        expect(find.byType(AiProviderDetailPage), findsNothing);

        await settleTimers(tester);
      },
    );
  });
}

class _PushSpy extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}
