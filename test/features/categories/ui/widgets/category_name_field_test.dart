import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_name_field.dart';
import 'package:lotti/widgets/form/form_widgets.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategoryNameField', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('displays correctly in create mode', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryNameField(
            controller: controller,
            isCreateMode: true,
          ),
        ),
      );

      // Verify LottiTextField is rendered
      expect(find.byType(LottiTextField), findsOneWidget);

      // Verify label and hint text
      expect(find.text('Category name:'), findsOneWidget);
      expect(find.text('Enter category name'), findsOneWidget);

      // Verify icon
      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
    });

    testWidgets('displays correctly in edit mode', (tester) async {
      var onChangedCalled = false;
      String? changedValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryNameField(
            controller: controller,
            isCreateMode: false,
            onChanged: (value) {
              onChangedCalled = true;
              changedValue = value;
            },
          ),
        ),
      );

      // Type text
      await tester.enterText(find.byType(TextField), 'Test Category');
      await tester.pump();

      // Verify onChanged is called in edit mode
      expect(onChangedCalled, isTrue);
      expect(changedValue, 'Test Category');
    });

    testWidgets('does not call onChanged in create mode', (tester) async {
      var onChangedCalled = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryNameField(
            controller: controller,
            isCreateMode: true,
            onChanged: (value) {
              onChangedCalled = true;
            },
          ),
        ),
      );

      // Type text
      await tester.enterText(find.byType(TextField), 'Test Category');
      await tester.pump();

      // Verify onChanged is not called in create mode
      expect(onChangedCalled, isFalse);
      // But controller should still have the value
      expect(controller.text, 'Test Category');
    });

    testWidgets('uses default validator when none provided', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        WidgetTestBench(
          child: Form(
            key: formKey,
            child: CategoryNameField(
              controller: controller,
              isCreateMode: true,
            ),
          ),
        ),
      );

      // Test empty validation
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Category name is required'), findsOneWidget);

      // Test valid input
      await tester.enterText(find.byType(TextField), 'Valid Name');
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('uses custom validator when provided', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        WidgetTestBench(
          child: Form(
            key: formKey,
            child: CategoryNameField(
              controller: controller,
              isCreateMode: true,
              validator: (value) {
                if (value == null || value.length < 5) {
                  return 'Name must be at least 5 characters';
                }
                return null;
              },
            ),
          ),
        ),
      );

      // Test short name
      await tester.enterText(find.byType(TextField), 'Test');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Name must be at least 5 characters'), findsOneWidget);

      // Test valid name
      await tester.enterText(find.byType(TextField), 'Valid Name');
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('trims whitespace in default validator', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        WidgetTestBench(
          child: Form(
            key: formKey,
            child: CategoryNameField(
              controller: controller,
              isCreateMode: true,
            ),
          ),
        ),
      );

      // Test whitespace only
      await tester.enterText(find.byType(TextField), '   ');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Category name is required'), findsOneWidget);
    });

    testWidgets('updates controller text', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryNameField(
            controller: controller,
            isCreateMode: true,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'New Category');
      expect(controller.text, 'New Category');
    });

    testWidgets('displays initial controller text', (tester) async {
      controller.text = 'Initial Category';

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryNameField(
            controller: controller,
            isCreateMode: false,
          ),
        ),
      );

      expect(find.text('Initial Category'), findsOneWidget);
    });

    testWidgets('handles null onChanged callback', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryNameField(
            controller: controller,
            isCreateMode: false,
          ),
        ),
      );

      // Should not throw when typing
      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();
    });

    testWidgets('passes through LottiTextField properties correctly',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryNameField(
            controller: controller,
            isCreateMode: true,
          ),
        ),
      );

      final lottiTextField = tester.widget<LottiTextField>(
        find.byType(LottiTextField),
      );

      expect(lottiTextField.controller, equals(controller));
      expect(lottiTextField.labelText, 'Category name:');
      expect(lottiTextField.hintText, 'Enter category name');
      expect(lottiTextField.prefixIcon, Icons.category_outlined);
    });
  });
}
