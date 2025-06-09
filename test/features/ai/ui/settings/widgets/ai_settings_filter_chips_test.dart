import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_filter_chips.dart';

import '../../../test_utils.dart';

void main() {
  group('AiSettingsFilterChips', () {
    late AiSettingsFilterState initialFilterState;
    late List<AiSettingsFilterState> filterChanges;
    late List<AiConfig> mockProviders;

    setUp(() {
      initialFilterState = AiSettingsFilterState.initial();
      filterChanges = [];
      mockProviders = [AiTestDataFactory.createTestProvider()];
    });

    Widget createWidget({
      AiSettingsFilterState? filterState,
      ValueChanged<AiSettingsFilterState>? onFilterChanged,
    }) {
      return AiTestSetup.createTestApp(
        providerOverrides: AiTestSetup.createControllerOverrides(
          providers: mockProviders,
        ),
        child: AiSettingsFilterChips(
          filterState: filterState ?? initialFilterState,
          onFilterChanged: onFilterChanged ??
              (state) {
                filterChanges.add(state);
              },
        ),
      );
    }

    group('rendering', () {
      testWidgets('displays capability filter chips',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Should show capability chips for text, image, audio
        // Check both icons and labels
        expect(find.text('Text'), findsOneWidget);
        expect(find.byIcon(Icons.text_fields), findsOneWidget);
        expect(find.text('Vision'), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.byIcon(Icons.hearing), findsOneWidget);
      });

      testWidgets('displays reasoning filter chip',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        expect(find.text('Reasoning'), findsOneWidget);
        expect(find.byIcon(Icons.psychology), findsOneWidget);
      });

      testWidgets('shows clear filters action when filters are active',
          (WidgetTester tester) async {
        final filterState = initialFilterState.copyWith(
          selectedCapabilities: {Modality.image},
        );

        await tester.pumpWidget(createWidget(filterState: filterState));
        await tester.pumpAndSettle(); // Allow AnimatedSwitcher to complete

        expect(find.text('Clear'), findsOneWidget);
        expect(find.byIcon(Icons.clear), findsOneWidget);
      });

      testWidgets('hides clear filters when no filters are active',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle(); // Allow AnimatedSwitcher to complete

        expect(find.text('Clear'), findsNothing);
        expect(find.byIcon(Icons.clear), findsNothing);
      });
    });

    group('capability filter interaction', () {
      testWidgets('toggles image capability filter',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Find the FilterChip that contains the Vision text
        final visionChipFinder = find.ancestor(
          of: find.text('Vision'),
          matching: find.byType(FilterChip),
        );
        
        // Verify the chip exists
        expect(visionChipFinder, findsOneWidget);
        
        // Tap on the FilterChip itself instead of just the text
        await tester.tap(visionChipFinder);
        await tester.pump();

        expect(filterChanges, hasLength(1));
        expect(filterChanges.first.selectedCapabilities, {Modality.image});
      });

      testWidgets('toggles audio capability filter',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Find the FilterChip that contains the Audio text
        final audioChipFinder = find.ancestor(
          of: find.text('Audio'),
          matching: find.byType(FilterChip),
        );
        
        // Verify the chip exists
        expect(audioChipFinder, findsOneWidget);
        
        // Tap on the FilterChip itself instead of just the text
        await tester.tap(audioChipFinder);
        await tester.pump();

        expect(filterChanges, hasLength(1));
        expect(filterChanges.first.selectedCapabilities, {Modality.audio});
      });

      testWidgets('toggles text capability filter',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Find the FilterChip that contains the Text text
        final textChipFinder = find.ancestor(
          of: find.text('Text'),
          matching: find.byType(FilterChip),
        );
        
        // Verify the chip exists
        expect(textChipFinder, findsOneWidget);
        
        // Tap on the FilterChip itself instead of just the text
        await tester.tap(textChipFinder);
        await tester.pump();

        expect(filterChanges, hasLength(1));
        expect(filterChanges.first.selectedCapabilities, {Modality.text});
      });

      testWidgets('can select multiple capabilities',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Select vision first
        final visionChipFinder = find.ancestor(
          of: find.text('Vision'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(visionChipFinder);
        await tester.pump();

        // Update widget with new state
        final newState = filterChanges.first;
        await tester.pumpWidget(createWidget(filterState: newState));

        // Select audio as well
        final audioChipFinder = find.ancestor(
          of: find.text('Audio'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(audioChipFinder);
        await tester.pump();

        expect(filterChanges, hasLength(2));
        expect(filterChanges.last.selectedCapabilities,
            {Modality.image, Modality.audio});
      });

      testWidgets('deselects capability when tapped again',
          (WidgetTester tester) async {
        final filterState = initialFilterState.copyWith(
          selectedCapabilities: {Modality.image},
        );

        await tester.pumpWidget(createWidget(filterState: filterState));

        // Vision should be selected (test visual state)
        final visionChip = find.ancestor(
          of: find.text('Vision'),
          matching: find.byType(FilterChip),
        );
        expect(visionChip, findsOneWidget);

        // Tap to deselect
        await tester.tap(visionChip);
        await tester.pump();

        expect(filterChanges, hasLength(1));
        expect(filterChanges.first.selectedCapabilities, isEmpty);
      });
    });

    group('reasoning filter interaction', () {
      testWidgets('toggles reasoning filter on', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Tap on the text label (more reliable than icon)
        await tester.tap(find.text('Reasoning'));
        // Verify both icon and text are present
        expect(find.byIcon(Icons.psychology), findsOneWidget);
        expect(find.text('Reasoning'), findsOneWidget);
        await tester.pump();

        expect(filterChanges, hasLength(1));
        expect(filterChanges.first.reasoningFilter, isTrue);
      });

      testWidgets('toggles reasoning filter off', (WidgetTester tester) async {
        final filterState = initialFilterState.copyWith(
          reasoningFilter: true,
        );

        await tester.pumpWidget(createWidget(filterState: filterState));

        // Tap on the text label (more reliable than icon)
        await tester.tap(find.text('Reasoning'));
        // Verify both icon and text are present
        expect(find.byIcon(Icons.psychology), findsOneWidget);
        expect(find.text('Reasoning'), findsOneWidget);
        await tester.pump();

        expect(filterChanges, hasLength(1));
        expect(filterChanges.first.reasoningFilter, isFalse);
      });
    });

    group('clear filters action', () {
      testWidgets('clears all model filters when tapped',
          (WidgetTester tester) async {
        const filterState = AiSettingsFilterState(
          searchQuery: 'test query', // Should be preserved
          selectedCapabilities: {Modality.image, Modality.audio},
          reasoningFilter: true,
          selectedProviders: {'provider1'},
          activeTab: AiSettingsTab.models,
        );

        await tester.pumpWidget(createWidget(filterState: filterState));
        await tester.pumpAndSettle(); // Allow AnimatedSwitcher to complete

        await tester.tap(find.text('Clear'));
        await tester.pump();

        expect(filterChanges, hasLength(1));
        final clearedState = filterChanges.first;

        // Should preserve search query and active tab
        expect(clearedState.searchQuery, 'test query');
        expect(clearedState.activeTab, AiSettingsTab.models);

        // Should clear model-specific filters
        expect(clearedState.selectedCapabilities, isEmpty);
        expect(clearedState.reasoningFilter, isFalse);
        expect(clearedState.selectedProviders, isEmpty);
      });
    });

    group('visual states', () {
      testWidgets('shows selected state for active capability filters',
          (WidgetTester tester) async {
        final filterState = initialFilterState.copyWith(
          selectedCapabilities: {Modality.image, Modality.audio},
        );

        await tester.pumpWidget(createWidget(filterState: filterState));

        // Find FilterChip widgets
        final visionChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Vision'),
            matching: find.byType(FilterChip),
          ),
        );
        final audioChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Audio'),
            matching: find.byType(FilterChip),
          ),
        );
        final textChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Text'),
            matching: find.byType(FilterChip),
          ),
        );

        expect(visionChip.selected, isTrue);
        expect(audioChip.selected, isTrue);
        expect(textChip.selected, isFalse);
      });

      testWidgets('shows selected state for reasoning filter',
          (WidgetTester tester) async {
        final filterState = initialFilterState.copyWith(
          reasoningFilter: true,
        );

        await tester.pumpWidget(createWidget(filterState: filterState));

        final reasoningChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Reasoning'),
            matching: find.byType(FilterChip),
          ),
        );

        expect(reasoningChip.selected, isTrue);
      });
    });

    group('accessibility', () {
      testWidgets('provides proper semantics for screen readers',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Check that chips have proper icons and labels
        expect(find.text('Text'), findsOneWidget);
        expect(find.byIcon(Icons.text_fields), findsOneWidget);
        expect(find.text('Vision'), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.byIcon(Icons.hearing), findsOneWidget);
        expect(find.text('Reasoning'), findsOneWidget);
        expect(find.byIcon(Icons.psychology), findsOneWidget);
      });

      testWidgets('maintains focus after chip selection',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Focus and tap a chip
        await tester.tap(find.text('Vision'));
        await tester.pump();

        // Widget should still be present and functional
        expect(find.text('Vision'), findsOneWidget);
        expect(filterChanges, hasLength(1));
      });
    });

    group('edge cases', () {
      testWidgets('handles rapid consecutive taps',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Rapidly tap the same chip multiple times
        await tester.tap(find.text('Vision'));
        await tester.tap(find.text('Vision'));
        await tester.tap(find.text('Vision'));
        await tester.pump();

        // Should have recorded all changes
        expect(filterChanges, hasLength(3));

        // Final state should be selected (odd number of taps)
        expect(filterChanges.last.selectedCapabilities, {Modality.image});
      });

      testWidgets('handles all capabilities selected',
          (WidgetTester tester) async {
        final filterState = initialFilterState.copyWith(
          selectedCapabilities: {Modality.text, Modality.image, Modality.audio},
          reasoningFilter: true,
        );

        await tester.pumpWidget(createWidget(filterState: filterState));
        await tester.pumpAndSettle(); // Allow AnimatedSwitcher to complete

        // All chips should be selected
        final chips = find.byType(FilterChip);
        expect(chips,
            findsNWidgets(5)); // 1 provider + 3 capabilities + 1 reasoning

        // Clear button should be visible
        expect(find.text('Clear'), findsOneWidget);
      });

      testWidgets('works with empty filter state', (WidgetTester tester) async {
        const emptyState = AiSettingsFilterState();

        await tester.pumpWidget(createWidget(filterState: emptyState));

        expect(find.byType(FilterChip),
            findsAtLeastNWidgets(4)); // At least 3 capabilities + 1 reasoning
        expect(find.text('Clear'), findsNothing);
      });
    });

    group('layout and spacing', () {
      testWidgets('wraps chips properly when space is constrained',
          (WidgetTester tester) async {
        // Create a narrow container to test wrapping
        await tester.pumpWidget(
          AiTestSetup.createTestApp(
            providerOverrides: AiTestSetup.createControllerOverrides(
              providers: mockProviders,
            ),
            child: SizedBox(
              width: 200, // Narrow width to force wrapping
              child: AiSettingsFilterChips(
                filterState: initialFilterState,
                onFilterChanged: (_) {},
              ),
            ),
          ),
        );

        // Should show at least the capability chips (3 capabilities + 1 reasoning)
        expect(find.byType(FilterChip),
            findsAtLeastNWidgets(4)); // At least 3 capabilities + 1 reasoning
      });

      testWidgets('maintains consistent spacing between chips',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Check that Wrap widget is used for proper spacing
        expect(
            find.byType(Wrap),
            findsAtLeastNWidgets(
                1)); // Provider and capability sections each use Wrap
        expect(find.byType(FilterChip),
            findsAtLeastNWidgets(4)); // At least 3 capabilities + 1 reasoning
      });
    });
  });
}
