import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/settings/ui/widgets/form/settings_form_text_field.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  Future<GlobalKey<FormBuilderState>> pumpField(
    WidgetTester tester, {
    String initialValue = '',
    bool fieldRequired = true,
    bool multiline = false,
  }) async {
    final formKey = GlobalKey<FormBuilderState>();
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        FormBuilder(
          key: formKey,
          child: SettingsFormTextField(
            name: 'name',
            initialValue: initialValue,
            labelText: 'Name',
            fieldRequired: fieldRequired,
            multiline: multiline,
          ),
        ),
      ),
    );
    return formKey;
  }

  testWidgets('seeds the visible text and the form value', (tester) async {
    final formKey = await pumpField(tester, initialValue: 'Running');

    expect(find.text('Running'), findsOneWidget);
    formKey.currentState!.save();
    expect(formKey.currentState!.value['name'], 'Running');
  });

  testWidgets('typing updates the form value', (tester) async {
    final formKey = await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'Meditation');
    formKey.currentState!.save();
    expect(formKey.currentState!.value['name'], 'Meditation');
  });

  testWidgets('required field surfaces a validation error on the design '
      'system input', (tester) async {
    final formKey = await pumpField(tester);

    expect(formKey.currentState!.saveAndValidate(), isFalse);
    await tester.pump();

    final input = tester.widget<DesignSystemTextInput>(
      find.byType(DesignSystemTextInput),
    );
    expect(input.errorText, isNotNull);
  });

  testWidgets('optional field validates when empty', (tester) async {
    final formKey = await pumpField(tester, fieldRequired: false);

    expect(formKey.currentState!.saveAndValidate(), isTrue);
  });

  testWidgets('multiline renders the design-system textarea', (tester) async {
    await pumpField(tester, multiline: true, initialValue: 'long text');

    expect(find.byType(DesignSystemTextarea), findsOneWidget);
    expect(find.byType(DesignSystemTextInput), findsNothing);
    expect(find.text('long text'), findsOneWidget);
  });
}
