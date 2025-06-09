import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_floating_action_button.dart';
import 'package:lotti/l10n/app_localizations.dart';

void main() {
  group('AiSettingsFloatingActionButton', () {
    late bool buttonPressed;

    setUp(() {
      buttonPressed = false;
    });

    Widget createWidget({
      required AiSettingsTab activeTab,
    }) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          floatingActionButton: AiSettingsFloatingActionButton(
            activeTab: activeTab,
            onPressed: () => buttonPressed = true,
          ),
        ),
      );
    }

    testWidgets('displays correct icon and label for providers tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.providers,
      ));

      await tester.pumpAndSettle(); // Wait for localization

      expect(find.byIcon(Icons.add_link_rounded), findsOneWidget);
      // Check that FAB contains text (localized)
      expect(
          find.descendant(
            of: find.byType(FloatingActionButton),
            matching: find.byType(Text),
          ),
          findsOneWidget);
    });

    testWidgets('displays correct icon and label for models tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.models,
      ));

      await tester.pumpAndSettle(); // Wait for localization

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      // Check that FAB contains text (localized)
      expect(
          find.descendant(
            of: find.byType(FloatingActionButton),
            matching: find.byType(Text),
          ),
          findsOneWidget);
    });

    testWidgets('displays correct icon and label for prompts tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.prompts,
      ));

      await tester.pumpAndSettle(); // Wait for localization

      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
      // Check that FAB contains text (localized)
      expect(
          find.descendant(
            of: find.byType(FloatingActionButton),
            matching: find.byType(Text),
          ),
          findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.providers,
      ));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(buttonPressed, isTrue);
    });

    testWidgets('is an extended FAB with icon and label',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.models,
      ));

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );

      // Extended FABs have both icon and label
      expect(fab.isExtended, isTrue);
    });

    testWidgets('has proper margin', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.providers,
      ));

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(FloatingActionButton),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(
        container.margin,
        const EdgeInsets.only(right: 20, bottom: 20),
      );
    });

    testWidgets('icon has gradient container', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.models,
      ));

      // Find the container within the FAB that has the gradient
      final containers = find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byType(Container),
      );

      // Should have at least one container for the icon
      expect(containers, findsWidgets);

      // Find the gradient container (it contains the icon)
      Container? gradientContainer;
      for (var i = 0; i < containers.evaluate().length; i++) {
        final container = tester.widget<Container>(containers.at(i));
        if (container.decoration is BoxDecoration) {
          final decoration = container.decoration! as BoxDecoration;
          if (decoration.gradient != null) {
            gradientContainer = container;
            break;
          }
        }
      }

      expect(gradientContainer, isNotNull);
      // Verify the container has the expected size through constraints
      expect(gradientContainer!.constraints, isNotNull);
      expect(gradientContainer.constraints!.minWidth, 32);
      expect(gradientContainer.constraints!.maxWidth, 32);
      expect(gradientContainer.constraints!.minHeight, 32);
      expect(gradientContainer.constraints!.maxHeight, 32);

      final decoration = gradientContainer.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.borderRadius, BorderRadius.circular(10));
    });

    testWidgets('has proper shape and elevation', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.prompts,
      ));

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );

      expect(fab.elevation, 8);
      expect(fab.shape, isA<RoundedRectangleBorder>());

      final shape = fab.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(20),
      );
    });

    testWidgets('label has proper text style', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.providers,
      ));

      await tester.pumpAndSettle(); // Wait for localization

      final text = tester.widget<Text>(find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byType(Text),
      ));
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.letterSpacing, 0.5);
    });

    testWidgets('icon has correct size', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.models,
      ));

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.auto_awesome_rounded),
      );
      expect(icon.size, 20);
    });

    testWidgets('updates when active tab changes', (WidgetTester tester) async {
      // Start with providers tab
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.providers,
      ));

      await tester.pumpAndSettle();

      // Check correct icon for providers
      expect(find.byIcon(Icons.add_link_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);

      // Change to models tab
      await tester.pumpWidget(createWidget(
        activeTab: AiSettingsTab.models,
      ));
      await tester.pumpAndSettle();

      // Check correct icon for models
      expect(find.byIcon(Icons.add_link_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });
  });
}
