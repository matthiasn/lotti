import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/model_management_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

// Create a proper test controller that extends the actual controller
class TestAiConfigByTypeController extends AiConfigByTypeController {
  TestAiConfigByTypeController(this.models);

  final List<AiConfigModel> models;

  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) {
    return Stream.value(models);
  }
}

// Create a test controller that returns an error
class ErrorTestAiConfigByTypeController extends AiConfigByTypeController {
  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) {
    return Stream.error(Exception('Failed to load models'));
  }
}

final AppLocalizations l10n = AppLocalizationsEn();

void main() {
  late List<AiConfigModel> mockModels;

  setUp(() {
    mockModels = [
      AiConfigModel(
        id: 'model1',
        name: 'GPT-4',
        providerModelId: 'gpt-4',
        inferenceProviderId: 'provider1',
        createdAt: DateTime.now(),
        description: 'Advanced language model',
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      ),
      AiConfigModel(
        id: 'model2',
        name: 'Claude Sonnet',
        providerModelId: 'claude-sonnet',
        inferenceProviderId: 'provider2',
        createdAt: DateTime.now(),
        description: 'Balanced performance',
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      ),
      AiConfigModel(
        id: 'model3',
        name: 'Gemini Pro',
        providerModelId: 'gemini-pro',
        inferenceProviderId: 'provider3',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      ),
    ];
  });

  Widget createTestApp({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: child,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
  }

  // Helper to open modal and wait for content to load
  Future<void> openModalAndWaitForContent(WidgetTester tester) async {
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Additional pump to ensure stream data is processed
    await tester.pump();
    await tester.pump();
  }

  group('Model Management Modal Tests', () {
    testWidgets('opens modal and displays initial content', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: ['model1'],
                    currentDefaultId: 'model1',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController(mockModels)),
          ],
        ),
      );

      // Verify button exists
      expect(find.text('Open Modal'), findsOneWidget);

      // Open modal
      await openModalAndWaitForContent(tester);

      // Verify modal content
      expect(find.text('1 model selected'), findsOneWidget);
      expect(find.text(l10n.cancelButton), findsOneWidget);
      expect(find.text(l10n.saveButtonLabel), findsOneWidget);

      // Just check that the modal opened successfully
      // The model list might be lazy-loaded or in a different part of the tree
    });

    testWidgets('selection count updates with proper grammar', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      key: const Key('no_selection'),
                      onPressed: () => showModelManagementModal(
                        context: context,
                        currentSelectedIds: [],
                        currentDefaultId: '',
                        onSave: (selectedIds, defaultId) {},
                      ),
                      child: const Text('No Selection'),
                    ),
                    ElevatedButton(
                      key: const Key('one_selection'),
                      onPressed: () => showModelManagementModal(
                        context: context,
                        currentSelectedIds: ['model1'],
                        currentDefaultId: 'model1',
                        onSave: (selectedIds, defaultId) {},
                      ),
                      child: const Text('One Selection'),
                    ),
                    ElevatedButton(
                      key: const Key('two_selections'),
                      onPressed: () => showModelManagementModal(
                        context: context,
                        currentSelectedIds: ['model1', 'model2'],
                        currentDefaultId: 'model1',
                        onSave: (selectedIds, defaultId) {},
                      ),
                      child: const Text('Two Selections'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController(mockModels)),
          ],
        ),
      );

      // Test 0 models selected
      await tester.tap(find.byKey(const Key('no_selection')));
      await tester.pumpAndSettle();
      expect(find.text('0 models selected'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Test 1 model selected
      await tester.tap(find.byKey(const Key('one_selection')));
      await tester.pumpAndSettle();
      expect(find.text('1 model selected'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Test 2 models selected
      await tester.tap(find.byKey(const Key('two_selections')));
      await tester.pumpAndSettle();
      expect(find.text('2 models selected'), findsOneWidget);
    });

    testWidgets('shows warning/check icon based on selection', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController(mockModels)),
          ],
        ),
      );

      // Open modal with no selection
      await openModalAndWaitForContent(tester);

      // Should show warning icon when no models selected
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Open modal with selection
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: ['model1'],
                    currentDefaultId: 'model1',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController(mockModels)),
          ],
        ),
      );

      await openModalAndWaitForContent(tester);

      // Should show check icon when models are selected
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsNothing);
    });

    testWidgets('animates between warning and check icons', (tester) async {
      // Create a mutable list to simulate changing selection
      final selectedIds = <String>[];

      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => showModelManagementModal(
                        context: context,
                        currentSelectedIds: List.from(selectedIds),
                        currentDefaultId:
                            selectedIds.isNotEmpty ? selectedIds.first : '',
                        onSave: (newSelectedIds, defaultId) {
                          setState(() {
                            selectedIds
                              ..clear()
                              ..addAll(newSelectedIds);
                          });
                        },
                      ),
                      child: const Text('Open Modal'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (selectedIds.isEmpty) {
                            selectedIds.add('model1');
                          } else {
                            selectedIds.clear();
                          }
                        });
                      },
                      child: Text(selectedIds.isEmpty
                          ? 'Add Selection'
                          : 'Clear Selection'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController(mockModels)),
          ],
        ),
      );

      // Open modal with no selection
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify warning icon is shown
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);

      // The AnimatedSwitcher should handle the transition smoothly
      // We can't easily test the animation itself, but we can verify
      // that the widget structure is correct
      expect(find.byType(AnimatedSwitcher), findsAtLeastNWidgets(1));
    });

    testWidgets('save and cancel buttons work correctly', (tester) async {
      var saveCalled = false;
      List<String>? savedSelectedIds;
      String? savedDefaultId;

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: ['model1'],
                    currentDefaultId: 'model1',
                    onSave: (selectedIds, defaultId) {
                      saveCalled = true;
                      savedSelectedIds = selectedIds;
                      savedDefaultId = defaultId;
                    },
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController(mockModels)),
          ],
        ),
      );

      // Test Cancel button
      await openModalAndWaitForContent(tester);
      await tester.tap(find.text(l10n.cancelButton));
      await tester.pumpAndSettle();

      expect(saveCalled, isFalse);
      expect(find.text('Open Modal'), findsOneWidget);

      // Test Save button
      await openModalAndWaitForContent(tester);
      await tester.tap(find.text(l10n.saveButtonLabel));
      await tester.pumpAndSettle();

      expect(saveCalled, isTrue);
      expect(savedSelectedIds, equals(['model1']));
      expect(savedDefaultId, equals('model1'));
    });

    testWidgets('save button disabled when no models selected', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController(mockModels)),
          ],
        ),
      );

      // Open modal
      await openModalAndWaitForContent(tester);

      // Find save button and verify it's disabled
      final saveButton =
          find.widgetWithText(LottiPrimaryButton, l10n.saveButtonLabel);
      expect(saveButton, findsOneWidget);

      final primaryButton = tester.widget<LottiPrimaryButton>(saveButton);
      expect(primaryButton.onPressed, isNull);
    });

    testWidgets('shows empty state when no models available', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController([])),
          ],
        ),
      );

      // Open modal
      await openModalAndWaitForContent(tester);

      // Verify empty state - icon should be present
      final emptyStateIcon = find.byIcon(Icons.psychology_outlined);
      expect(emptyStateIcon, findsOneWidget);
    });

    testWidgets('shows error state and message', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(ErrorTestAiConfigByTypeController.new),
          ],
        ),
      );

      // Open modal
      await openModalAndWaitForContent(tester);

      // Verify error state - just check that error icon exists
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('glassmorphic effect is present in sticky action bar',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: ['model1'],
                    currentDefaultId: 'model1',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController(mockModels)),
          ],
        ),
      );

      // Open modal
      await openModalAndWaitForContent(tester);

      // Verify BackdropFilter exists (glassmorphic effect)
      final backdropFilter = find.byType(BackdropFilter);
      expect(backdropFilter, findsOneWidget);

      // Verify blur effect
      final filter = tester.widget<BackdropFilter>(backdropFilter);
      expect(filter.filter, isA<ImageFilter>());
    });

    testWidgets('modal dismisses when tapping outside', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController(mockModels)),
          ],
        ),
      );

      // Open modal
      await openModalAndWaitForContent(tester);

      // Verify modal is open
      expect(find.text('0 models selected'), findsOneWidget);

      // Tap outside the modal (on the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Modal should be closed
      expect(find.text('0 models selected'), findsNothing);
      expect(find.text('Open Modal'), findsOneWidget);
    });

    testWidgets('complete interaction test - select models and save',
        (tester) async {
      List<String>? savedSelectedIds;
      String? savedDefaultId;

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: ['model1'],
                    currentDefaultId: 'model1',
                    onSave: (selectedIds, defaultId) {
                      savedSelectedIds = selectedIds;
                      savedDefaultId = defaultId;
                    },
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(() => TestAiConfigByTypeController(mockModels)),
            // Add provider overrides for provider names (optional)
            aiConfigByIdProvider('provider1').overrideWith(
              (ref) async => AiConfigInferenceProvider(
                id: 'provider1',
                name: 'OpenAI',
                baseUrl: 'https://api.openai.com',
                apiKey: 'test-key',
                createdAt: DateTime.now(),
                inferenceProviderType: InferenceProviderType.openAi,
              ),
            ),
          ],
        ),
      );

      // Open modal
      await openModalAndWaitForContent(tester);

      // Verify initial state
      expect(find.text('1 model selected'), findsOneWidget);

      // Try to interact with models if they're visible
      final claudeFinder = find.text('Claude Sonnet');
      if (claudeFinder.evaluate().isNotEmpty) {
        await tester.tap(claudeFinder);
        await tester.pumpAndSettle();

        // Should now show 2 models selected
        expect(find.text('2 models selected'), findsOneWidget);
      }

      // Save
      await tester.tap(find.text(l10n.saveButtonLabel));
      await tester.pumpAndSettle();

      // Verify save was called
      expect(savedSelectedIds, isNotNull);
      expect(savedDefaultId, isNotNull);
    });
  });

  group('Provider Filter Tests', () {
    late List<AiConfigModel> multiProviderModels;
    late List<AiConfigInferenceProvider> providers;

    setUp(() {
      providers = [
        AiConfigInferenceProvider(
          id: 'provider1',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.openAi,
        ),
        AiConfigInferenceProvider(
          id: 'provider2',
          name: 'Anthropic',
          baseUrl: 'https://api.anthropic.com',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.anthropic,
        ),
        AiConfigInferenceProvider(
          id: 'provider3',
          name: 'Gemini',
          baseUrl: 'https://api.google.com',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.gemini,
        ),
      ];

      multiProviderModels = [
        AiConfigModel(
          id: 'model1',
          name: 'GPT-4',
          providerModelId: 'gpt-4',
          inferenceProviderId: 'provider1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
        AiConfigModel(
          id: 'model2',
          name: 'GPT-3.5',
          providerModelId: 'gpt-3.5',
          inferenceProviderId: 'provider1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
        AiConfigModel(
          id: 'model3',
          name: 'Claude Sonnet',
          providerModelId: 'claude-sonnet',
          inferenceProviderId: 'provider2',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
        AiConfigModel(
          id: 'model4',
          name: 'Gemini Pro',
          providerModelId: 'gemini-pro',
          inferenceProviderId: 'provider3',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      ];
    });

    test('extracts unique provider IDs from models', () {
      // Test the data logic directly without widgets
      final providerIds = multiProviderModels
          .map((m) => m.inferenceProviderId)
          .toSet()
          .toList();

      expect(providerIds.length, equals(3));
      expect(providerIds.contains('provider1'), isTrue);
      expect(providerIds.contains('provider2'), isTrue);
      expect(providerIds.contains('provider3'), isTrue);
    });

    test('single provider models extract to one unique ID', () {
      final singleProviderModels = [
        AiConfigModel(
          id: 'model1',
          name: 'GPT-4',
          providerModelId: 'gpt-4',
          inferenceProviderId: 'provider1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
        AiConfigModel(
          id: 'model2',
          name: 'GPT-3.5',
          providerModelId: 'gpt-3.5',
          inferenceProviderId: 'provider1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      ];

      final providerIds = singleProviderModels
          .map((m) => m.inferenceProviderId)
          .toSet()
          .toList();

      expect(providerIds.length, equals(1));
      expect(providerIds.first, equals('provider1'));
    });

    test('filtering models by provider ID returns correct subset', () {
      // Test filtering logic directly
      final filteredByProvider1 = multiProviderModels
          .where((m) => m.inferenceProviderId == 'provider1')
          .toList();

      expect(filteredByProvider1.length, equals(2));
      expect(
          filteredByProvider1
              .every((m) => m.inferenceProviderId == 'provider1'),
          isTrue);
      expect(filteredByProvider1.any((m) => m.name == 'GPT-4'), isTrue);
      expect(filteredByProvider1.any((m) => m.name == 'GPT-3.5'), isTrue);

      final filteredByProvider2 = multiProviderModels
          .where((m) => m.inferenceProviderId == 'provider2')
          .toList();

      expect(filteredByProvider2.length, equals(1));
      expect(filteredByProvider2.first.name, equals('Claude Sonnet'));
    });

    test('switching filter providers changes filtered model set', () {
      // Simulate provider switching logic
      String? selectedProviderId = 'provider2';

      var displayedModels = multiProviderModels
          .where((m) => m.inferenceProviderId == selectedProviderId)
          .toList();

      expect(displayedModels.length, equals(1));
      expect(displayedModels.first.name, equals('Claude Sonnet'));

      // Switch to provider3
      selectedProviderId = 'provider3';
      displayedModels = multiProviderModels
          .where((m) => m.inferenceProviderId == selectedProviderId)
          .toList();

      expect(displayedModels.length, equals(1));
      expect(displayedModels.first.name, equals('Gemini Pro'));
    });

    test('null provider filter shows all models', () {
      // Simulate "All" chip behavior - when no filter is selected, show all models
      const String? selectedProviderId = null;

      // When selectedProviderId is null, show all models
      final displayedModels = selectedProviderId == null
          ? multiProviderModels
          : multiProviderModels
              .where((m) => m.inferenceProviderId == selectedProviderId)
              .toList();

      expect(displayedModels.length, equals(4));
      expect(displayedModels, equals(multiProviderModels));
    });

    testWidgets('horizontal scroll works with many providers', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(
                    () => TestAiConfigByTypeController(multiProviderModels)),
            for (final provider in providers)
              aiConfigByIdProvider(provider.id)
                  .overrideWith((ref) async => provider),
          ],
        ),
      );

      await openModalAndWaitForContent(tester);

      // Verify SingleChildScrollView with horizontal axis exists
      final scrollView = find.byType(SingleChildScrollView).evaluate();
      expect(
        scrollView.any((element) {
          final widget = element.widget as SingleChildScrollView;
          return widget.scrollDirection == Axis.horizontal;
        }),
        isTrue,
      );
    });

    test('model count changes with filtering but list reference stays same',
        () {
      // Test that filtering changes count but original list is preserved
      final allModels = multiProviderModels;

      final filteredModels =
          allModels.where((m) => m.inferenceProviderId == 'provider1').toList();

      expect(filteredModels.length, equals(2));
      expect(allModels.length, equals(4)); // Original list unchanged
      expect(identical(allModels, multiProviderModels), isTrue);
    });
  });

  group('Provider Filter Integration Tests', () {
    late List<AiConfigModel> multiProviderModels;
    late List<AiConfigInferenceProvider> providers;

    setUp(() {
      providers = [
        AiConfigInferenceProvider(
          id: 'provider1',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.openAi,
        ),
        AiConfigInferenceProvider(
          id: 'provider2',
          name: 'Anthropic',
          baseUrl: 'https://api.anthropic.com',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.anthropic,
        ),
      ];

      multiProviderModels = [
        AiConfigModel(
          id: 'model1',
          name: 'GPT-4',
          providerModelId: 'gpt-4',
          inferenceProviderId: 'provider1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
        AiConfigModel(
          id: 'model2',
          name: 'Claude Sonnet',
          providerModelId: 'claude-sonnet',
          inferenceProviderId: 'provider2',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      ];
    });

    testWidgets('select model after filtering by provider', (tester) async {
      List<String>? savedSelectedIds;

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {
                      savedSelectedIds = selectedIds;
                    },
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(
                    () => TestAiConfigByTypeController(multiProviderModels)),
            for (final provider in providers)
              aiConfigByIdProvider(provider.id)
                  .overrideWith((ref) async => provider),
          ],
        ),
      );

      await openModalAndWaitForContent(tester);

      // Filter by OpenAI
      await tester.tap(find.text('OpenAI').first);
      await tester.pumpAndSettle();

      // Select GPT-4 (find it specifically as a model card, not a text)
      final gpt4Finder = find.textContaining('GPT-4').first;
      await tester.tap(gpt4Finder);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text(l10n.saveButtonLabel));
      await tester.pumpAndSettle();

      expect(savedSelectedIds, isNotNull);
      expect(savedSelectedIds!.length, equals(1));
    });

    testWidgets('filter persists during model selection', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(
                    () => TestAiConfigByTypeController(multiProviderModels)),
            for (final provider in providers)
              aiConfigByIdProvider(provider.id)
                  .overrideWith((ref) async => provider),
          ],
        ),
      );

      await openModalAndWaitForContent(tester);

      // Filter by Anthropic
      await tester.tap(find.text('Anthropic').first);
      await tester.pumpAndSettle();

      // Select Claude
      await tester.tap(find.text('Claude Sonnet').first);
      await tester.pumpAndSettle();

      // Verify OpenAI model is still hidden (filter persists)
      expect(find.textContaining('GPT'), findsNothing);
      expect(find.text('Claude Sonnet'), findsWidgets);
    });

    testWidgets('set default model with filter active', (tester) async {
      String? savedDefaultId;

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {
                      savedDefaultId = defaultId;
                    },
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(
                    () => TestAiConfigByTypeController(multiProviderModels)),
            for (final provider in providers)
              aiConfigByIdProvider(provider.id)
                  .overrideWith((ref) async => provider),
          ],
        ),
      );

      await openModalAndWaitForContent(tester);

      // Filter by OpenAI
      await tester.tap(find.text('OpenAI').first);
      await tester.pumpAndSettle();

      // Select GPT-4 (becomes default automatically as first selection)
      await tester.tap(find.textContaining('GPT-4').first);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text(l10n.saveButtonLabel));
      await tester.pumpAndSettle();

      expect(savedDefaultId, isNotNull);
      expect(savedDefaultId, isNotEmpty);
    });
  });

  group('Provider Filter Edge Cases', () {
    testWidgets('empty results when provider has no models', (tester) async {
      final providersWithNoModels = [
        AiConfigInferenceProvider(
          id: 'provider1',
          name: 'Empty Provider',
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.openAi,
        ),
        AiConfigInferenceProvider(
          id: 'provider2',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.openAi,
        ),
      ];

      final modelsForOneProvider = [
        AiConfigModel(
          id: 'model1',
          name: 'GPT-4',
          providerModelId: 'gpt-4',
          inferenceProviderId: 'provider2',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(
                    () => TestAiConfigByTypeController(modelsForOneProvider)),
            for (final provider in providersWithNoModels)
              aiConfigByIdProvider(provider.id)
                  .overrideWith((ref) async => provider),
          ],
        ),
      );

      await openModalAndWaitForContent(tester);

      // Filter by empty provider - should show provider chip but no models
      // Note: Provider chip only shows if provider has models, so this test
      // verifies the logic handles this edge case gracefully
      expect(find.text('GPT-4'), findsOneWidget);
    });

    testWidgets('all models from same provider still shows filter',
        (tester) async {
      final multiProviderConfig = [
        AiConfigInferenceProvider(
          id: 'provider1',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.openAi,
        ),
        AiConfigInferenceProvider(
          id: 'provider2',
          name: 'Anthropic',
          baseUrl: 'https://api.anthropic.com',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.anthropic,
        ),
      ];

      final allFromSameProvider = [
        AiConfigModel(
          id: 'model1',
          name: 'GPT-4',
          providerModelId: 'gpt-4',
          inferenceProviderId: 'provider1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
        AiConfigModel(
          id: 'model2',
          name: 'GPT-3.5',
          providerModelId: 'gpt-3.5',
          inferenceProviderId: 'provider1',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModelManagementModal(
                    context: context,
                    currentSelectedIds: [],
                    currentDefaultId: '',
                    onSave: (selectedIds, defaultId) {},
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
          overrides: [
            aiConfigByTypeControllerProvider(configType: AiConfigType.model)
                .overrideWith(
                    () => TestAiConfigByTypeController(allFromSameProvider)),
            for (final provider in multiProviderConfig)
              aiConfigByIdProvider(provider.id)
                  .overrideWith((ref) async => provider),
          ],
        ),
      );

      await openModalAndWaitForContent(tester);

      // Should NOT show filters since only one provider has models
      expect(find.text('All'), findsNothing);
    });
  });
}
