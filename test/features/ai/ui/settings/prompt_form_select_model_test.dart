import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/prompt_form_select_model.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:mocktail/mocktail.dart';

// Manual Fake for PromptFormController
class FakePromptFormController
    extends AutoDisposeAsyncNotifier<PromptFormState?>
    with
        Mock // Add Mock mixin to allow stubbing other methods if needed
    implements
        PromptFormController {
  Future<PromptFormState?> Function({String? configId})? onBuild;
  PromptFormState? initialStateForBuild; // Alternative for simpler cases

  @override
  Future<PromptFormState?> build({String? configId}) async {
    if (onBuild != null) {
      return onBuild!(configId: configId);
    }
    if (initialStateForBuild != null) {
      return initialStateForBuild;
    }
    throw UnimplementedError(
      'FakePromptFormController.build was not set up for the test.',
    );
  }

  // Implement other methods from PromptFormController or let them be handled by `Mock` mixin
  // For example, if we don't want to use `when` for these, we can provide concrete implementations or track calls.
  // For now, relying on `with Mock` for these to be stubbable with `when`.

  @override
  TextEditingController get nameController => _nameController;
  final _nameController = MockTextEditingController();

  @override
  TextEditingController get systemMessageController => _systemMessageController;
  final _systemMessageController = MockTextEditingController();

  @override
  TextEditingController get userMessageController => _userMessageController;
  final _userMessageController = MockTextEditingController();

  @override
  TextEditingController get descriptionController => _descriptionController;
  final _descriptionController = MockTextEditingController();

  // modelIdsChanged and defaultModelIdChanged will be stubbed using `when`
  // as FakePromptFormController uses `with Mock`.
}

class MockTextEditingController extends Mock implements TextEditingController {}

class MockAiConfig extends Mock implements AiConfig {}

final AppLocalizations l10n = AppLocalizationsEn();

void main() {
  late PromptFormControllerProvider promptFormControllerProviderInstance;
  late FakePromptFormController fakeFormController; // Use the fake controller

  setUp(() {
    fakeFormController = FakePromptFormController();
    promptFormControllerProviderInstance =
        promptFormControllerProvider(configId: null);

    // Stub methods on the fake controller using `when` (thanks to `with Mock`)
    when(() => fakeFormController.modelIdsChanged(any<List<String>>()))
        .thenAnswer((_) async {});
    when(() => fakeFormController.defaultModelIdChanged(any<String>()))
        .thenAnswer((_) async {});

    when(() => fakeFormController.nameController.text).thenReturn('');
    when(() => fakeFormController.systemMessageController.text).thenReturn('');
    when(() => fakeFormController.userMessageController.text).thenReturn('');
    when(() => fakeFormController.descriptionController.text).thenReturn('');
  });

  PromptFormState createFormState({
    List<String>? modelIds,
    String? defaultModelId,
    PromptName name = const PromptName.pure(),
    PromptSystemMessage systemMessage = const PromptSystemMessage.pure(),
    PromptUserMessage userMessage = const PromptUserMessage.pure(),
    bool useReasoning = false,
    List<InputDataType> requiredInputData = const [],
    PromptComment comment = const PromptComment.pure(),
    PromptDescription description = const PromptDescription.pure(),
    PromptCategory category = const PromptCategory.pure(),
    Map<String, String> defaultVariables = const {},
    bool isSubmitting = false,
    bool submitFailed = false,
  }) {
    return PromptFormState(
      modelIds: modelIds ?? [],
      defaultModelId: defaultModelId ?? '',
      name: name,
      systemMessage: systemMessage,
      userMessage: userMessage,
      useReasoning: useReasoning,
      requiredInputData: requiredInputData,
      comment: comment,
      description: description,
      category: category,
      defaultVariables: defaultVariables,
      isSubmitting: isSubmitting,
      submitFailed: submitFailed,
    );
  }

  testWidgets('shows CircularProgressIndicator when formState is AsyncLoading',
      (WidgetTester tester) async {
    fakeFormController.onBuild = ({String? configId}) async => null;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promptFormControllerProviderInstance.overrideWith(
            () => fakeFormController, // Provide the fake
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PromptFormSelectModel(),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows "No models selected" when modelIds is empty',
      (WidgetTester tester) async {
    final emptyState = createFormState(modelIds: []);
    fakeFormController.onBuild = ({String? configId}) async => emptyState;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promptFormControllerProviderInstance.overrideWith(
            () => fakeFormController,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PromptFormSelectModel(),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.aiConfigNoModelsSelected), findsOneWidget);
  });

  testWidgets('shows "Manage" button', (WidgetTester tester) async {
    final initialFormState = createFormState(modelIds: ['model1']);
    fakeFormController.onBuild = ({String? configId}) async => initialFormState;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promptFormControllerProviderInstance
              .overrideWith(() => fakeFormController),
          aiConfigByIdProvider('model1').overrideWith(
            (ref) async => AiConfigModel(
              id: 'model1',
              name: 'Test Model 1',
              providerModelId: 'pm1',
              inferenceProviderId: 'ip1',
              createdAt: DateTime.now(),
              inputModalities: [],
              outputModalities: [],
              isReasoningModel: false,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PromptFormSelectModel(),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.aiConfigManageModelsButton), findsOneWidget);
  });

  testWidgets('displays list of models with default star icon',
      (WidgetTester tester) async {
    final models = ['model1', 'model2'];
    const defaultModel = 'model1';
    final formStateWithModels =
        createFormState(modelIds: models, defaultModelId: defaultModel);
    fakeFormController.onBuild =
        ({String? configId}) async => formStateWithModels;

    final mockModel1 = AiConfigModel(
      id: 'model1',
      name: 'Test Model 1',
      providerModelId: 'pm1',
      inferenceProviderId: 'ip1',
      createdAt: DateTime.now(),
      inputModalities: [],
      outputModalities: [],
      isReasoningModel: false,
    );
    final mockModel2 = AiConfigModel(
      id: 'model2',
      name: 'Test Model 2',
      providerModelId: 'pm2',
      inferenceProviderId: 'ip1',
      createdAt: DateTime.now(),
      inputModalities: [],
      outputModalities: [],
      isReasoningModel: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promptFormControllerProviderInstance
              .overrideWith(() => fakeFormController),
          aiConfigByIdProvider('model1')
              .overrideWith((ref) async => mockModel1),
          aiConfigByIdProvider('model2')
              .overrideWith((ref) async => mockModel2),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PromptFormSelectModel(),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Model 1'), findsOneWidget);
    expect(find.text('Test Model 2'), findsOneWidget);
    final model1CardFinder = find.ancestor(
      of: find.text('Test Model 1'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(
        of: model1CardFinder,
        matching: find.byIcon(Icons.star),
      ),
      findsOneWidget,
    );
    final model2CardFinder = find.ancestor(
      of: find.text('Test Model 2'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(
        of: model2CardFinder,
        matching: find.byIcon(Icons.star),
      ),
      findsNothing,
    );
  });

  testWidgets('shows loading indicator for individual model data',
      (WidgetTester tester) async {
    final formStateWithModels =
        createFormState(modelIds: ['model1'], defaultModelId: 'model1');
    fakeFormController.onBuild =
        ({String? configId}) async => formStateWithModels;

    final modelDataCompleter = Completer<AiConfigModel?>(); // Use a completer

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promptFormControllerProviderInstance
              .overrideWith(() => fakeFormController),
          aiConfigByIdProvider('model1').overrideWith(
            (ref) => modelDataCompleter.future,
          ), // Return the completer's future
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PromptFormSelectModel(),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
        ),
      ),
    );
    await tester.pump(); // Pump once to show initial loading state

    expect(find.text('Loading model...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    // Test ends, modelDataCompleter is not completed, provider remains loading.
    // This should not cause a pending timer error.
  });

  testWidgets('shows error message for individual model data loading failure',
      (WidgetTester tester) async {
    final formStateWithModels =
        createFormState(modelIds: ['model1'], defaultModelId: 'model1');
    fakeFormController.onBuild =
        ({String? configId}) async => formStateWithModels;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promptFormControllerProviderInstance
              .overrideWith(() => fakeFormController),
          aiConfigByIdProvider('model1').overrideWith((ref) async {
            throw Exception('Failed to load model1');
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PromptFormSelectModel(),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Error: model1'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('dismissing a model calls controller and shows snackbar',
      (WidgetTester tester) async {
    final models = ['model1', 'model2'];
    const defaultModel = 'model1';
    final formStateWithModels =
        createFormState(modelIds: models, defaultModelId: defaultModel);
    fakeFormController.onBuild =
        ({String? configId}) async => formStateWithModels;

    final mockModel1 = AiConfigModel(
      id: 'model1',
      name: 'Test Model To Dismiss',
      providerModelId: 'pm1',
      inferenceProviderId: 'ip1',
      createdAt: DateTime.now(),
      inputModalities: [],
      outputModalities: [],
      isReasoningModel: false,
    );
    final mockModel2 = AiConfigModel(
      id: 'model2',
      name: 'Another Model',
      providerModelId: 'pm2',
      inferenceProviderId: 'ip1',
      createdAt: DateTime.now(),
      inputModalities: [],
      outputModalities: [],
      isReasoningModel: false,
    );

    List<String>? capturedModelIds;
    when(() => fakeFormController.modelIdsChanged(any<List<String>>()))
        .thenAnswer((invocation) async {
      capturedModelIds = invocation.positionalArguments.first as List<String>;
    });

    final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promptFormControllerProviderInstance
              .overrideWith(() => fakeFormController),
          aiConfigByIdProvider('model1')
              .overrideWith((ref) async => mockModel1),
          aiConfigByIdProvider('model2')
              .overrideWith((ref) async => mockModel2),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const Scaffold(
            body: PromptFormSelectModel(),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Model To Dismiss'), findsOneWidget);
    final dismissibleFinder =
        find.byKey(const ValueKey('selected_model_model1'));
    expect(dismissibleFinder, findsOneWidget);
    await tester.drag(dismissibleFinder, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.aiConfigListDeleteConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l10n.aiConfigListDeleteConfirmDelete));
    await tester.pumpAndSettle();
    expect(capturedModelIds, isNotNull);
    expect(capturedModelIds, contains('model2'));
    expect(capturedModelIds, isNot(contains('model1')));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text(l10n.aiConfigModelRemovedMessage('Test Model To Dismiss')),
      findsOneWidget,
    );
  });

  // TODO: Add more tests:
  // - Tapping manage button and modal interaction
}
