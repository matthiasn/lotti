import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
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
            activeColor: Colors.red,
          ),
        ),
      ),
    );
    return formKey;
  }

  testWidgets('renders title and seeds the form with the initial value', (
    tester,
  ) async {
    final formKey = await pumpSwitch(tester, initialValue: true);

    expect(find.text('Private'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    formKey.currentState!.save();
    expect(formKey.currentState!.value['private'], isTrue);
  });

  testWidgets('toggling flips both the switch and the form value', (
    tester,
  ) async {
    final formKey = await pumpSwitch(tester, initialValue: false);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    formKey.currentState!.save();
    expect(formKey.currentState!.value['private'], isTrue);
  });
}
