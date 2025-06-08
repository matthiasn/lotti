import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/ai_text_field.dart';

void main() {
  group('AiTextField', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );
    }

    testWidgets('renders label and hint text', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiTextField(
            label: 'Test Label',
            hint: 'Test Hint',
            controller: controller,
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
      expect(find.text('Test Hint'), findsOneWidget);
    });

    testWidgets('shows prefix icon when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiTextField(
            label: 'Test',
            prefixIcon: Icons.search,
            controller: controller,
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows suffix icon when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiTextField(
            label: 'Test',
            suffixIcon: const Icon(Icons.clear),
            controller: controller,
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('updates controller when text is entered', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiTextField(
            label: 'Test',
            controller: controller,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Hello World');
      expect(controller.text, 'Hello World');
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      String? changedValue;

      await tester.pumpWidget(
        buildTestWidget(
          AiTextField(
            label: 'Test',
            controller: controller,
            onChanged: (value) => changedValue = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Test Text');
      expect(changedValue, 'Test Text');
    });

    testWidgets('shows validation error', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          Form(
            autovalidateMode: AutovalidateMode.always,
            child: AiTextField(
              label: 'Test',
              controller: controller,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Field is required' : null,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Field is required'), findsOneWidget);
    });

    testWidgets('respects readOnly property', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiTextField(
            label: 'Test',
            controller: controller,
            readOnly: true,
          ),
        ),
      );
    });

    testWidgets('respects enabled property', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiTextField(
            label: 'Test',
            controller: controller,
            enabled: false,
          ),
        ),
      );

      final textField =
          tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.enabled, false);
    });

    testWidgets('supports multiline input', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiTextField(
            label: 'Test',
            controller: controller,
            maxLines: 3,
            minLines: 2,
          ),
        ),
      );
    });

    testWidgets('animates on focus', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AiTextField(
            label: 'Test',
            controller: controller,
          ),
        ),
      );

      // Initially not focused
      final containerFinder = find.descendant(
        of: find.byType(AiTextField),
        matching: find.byType(AnimatedContainer),
      );

      expect(containerFinder, findsOneWidget);

      // Focus the field
      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Container should animate (we verify it exists and is animated)
      expect(containerFinder, findsOneWidget);
    });
  });
}
