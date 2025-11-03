import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_filter_chip.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_filter_chips_row.dart';
import 'package:lotti/l10n/app_localizations.dart';

// Test controller for overriding provider data
class TestAiConfigByTypeController extends AiConfigByTypeController {
  TestAiConfigByTypeController(this.providers);

  final List<AiConfig> providers;

  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) {
    return Stream.value(providers);
  }
}

// Test controller that returns an error
class ErrorTestAiConfigByTypeController extends AiConfigByTypeController {
  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) {
    return Stream.error(Exception('Test error'));
  }
}

// Test controller that returns empty stream for loading state
class LoadingTestAiConfigByTypeController extends AiConfigByTypeController {
  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) {
    return const Stream.empty();
  }
}

void main() {
  group('ProviderFilterChipsRow', () {
    // Helper function to create mock providers for testing
    List<AiConfigInferenceProvider> createMockProviders() {
      return [
        AiConfigInferenceProvider(
          id: 'provider1',
          name: 'Anthropic',
          baseUrl: 'https://api.anthropic.com',
          apiKey: 'test-key',
          createdAt: DateTime(2025),
          inferenceProviderType: InferenceProviderType.anthropic,
        ),
        AiConfigInferenceProvider(
          id: 'provider2',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com',
          apiKey: 'test-key',
          createdAt: DateTime(2025, 1, 2),
          inferenceProviderType: InferenceProviderType.openAi,
        ),
        AiConfigInferenceProvider(
          id: 'provider3',
          name: 'Gemini',
          baseUrl: 'https://api.google.com',
          apiKey: 'test-key',
          createdAt: DateTime(2025, 1, 3),
          inferenceProviderType: InferenceProviderType.gemini,
        ),
      ];
    }

    // Helper function to create test widget with proper setup
    Widget createTestWidget({
      required Set<String> selectedProviderIds,
      required ValueChanged<Set<String>> onChanged,
      required List<AiConfig> mockProviders,
      bool allowMultiSelect = true,
      bool showAllChip = false,
      List<String>? availableProviderIds,
      bool useStyledChips = false,
    }) {
      return ProviderScope(
        overrides: [
          aiConfigByTypeControllerProvider(
            configType: AiConfigType.inferenceProvider,
          ).overrideWith(() => TestAiConfigByTypeController(mockProviders)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProviderFilterChipsRow(
              selectedProviderIds: selectedProviderIds,
              onChanged: onChanged,
              allowMultiSelect: allowMultiSelect,
              showAllChip: showAllChip,
              availableProviderIds: availableProviderIds,
              useStyledChips: useStyledChips,
            ),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
    }

    group('Basic Rendering', () {
      testWidgets('renders provider chips for all available providers',
          (tester) async {
        final mockProviders = createMockProviders();

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (_) {},
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify all provider names are displayed
        expect(find.text('Anthropic'), findsOneWidget);
        expect(find.text('OpenAI'), findsOneWidget);
        expect(find.text('Gemini'), findsOneWidget);

        // Verify 3 FilterChip widgets are found
        expect(find.byType(FilterChip), findsNWidgets(3));
      });

      testWidgets('shows All chip when showAllChip is true', (tester) async {
        final mockProviders = createMockProviders();

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (_) {},
            showAllChip: true,
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify "All" chip is rendered (using the localized string)
        expect(find.text('All'), findsOneWidget);

        // Verify 4 FilterChip widgets (3 providers + All)
        expect(find.byType(FilterChip), findsNWidgets(4));
      });

      testWidgets('hides All chip when showAllChip is false', (tester) async {
        final mockProviders = createMockProviders();

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (_) {},
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify "All" text is not found
        expect(find.text('All'), findsNothing);

        // Verify only 3 FilterChip widgets (just providers)
        expect(find.byType(FilterChip), findsNWidgets(3));
      });

      testWidgets('renders empty when no providers available', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (_) {},
            mockProviders: [],
          ),
        );

        await tester.pumpAndSettle();

        // Verify no FilterChip widgets are found
        expect(find.byType(FilterChip), findsNothing);

        // Verify no provider names appear
        expect(find.text('Anthropic'), findsNothing);
        expect(find.text('OpenAI'), findsNothing);
        expect(find.text('Gemini'), findsNothing);
      });
    });

    group('Multi-Select Mode', () {
      testWidgets('allows selecting multiple providers in multi-select mode',
          (tester) async {
        final mockProviders = createMockProviders();
        Set<String>? callbackValue;

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (newSelection) => callbackValue = newSelection,
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Tap first provider
        await tester.tap(find.text('Anthropic'));
        await tester.pump();

        expect(callbackValue, equals({'provider1'}));

        // Rebuild with updated selection
        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider1'},
            onChanged: (newSelection) => callbackValue = newSelection,
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Tap second provider
        await tester.tap(find.text('OpenAI'));
        await tester.pump();

        expect(callbackValue, equals({'provider1', 'provider2'}));
      });

      testWidgets('allows deselecting providers in multi-select mode',
          (tester) async {
        final mockProviders = createMockProviders();
        Set<String>? callbackValue;

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider1', 'provider2'},
            onChanged: (newSelection) => callbackValue = newSelection,
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Tap provider1 chip to deselect
        await tester.tap(find.text('Anthropic'));
        await tester.pump();

        expect(callbackValue, equals({'provider2'}));
      });

      testWidgets('All chip clears all selections in multi-select mode',
          (tester) async {
        final mockProviders = createMockProviders();
        Set<String>? callbackValue;

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider1', 'provider2'},
            onChanged: (newSelection) => callbackValue = newSelection,
            showAllChip: true,
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Tap "All" chip
        await tester.tap(find.text('All'));
        await tester.pump();

        expect(callbackValue, equals(<String>{}));
      });
    });

    group('Single-Select Mode', () {
      testWidgets('replaces selection in single-select mode', (tester) async {
        final mockProviders = createMockProviders();
        Set<String>? callbackValue;

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (newSelection) => callbackValue = newSelection,
            allowMultiSelect: false,
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Tap provider1
        await tester.tap(find.text('Anthropic'));
        await tester.pump();

        expect(callbackValue, equals({'provider1'}));

        // Rebuild with updated selection
        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider1'},
            onChanged: (newSelection) => callbackValue = newSelection,
            allowMultiSelect: false,
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Tap provider2 - should replace selection
        await tester.tap(find.text('OpenAI'));
        await tester.pump();

        expect(callbackValue, equals({'provider2'}));
      });

      testWidgets('deselects when tapping selected chip in single-select mode',
          (tester) async {
        final mockProviders = createMockProviders();
        Set<String>? callbackValue;

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider1'},
            onChanged: (newSelection) => callbackValue = newSelection,
            allowMultiSelect: false,
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Tap provider1 chip again to deselect
        await tester.tap(find.text('Anthropic'));
        await tester.pump();

        expect(callbackValue, equals(<String>{}));
      });

      testWidgets('All chip clears selection in single-select mode',
          (tester) async {
        final mockProviders = createMockProviders();
        Set<String>? callbackValue;

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider1'},
            onChanged: (newSelection) => callbackValue = newSelection,
            allowMultiSelect: false,
            showAllChip: true,
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Tap "All" chip
        await tester.tap(find.text('All'));
        await tester.pump();

        expect(callbackValue, equals(<String>{}));

        // Verify All chip is selected by checking the widget
        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (newSelection) => callbackValue = newSelection,
            allowMultiSelect: false,
            showAllChip: true,
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // All chip should show as selected when selection is empty
        final allChipFinder = find.ancestor(
          of: find.text('All'),
          matching: find.byType(FilterChip),
        );
        final allChip = tester.widget<FilterChip>(allChipFinder.first);
        expect(allChip.selected, isTrue);
      });
    });

    group('Styled vs Plain Chips', () {
      testWidgets('uses ProviderFilterChip when useStyledChips is true',
          (tester) async {
        final mockProviders = createMockProviders();

        // Need to override individual provider lookups for styled chips
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(() => TestAiConfigByTypeController(mockProviders)),
              aiConfigByIdProvider('provider1')
                  .overrideWith((ref) async => mockProviders[0]),
              aiConfigByIdProvider('provider2')
                  .overrideWith((ref) async => mockProviders[1]),
              aiConfigByIdProvider('provider3')
                  .overrideWith((ref) async => mockProviders[2]),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ProviderFilterChipsRow(
                  selectedProviderIds: const {},
                  onChanged: (_) {},
                  useStyledChips: true,
                ),
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify ProviderFilterChip widgets are found
        expect(find.byType(ProviderFilterChip), findsNWidgets(3));

        // Note: FilterChip will still be found because ProviderFilterChip
        // uses FilterChip internally. We just verify ProviderFilterChip exists.
        expect(find.byType(FilterChip), findsNWidgets(3));
      });

      testWidgets('uses plain FilterChip when useStyledChips is false',
          (tester) async {
        final mockProviders = createMockProviders();

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (_) {},
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify FilterChip widgets are found
        expect(find.byType(FilterChip), findsNWidgets(3));

        // Verify ProviderFilterChip is NOT found
        expect(find.byType(ProviderFilterChip), findsNothing);
      });
    });

    group('Provider Filtering', () {
      testWidgets('shows only providers in availableProviderIds list',
          (tester) async {
        final mockProviders = createMockProviders();

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (_) {},
            availableProviderIds: ['provider1', 'provider3'],
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify only 2 chips are rendered
        expect(find.byType(FilterChip), findsNWidgets(2));

        // Verify provider1 and provider3 names appear
        expect(find.text('Anthropic'), findsOneWidget);
        expect(find.text('Gemini'), findsOneWidget);

        // Verify provider2 name does NOT appear
        expect(find.text('OpenAI'), findsNothing);
      });

      testWidgets('shows all providers when availableProviderIds is null',
          (tester) async {
        final mockProviders = createMockProviders();

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (_) {},
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify all 3 provider chips are rendered
        expect(find.byType(FilterChip), findsNWidgets(3));
        expect(find.text('Anthropic'), findsOneWidget);
        expect(find.text('OpenAI'), findsOneWidget);
        expect(find.text('Gemini'), findsOneWidget);
      });

      testWidgets(
          'renders empty when availableProviderIds list excludes all providers',
          (tester) async {
        final mockProviders = createMockProviders();

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (_) {},
            availableProviderIds: [],
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify SizedBox.shrink is rendered
        expect(find.byType(SizedBox), findsOneWidget);

        // Verify no chips are rendered
        expect(find.byType(FilterChip), findsNothing);
      });
    });

    group('State Management', () {
      testWidgets('maintains selection state across rebuilds', (tester) async {
        final mockProviders = createMockProviders();

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider1'},
            onChanged: (_) {},
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Get the FilterChip for provider1 and verify it's selected
        final provider1Chips = find.ancestor(
          of: find.text('Anthropic'),
          matching: find.byType(FilterChip),
        );
        final provider1Chip = tester.widget<FilterChip>(provider1Chips.first);
        expect(provider1Chip.selected, isTrue);

        // Trigger rebuild with same selection
        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider1'},
            onChanged: (_) {},
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify provider1 chip still shows as selected
        final provider1ChipAfterRebuild =
            tester.widget<FilterChip>(provider1Chips.first);
        expect(provider1ChipAfterRebuild.selected, isTrue);
      });

      testWidgets('updates UI when selectedProviderIds prop changes',
          (tester) async {
        final mockProviders = createMockProviders();

        // Start with provider1 selected
        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider1'},
            onChanged: (_) {},
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify provider1 is selected
        final provider1Chips = find.ancestor(
          of: find.text('Anthropic'),
          matching: find.byType(FilterChip),
        );
        var provider1Chip = tester.widget<FilterChip>(provider1Chips.first);
        expect(provider1Chip.selected, isTrue);

        // Rebuild with provider2 selected instead
        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider2'},
            onChanged: (_) {},
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify provider2 chip is now selected
        final provider2Chips = find.ancestor(
          of: find.text('OpenAI'),
          matching: find.byType(FilterChip),
        );
        final provider2Chip = tester.widget<FilterChip>(provider2Chips.first);
        expect(provider2Chip.selected, isTrue);

        // Verify provider1 chip is not selected
        provider1Chip = tester.widget<FilterChip>(provider1Chips.first);
        expect(provider1Chip.selected, isFalse);
      });
    });

    group('Async Data Loading', () {
      testWidgets('shows empty state while loading', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(LoadingTestAiConfigByTypeController.new),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ProviderFilterChipsRow(
                  selectedProviderIds: const {},
                  onChanged: (_) {},
                ),
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        // Don't wait for settle, check loading state immediately
        await tester.pump();

        // Verify loading state shows SizedBox.shrink
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(FilterChip), findsNothing);
      });

      testWidgets('shows empty state on error', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(ErrorTestAiConfigByTypeController.new),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ProviderFilterChipsRow(
                  selectedProviderIds: const {},
                  onChanged: (_) {},
                ),
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify error state shows SizedBox.shrink
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(FilterChip), findsNothing);
      });

      testWidgets('displays providers after successful load', (tester) async {
        final mockProviders = createMockProviders();

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (_) {},
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Verify all chips render correctly
        expect(find.byType(FilterChip), findsNWidgets(3));
        expect(find.text('Anthropic'), findsOneWidget);
        expect(find.text('OpenAI'), findsOneWidget);
        expect(find.text('Gemini'), findsOneWidget);
      });
    });

    group('Interaction & Callbacks', () {
      testWidgets('onChanged callback receives correct Set on selection',
          (tester) async {
        final mockProviders = createMockProviders();
        Set<String>? callbackValue;
        var callbackCount = 0;

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {},
            onChanged: (newSelection) {
              callbackValue = newSelection;
              callbackCount++;
            },
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Tap a chip
        await tester.tap(find.text('Anthropic'));
        await tester.pump();

        // Verify onChanged called once
        expect(callbackCount, equals(1));

        // Verify Set parameter contains correct provider ID
        expect(callbackValue, equals({'provider1'}));
      });

      testWidgets('onChanged callback receives correct Set on deselection',
          (tester) async {
        final mockProviders = createMockProviders();
        Set<String>? callbackValue;
        var callbackCount = 0;

        await tester.pumpWidget(
          createTestWidget(
            selectedProviderIds: {'provider1', 'provider2'},
            onChanged: (newSelection) {
              callbackValue = newSelection;
              callbackCount++;
            },
            mockProviders: mockProviders,
          ),
        );

        await tester.pumpAndSettle();

        // Tap to deselect
        await tester.tap(find.text('Anthropic'));
        await tester.pump();

        // Verify onChanged called with correct reduced Set
        expect(callbackCount, equals(1));
        expect(callbackValue, equals({'provider2'}));
      });
    });
  });
}
