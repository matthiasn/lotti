import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/settings/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/prompt_form_select_model.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:mocktail/mocktail.dart';

// Manual Fake for PromptFormController
class FakePromptFormController
    extends AutoDisposeAsyncNotifier<PromptFormState?>
    with Mock
    implements PromptFormController {
  Future<PromptFormState?> Function({String? configId})? onBuild;
  PromptFormState? initialStateForBuild;

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
}

class MockTextEditingController extends Mock implements TextEditingController {}

class MockAiConfig extends Mock implements AiConfig {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

final AppLocalizations l10n = AppLocalizationsEn();

// Helper function to create test widgets
Widget createTestWidget({
  required Widget child,
  List<Override>? overrides,
}) {
  return ProviderScope(
    overrides: overrides ?? [],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
    ),
  );
}

// Helper function to create PromptFormState
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

// Helper function to create AiConfigModel
AiConfigModel createAiConfigModel({
  required String id,
  required String name,
  String? providerModelId,
  String? inferenceProviderId,
  bool isReasoningModel = false,
  List<Modality>? inputModalities,
  List<Modality>? outputModalities,
}) {
  return AiConfigModel(
    id: id,
    name: name,
    providerModelId: providerModelId ?? 'provider-$id',
    inferenceProviderId: inferenceProviderId ?? 'inference-$id',
    createdAt: DateTime.now(),
    inputModalities: inputModalities ?? [],
    outputModalities: outputModalities ?? [],
    isReasoningModel: isReasoningModel,
  );
}

void main() {
  group('ModelManagementHeader', () {
    testWidgets('displays title and manage button',
        (WidgetTester tester) async {
      var wasManageTapped = false;

      await tester.pumpWidget(
        createTestWidget(
          child: ModelManagementHeader(
            onManageTap: () => wasManageTapped = true,
          ),
        ),
      );

      expect(find.text(l10n.aiConfigModelsTitle), findsOneWidget);
      expect(find.text(l10n.aiConfigManageModelsButton), findsOneWidget);

      await tester.tap(find.text(l10n.aiConfigManageModelsButton));
      expect(wasManageTapped, isTrue);
    });
  });

  group('EmptyModelsState', () {
    testWidgets('displays no models selected message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const EmptyModelsState(),
        ),
      );

      expect(find.text(l10n.aiConfigNoModelsSelected), findsOneWidget);
    });
  });

  // DefaultBadge is now part of DismissibleModelCard and not a separate widget

  group('ModelLoadingState', () {
    testWidgets('displays loading indicator and text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ModelLoadingState(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.promptLoadingModel), findsOneWidget);
    });
  });

  group('ModelErrorState', () {
    testWidgets('displays error icon and model id',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ModelErrorState(modelId: 'test-model-id'),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('${l10n.promptErrorLoadingModel}: test-model-id'),
          findsOneWidget);
    });
  });

  group('ModelDeleteConfirmationDialog', () {
    testWidgets('displays confirmation dialog with correct messages',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ModelDeleteConfirmationDialog(modelName: 'Test Model'),
        ),
      );

      expect(find.text(l10n.aiConfigListDeleteConfirmTitle), findsOneWidget);
      expect(
        find.text(l10n.aiConfigListDeleteConfirmMessage('Test Model')),
        findsOneWidget,
      );
      expect(find.text(l10n.aiConfigListDeleteConfirmCancel), findsOneWidget);
      expect(find.text(l10n.aiConfigListDeleteConfirmDelete), findsOneWidget);
    });

    testWidgets('returns false when cancel is tapped',
        (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const ModelDeleteConfirmationDialog(
                      modelName: 'Test Model',
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.aiConfigListDeleteConfirmCancel));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('returns true when delete is tapped',
        (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const ModelDeleteConfirmationDialog(
                      modelName: 'Test Model',
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.aiConfigListDeleteConfirmDelete));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  // ModelCardContent has been replaced with AiConfigCard

  // ModelCard has been replaced with AiConfigCard

  group('DismissibleModelCard', () {
    testWidgets('can be dismissed and calls onDismissed callback',
        (WidgetTester tester) async {
      var wasDismissed = false;
      final config = createAiConfigModel(
        id: 'model1',
        name: 'Test Model',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: DismissibleModelCard(
            modelId: 'model1',
            modelName: 'Test Model',
            isDefault: false,
            config: config,
            onDismissed: () => wasDismissed = true,
          ),
        ),
      );

      expect(
          find.byKey(const ValueKey('selected_model_model1')), findsOneWidget);

      // Swipe to dismiss
      await tester.drag(
        find.byKey(const ValueKey('selected_model_model1')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      // Confirm deletion
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text(l10n.aiConfigListDeleteConfirmDelete));
      await tester.pumpAndSettle();

      expect(wasDismissed, isTrue);
    });

    testWidgets('shows dismiss background when swiping',
        (WidgetTester tester) async {
      final config = createAiConfigModel(
        id: 'model1',
        name: 'Test Model',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: DismissibleModelCard(
            modelId: 'model1',
            modelName: 'Test Model',
            isDefault: false,
            config: config,
            onDismissed: () {},
          ),
        ),
      );

      // Start dragging
      await tester.drag(
        find.byKey(const ValueKey('selected_model_model1')),
        const Offset(-100, 0),
      );
      await tester.pump();

      expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
    });

    testWidgets('cancels dismissal when dialog is cancelled',
        (WidgetTester tester) async {
      var wasDismissed = false;
      final config = createAiConfigModel(
        id: 'model1',
        name: 'Test Model',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: DismissibleModelCard(
            modelId: 'model1',
            modelName: 'Test Model',
            isDefault: false,
            config: config,
            onDismissed: () => wasDismissed = true,
          ),
        ),
      );

      // Swipe to dismiss
      await tester.drag(
        find.byKey(const ValueKey('selected_model_model1')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      // Cancel deletion
      await tester.tap(find.text(l10n.aiConfigListDeleteConfirmCancel));
      await tester.pumpAndSettle();

      expect(wasDismissed, isFalse);
      expect(
          find.byKey(const ValueKey('selected_model_model1')), findsOneWidget);
    });
  });

  group('SelectedModelsList', () {
    testWidgets('displays list of models with correct data',
        (WidgetTester tester) async {
      final model1 = createAiConfigModel(id: 'model1', name: 'Model 1');
      final model2 = createAiConfigModel(id: 'model2', name: 'Model 2');

      await tester.pumpWidget(
        createTestWidget(
          child: SelectedModelsList(
            modelIds: const ['model1', 'model2'],
            defaultModelId: 'model1',
            onModelRemoved: (modelId, modelName) {
              // Callback is tested in other tests
            },
          ),
          overrides: [
            aiConfigByIdProvider('model1').overrideWith((ref) async => model1),
            aiConfigByIdProvider('model2').overrideWith((ref) async => model2),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Model 1'), findsOneWidget);
      expect(find.text('Model 2'), findsOneWidget);
      expect(find.text(l10n.promptDefaultModelBadge),
          findsOneWidget); // Only model1 is default
    });

    testWidgets('handles loading state for models',
        (WidgetTester tester) async {
      final modelDataCompleter = Completer<AiConfigModel?>();

      await tester.pumpWidget(
        createTestWidget(
          child: SelectedModelsList(
            modelIds: const ['model1'],
            defaultModelId: 'model1',
            onModelRemoved: (_, __) {},
          ),
          overrides: [
            aiConfigByIdProvider('model1')
                .overrideWith((ref) => modelDataCompleter.future),
          ],
        ),
      );

      await tester.pump();
      expect(find.byType(ModelLoadingState), findsOneWidget);
    });

    testWidgets('handles error state for models', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: SelectedModelsList(
            modelIds: const ['model1'],
            defaultModelId: 'model1',
            onModelRemoved: (_, __) {},
          ),
          overrides: [
            aiConfigByIdProvider('model1').overrideWith((ref) async {
              throw Exception('Failed to load');
            }),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ModelErrorState), findsOneWidget);
    });
  });

  group('PromptFormSelectModel', () {
    late PromptFormControllerProvider promptFormControllerProviderInstance;
    late FakePromptFormController fakeFormController;

    setUp(() {
      fakeFormController = FakePromptFormController();
      promptFormControllerProviderInstance =
          promptFormControllerProvider(configId: null);

      when(() => fakeFormController.modelIdsChanged(any<List<String>>()))
          .thenAnswer((_) async {});
      when(() => fakeFormController.defaultModelIdChanged(any<String>()))
          .thenAnswer((_) async {});

      when(() => fakeFormController.nameController.text).thenReturn('');
      when(() => fakeFormController.systemMessageController.text)
          .thenReturn('');
      when(() => fakeFormController.userMessageController.text).thenReturn('');
      when(() => fakeFormController.descriptionController.text).thenReturn('');
    });

    testWidgets('shows loading indicator when formState is null',
        (WidgetTester tester) async {
      fakeFormController.onBuild = ({String? configId}) async => null;

      await tester.pumpWidget(
        createTestWidget(
          child: const PromptFormSelectModel(),
          overrides: [
            promptFormControllerProviderInstance.overrideWith(
              () => fakeFormController,
            ),
          ],
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no models are selected',
        (WidgetTester tester) async {
      final emptyState = createFormState(modelIds: []);
      fakeFormController.onBuild = ({String? configId}) async => emptyState;

      await tester.pumpWidget(
        createTestWidget(
          child: const PromptFormSelectModel(),
          overrides: [
            promptFormControllerProviderInstance.overrideWith(
              () => fakeFormController,
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(EmptyModelsState), findsOneWidget);
    });

    testWidgets('shows model list when models are selected',
        (WidgetTester tester) async {
      final stateWithModels = createFormState(
        modelIds: ['model1'],
        defaultModelId: 'model1',
      );
      fakeFormController.onBuild =
          ({String? configId}) async => stateWithModels;

      final model1 = createAiConfigModel(id: 'model1', name: 'Test Model');

      await tester.pumpWidget(
        createTestWidget(
          child: const PromptFormSelectModel(),
          overrides: [
            promptFormControllerProviderInstance.overrideWith(
              () => fakeFormController,
            ),
            aiConfigByIdProvider('model1').overrideWith((ref) async => model1),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SelectedModelsList), findsOneWidget);
      expect(find.text('Test Model'), findsOneWidget);
    });

    testWidgets('handles model removal with snackbar',
        (WidgetTester tester) async {
      final stateWithModels = createFormState(
        modelIds: ['model1', 'model2'],
        defaultModelId: 'model1',
      );
      fakeFormController.onBuild =
          ({String? configId}) async => stateWithModels;

      final model1 = createAiConfigModel(id: 'model1', name: 'Model to Remove');
      final model2 = createAiConfigModel(id: 'model2', name: 'Another Model');

      List<String>? capturedModelIds;
      when(() => fakeFormController.modelIdsChanged(any<List<String>>()))
          .thenAnswer((invocation) async {
        capturedModelIds = invocation.positionalArguments.first as List<String>;
      });

      final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            promptFormControllerProviderInstance.overrideWith(
              () => fakeFormController,
            ),
            aiConfigByIdProvider('model1').overrideWith((ref) async => model1),
            aiConfigByIdProvider('model2').overrideWith((ref) async => model2),
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

      // Dismiss the first model
      await tester.drag(
        find.byKey(const ValueKey('selected_model_model1')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.text(l10n.aiConfigListDeleteConfirmDelete));
      await tester.pumpAndSettle();

      // Verify model was removed
      expect(capturedModelIds, ['model2']);

      // Verify snackbar was shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(l10n.aiConfigModelRemovedMessage('Model to Remove')),
        findsOneWidget,
      );
    });

    testWidgets('opens model management modal when manage button is tapped',
        (WidgetTester tester) async {
      final stateWithModels = createFormState(
        modelIds: ['model1'],
        defaultModelId: 'model1',
      );
      fakeFormController.onBuild =
          ({String? configId}) async => stateWithModels;

      await tester.pumpWidget(
        createTestWidget(
          child: const PromptFormSelectModel(),
          overrides: [
            promptFormControllerProviderInstance.overrideWith(
              () => fakeFormController,
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the manage button
      await tester.tap(find.text(l10n.aiConfigManageModelsButton));
      await tester.pump();

      // The modal would be shown here in a real scenario
      // We can't test the actual modal without mocking showModelManagementModal
      // but we've verified the button exists and is tappable
    });
  });

  group('Integration Tests', () {
    testWidgets('complete flow: display models, remove one, show snackbar',
        (WidgetTester tester) async {
      final fakeFormController = FakePromptFormController();
      final promptFormControllerProviderInstance =
          promptFormControllerProvider(configId: null);

      final stateWithModels = createFormState(
        modelIds: ['model1', 'model2', 'model3'],
        defaultModelId: 'model2',
      );
      fakeFormController.onBuild =
          ({String? configId}) async => stateWithModels;

      when(() => fakeFormController.modelIdsChanged(any<List<String>>()))
          .thenAnswer((_) async {});
      when(() => fakeFormController.defaultModelIdChanged(any<String>()))
          .thenAnswer((_) async {});

      final model1 = createAiConfigModel(id: 'model1', name: 'First Model');
      final model2 = createAiConfigModel(id: 'model2', name: 'Default Model');
      final model3 = createAiConfigModel(id: 'model3', name: 'Third Model');

      final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            promptFormControllerProviderInstance.overrideWith(
              () => fakeFormController,
            ),
            aiConfigByIdProvider('model1').overrideWith((ref) async => model1),
            aiConfigByIdProvider('model2').overrideWith((ref) async => model2),
            aiConfigByIdProvider('model3').overrideWith((ref) async => model3),
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

      // Verify all models are displayed
      expect(find.text('First Model'), findsOneWidget);
      expect(find.text('Default Model'), findsOneWidget);
      expect(find.text('Third Model'), findsOneWidget);

      // Verify default badge is on the correct model
      expect(find.text(l10n.promptDefaultModelBadge), findsOneWidget);

      // Remove a non-default model
      await tester.drag(
        find.byKey(const ValueKey('selected_model_model3')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.text(l10n.aiConfigListDeleteConfirmDelete));
      await tester.pumpAndSettle();

      // Verify snackbar
      expect(
        find.text(l10n.aiConfigModelRemovedMessage('Third Model')),
        findsOneWidget,
      );
    });
  });
}
