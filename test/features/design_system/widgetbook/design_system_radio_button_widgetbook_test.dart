import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/radio_buttons/design_system_radio_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_radio_button_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemRadioButtonWidgetbookComponent', () {
    const sizeScaleDefaultKey = Key('radio-size-scale-default');
    const sizeScaleDefaultSelectedKey = Key(
      'radio-size-scale-default-selected',
    );

    testWidgets('builds the radio overview use case', (tester) async {
      final component = buildDesignSystemRadioButtonWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Radio buttons');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('State Matrix'), findsOneWidget);
      expect(find.text('Default'), findsAtLeastNWidgets(1));
      expect(find.text('Hover'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.byType(DesignSystemRadioButton), findsAtLeastNWidgets(1));

      expect(
        _radioSemantics(tester, sizeScaleDefaultKey).properties.selected,
        isFalse,
      );
      expect(
        _radioSemantics(
          tester,
          sizeScaleDefaultSelectedKey,
        ).properties.selected,
        isTrue,
      );

      await tester.tap(find.byKey(sizeScaleDefaultKey));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        _radioSemantics(tester, sizeScaleDefaultKey).properties.selected,
        isTrue,
      );
      expect(
        _radioSemantics(
          tester,
          sizeScaleDefaultSelectedKey,
        ).properties.selected,
        isFalse,
      );

      await tester.tap(find.byKey(sizeScaleDefaultKey));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        _radioSemantics(tester, sizeScaleDefaultKey).properties.selected,
        isTrue,
      );
      expect(
        _radioSemantics(
          tester,
          sizeScaleDefaultSelectedKey,
        ).properties.selected,
        isFalse,
      );

      await tester.tap(find.byKey(sizeScaleDefaultSelectedKey));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        _radioSemantics(tester, sizeScaleDefaultKey).properties.selected,
        isFalse,
      );
      expect(
        _radioSemantics(
          tester,
          sizeScaleDefaultSelectedKey,
        ).properties.selected,
        isTrue,
      );
    });
  });
}

Semantics _radioSemantics(WidgetTester tester, Key key) {
  return tester.widget<Semantics>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.button == true,
      ),
    ),
  );
}
