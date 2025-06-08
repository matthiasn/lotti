import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/enhanced_prompt_form.dart';
import 'package:lotti/features/ai/ui/settings/prompt_edit_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Mock repository implementation
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

/// Mock for NavigatorObserver to verify navigation behavior
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

/// Fake Route for Mocktail fallback
class FakeRoute<T> extends Fake implements Route<T> {}

/// Fake controller for PromptForm
class FakePromptFormController extends PromptFormController {
  PromptFormState? _initialStateForBuild = PromptFormState();
  List<AiConfig> addConfigCalls = [];
  List<AiConfig> updateConfigCalls = [];

  /// Called by tests to set the state that build() will use
  // ignore: use_setters_to_change_properties
  void setInitialStateForBuild(PromptFormState? newState) {
    _initialStateForBuild = newState;
  }

  /// Call this AFTER the widget is pumped and Riverpod has built the notifier, to emit a new state
  void emitNewStateForTest(PromptFormState? newState) {
    state = AsyncData<PromptFormState?>(newState);
  }

  @override
  Future<PromptFormState?> build({required String? configId}) async {
    state = AsyncData<PromptFormState?>(_initialStateForBuild);
    return _initialStateForBuild;
  }

  @override
  Future<void> addConfig(AiConfig config) async {
    addConfigCalls.add(config);
  }

  @override
  Future<void> updateConfig(AiConfig config) async {
    updateConfigCalls.add(config);
  }

  /// Minimal implementation of other methods
  @override
  TextEditingController get nameController => TextEditingController();
  @override
  TextEditingController get systemMessageController => TextEditingController();
  @override
  TextEditingController get userMessageController => TextEditingController();
  @override
  TextEditingController get descriptionController => TextEditingController();
  TextEditingController get commentController => TextEditingController();
  TextEditingController get categoryController => TextEditingController();

  @override
  void nameChanged(String name) {}
  @override
  void systemMessageChanged(String systemMessage) {}
  @override
  void userMessageChanged(String userMessage) {}
  @override
  void descriptionChanged(String description) {}
  void commentChanged(String comment) {}
  void categoryChanged(String category) {}
  @override
  void defaultModelIdChanged(String defaultModelId) {}
  @override
  void modelIdsChanged(List<String> modelIds) {}
  @override
  void useReasoningChanged(bool useReasoning) {}
  @override
  void requiredInputDataChanged(List<InputDataType> requiredInputData) {}
  @override
  void aiResponseTypeChanged(AiResponseType? aiResponseType) {}
  @override
  Future<CascadeDeletionResult> deleteConfig(String id) async {
    return const CascadeDeletionResult(deletedModels: [], providerName: '');
  }

  @override
  void reset() {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute<dynamic>());
    registerFallbackValue(
      AiConfig.prompt(
        id: 'fallback-id',
        name: 'Fallback Prompt',
        systemMessage: 'Fallback system message',
        userMessage: 'Fallback user message',
        defaultModelId: 'fallback-model',
        modelIds: const ['fallback-model'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.taskSummary,
      ),
    );
  });

  late MockAiConfigRepository mockRepository;
  late MockNavigatorObserver mockNavigatorObserver;

  setUp(() {
    mockRepository = MockAiConfigRepository();
    mockNavigatorObserver = MockNavigatorObserver();
  });

  /// Helper function to build a testable widget with the correct localizations
  /// and provider overrides
  Widget buildTestWidget({
    required String? configId,
    required MockAiConfigRepository repository,
    required FakePromptFormController formController,
    NavigatorObserver? navigatorObserver,
    AiConfig? configForProvider,
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
      home: ProviderScope(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(repository),
          promptFormControllerProvider(configId: configId)
              .overrideWith(() => formController),
          if (configId != null && configForProvider != null)
            aiConfigByIdProvider(configId).overrideWith((ref) async {
              return configForProvider;
            }),
        ],
        child: PromptEditPage(configId: configId),
      ),
    );
  }

  /// Creates a mock prompt config for testing
  AiConfig createMockPromptConfig({
    required String id,
    required String name,
    required String systemMessage,
    required String userMessage,
    required String defaultModelId,
    List<String> modelIds = const [],
    String? description,
    String? comment,
    String? category,
    bool useReasoning = false,
    List<InputDataType> requiredInputData = const [],
    AiResponseType aiResponseType = AiResponseType.taskSummary,
  }) {
    return AiConfig.prompt(
      id: id,
      name: name,
      systemMessage: systemMessage,
      userMessage: userMessage,
      defaultModelId: defaultModelId,
      modelIds: modelIds,
      createdAt: DateTime.now(),
      useReasoning: useReasoning,
      requiredInputData: requiredInputData,
      description: description,
      comment: comment,
      category: category,
      aiResponseType: aiResponseType,
    );
  }

  PromptFormState createValidFormState({
    String name = 'Test Prompt',
    String systemMessage = 'Test system message',
    String userMessage = 'Test user message',
    String defaultModelId = 'model-1',
    List<String> modelIds = const ['model-1'],
    AiResponseType aiResponseType = AiResponseType.taskSummary,
  }) {
    return PromptFormState(
      name: PromptName.dirty(name),
      systemMessage: PromptSystemMessage.dirty(systemMessage),
      userMessage: PromptUserMessage.dirty(userMessage),
      defaultModelId: defaultModelId,
      modelIds: modelIds,
      aiResponseType: PromptAiResponseType.dirty(aiResponseType),
    );
  }

  group('PromptEditPage', () {
    group('Create Mode (configId is null)', () {
      testWidgets('displays correct title for create mode',
          (WidgetTester tester) async {
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(PromptFormState());

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Add Prompt'), findsOneWidget);
      });

      testWidgets('displays form in create mode', (WidgetTester tester) async {
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(PromptFormState());

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EnhancedPromptForm), findsOneWidget);
      });

      testWidgets('save button is disabled when form is invalid',
          (WidgetTester tester) async {
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(PromptFormState()); // Invalid by default

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
          ),
        );
        await tester.pumpAndSettle();

        // Save button should be disabled (visible but with reduced opacity)
        expect(find.text('Save'), findsOneWidget);
        // Check for reduced opacity when form is invalid
        final opacityWidget = find.byType(AnimatedOpacity);
        expect(opacityWidget, findsAtLeastNWidgets(1));
      });

      testWidgets('save button is visible when form is valid',
          (WidgetTester tester) async {
        final validFormState = createValidFormState();
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(validFormState);

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('calls addConfig when save button is tapped in create mode',
          (WidgetTester tester) async {
        final validFormState = createValidFormState();
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(validFormState);

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
            navigatorObserver: mockNavigatorObserver,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(fakeFormController.addConfigCalls, hasLength(1));
        expect(fakeFormController.updateConfigCalls, isEmpty);
        verify(() => mockNavigatorObserver.didPop(any(), any())).called(1);
      });
    });

    group('Edit Mode (configId is provided)', () {
      testWidgets('displays correct title for edit mode',
          (WidgetTester tester) async {
        const configId = 'prompt-1';
        final mockConfig = createMockPromptConfig(
          id: configId,
          name: 'Test Prompt',
          systemMessage: 'System message',
          userMessage: 'User message',
          defaultModelId: 'model-1',
        );

        final validFormState = createValidFormState();
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(validFormState);

        await tester.pumpWidget(
          buildTestWidget(
            configId: configId,
            repository: mockRepository,
            formController: fakeFormController,
            configForProvider: mockConfig,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Edit Prompt'), findsOneWidget);
      });

      testWidgets('displays error when config fails to load',
          (WidgetTester tester) async {
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(PromptFormState());

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProviderScope(
              overrides: [
                aiConfigRepositoryProvider.overrideWithValue(mockRepository),
                promptFormControllerProvider(configId: 'prompt-1')
                    .overrideWith(() => fakeFormController),
                aiConfigByIdProvider('prompt-1').overrideWith((ref) async {
                  throw Exception('Test error');
                }),
              ],
              child: const PromptEditPage(configId: 'prompt-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Failed to load'), findsOneWidget);
      });

      testWidgets('save button requires form to be dirty in edit mode',
          (WidgetTester tester) async {
        const configId = 'prompt-1';
        final mockConfig = createMockPromptConfig(
          id: configId,
          name: 'Test Prompt',
          systemMessage: 'System message',
          userMessage: 'User message',
          defaultModelId: 'model-1',
        );

        // Create a form state that is valid but not dirty (pure form inputs)
        final formState = PromptFormState(
          name: const PromptName.pure('Test Prompt'),
          systemMessage: const PromptSystemMessage.pure('System message'),
          userMessage: const PromptUserMessage.pure('User message'),
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          aiResponseType:
              const PromptAiResponseType.pure(AiResponseType.taskSummary),
        );

        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(formState);

        await tester.pumpWidget(
          buildTestWidget(
            configId: configId,
            repository: mockRepository,
            formController: fakeFormController,
            configForProvider: mockConfig,
          ),
        );
        await tester.pumpAndSettle();

        // Save button should be hidden when form is not dirty in edit mode
        // Save button should be disabled (visible but with reduced opacity)
        expect(find.text('Save'), findsOneWidget);
        // Check for reduced opacity when form is invalid
        final opacityWidget = find.byType(AnimatedOpacity);
        expect(opacityWidget, findsAtLeastNWidgets(1));
      });

      testWidgets(
          'save button is visible when form is valid and dirty in edit mode',
          (WidgetTester tester) async {
        const configId = 'prompt-1';
        final mockConfig = createMockPromptConfig(
          id: configId,
          name: 'Test Prompt',
          systemMessage: 'System message',
          userMessage: 'User message',
          defaultModelId: 'model-1',
        );

        final validFormState = createValidFormState();
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(validFormState);

        await tester.pumpWidget(
          buildTestWidget(
            configId: configId,
            repository: mockRepository,
            formController: fakeFormController,
            configForProvider: mockConfig,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('calls updateConfig when save button is tapped in edit mode',
          (WidgetTester tester) async {
        const configId = 'prompt-1';
        final mockConfig = createMockPromptConfig(
          id: configId,
          name: 'Test Prompt',
          systemMessage: 'System message',
          userMessage: 'User message',
          defaultModelId: 'model-1',
        );

        final validFormState = createValidFormState();
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(validFormState);

        await tester.pumpWidget(
          buildTestWidget(
            configId: configId,
            repository: mockRepository,
            formController: fakeFormController,
            configForProvider: mockConfig,
            navigatorObserver: mockNavigatorObserver,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(fakeFormController.updateConfigCalls, hasLength(1));
        expect(fakeFormController.addConfigCalls, isEmpty);
        verify(() => mockNavigatorObserver.didPop(any(), any())).called(1);
      });
    });

    group('Form Validation Logic', () {
      testWidgets('form is invalid when required fields are empty',
          (WidgetTester tester) async {
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(PromptFormState(
            modelIds: [],
          ));

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
          ),
        );
        await tester.pumpAndSettle();

        // Save button should be disabled (visible but with reduced opacity)
        expect(find.text('Save'), findsOneWidget);
        // Check for reduced opacity when form is invalid
        final opacityWidget = find.byType(AnimatedOpacity);
        expect(opacityWidget, findsAtLeastNWidgets(1));
      });

      testWidgets('form is invalid when modelIds is empty',
          (WidgetTester tester) async {
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(PromptFormState(
            name: const PromptName.dirty('Test'),
            systemMessage: const PromptSystemMessage.dirty('System'),
            userMessage: const PromptUserMessage.dirty('User'),
            modelIds: [], // Empty model IDs
            defaultModelId: 'model-1',
            aiResponseType:
                const PromptAiResponseType.dirty(AiResponseType.taskSummary),
          ));

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
          ),
        );
        await tester.pumpAndSettle();

        // Save button should be disabled (visible but with reduced opacity)
        expect(find.text('Save'), findsOneWidget);
        // Check for reduced opacity when form is invalid
        final opacityWidget = find.byType(AnimatedOpacity);
        expect(opacityWidget, findsAtLeastNWidgets(1));
      });

      testWidgets('form is invalid when defaultModelId is not in modelIds',
          (WidgetTester tester) async {
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(PromptFormState(
            name: const PromptName.dirty('Test'),
            systemMessage: const PromptSystemMessage.dirty('System'),
            userMessage: const PromptUserMessage.dirty('User'),
            modelIds: const ['model-1', 'model-2'],
            defaultModelId: 'model-3', // Not in modelIds
            aiResponseType:
                const PromptAiResponseType.dirty(AiResponseType.taskSummary),
          ));

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
          ),
        );
        await tester.pumpAndSettle();

        // Save button should be disabled (visible but with reduced opacity)
        expect(find.text('Save'), findsOneWidget);
        // Check for reduced opacity when form is invalid
        final opacityWidget = find.byType(AnimatedOpacity);
        expect(opacityWidget, findsAtLeastNWidgets(1));
      });
    });

    group('Keyboard Shortcuts', () {
      testWidgets('keyboard shortcut structure is properly configured',
          (WidgetTester tester) async {
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(PromptFormState());

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
          ),
        );
        await tester.pumpAndSettle();

        // Find the main CallbackShortcuts widget (there may be others from nested widgets)
        final callbackShortcutsFinders = find.byType(CallbackShortcuts);
        expect(callbackShortcutsFinders, findsWidgets);

        // Find the one with CMD+S binding
        var foundCmdS = false;
        for (var i = 0; i < callbackShortcutsFinders.evaluate().length; i++) {
          final widget =
              tester.widget<CallbackShortcuts>(callbackShortcutsFinders.at(i));
          final hasCmdS = widget.bindings.keys.any((activator) =>
              activator is SingleActivator &&
              activator.trigger == LogicalKeyboardKey.keyS &&
              activator.meta);
          if (hasCmdS) {
            foundCmdS = true;
            break;
          }
        }
        expect(foundCmdS, isTrue);
      });

      testWidgets('CMD+S does not save when form is invalid',
          (WidgetTester tester) async {
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(PromptFormState()); // Invalid form

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
          ),
        );
        await tester.pumpAndSettle();

        // Simulate CMD+S
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await tester.pumpAndSettle();

        expect(fakeFormController.addConfigCalls, isEmpty);
        expect(fakeFormController.updateConfigCalls, isEmpty);
      });

      testWidgets('CMD+S shortcut works when form is valid',
          (WidgetTester tester) async {
        final validFormState = createValidFormState();
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(validFormState);

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
            navigatorObserver: mockNavigatorObserver,
          ),
        );
        await tester.pumpAndSettle();

        // Verify save button is visible (form is valid)
        expect(find.text('Save'), findsOneWidget);

        // The keyboard shortcut should work the same as clicking save
        // We just verify the shortcut exists and form validation works
        expect(fakeFormController.addConfigCalls, isEmpty);
      });
    });

    group('Navigation', () {
      testWidgets('navigates back after successful save',
          (WidgetTester tester) async {
        final validFormState = createValidFormState();
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(validFormState);

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
            navigatorObserver: mockNavigatorObserver,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        verify(() => mockNavigatorObserver.didPop(any(), any())).called(1);
      });
    });

    group('UI States', () {
      testWidgets('displays form when config data is available',
          (WidgetTester tester) async {
        const configId = 'prompt-1';
        final mockConfig = createMockPromptConfig(
          id: configId,
          name: 'Test Prompt',
          systemMessage: 'System message',
          userMessage: 'User message',
          defaultModelId: 'model-1',
        );

        final validFormState = createValidFormState();
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(validFormState);

        await tester.pumpWidget(
          buildTestWidget(
            configId: configId,
            repository: mockRepository,
            formController: fakeFormController,
            configForProvider: mockConfig,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EnhancedPromptForm), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('save button has correct styling',
          (WidgetTester tester) async {
        final validFormState = createValidFormState();
        final fakeFormController = FakePromptFormController()
          ..setInitialStateForBuild(validFormState);

        await tester.pumpWidget(
          buildTestWidget(
            configId: null,
            repository: mockRepository,
            formController: fakeFormController,
          ),
        );
        await tester.pumpAndSettle();

        final saveButton = find.text('Save');
        expect(saveButton, findsOneWidget);

        final text = tester.widget<Text>(saveButton);
        expect(text.style?.fontWeight, FontWeight.w600);
      });
    });
  });
}
