import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/inference_model_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/provider_selection_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Mock repository implementation
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

/// Mock state for InferenceModelForm - useful for defining state structure for the fake
class MockInferenceModelFormState extends Mock
    implements InferenceModelFormState {}

// Mock for NavigatorObserver
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

// Fake Route for Mocktail fallback
class FakeRoute<T> extends Fake implements Route<T> {}

/// Fake controller for InferenceModelForm
class FakeInferenceModelFormController extends InferenceModelFormController {
  InferenceModelFormState? _initialStateForBuild =
      InferenceModelFormState(); // Default initial state
  List<String?> inferenceProviderIdChangedCalls = [];

  // Called by tests to set the state that build() will use
  // ignore: use_setters_to_change_properties
  void setInitialStateForBuild(InferenceModelFormState? newState) {
    _initialStateForBuild = newState;
  }

  // Call this AFTER the widget is pumped and Riverpod has built the notifier, to emit a new state
  void emitNewStateForTest(InferenceModelFormState? newState) {
    // This assumes Riverpod has called build() and super.state (the inherited setter) is safe to use.
    state = AsyncData<InferenceModelFormState?>(newState);
  }

  @override
  Future<InferenceModelFormState?> build({required String? configId}) async {
    // Explicitly set the state that Riverpod will expose, based on what was prepared.
    // Riverpod should do this from the return value, but being explicit can help in fakes.
    state = AsyncData<InferenceModelFormState?>(_initialStateForBuild);
    return _initialStateForBuild;
  }

  @override
  void inferenceProviderIdChanged(String? id) {
    inferenceProviderIdChangedCalls.add(id);
    // After build, we can safely use the inherited state setter
    if (state.value != null) {
      // Check if current state has a value
      final newState = state.value!.copyWith(inferenceProviderId: id);
      state = AsyncData<InferenceModelFormState?>(
        newState,
      ); // Use the inherited 'state' setter
    } else {
      // Fallback: if state.value is null (e.g. initial build hasn't completed or was null)
      // This might happen if build returned null and then this is called.
      // For safety, update _initialStateForBuild and try to set state.
      _initialStateForBuild =
          _initialStateForBuild?.copyWith(inferenceProviderId: id) ??
              InferenceModelFormState(inferenceProviderId: id ?? '');
      state = AsyncData<InferenceModelFormState?>(_initialStateForBuild);
    }
  }

  // Minimal implementation of other methods from InferenceModelFormController
  @override
  TextEditingController get nameController => TextEditingController();
  @override
  TextEditingController get providerModelIdController =>
      TextEditingController();

  @override
  TextEditingController get descriptionController => TextEditingController();
  @override
  void nameChanged(String name) {}
  @override
  void providerModelIdChanged(String value) {}
  @override
  void descriptionChanged(String description) {}
  @override
  void inputModalitiesChanged(List<Modality> modalities) {}
  @override
  void outputModalitiesChanged(List<Modality> modalities) {}
  @override
  void isReasoningModelChanged(bool value) {}

  @override
  Future<void> addConfig(AiConfig config) async {}
  @override
  Future<void> updateConfig(AiConfig config) async {}
  @override
  Future<void> deleteConfig(String id) async {}
  @override
  void reset() {}
}

void main() {
  // setUpAll for Mocktail fallbacks
  setUpAll(() {
    registerFallbackValue(FakeRoute<dynamic>());
  });

  late MockAiConfigRepository mockRepository;
  late MockInferenceModelFormState mockInferenceModelFormState;
  late MockNavigatorObserver mockNavigatorObserver;

  setUp(() {
    mockRepository = MockAiConfigRepository();
    mockInferenceModelFormState = MockInferenceModelFormState();
    mockNavigatorObserver = MockNavigatorObserver();

    when(() => mockInferenceModelFormState.inferenceProviderId).thenReturn('');
    when(() => mockInferenceModelFormState.name)
        .thenReturn(const ModelName.pure());
    when(() => mockInferenceModelFormState.providerModelId)
        .thenReturn(const ProviderModelId.pure());
    when(() => mockInferenceModelFormState.description)
        .thenReturn(const ModelDescription.pure());
    when(() => mockInferenceModelFormState.inputModalities)
        .thenReturn(const [Modality.text]);
    when(() => mockInferenceModelFormState.outputModalities)
        .thenReturn(const [Modality.text]);
    when(() => mockInferenceModelFormState.isReasoningModel).thenReturn(false);
    when(() => mockInferenceModelFormState.isSubmitting).thenReturn(false);
    when(() => mockInferenceModelFormState.submitFailed).thenReturn(false);
    when(
      () => mockInferenceModelFormState.copyWith(
        id: any(named: 'id'),
        name: any(named: 'name'),
        providerModelId: any(named: 'providerModelId'),
        description: any(named: 'description'),
        inferenceProviderId: any(named: 'inferenceProviderId'),
        inputModalities: any(named: 'inputModalities'),
        outputModalities: any(named: 'outputModalities'),
        isReasoningModel: any(named: 'isReasoningModel'),
        isSubmitting: any(named: 'isSubmitting'),
        submitFailed: any(named: 'submitFailed'),
      ),
    ).thenReturn(mockInferenceModelFormState);
  });

  Widget buildTestWidget({
    required String? configId,
    required MockAiConfigRepository repository,
    required FakeInferenceModelFormController formController,
    NavigatorObserver? navigatorObserver,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
      home: Scaffold(
        body: ProviderScope(
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(repository),
            inferenceModelFormControllerProvider(configId: configId)
                .overrideWith(() => formController),
          ],
          child: ProviderSelectionModal(configId: configId),
        ),
      ),
    );
  }

  List<AiConfig> createMockProviders({int count = 3}) {
    return List.generate(
      count,
      (index) => AiConfig.inferenceProvider(
        id: 'provider-$index',
        baseUrl: 'https://example.com/$index',
        apiKey: 'api-key-$index',
        name: 'Provider $index',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
        description: index.isEven ? 'Description for provider $index' : null,
      ),
    );
  }

  group('ProviderSelectionModal', () {
    testWidgets('displays list of providers when data is loaded',
        (WidgetTester tester) async {
      final fakeFormController = FakeInferenceModelFormController()
        ..setInitialStateForBuild(InferenceModelFormState());

      final mockProviders = createMockProviders();
      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.value(mockProviders));

      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
          formController: fakeFormController,
        ),
      );
      await tester.pumpAndSettle();

      for (final provider in mockProviders) {
        expect(find.text(provider.name), findsOneWidget);
        if (provider.maybeMap(
          inferenceProvider: (p) => p.description != null,
          orElse: () => false,
        )) {
          expect(
            find.text(
              provider.maybeMap(
                inferenceProvider: (p) => p.description!,
                orElse: () => '',
              ),
            ),
            findsOneWidget,
          );
        } else {
          expect(
            find.text(
              provider.maybeMap(
                inferenceProvider: (p) => p.baseUrl,
                orElse: () => '',
              ),
            ),
            findsOneWidget,
          );
        }
      }
    });

    testWidgets('displays loading indicator when data is loading',
        (WidgetTester tester) async {
      final fakeFormController = FakeInferenceModelFormController()
        ..setInitialStateForBuild(InferenceModelFormState());

      final completer = Completer<List<AiConfig>>();
      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.fromFuture(completer.future));

      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
          formController: fakeFormController,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.complete([]);
      await tester.pump();
    });

    testWidgets('displays error message when loading fails',
        (WidgetTester tester) async {
      final fakeFormController = FakeInferenceModelFormController()
        ..setInitialStateForBuild(InferenceModelFormState());

      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.error(Exception('Test error')));

      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
          formController: fakeFormController,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Error loading configurations'),
        findsOneWidget,
      );
      expect(find.textContaining('Test error'), findsOneWidget);
    });

    testWidgets('displays message when no providers are available',
        (WidgetTester tester) async {
      final fakeFormController = FakeInferenceModelFormController()
        ..setInitialStateForBuild(InferenceModelFormState());

      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
          formController: fakeFormController,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No API providers available. Please add an API provider first.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays checkmark for selected provider',
        (WidgetTester tester) async {
      final fakeFormController = FakeInferenceModelFormController();
      final mockProviders = createMockProviders();
      const providerIdInParentForm = 'config-for-parent-form';
      const selectedProviderInModal = 'provider-1';

      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.value(mockProviders));

      fakeFormController.setInitialStateForBuild(
        InferenceModelFormState(
          inferenceProviderId: selectedProviderInModal,
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          configId: providerIdInParentForm,
          repository: mockRepository,
          formController: fakeFormController,
        ),
      );
      await tester.pumpAndSettle();

      final provider1Tile = find.widgetWithText(ListTile, 'Provider 1');
      expect(provider1Tile, findsOneWidget);
      expect(
        find.descendant(
          of: provider1Tile,
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );

      final provider0Tile = find.widgetWithText(ListTile, 'Provider 0');
      expect(
        find.descendant(
          of: provider0Tile,
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
    });

    testWidgets('tapping a provider calls controller and pops navigator',
        (WidgetTester tester) async {
      final fakeFormController = FakeInferenceModelFormController()
        ..setInitialStateForBuild(
          InferenceModelFormState(),
        );

      final mockProviders = createMockProviders(count: 2);
      final providerToTap = mockProviders[0];
      const parentFormConfigId = 'some-parent-config-id';

      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => Stream.value(mockProviders));

      await tester.pumpWidget(
        buildTestWidget(
          configId: parentFormConfigId,
          repository: mockRepository,
          formController: fakeFormController,
          navigatorObserver: mockNavigatorObserver,
        ),
      );
      await tester.pumpAndSettle();

      final provider0Tile = find.widgetWithText(ListTile, providerToTap.name);
      expect(provider0Tile, findsOneWidget);
      await tester.tap(provider0Tile);
      await tester.pumpAndSettle();

      expect(
        fakeFormController.inferenceProviderIdChangedCalls,
        contains(providerToTap.id),
      );
      verify(() => mockNavigatorObserver.didPop(any(), any())).called(1);
    });
  });
}
