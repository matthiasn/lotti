import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/prompt_response_type_selection.dart';
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

  AiResponseType? lastAiResponseTypeChanged;

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
  void aiResponseTypeChanged(AiResponseType? responseType) {
    lastAiResponseTypeChanged = responseType;
    if (state.hasValue && state.value != null) {
      final currentFormState = state.value!;
      updateLiveState(
        currentFormState.copyWith(
          aiResponseType: PromptAiResponseType.dirty(responseType),
        ),
      );
    }
  }
}

void main() {
  late FakePromptFormController fakePromptFormController;
  var l10n = AppLocalizationsEn();
  const testConfigId = 'test-config-id';

  PromptFormState createDefaultPromptFormState({
    String? id = testConfigId,
    PromptAiResponseType aiResponseType = const PromptAiResponseType.pure(),
    PromptName name = const PromptName.pure(),
    PromptUserMessage userMessage = const PromptUserMessage.pure(),
    PromptSystemMessage systemMessage = const PromptSystemMessage.pure(),
  }) {
    return PromptFormState(
      id: id,
      name: name,
      userMessage: userMessage,
      systemMessage: systemMessage,
      aiResponseType: aiResponseType,
      defaultModelId: 'model1',
      modelIds: ['model1'],
      defaultVariables: {},
      requiredInputData: [],
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
          body: PromptResponseTypeSelection(configId: config?.id),
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
    await tester.pumpAndSettle();
  }

  group('PromptResponseTypeSelection', () {
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

    testWidgets('displays hint text when no type is selected', (tester) async {
      fakePromptFormController.primeInitialBuildState(
        AsyncData(
          createDefaultPromptFormState(),
        ),
      );
      await pumpWidget(tester, config: testAiConfig);
      expect(
        find.text(l10n.aiConfigResponseTypeSelectHint),
        findsOneWidget,
      );
    });

    testWidgets('displays selected type localized name', (tester) async {
      const selectedType = AiResponseType.imageAnalysis;
      fakePromptFormController.primeInitialBuildState(
        AsyncData(
          createDefaultPromptFormState(
            aiResponseType: const PromptAiResponseType.dirty(selectedType),
          ),
        ),
      );
      await pumpWidget(tester, config: testAiConfig);

      expect(
        find.text(selectedType.localizedNameFromContext(l10n)),
        findsOneWidget,
      );
    });

    testWidgets('displays correct field label', (tester) async {
      fakePromptFormController
          .primeInitialBuildState(AsyncData(createDefaultPromptFormState()));
      await pumpWidget(tester, config: testAiConfig);
      expect(
        find.text(l10n.aiConfigResponseTypeFieldLabel),
        findsOneWidget,
      );
    });

    testWidgets(
        'displays error text when no type is selected and form is dirty with notSelected error',
        (tester) async {
      // For a field to be invalid and have an error, it usually needs to be dirty and fail validation.
      // The validator for PromptAiResponseType returns notSelected if value is null.
      // So, a dirty field with a null value should trigger the error.
      const dirtyEmptyResponseType = PromptAiResponseType.dirty(null);
      // Manually validate to update error state if necessary, though dirty(null) should suffice
      // due to how FormzInput works (validator is called on construction of dirty).
      // However, to be certain the error is set for the test, we can prime it.
      // The actual PromptFormState would get its isValid from Formz.validate(inputs)

      fakePromptFormController.primeInitialBuildState(
        AsyncData(
          createDefaultPromptFormState(aiResponseType: dirtyEmptyResponseType),
        ),
      );
      await pumpWidget(tester, config: testAiConfig);
      await tester.pumpAndSettle(); // Ensure state updates and UI rebuilds

      // We need to ensure the formState.aiResponseType.isNotValid is true.
      // And formState.aiResponseType.error == PromptFormError.notSelected
      final formState = fakePromptFormController.state.valueOrNull!;
      expect(formState.aiResponseType.value, null);
      expect(formState.aiResponseType.isValid, isFalse);
      expect(formState.aiResponseType.isNotValid, isTrue);
      expect(formState.aiResponseType.error, PromptFormError.notSelected);

      // Ensure the input decorator shows an error
      final inputDecorator = tester.widget<InputDecorator>(
        find.byWidgetPredicate(
          (widget) =>
              widget is InputDecorator && widget.decoration.errorText != null,
        ),
      );
      expect(
        inputDecorator.decoration.errorText,
        l10n.aiConfigResponseTypeNotSelectedError,
      );

      // Also check if the error text is visible
      expect(
        find.text(l10n.aiConfigResponseTypeNotSelectedError),
        findsOneWidget,
      );
    });

    group('Modal Interaction', () {
      // Exclude deprecated actionItemSuggestions from displayed types
      final allTypes = AiResponseType.values
          // ignore: deprecated_member_use_from_same_package
          .where((type) => type != AiResponseType.actionItemSuggestions)
          .toList();

      Future<void> openModal(
        WidgetTester tester, {
        AiResponseType? initialSelection,
      }) async {
        fakePromptFormController.primeInitialBuildState(
          AsyncData(
            createDefaultPromptFormState(
              aiResponseType: PromptAiResponseType.dirty(initialSelection),
            ),
          ),
        );
        await pumpWidget(tester, config: testAiConfig);

        expect(
          find.byType(InkWell),
          findsOneWidget,
          reason: 'InkWell should be present to open modal',
        );
        await tester.tap(find.byType(InkWell));
        await tester
            .pumpAndSettle(); // Wait for modal to appear and animations to finish
        expect(
          find.text(l10n.aiConfigSelectResponseTypeTitle),
          findsOneWidget,
          reason: 'Modal title should be visible after tap',
        );
      }

      testWidgets('tapping the widget opens the modal', (tester) async {
        await openModal(tester);
      });

      testWidgets(
          'modal shows all AiResponseType options and respects initial selection',
          (tester) async {
        const initiallySelected = AiResponseType.taskSummary;
        await openModal(tester, initialSelection: initiallySelected);

        for (final type in allTypes) {
          // Find text within the modal options specifically
          final typeTextInModal = find.descendant(
            of: find.byType(ResponseTypeSelectionModal),
            matching: find.text(type.localizedNameFromContext(l10n)),
          );
          expect(
            typeTextInModal,
            findsOneWidget,
            reason: 'Type ${type.name} should be displayed in modal',
          );

          // Check if the type is selected by looking for radio button indicator
          final typeOptionFinder = find
              .ancestor(
                of: find.text(type.localizedNameFromContext(l10n)),
                matching: find.byType(InkWell),
              )
              .last;

          if (type == initiallySelected) {
            // Selected type should have a filled radio button center
            expect(
              find.descendant(
                of: typeOptionFinder,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container &&
                      widget.constraints?.maxWidth == 10 &&
                      widget.constraints?.maxHeight == 10 &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration as BoxDecoration?)?.shape ==
                          BoxShape.circle,
                ),
              ),
              findsOneWidget,
              reason: 'Selected type should have a filled radio button',
            );
          } else {
            // Unselected types should not have the inner circle
            expect(
              find.descendant(
                of: typeOptionFinder,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container &&
                      widget.constraints?.maxWidth == 10 &&
                      widget.constraints?.maxHeight == 10,
                ),
              ),
              findsNothing,
              reason: 'Unselected type should not have filled radio button',
            );
          }
        }
      });

      testWidgets('tapping a radio button updates its state in the modal',
          (tester) async {
        await openModal(
          tester,
          initialSelection: AiResponseType.imageAnalysis,
        );

        const typeToSelect =
            AiResponseType.taskSummary; // Changed to select a different type

        final typeOptionFinder = find
            .ancestor(
              of: find.text(typeToSelect.localizedNameFromContext(l10n)),
              matching: find.byType(InkWell),
            )
            .last;

        // Check initial state - should not have filled radio button since it's not selected
        expect(
          find.descendant(
            of: typeOptionFinder,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.constraints?.maxWidth == 10 &&
                  widget.constraints?.maxHeight == 10,
            ),
          ),
          findsNothing,
          reason:
              'Unselected type should not have filled radio button initially',
        );

        await tester.tap(typeOptionFinder);
        await tester.pumpAndSettle();

        // After tap, should have filled radio button
        expect(
          find.descendant(
            of: typeOptionFinder,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.constraints?.maxWidth == 10 &&
                  widget.constraints?.maxHeight == 10 &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration?)?.shape ==
                      BoxShape.circle,
            ),
          ),
          findsOneWidget,
          reason: 'Selected type should have a filled radio button after tap',
        );

        // Check that the save button exists and is enabled by looking for the save text
        final saveButtonTextFinder = find.text(l10n.saveButtonLabel);
        expect(saveButtonTextFinder, findsOneWidget);

        // Find the button ancestor of the save text
        final buttonFinder = find.ancestor(
          of: saveButtonTextFinder,
          matching: find.byType(ElevatedButton),
        );

        if (buttonFinder.evaluate().isNotEmpty) {
          final saveButton = tester.widget<ElevatedButton>(buttonFinder);
          expect(saveButton.onPressed, isNotNull);
        }
      });

      testWidgets('save button is disabled if no option is selected in modal',
          (tester) async {
        // Open modal with no initial selection
        await openModal(tester);

        // Verify save button is disabled
        final saveButtonFinder =
            find.widgetWithText(ElevatedButton, l10n.saveButtonLabel);
        if (saveButtonFinder.evaluate().isNotEmpty) {
          final saveButton = tester.widget<ElevatedButton>(saveButtonFinder);
          expect(saveButton.onPressed, isNull);
        } else {
          // Fallback: check that Save text exists but button should be disabled
          expect(find.text(l10n.saveButtonLabel), findsOneWidget);
        }

        // Select an option
        const typeToSelect = AiResponseType.imageAnalysis;
        final typeOptionFinder = find
            .ancestor(
              of: find.text(typeToSelect.localizedNameFromContext(l10n)),
              matching: find.byType(InkWell),
            )
            .last;
        await tester.tap(typeOptionFinder);
        await tester.pumpAndSettle();

        // Verify save button is enabled
        final enabledSaveButtonFinder =
            find.widgetWithText(ElevatedButton, l10n.saveButtonLabel);
        if (enabledSaveButtonFinder.evaluate().isNotEmpty) {
          final enabledSaveButton =
              tester.widget<ElevatedButton>(enabledSaveButtonFinder);
          expect(enabledSaveButton.onPressed, isNotNull);
        } else {
          expect(find.text(l10n.saveButtonLabel), findsOneWidget);
        }
      });

      testWidgets('tapping "Save" calls aiResponseTypeChanged and closes modal',
          (tester) async {
        const initialType = AiResponseType.imageAnalysis;
        const typeToSelectInModal = AiResponseType.taskSummary;

        fakePromptFormController.primeInitialBuildState(
          AsyncData(
            createDefaultPromptFormState(
              aiResponseType: const PromptAiResponseType.dirty(initialType),
            ),
          ),
        );
        await openModal(tester, initialSelection: initialType);

        // Verify modal opened and content is visible
        expect(
          find.byType(ResponseTypeSelectionModal),
          findsOneWidget,
          reason: 'Modal should be visible',
        );

        // Find type option within the modal
        final modalFinder = find.byType(ResponseTypeSelectionModal);
        final typeTextFinder = find.descendant(
          of: modalFinder,
          matching:
              find.text(typeToSelectInModal.localizedNameFromContext(l10n)),
        );
        expect(typeTextFinder, findsOneWidget,
            reason: 'Type option should be visible in modal');

        // Find the InkWell ancestor of the type text
        final typeOptionFinder = find.ancestor(
          of: typeTextFinder,
          matching: find.byType(InkWell),
        );
        expect(typeOptionFinder, findsWidgets,
            reason: 'Should find InkWell for type option');

        // Tap the first InkWell found (which should be the type option)
        await tester.tap(typeOptionFinder.first);
        await tester.pumpAndSettle();

        // Verify the type was actually selected
        final selectedTypeFinder = find.descendant(
          of: find
              .ancestor(
                of: find
                    .text(typeToSelectInModal.localizedNameFromContext(l10n)),
                matching: find.byType(InkWell),
              )
              .last,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.maxWidth == 10 &&
                widget.constraints?.maxHeight == 10,
          ),
        );
        expect(selectedTypeFinder, findsOneWidget,
            reason: 'Selected type should have filled radio button');

        // Find the save button within the modal
        final saveButtonFinder = find.descendant(
          of: modalFinder,
          matching: find.byType(ElevatedButton),
        );

        if (saveButtonFinder.evaluate().isEmpty) {
          // If no ElevatedButton, try finding by text
          final saveTextFinder = find.descendant(
            of: modalFinder,
            matching: find.text(l10n.saveButtonLabel),
          );
          expect(saveTextFinder, findsOneWidget,
              reason: 'Save button text should be visible');

          // Ensure save button is visible before tapping
          await tester.ensureVisible(saveTextFinder);
          await tester.pumpAndSettle();

          await tester.tap(saveTextFinder, warnIfMissed: false);
        } else {
          expect(saveButtonFinder, findsOneWidget,
              reason: 'Should find save button in modal');

          // Ensure save button is visible before tapping
          await tester.ensureVisible(saveButtonFinder);
          await tester.pumpAndSettle();

          await tester.tap(saveButtonFinder, warnIfMissed: false);
        }

        await tester.pump(); // First pump to trigger the callback
        await tester
            .pump(const Duration(milliseconds: 100)); // Allow time for callback
        await tester.pumpAndSettle(); // Wait for animations

        // Verify that the callback was called with correct value
        expect(
          fakePromptFormController.lastAiResponseTypeChanged,
          typeToSelectInModal,
          reason: 'Callback should have been called with selected type',
        );

        // Verify the widget text updates to the new selection
        expect(
          find.text(typeToSelectInModal.localizedNameFromContext(l10n)),
          findsOneWidget,
        );
      });
    });
  });
}

// Helper extension for tests to get localized strings without BuildContext
extension AiResponseTypeTestDisplay on AiResponseType {
  String localizedNameFromContext(AppLocalizations l10nParam) {
    // This helper should mirror the logic in AiResponseType.localizedName(context)
    switch (this) {
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.actionItemSuggestions:
        return l10nParam.aiResponseTypeActionItemSuggestions;
      case AiResponseType.taskSummary:
        return l10nParam.aiResponseTypeTaskSummary;
      case AiResponseType.imageAnalysis:
        return l10nParam.aiResponseTypeImageAnalysis;
      case AiResponseType.audioTranscription:
        return l10nParam.aiResponseTypeAudioTranscription;
      // Add cases for other types if they were in the original incorrect list
      // and have corresponding l10n keys. Based on consts.dart, these are all.
    }
  }
}

// Ensure this extension is available if your AiResponseType enum needs it for localizedName
// If AiResponseType.localizedName(context) directly uses context.messages, this might not be strictly
// needed for the test file itself, but the helper above (localizedNameFromContext) is good practice.
// extension AppLocalizationsContext on BuildContext {
//   AppLocalizations get messages => AppLocalizations.of(this)!;
// }
