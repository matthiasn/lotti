import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_picker_field.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? value,
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Column(
        children: [
          const DesignSystemTextInput(label: 'Agent name'),
          DesignSystemPickerField(
            fieldKey: const ValueKey('field'),
            label: 'Birthday',
            value: value,
            placeholder: 'Add birthday',
            leading: const Icon(LottiIcons.calendar),
            onTap: onTap,
          ),
        ],
      ),
    ),
  );

  testWidgets(
    'reads as one more field of the form: the input label tier over a box '
    'as tall as a text input',
    (tester) async {
      await pump(tester, value: 'March 14, 1990', onTap: () {});
      await tester.pumpAndSettle();

      final labelStyle = tester.widget<Text>(find.text('Birthday')).style;
      final inputLabelStyle = tester
          .widget<Text>(find.text('Agent name'))
          .style;
      expect(labelStyle?.fontSize, inputLabelStyle?.fontSize);
      expect(labelStyle?.fontWeight, inputLabelStyle?.fontWeight);
      final tokens = tester.element(find.text('Birthday')).designTokens;
      expect(
        tester.getSize(find.byKey(const ValueKey('field'))).height,
        greaterThanOrEqualTo(tokens.spacing.step9),
      );
      expect(find.text('March 14, 1990'), findsOneWidget);
      expect(find.byIcon(LottiIcons.chevronDown), findsOneWidget);
    },
  );

  testWidgets('an empty value shows the placeholder in the hint ink', (
    tester,
  ) async {
    await pump(tester, onTap: () {});
    await tester.pumpAndSettle();

    final tokens = tester.element(find.text('Birthday')).designTokens;
    expect(
      tester.widget<Text>(find.text('Add birthday')).style?.color,
      tokens.colors.text.lowEmphasis,
    );
  });

  testWidgets('a tap opens the picker; without onTap it is shown, not '
      'offered', (tester) async {
    var taps = 0;
    await pump(tester, value: 'Fitness', onTap: () => taps++);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('field')));
    expect(taps, 1);

    await pump(tester, value: 'Fitness');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('field')));
    expect(taps, 1);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Birthday: Fitness')),
      isSemantics(
        label: 'Birthday: Fitness',
        isButton: true,
        hasEnabledState: true,
      ),
    );
  });

  testWidgets('a pointer over an enabled field strengthens its hairline', (
    tester,
  ) async {
    await pump(tester, value: 'Fitness', onTap: () {});
    await tester.pumpAndSettle();
    final tokens = tester.element(find.text('Birthday')).designTokens;
    Color border() =>
        ((tester
                            .widget<Ink>(
                              find.descendant(
                                of: find.byKey(const ValueKey('field')),
                                matching: find.byType(Ink),
                              ),
                            )
                            .decoration!
                        as BoxDecoration)
                    .border!
                as Border)
            .top
            .color;

    final resting = border();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('field'))));
    await tester.pumpAndSettle();

    expect(border(), designSystemFieldBorderColor(tokens, hovered: true));
    expect(border(), isNot(resting));
  });

  testWidgets('inside a sheet it is unfilled, so the sheet shows through', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DesignSystemPickerField(
          fieldKey: const ValueKey('field'),
          label: 'Category',
          value: null,
          placeholder: 'Select a category',
          onTap: () {},
          filled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final decoration =
        tester
                .widget<Ink>(
                  find.descendant(
                    of: find.byKey(const ValueKey('field')),
                    matching: find.byType(Ink),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(decoration.color, Colors.transparent);
  });
}
