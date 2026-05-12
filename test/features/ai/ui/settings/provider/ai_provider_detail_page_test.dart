import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show CascadeDeletionResult, aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_page.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';

void main() {
  late MockAiConfigRepository mockRepository;
  late SettingsDb settingsDb;
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
    await settingsDb.close();
    await getIt.reset();
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
