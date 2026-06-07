import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/form_text_field.dart';

import '../../../../test_helper.dart';

void main() {
  Future<GlobalKey<FormBuilderState>> pumpField(
    WidgetTester tester, {
    String initialValue = '',
    bool fieldRequired = true,
  }) async {
    final formKey = GlobalKey<FormBuilderState>();
    await tester.pumpWidget(
      WidgetTestBench(
        child: FormBuilder(
          key: formKey,
          child: FormTextField(
            initialValue: initialValue,
            name: 'title',
            labelText: 'Title',
            fieldRequired: fieldRequired,
          ),
        ),
      ),
    );
    return formKey;
  }

  testWidgets('required field fails validation when left empty', (
    tester,
  ) async {
    final formKey = await pumpField(tester);

    expect(formKey.currentState!.saveAndValidate(), isFalse);
    await tester.pump();

    // The field carries the validator error.
    expect(formKey.currentState!.fields['title']!.hasError, isTrue);
  });

  testWidgets('required field passes validation with text and saves it', (
    tester,
  ) async {
    final formKey = await pumpField(tester);

    await tester.enterText(find.byType(FormBuilderTextField), 'My title');
    await tester.pump();

    expect(formKey.currentState!.saveAndValidate(), isTrue);
    expect(formKey.currentState!.value['title'], 'My title');
  });

  testWidgets('optional field (fieldRequired: false) accepts empty input', (
    tester,
  ) async {
    final formKey = await pumpField(tester, fieldRequired: false);

    expect(formKey.currentState!.saveAndValidate(), isTrue);
  });

  testWidgets('renders the initial value and label', (tester) async {
    await pumpField(tester, initialValue: 'Seeded');

    expect(find.text('Seeded'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
  });
}
