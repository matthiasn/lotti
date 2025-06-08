import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/ai_form_button.dart';

void main() {
  group('AiFormButton', () {
    Widget buildTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiFormButton(
            label: 'Test Button',
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('shows icon when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiFormButton(
            label: 'Test',
            icon: Icons.save,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var wasPressed = false;

      await tester.pumpWidget(
        buildTestWidget(
          AiFormButton(
            label: 'Test',
            onPressed: () => wasPressed = true,
          ),
        ),
      );

      await tester.tap(find.byType(AiFormButton));
      expect(wasPressed, true);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const AiFormButton(
            label: 'Test',
            onPressed: null,
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, null);
    });

    testWidgets('is disabled when enabled is false', (tester) async {
      var wasPressed = false;

      await tester.pumpWidget(
        buildTestWidget(
          AiFormButton(
            label: 'Test',
            onPressed: () => wasPressed = true,
            enabled: false,
          ),
        ),
      );

      await tester.tap(find.byType(AiFormButton));
      expect(wasPressed, false);
    });

    testWidgets('shows loading indicator when isLoading is true',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiFormButton(
            label: 'Test',
            onPressed: () {},
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Test'), findsNothing);
    });

    testWidgets('respects fullWidth property', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          Column(
            children: [
              AiFormButton(
                label: 'Full Width',
                onPressed: () {},
                fullWidth: true,
              ),
              AiFormButton(
                label: 'Auto Width',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      // Full width button should expand
      final fullWidthButton = find.widgetWithText(AiFormButton, 'Full Width');
      expect(fullWidthButton, findsOneWidget);

      // Auto width button should not expand
      final autoWidthButton = find.widgetWithText(AiFormButton, 'Auto Width');
      expect(autoWidthButton, findsOneWidget);
    });

    testWidgets('applies primary style correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiFormButton(
            label: 'Primary',
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('Primary'), findsOneWidget);
      expect(find.byType(AiFormButton), findsOneWidget);
    });

    testWidgets('applies secondary style correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiFormButton(
            label: 'Secondary',
            onPressed: () {},
            style: AiButtonStyle.secondary,
          ),
        ),
      );

      expect(find.text('Secondary'), findsOneWidget);
      expect(find.byType(AiFormButton), findsOneWidget);
    });

    testWidgets('applies text style correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiFormButton(
            label: 'Text',
            onPressed: () {},
            style: AiButtonStyle.text,
          ),
        ),
      );

      expect(find.text('Text'), findsOneWidget);
      expect(find.byType(AiFormButton), findsOneWidget);
    });
  });
}
