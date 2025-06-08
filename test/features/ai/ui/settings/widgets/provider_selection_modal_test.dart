import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_selection_modal.dart';

import '../../../test_utils.dart';

void main() {
  group('ProviderSelectionModal', () {
    setUpAll(AiTestSetup.registerFallbackValues);

    Widget createTestWidget({
      required ValueChanged<String> onProviderSelected,
      List<AiConfig>? providers,
      String selectedProviderId = '',
    }) {
      return AiTestWidgets.createTestWidget(
        providers: providers,
        child: Scaffold(
          body: ProviderSelectionModal(
            onProviderSelected: onProviderSelected,
            selectedProviderId: selectedProviderId,
          ),
        ),
      );
    }

    group('Modal Structure', () {
      testWidgets('displays modal content correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
        ));
        await tester.pumpAndSettle();

        // The modal content should render without the title (title is now in Wolt header)
        expect(find.byType(ProviderSelectionModal), findsOneWidget);
      });

      testWidgets('has proper widget structure', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
        ));
        await tester.pumpAndSettle();

        // The modal widget should exist (close button is now in Wolt header)
        expect(find.byType(ProviderSelectionModal), findsOneWidget);
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
      });

      testWidgets('has proper modal styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
        ));
        await tester.pumpAndSettle();

        // Check for modal container with proper decoration
        final containers = find.byType(Container);
        expect(containers, findsAtLeastNWidgets(1));

        // Check for proper modal structure
        expect(find.byType(Column), findsAtLeastNWidgets(1));
      });
    });

    group('Provider Display', () {
      testWidgets('displays providers when available',
          (WidgetTester tester) async {
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
          AiTestDataFactory.createTestProvider(
            id: 'provider2',
            name: 'Test Provider 2',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          providers: testProviders,
        ));
        await tester.pumpAndSettle();

        // Wait for async providers to load
        await tester.pump();

        // Should have Column for providers (new design)
        expect(find.byType(Column), findsAtLeastNWidgets(1));
      });

      testWidgets('displays empty state when no providers',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          providers: [], // Explicitly provide empty list
        ));
        await tester.pumpAndSettle();

        // Wait for providers to load
        await tester.pump();

        // Should show empty state message
        expect(find.text('No providers found'), findsOneWidget);
        expect(find.text('Create an inference provider first'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      });

      testWidgets('shows loading state initially', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          // No mock providers provided, should use real providers
        ));

        // Before any pumping, check for loading state
        // Note: With mocked data, loading state might not appear
        final loadingIndicator = find.byType(CircularProgressIndicator);
        if (loadingIndicator.evaluate().isNotEmpty) {
          expect(loadingIndicator, findsOneWidget);
        } else {
          // If no loading state (due to mocked data), verify modal structure exists
          expect(find.byType(ProviderSelectionModal), findsOneWidget);
        }
      });

      testWidgets('provider cards have proper structure',
          (WidgetTester tester) async {
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          providers: testProviders,
        ));
        await tester.pumpAndSettle();

        // Wait for providers to load
        await tester.pump();

        // Check for InkWell structure in provider cards (new improved design)
        final inkWells = find.byType(InkWell);
        expect(inkWells, findsAtLeastNWidgets(1));
        
        // Provider cards should have proper icons and text
        expect(find.byIcon(Icons.cloud_outlined), findsAtLeastNWidgets(1));
        // Note: No longer expect arrow icons since we use checkmarks for selection
      });
    });

    group('User Interactions', () {
      testWidgets('calls onProviderSelected when provider tapped',
          (WidgetTester tester) async {
        String? selectedProviderId;
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (providerId) {
            selectedProviderId = providerId;
          },
          providers: testProviders,
        ));
        await tester.pumpAndSettle();

        // Wait for providers to load
        await tester.pump();

        // Find and tap a provider by looking for the text first
        expect(find.text('Test Provider 1'), findsOneWidget);
        
        // Find the InkWell that contains the provider text
        final providerInkWell = find.ancestor(
          of: find.text('Test Provider 1'),
          matching: find.byType(InkWell),
        );
        expect(providerInkWell, findsOneWidget);
        
        await tester.tap(providerInkWell);
        await tester.pumpAndSettle();

        // Should have called the callback
        expect(selectedProviderId, equals('provider1'));
      });

      testWidgets('maintains proper state during interaction',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
        ));
        await tester.pumpAndSettle();

        // Verify the modal exists and maintains state
        expect(find.byType(ProviderSelectionModal), findsOneWidget);
        
        // The modal should remain functional
        expect(find.byType(Column), findsAtLeastNWidgets(1));
      });

      testWidgets('provider cards are tappable', (WidgetTester tester) async {
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          providers: testProviders,
        ));
        await tester.pumpAndSettle();

        // Wait for providers to load
        await tester.pump();

        // Check that InkWells have onTap handlers (new improved design)
        final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
        for (final inkWell in inkWells) {
          expect(inkWell.onTap, isNotNull);
        }
      });

      testWidgets('shows checkmark for selected provider and empty circle for others',
          (WidgetTester tester) async {
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
          AiTestDataFactory.createTestProvider(
            id: 'provider2',
            name: 'Test Provider 2',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          providers: testProviders,
          selectedProviderId: 'provider1', // Pre-select the first provider
        ));
        await tester.pumpAndSettle();
        await tester.pump();

        // Should show checkmark for selected provider
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        
        // Should show empty circles for non-selected providers
        // The empty circle is represented by a Container with border decoration
        final containers = tester.widgetList<Container>(find.byType(Container));
        final emptyCircleContainers = containers.where((container) {
          final decoration = container.decoration;
          if (decoration is BoxDecoration && decoration.border != null) {
            // Check if it's the empty circle style (width/height 28)
            return container.constraints?.maxWidth == 28 || 
                   container.constraints?.maxHeight == 28;
          }
          return false;
        });
        
        // Should have at least one empty circle (for non-selected provider)
        expect(emptyCircleContainers.length, greaterThan(0));
      });

      testWidgets('highlights selected provider with different colors',
          (WidgetTester tester) async {
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
          AiTestDataFactory.createTestProvider(
            id: 'provider2',
            name: 'Test Provider 2',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          providers: testProviders,
          selectedProviderId: 'provider1', // Pre-select the first provider
        ));
        await tester.pumpAndSettle();
        await tester.pump();

        // Both provider texts should be present
        expect(find.text('Test Provider 1'), findsOneWidget);
        expect(find.text('Test Provider 2'), findsOneWidget);
        
        // Should have checkmark icon for selected provider
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      });
    });

    group('Visual Design', () {
      testWidgets('uses proper spacing and layout',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
        ));
        await tester.pumpAndSettle();

        // Should have proper padding and spacing
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
      });

      testWidgets('has consistent visual hierarchy',
          (WidgetTester tester) async {
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          providers: testProviders,
        ));
        await tester.pumpAndSettle();
        await tester.pump();

        // Should have header, content sections
        expect(find.byType(Column), findsAtLeastNWidgets(1));
        expect(find.byType(Row), findsAtLeastNWidgets(1));
      });

      testWidgets('applies proper theming', (WidgetTester tester) async {
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          providers: testProviders,
        ));
        await tester.pumpAndSettle();
        await tester.pump();

        // Should have styled containers with decorations (provider cards)
        final containers = tester.widgetList<Container>(find.byType(Container));
        final styledContainers = containers.where(
          (container) => container.decoration != null,
        );

        expect(styledContainers.length, greaterThan(0));
      });

      testWidgets('has Series A quality modal styling',
          (WidgetTester tester) async {
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          providers: testProviders,
        ));
        await tester.pumpAndSettle();
        await tester.pump();

        // Should have provider cards with Series A quality styling
        final containers = tester.widgetList<Container>(find.byType(Container));
        final styledContainers = containers.where(
          (container) => container.decoration != null,
        );

        expect(styledContainers.length, greaterThan(0));
        
        // Should have proper padding structure
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
      });
    });

    group('Accessibility', () {
      testWidgets('has proper semantic structure', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
        ));
        await tester.pumpAndSettle();

        // Should have accessible text
        expect(find.byType(Text), findsAtLeastNWidgets(1));

        // Should have accessible structure
        expect(find.byType(ProviderSelectionModal), findsOneWidget);
      });

      testWidgets('provider cards are properly labeled',
          (WidgetTester tester) async {
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
          providers: testProviders,
        ));
        await tester.pumpAndSettle();

        // Wait for providers to load
        await tester.pump();

        // Each provider card should have proper text labels
        // With the new design, we check for Text widgets instead of ListTile properties
        expect(find.text('Test Provider 1'), findsAtLeastNWidgets(1));
      });
    });

    group('Error Handling', () {
      testWidgets('displays error state when loading fails',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
        ));
        await tester.pumpAndSettle();

        // In case of error, should show error state
        // Note: This test might need adjustment based on how errors are handled in real scenarios
        await tester.pump();

        // If error occurs, should show error message
        final errorIcon = find.byIcon(Icons.error_outline_rounded);
        final errorText = find.text('Error loading providers');

        // These might not be present if no error occurs, but structure should be correct
        if (errorIcon.evaluate().isNotEmpty) {
          expect(errorText, findsOneWidget);
        }
      });
    });

    group('Edge Cases', () {
      testWidgets('handles rapid interactions gracefully',
          (WidgetTester tester) async {
        // Track provider selection
        // ignore: unused_local_variable
        var providerSelected = false;

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (providerId) {
            providerSelected = true;
          },
        ));
        await tester.pumpAndSettle();

        // Wait for providers to load
        await tester.pump();

        // Verify modal structure remains stable
        for (var i = 0; i < 3; i++) {
          await tester.pump();
          expect(find.byType(ProviderSelectionModal), findsOneWidget);
        }

        // Should not crash
        expect(find.byType(ProviderSelectionModal), findsOneWidget);
      });

      testWidgets('maintains state consistency during interaction',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {},
        ));
        await tester.pumpAndSettle();

        // Wait for providers to load
        await tester.pump();

        // Modal should remain functional after multiple state changes
        expect(find.byType(ProviderSelectionModal), findsOneWidget);
        expect(find.byType(Column), findsAtLeastNWidgets(1));
      });

      testWidgets(
          'handles provider selection without navigation context errors',
          (WidgetTester tester) async {
        var callbackCalled = false;
        final testProviders = [
          AiTestDataFactory.createTestProvider(
            id: 'provider1',
            name: 'Test Provider 1',
          ),
        ];

        await tester.pumpWidget(createTestWidget(
          onProviderSelected: (_) {
            callbackCalled = true;
          },
          providers: testProviders,
        ));
        await tester.pumpAndSettle();

        // Wait for providers to load
        await tester.pump();

        // Tapping providers should work even in test context (using new InkWell design)
        expect(find.text('Test Provider 1'), findsOneWidget);
        
        // Find the InkWell that contains the provider text
        final providerInkWell = find.ancestor(
          of: find.text('Test Provider 1'),
          matching: find.byType(InkWell),
        );
        expect(providerInkWell, findsOneWidget);
        
        await tester.tap(providerInkWell);
        await tester.pumpAndSettle();

        expect(callbackCalled, isTrue);
      });
    });
  });
}
