import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_name_field.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';

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

    Future<void> pumpField(
      WidgetTester tester, {
      required bool isCreateMode,
      ValueChanged<String>? onChanged,
    }) {
      return tester.pumpWidget(
        WidgetTestBench(
          child: CategoryNameField(
            controller: controller,
            isCreateMode: isCreateMode,
            onChanged: onChanged,
          ),
        ),
      );
    }

    testWidgets('renders the design-system input with label, hint, and icon', (
      tester,
    ) async {
      await pumpField(tester, isCreateMode: true);

      expect(find.byType(DesignSystemTextInput), findsOneWidget);
      expect(find.text('Category name:'), findsOneWidget);
      expect(find.text('Enter category name'), findsOneWidget);
      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
    });

    testWidgets('calls onChanged with the typed value in edit mode', (
      tester,
    ) async {
      String? changedValue;

      await pumpField(
        tester,
        isCreateMode: false,
        onChanged: (value) => changedValue = value,
      );

      await tester.enterText(find.byType(TextField), 'Test Category');
      await tester.pump();

      expect(changedValue, 'Test Category');
    });

    testWidgets('does not call onChanged in create mode', (tester) async {
      var onChangedCalled = false;

      await pumpField(
        tester,
        isCreateMode: true,
        onChanged: (value) => onChangedCalled = true,
      );

      await tester.enterText(find.byType(TextField), 'Test Category');
      await tester.pump();

      // Create mode tracks input via the controller only.
      expect(onChangedCalled, isFalse);
      expect(controller.text, 'Test Category');
    });

    testWidgets('autofocuses in create mode but not in edit mode', (
      tester,
    ) async {
      await pumpField(tester, isCreateMode: true);
      expect(
        tester
            .widget<DesignSystemTextInput>(
              find.byType(DesignSystemTextInput),
            )
            .autofocus,
        isTrue,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isTrue,
      );

      await pumpField(tester, isCreateMode: false);
      expect(
        tester
            .widget<DesignSystemTextInput>(
              find.byType(DesignSystemTextInput),
            )
            .autofocus,
        isFalse,
      );
    });

    testWidgets('updates controller text', (tester) async {
      await pumpField(tester, isCreateMode: true);

      await tester.enterText(find.byType(TextField), 'New Category');
      expect(controller.text, 'New Category');
    });

    testWidgets('displays initial controller text', (tester) async {
      controller.text = 'Initial Category';

      await pumpField(tester, isCreateMode: false);

      expect(find.text('Initial Category'), findsOneWidget);
    });

    testWidgets('handles null onChanged callback without throwing', (
      tester,
    ) async {
      await pumpField(tester, isCreateMode: false);

      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();

      expect(controller.text, 'Test');
      expect(tester.takeException(), isNull);
    });

    testWidgets('forwards controller and capitalization to the input', (
      tester,
    ) async {
      await pumpField(tester, isCreateMode: true);

      final input = tester.widget<DesignSystemTextInput>(
        find.byType(DesignSystemTextInput),
      );

      expect(input.controller, equals(controller));
      expect(input.label, 'Category name:');
      expect(input.hintText, 'Enter category name');
      expect(input.leadingIcon, Icons.category_outlined);
      expect(input.textCapitalization, TextCapitalization.sentences);
    });
  });
}
