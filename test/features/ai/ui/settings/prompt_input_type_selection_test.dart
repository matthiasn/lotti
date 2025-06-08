import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/prompt_input_type_selection.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

class FakePromptFormController extends PromptFormController {
  FakePromptFormController()
      : _nextStateForBuild = AsyncData(PromptFormState()) {
    final initialDefaultState = _nextStateForBuild.value!;
    nameController.text = initialDefaultState.name.value;
    userMessageController.text = initialDefaultState.userMessage.value;
    systemMessageController.text = initialDefaultState.systemMessage.value;
    descriptionController.text = initialDefaultState.description.value;
  }
  AsyncValue<PromptFormState?> _nextStateForBuild;

  List<InputDataType> lastRequiredInputDataChanged = [];

  // ignore: use_setters_to_change_properties
  void primeInitialBuildState(AsyncValue<PromptFormState?> nextState) {
    _nextStateForBuild = nextState;
  }

  @override
  Future<PromptFormState?> build({String? configId}) async {
    if (_nextStateForBuild.hasError) {
      // ignore: only_throw_errors
      throw _nextStateForBuild.error!;
    }
    if (_nextStateForBuild.isLoading) {
      return null;
    }

    final stateToBuildWith =
        _nextStateForBuild.valueOrNull ?? PromptFormState(id: configId);

    nameController.text = stateToBuildWith.name.value;
    userMessageController.text = stateToBuildWith.userMessage.value;
    systemMessageController.text = stateToBuildWith.systemMessage.value;
    descriptionController.text = stateToBuildWith.description.value;

    return stateToBuildWith;
  }

  void updateLiveState(PromptFormState newState) {
    nameController.text = newState.name.value;
    userMessageController.text = newState.userMessage.value;
    systemMessageController.text = newState.systemMessage.value;
    descriptionController.text = newState.description.value;
    state = AsyncData(newState);
  }

  @override
  void requiredInputDataChanged(List<InputDataType> inputData) {
    lastRequiredInputDataChanged = inputData;
    if (state.hasValue && state.value != null) {
      final currentFormState = state.value!;
      updateLiveState(currentFormState.copyWith(requiredInputData: inputData));
    }
  }
}

// class MockPromptFormState extends Mock implements PromptFormState {} // Removed as not directly used by fake

void main() {
  late FakePromptFormController fakePromptFormController;
  var l10n = AppLocalizationsEn();
  const testConfigId = 'test-config-id';

  PromptFormState createDefaultPromptFormState({
    String? id = testConfigId,
    List<InputDataType> requiredInputData = const [],
    PromptName? name,
    PromptUserMessage? userMessage,
    PromptSystemMessage? systemMessage,
  }) {
    return PromptFormState(
      id: id,
      name: name ?? const PromptName.dirty('Default Name'),
      userMessage: userMessage ?? const PromptUserMessage.dirty('Default User'),
      systemMessage:
          systemMessage ?? const PromptSystemMessage.dirty('Default System'),
      requiredInputData: requiredInputData,
      defaultModelId: 'model1',
      modelIds: ['model1'],
      defaultVariables: {},
    );
  }

  final testAiConfig = AiConfig.prompt(
    id: testConfigId,
    name: 'Test',
    systemMessage: '',
    userMessage: '',
    defaultModelId: '',
    modelIds: [],
    createdAt: DateTime.now(),
    useReasoning: false,
    requiredInputData: [],
    aiResponseType: AiResponseType.taskSummary,
  );

  setUp(() {
    l10n = AppLocalizationsEn();
    fakePromptFormController = FakePromptFormController();
  });

  Widget createTestWidget({
    AiConfig? config,
    FakePromptFormController? controllerInstance,
  }) {
    final controllerToUse = controllerInstance ?? fakePromptFormController;
    final currentConfigId = config?.id;

    return ProviderScope(
      overrides: [
        promptFormControllerProvider(configId: currentConfigId).overrideWith(
          () => controllerToUse,
        ),
        if (currentConfigId == null)
          promptFormControllerProvider(configId: null)
              .overrideWith(() => controllerToUse),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: PromptInputTypeSelection(configId: config?.id),
        ),
      ),
    );
  }

  Future<void> pumpWidget(
    WidgetTester tester, {
    AiConfig? config,
    FakePromptFormController? controllerInstance,
  }) async {
    await tester.pumpWidget(
      createTestWidget(
        config: config,
        controllerInstance: controllerInstance,
      ),
    );
    // pumpAndSettle is important to allow Riverpod to execute the async build method
    // and for the widget to react to the initial state.
    await tester.pumpAndSettle();
  }

  group('PromptInputTypeSelection', () {
    testWidgets('renders SizedBox.shrink when formState is AsyncLoading',
        (tester) async {
      final loadingController = FakePromptFormController()
        ..primeInitialBuildState(const AsyncLoading());

      await pumpWidget(
        tester,
        config: testAiConfig,
        controllerInstance: loadingController,
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('renders SizedBox.shrink when formState is AsyncError',
        (tester) async {
      final errorController = FakePromptFormController()
        // Make sure to use a real error object for the AsyncError, not just a string.
        ..primeInitialBuildState(
          AsyncError(Exception('Test error'), StackTrace.current),
        );

      await pumpWidget(
        tester,
        config: testAiConfig,
        controllerInstance: errorController,
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('displays prompt text when no types are selected',
        (tester) async {
      fakePromptFormController.primeInitialBuildState(
        AsyncData(createDefaultPromptFormState(requiredInputData: [])),
      );
      await pumpWidget(tester, config: testAiConfig);
      expect(
        find.text(l10n.aiConfigSelectInputDataTypesPrompt),
        findsOneWidget,
      );
    });

    testWidgets('displays selected types as comma-separated string',
        (tester) async {
      final selectedData = [InputDataType.task, InputDataType.images];
      fakePromptFormController.primeInitialBuildState(
        AsyncData(
          createDefaultPromptFormState(requiredInputData: selectedData),
        ),
      );
      await pumpWidget(tester, config: testAiConfig);

      final expectedString = selectedData
          .map((type) => type.displayNameFromContext(l10n))
          .join(', ');
      expect(find.text(expectedString), findsOneWidget);
    });

    testWidgets('displays correct field label', (tester) async {
      fakePromptFormController
          .primeInitialBuildState(AsyncData(createDefaultPromptFormState()));
      await pumpWidget(tester, config: testAiConfig);
      expect(
        find.text(l10n.aiConfigRequiredInputDataFieldLabel),
        findsOneWidget,
      );
    });

    group('Modal Interaction', () {
      const allTypes = InputDataType.values;

      Future<void> openModal(
        WidgetTester tester, {
        List<InputDataType> initialSelection = const [],
      }) async {
        fakePromptFormController.primeInitialBuildState(
          AsyncData(
            createDefaultPromptFormState(requiredInputData: initialSelection),
          ),
        );
        await pumpWidget(tester, config: testAiConfig);

        expect(
          find.byType(InkWell),
          findsOneWidget,
          reason: 'InkWell should be present to open modal',
        );
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.aiConfigInputDataTypesTitle),
          findsOneWidget,
          reason: 'Modal title should be visible after tap',
        );
      }

      testWidgets('tapping the widget opens the modal', (tester) async {
        await openModal(tester);
      });

      testWidgets(
          'modal shows all InputDataType options and respects initial selection',
          (tester) async {
        final initiallySelected = [
          InputDataType.task,
          InputDataType.audioFiles,
        ];
        await openModal(tester, initialSelection: initiallySelected);

        for (final type in allTypes) {
          expect(find.text(type.displayNameFromContext(l10n)), findsOneWidget);
          expect(find.text(type.descriptionFromContext(l10n)), findsOneWidget);

          // Check if the type is selected by looking for the checkmark icon
          final isSelected = initiallySelected.contains(type);
          
          if (isSelected) {
            // Look for checkmark icon next to this type's text
            final checkmarkFinder = find.ancestor(
              of: find.byIcon(Icons.check_rounded),
              matching: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_InputDataTypeOption',
              ),
            );
            // Verify this checkmark is for the correct type
            expect(
              find.descendant(
                of: checkmarkFinder,
                matching: find.text(type.displayNameFromContext(l10n)),
              ),
              findsOneWidget,
              reason: 'Selected type ${type.name} should have a checkmark',
            );
          }
        }
      });

      testWidgets('tapping a checkbox updates its state in the modal',
          (tester) async {
        await openModal(tester, initialSelection: []);

        const typeToSelect = InputDataType.images;

        // Find the container for the type option using InkWell
        final typeOptionFinder = find.ancestor(
          of: find.text(typeToSelect.displayNameFromContext(l10n)),
          matching: find.byType(InkWell),
        ).last; // Get the InkWell inside the modal
        
        // Ensure the option is visible before interacting with it
        await tester.ensureVisible(typeOptionFinder);
        await tester.pumpAndSettle();
        
        // Verify no checkmark initially
        expect(
          find.descendant(
            of: typeOptionFinder,
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsNothing,
        );

        await tester.tap(typeOptionFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Verify checkmark appears after tap
        expect(
          find.descendant(
            of: typeOptionFinder,
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsOneWidget,
        );
      });

      testWidgets(
          'tapping "Save" calls requiredInputDataChanged and closes modal',
          (tester) async {
        final initiallySelected = [InputDataType.task];
        const typeToNewlySelect = InputDataType.audioFiles;

        fakePromptFormController.primeInitialBuildState(
          AsyncData(
            createDefaultPromptFormState(
              requiredInputData: initiallySelected,
            ),
          ),
        );
        await openModal(tester, initialSelection: initiallySelected);

        // Find the type option to select
        final typeOptionFinder = find.ancestor(
          of: find.text(typeToNewlySelect.displayNameFromContext(l10n)),
          matching: find.byType(InkWell),
        ).last;
        
        // Ensure the option is visible before tapping
        await tester.ensureVisible(typeOptionFinder);
        await tester.pumpAndSettle();
        
        await tester.tap(typeOptionFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Find and tap the save button by text
        final saveButtonTextFinder = find.text(l10n.saveButtonLabel);
        await tester.ensureVisible(saveButtonTextFinder);
        await tester.pumpAndSettle();
        
        await tester.tap(saveButtonTextFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.aiConfigInputDataTypesTitle),
          findsNothing,
          reason: 'Modal should be closed',
        );
        expect(
          fakePromptFormController.lastRequiredInputDataChanged,
          unorderedEquals([InputDataType.task, InputDataType.audioFiles]),
        );

        final expectedString = [InputDataType.task, InputDataType.audioFiles]
            .map((type) => type.displayNameFromContext(l10n))
            .join(', ');
        expect(
          find.text(expectedString),
          findsOneWidget,
          reason: 'Widget text should update after save',
        );
      });
    });
  });
}

// Helper extension for tests to get localized strings without BuildContext
extension InputDataTypeTestDisplay on InputDataType {
  String displayNameFromContext(AppLocalizations l10nParam) {
    switch (this) {
      case InputDataType.task:
        return l10nParam.inputDataTypeTaskName;
      case InputDataType.tasksList:
        return l10nParam.inputDataTypeTasksListName;
      case InputDataType.audioFiles:
        return l10nParam.inputDataTypeAudioFilesName;
      case InputDataType.images:
        return l10nParam.inputDataTypeImagesName;
    }
  }

  String descriptionFromContext(AppLocalizations l10nParam) {
    switch (this) {
      case InputDataType.task:
        return l10nParam.inputDataTypeTaskDescription;
      case InputDataType.tasksList:
        return l10nParam.inputDataTypeTasksListDescription;
      case InputDataType.audioFiles:
        return l10nParam.inputDataTypeAudioFilesDescription;
      case InputDataType.images:
        return l10nParam.inputDataTypeImagesDescription;
    }
  }
}
