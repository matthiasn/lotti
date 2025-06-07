import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:lotti/features/ai/ui/widgets/enhanced_form_field.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Test FormzInput implementation for testing
enum TestFormError { empty, tooShort }

class TestFormzField extends FormzInput<String, TestFormError> {
  const TestFormzField.pure() : super.pure('');
  const TestFormzField.dirty([super.value = '']) : super.dirty();

  @override
  TestFormError? validator(String value) {
    if (value.isEmpty) return TestFormError.empty;
    if (value.length < 3) return TestFormError.tooShort;
    return null;
  }
}

/// Test class for enhanced form field widget
void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  /// Helper function to build the widget under test
  Widget buildTestWidget({
    required Widget child,
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
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  group('EnhancedFormField Tests', () {
    testWidgets('should render basic form field with label', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(EnhancedFormField), findsOneWidget);
      expect(find.text('Test Field'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('should display required indicator when isRequired is true',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Required Field',
          isRequired: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Required Field'), findsOneWidget);
      expect(find.text(' *'), findsOneWidget);
    });

    testWidgets(
        'should not display required indicator when isRequired is false',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Optional Field',
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Optional Field'), findsOneWidget);
      expect(find.text(' *'), findsNothing);
    });

    testWidgets('should display helper text when provided', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
          helperText: 'This is a helpful message',
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('This is a helpful message'), findsOneWidget);
    });

    testWidgets('should display prefix icon when provided', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
          prefixIcon: const Icon(Icons.email),
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('should display suffix icon when provided', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
          suffixIcon: const Icon(Icons.visibility),
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('should handle multiline text input', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Multiline Field',
          maxLines: 3,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, equals(3));
    });

    testWidgets('should handle obscured text input', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Password Field',
          obscureText: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('should call onChanged when text is entered', (tester) async {
      // Arrange
      String? changedValue;
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
          onChanged: (value) => changedValue = value,
        ),
      ));
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byType(TextField), 'test input');
      await tester.pumpAndSettle();

      // Assert
      expect(changedValue, equals('test input'));
    });

    testWidgets('should display Formz validation error', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
          formzField: const TestFormzField.dirty('ab'), // Too short
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('This field is too short'), findsOneWidget);
    });

    testWidgets('should display custom error text over Formz error',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
          formzField: const TestFormzField.dirty('ab'), // Too short
          customErrorText: 'Custom error message',
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Custom error message'), findsOneWidget);
      expect(find.text('This field is too short'), findsNothing);
    });

    testWidgets('should not display error for pure Formz field',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
          formzField:
              const TestFormzField.pure(), // Pure field with empty value
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.text('This field is required'), findsNothing);
    });

    testWidgets('should hide helper text when error is displayed',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
          helperText: 'Helper text',
          customErrorText: 'Error message',
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Error message'), findsOneWidget);
      expect(find.text('Helper text'), findsNothing);
    });

    testWidgets('should apply focus styling when field is focused',
        (tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
        ),
      ));
      await tester.pumpAndSettle();

      // Act - tap to focus the field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Assert - check that animations have completed
      expect(find.byType(TextField), findsOneWidget);

      // The field should have focus
      final focusNode =
          tester.widget<TextField>(find.byType(TextField)).focusNode;
      expect(focusNode?.hasFocus, isTrue);
    });

    testWidgets('should apply error styling when there is an error',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Test Field',
          formzField: const TestFormzField.dirty(), // Empty field (error)
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('should have proper accessibility semantics', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Accessible Field',
          helperText: 'Helper text for accessibility',
          isRequired: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert - check that the field has proper semantic labels
      expect(find.text('Accessible Field'), findsOneWidget);
      expect(find.text(' *'), findsOneWidget);
      expect(find.text('Helper text for accessibility'), findsOneWidget);
    });

    testWidgets('should handle read-only mode', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Read Only Field',
          readOnly: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.readOnly, isTrue);
    });

    testWidgets('should call onTap when tapped in read-only mode',
        (tester) async {
      // Arrange
      var wasTapped = false;
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Tappable Field',
          readOnly: true,
          onTap: () => wasTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Assert
      expect(wasTapped, isTrue);
    });

    testWidgets('should apply modern Series A styling', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Styled Field',
        ),
      ));
      await tester.pumpAndSettle();

      // Assert - check for styled containers
      final styledContainer = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).borderRadius != null);
      expect(styledContainer, findsAtLeastNWidgets(1));
    });

    testWidgets('should update error state when Formz field changes',
        (tester) async {
      // Arrange
      var formzField = const TestFormzField.pure();

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildTestWidget(
            child: Column(
              children: [
                EnhancedFormField(
                  controller: controller,
                  labelText: 'Dynamic Field',
                  formzField: formzField,
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      formzField =
                          const TestFormzField.dirty(); // Make it invalid
                    });
                  },
                  child: const Text('Make Invalid'),
                ),
              ],
            ),
          );
        },
      ));
      await tester.pumpAndSettle();

      // Initially no error
      expect(find.byIcon(Icons.error_outline), findsNothing);

      // Act - make the field invalid
      await tester.tap(find.text('Make Invalid'));
      await tester.pumpAndSettle();

      // Assert - error should appear
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('EnhancedSelectionField Tests', () {
    testWidgets('should render selection field with value', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedSelectionField(
          labelText: 'Selection Field',
          value: 'Selected Value',
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(EnhancedSelectionField), findsOneWidget);
      expect(find.text('Selection Field'), findsOneWidget);
      expect(find.text('Selected Value'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('should display required indicator for selection field',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedSelectionField(
          labelText: 'Required Selection',
          value: 'Value',
          onTap: () {},
          isRequired: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Required Selection'), findsOneWidget);
      expect(find.text(' *'), findsOneWidget);
    });

    testWidgets('should display helper text for selection field',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedSelectionField(
          labelText: 'Selection Field',
          value: 'Value',
          onTap: () {},
          helperText: 'Selection helper text',
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Selection helper text'), findsOneWidget);
    });

    testWidgets('should display prefix icon for selection field',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedSelectionField(
          labelText: 'Selection Field',
          value: 'Value',
          onTap: () {},
          prefixIcon: const Icon(Icons.category),
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.category), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('should call onTap when selection field is tapped',
        (tester) async {
      // Arrange
      var wasTapped = false;
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedSelectionField(
          labelText: 'Tappable Selection',
          value: 'Value',
          onTap: () => wasTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      // Assert
      expect(wasTapped, isTrue);
    });

    testWidgets('should apply press animation when tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedSelectionField(
          labelText: 'Animated Selection',
          value: 'Value',
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Act - tap down and hold
      final gesture = await tester
          .startGesture(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - should be in pressed state during gesture
      expect(find.byType(EnhancedSelectionField), findsOneWidget);

      // Complete the tap
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('should apply modern styling to selection field',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedSelectionField(
          labelText: 'Styled Selection',
          value: 'Value',
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Assert - check for styled containers with rounded borders
      final styledContainer = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).borderRadius != null);
      expect(styledContainer, findsAtLeastNWidgets(1));
    });
  });

  group('EnhancedFormField Animation Tests', () {
    testWidgets('should animate scale on focus', (tester) async {
      // Arrange
      await tester.pumpWidget(buildTestWidget(
        child: EnhancedFormField(
          controller: controller,
          labelText: 'Animated Field',
        ),
      ));
      await tester.pumpAndSettle();

      // Act - focus the field
      await tester.tap(find.byType(TextField));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 100)); // Mid-animation
      await tester.pumpAndSettle(); // Complete animation

      // Assert - field should be animated (we can't easily test the exact scale value,
      // but we can verify the AnimatedBuilder is present)
      expect(find.byType(AnimatedBuilder), findsAtLeastNWidgets(1));
    });

    testWidgets('should animate error appearance', (tester) async {
      // Arrange
      var formzField = const TestFormzField.pure();

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildTestWidget(
            child: Column(
              children: [
                EnhancedFormField(
                  controller: controller,
                  labelText: 'Error Animation Field',
                  formzField: formzField,
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      formzField =
                          const TestFormzField.dirty(); // Make it invalid
                    });
                  },
                  child: const Text('Show Error'),
                ),
              ],
            ),
          );
        },
      ));
      await tester.pumpAndSettle();

      // Act - trigger error
      await tester.tap(find.text('Show Error'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 150)); // Mid-animation
      await tester.pumpAndSettle(); // Complete animation

      // Assert - error should be visible with animations
      expect(find.byType(SlideTransition), findsOneWidget);
      expect(find.byType(FadeTransition), findsAtLeastNWidgets(1));
      expect(find.text('This field is required'), findsOneWidget);
    });
  });
}
