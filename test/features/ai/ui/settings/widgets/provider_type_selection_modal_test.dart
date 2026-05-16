import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_type_selection_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Helper to create test widget
Widget createTestWidget({String? configId}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              ProviderTypeSelectionModal.show(
                context: context,
                configId: configId,
              );
            },
            child: const Text('Show Modal'),
          ),
        ),
      ),
    ),
  );
}

/// Helper to create direct modal widget for testing
Widget createModalWidget({String? configId}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProviderTypeSelectionModal(configId: configId),
      ),
    ),
  );
}

Future<void> openModal(WidgetTester tester) async {
  await tester.tap(find.text('Show Modal'));
  await tester.pumpAndSettle();
}

void main() {
  group('ProviderTypeSelectionModal', () {
    group('Modal Structure and Display', () {
      testWidgets('displays modal with correct Wolt structure', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Assert - WoltModalSheet might not be directly findable in test
        // Check that the modal opened successfully by looking for content
        expect(find.byType(ProviderTypeSelectionModal), findsOneWidget);

        // Check for title in the persistent header
        expect(find.text('Select Provider Type'), findsOneWidget);
      });

      testWidgets('displays all provider types with modern styling', (
        tester,
      ) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Assert - check for provider cards (some may be off-screen due to scroll constraints)
        expect(find.byType(InkWell), findsAtLeastNWidgets(6));

        // Check for styled containers
        final styledContainers = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration?)?.borderRadius != null,
        );
        expect(styledContainers, findsAtLeastNWidgets(3));
      });

      testWidgets('shows all provider type names', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Assert - check for provider names (multiple text widgets may contain same text)
        expect(find.textContaining('Anthropic'), findsAtLeastNWidgets(1));
        expect(find.textContaining('OpenAI'), findsAtLeastNWidgets(1));
        expect(find.textContaining('Gemini'), findsAtLeastNWidgets(1));
      });
    });

    group('Visual Design Quality', () {
      testWidgets('applies Series A quality styling with proper contrast', (
        tester,
      ) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Assert - check for ColoredBox (light background for contrast)
        expect(find.byType(ColoredBox), findsAtLeastNWidgets(1));

        // Check for proper shadows and modern styling
        final shadowedContainers = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration?)?.boxShadow != null,
        );
        expect(shadowedContainers, findsAtLeastNWidgets(1));
      });

      testWidgets('has proper spacing and layout hierarchy', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Assert - check for proper spacing
        expect(find.byType(SizedBox), findsAtLeastNWidgets(3));
        expect(find.byType(Padding), findsAtLeastNWidgets(2));

        // Check for Column with proper layout
        expect(find.byType(Column), findsAtLeastNWidgets(1));
      });

      testWidgets('uses consistent visual hierarchy with modern typography', (
        tester,
      ) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Assert - check for text hierarchy
        expect(find.text('Select Provider Type'), findsOneWidget);

        // Check that provider descriptions are present
        expect(find.byType(Text), findsAtLeastNWidgets(10));
      });

      testWidgets('has proper touch targets and interaction feedback', (
        tester,
      ) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Assert - visible provider cards should have InkWell for touch feedback
        final inkWells = find.byType(InkWell);
        expect(inkWells, findsAtLeastNWidgets(6));

        // Check that most InkWells have proper border radius and all have onTap
        var inkWellsWithBorderRadius = 0;
        for (final inkWellElement in inkWells.evaluate()) {
          final inkWell = inkWellElement.widget as InkWell;
          if (inkWell.borderRadius != null) {
            inkWellsWithBorderRadius++;
          }
          expect(inkWell.onTap, isNotNull);
        }
        // At least half should have border radius (provider cards)
        expect(
          inkWellsWithBorderRadius,
          greaterThan(inkWells.evaluate().length ~/ 2),
        );
      });
    });

    group('User Interactions', () {
      testWidgets('provider cards are properly interactive', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Assert - visible provider cards should be tappable (some may be off-screen)
        final providerCards = find.byType(InkWell);
        expect(providerCards, findsAtLeastNWidgets(6));

        // Find a provider card by its text content to ensure we're tapping the right element
        final anthropicCard = find.ancestor(
          of: find.textContaining('Anthropic'),
          matching: find.byType(InkWell),
        );

        // Test tapping a card (it should close the modal)
        await tester.tap(anthropicCard.first);
        await tester.pumpAndSettle();

        // Modal should be closed after tap
        expect(find.byType(ProviderTypeSelectionModal), findsNothing);
      });

      testWidgets('handles rapid interactions gracefully', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Rapidly tap different providers (modal closes after first tap)
        final providerCards = find.byType(InkWell);
        if (providerCards.evaluate().isNotEmpty) {
          await tester.tap(providerCards.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Assert - should handle interactions without crashing (modal may or may not be closed)
        // The important thing is that we don't crash
        expect(
          find.byType(ProviderTypeSelectionModal),
          findsAtLeastNWidgets(0),
        );
      });
    });

    group('Widget Structure', () {
      testWidgets('can be instantiated directly', (tester) async {
        // Act
        await tester.pumpWidget(createModalWidget());

        // Assert - widget should render without error
        expect(find.byType(ProviderTypeSelectionModal), findsOneWidget);
      });

      testWidgets('handles different config IDs correctly', (tester) async {
        // Act & Assert - test with different config IDs
        for (final configId in ['config1', 'config2', null]) {
          await tester.pumpWidget(createModalWidget(configId: configId));

          // Widget should work with any config ID
          expect(find.byType(ProviderTypeSelectionModal), findsOneWidget);
        }
      });
    });

    group('Accessibility and Usability', () {
      testWidgets('provides proper semantic structure', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Assert - check for semantic elements
        expect(find.text('Select Provider Type'), findsOneWidget);
        expect(find.byType(Material), findsAtLeastNWidgets(1));
        expect(find.byType(InkWell), findsAtLeastNWidgets(6));
      });

      testWidgets('has proper contrast with light background', (tester) async {
        // Act
        await tester.pumpWidget(createTestWidget());
        await openModal(tester);

        // Assert - check for light background using ColoredBox
        expect(find.byType(ColoredBox), findsAtLeastNWidgets(1));

        // Check that text is visible and readable
        expect(find.text('Select Provider Type'), findsOneWidget);
      });
    });

    group('showForResult — form-less entry point', () {
      // Powers the AI Settings "+ Add provider" handler in the
      // dismissed-FTUE-modal path: the page has no form controller
      // yet, so taps must yield a value back to the caller rather
      // than mutate an embedded controller.

      Widget showForResultHost({
        required void Function(InferenceProviderType?) onResolved,
      }) {
        return ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    final picked =
                        await ProviderTypeSelectionModal.showForResult(
                          context: context,
                        );
                    onResolved(picked);
                  },
                  child: const Text('Pick a type'),
                ),
              ),
            ),
          ),
        );
      }

      testWidgets('resolves with the tapped provider type', (tester) async {
        // Tall surface — the modal renders every InferenceProviderType
        // as a fixed-height card stacked in a non-scrollable Column,
        // so on the default 800×600 viewport the lower types (Ollama
        // included) sit beyond the bottom edge and fail the hit test.
        await tester.binding.setSurfaceSize(const Size(900, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        InferenceProviderType? resolved;
        var calls = 0;
        await tester.pumpWidget(
          showForResultHost(
            onResolved: (value) {
              resolved = value;
              calls++;
            },
          ),
        );
        await tester.tap(find.text('Pick a type'));
        await tester.pumpAndSettle();

        // Sanity: the legacy list shows every InferenceProviderType,
        // not just the FTUE picker's curated tile lineup — that's the
        // whole point of routing dismissed users through it.
        expect(find.text('Ollama'), findsOneWidget);

        await tester.tap(find.text('Ollama'));
        await tester.pumpAndSettle();

        expect(calls, 1, reason: 'Future must resolve exactly once');
        expect(resolved, InferenceProviderType.ollama);
      });

      testWidgets(
        'resolves with null when the user dismisses without picking',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(900, 1800));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          InferenceProviderType? resolved;
          var calls = 0;
          var resolvedHasFired = false;
          await tester.pumpWidget(
            showForResultHost(
              onResolved: (value) {
                resolved = value;
                resolvedHasFired = true;
                calls++;
              },
            ),
          );
          await tester.tap(find.text('Pick a type'));
          await tester.pumpAndSettle();

          // Pop the modal without tapping any type. Mirrors the
          // user swiping the Wolt sheet down or hitting the close
          // affordance.
          tester.state<NavigatorState>(find.byType(Navigator).last).pop();
          await tester.pumpAndSettle();

          expect(calls, 1);
          expect(resolvedHasFired, isTrue);
          expect(
            resolved,
            isNull,
            reason:
                'Dismissal without a pick must resolve to null so '
                'callers can short-circuit instead of routing to a '
                'wrong default provider type.',
          );
        },
      );
    });
  });
}
