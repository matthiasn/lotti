import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';

import '../../../../../test_helper.dart';

void main() {
  Future<GlobalKey<FormBuilderState>> pumpSwitch(
    WidgetTester tester, {
    bool? initialValue,
  }) async {
    final formKey = GlobalKey<FormBuilderState>();
    await tester.pumpWidget(
      WidgetTestBench(
        child: FormBuilder(
          key: formKey,
          child: FormSwitch(
            initialValue: initialValue,
            name: 'private',
            title: 'Private',
            semanticsLabel: 'Private switch',
          ),
        ),
      ),
    );
    return formKey;
  }

  DesignSystemToggle currentToggle(WidgetTester tester) =>
      tester.widget<DesignSystemToggle>(find.byType(DesignSystemToggle));

  testWidgets('renders title and seeds the form with the initial value', (
    tester,
  ) async {
    final formKey = await pumpSwitch(tester, initialValue: true);

    expect(find.text('Private'), findsOneWidget);
    expect(currentToggle(tester).value, isTrue);

    formKey.currentState!.save();
    expect(formKey.currentState!.value['private'], isTrue);
  });

  testWidgets('null initial value defaults to off', (tester) async {
    final formKey = await pumpSwitch(tester);

    expect(currentToggle(tester).value, isFalse);
    formKey.currentState!.save();
    expect(formKey.currentState!.value['private'], isFalse);
  });

  testWidgets('toggling flips both the toggle and the form value', (
    tester,
  ) async {
    final formKey = await pumpSwitch(tester, initialValue: false);

    expect(currentToggle(tester).value, isFalse);

    await tester.tap(find.text('Private'));
    await tester.pump();

    expect(currentToggle(tester).value, isTrue);
    formKey.currentState!.save();
    expect(formKey.currentState!.value['private'], isTrue);
  });
}
