import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_checkbox_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemCheckboxWidgetbookComponent', () {
    testWidgets('builds the checkbox overview use case', (tester) async {
      final component = buildDesignSystemCheckboxWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Checkbox');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Combination Scale'), findsOneWidget);
      expect(find.text('State Matrix'), findsOneWidget);
      expect(find.text('Checkbox label'), findsWidgets);
      expect(find.text('Disabled'), findsOneWidget);

      final initialGlyphCount = find.byType(CustomPaint).evaluate().length;
      await tester.tap(find.byType(DesignSystemCheckbox).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint).evaluate().length, initialGlyphCount + 1);
    });

    testWidgets(
      'preserves interactive checkbox state across overview rebuilds',
      (tester) async {
        final component = buildDesignSystemCheckboxWidgetbookComponent();
        final useCase = component.useCases.single;

        Widget buildOverview() => makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        );

        await tester.pumpWidget(buildOverview());

        expect(
          tester
              .widget<DesignSystemCheckbox>(
                find.byType(DesignSystemCheckbox).first,
              )
              .value,
          isFalse,
        );

        await tester.tap(find.byType(DesignSystemCheckbox).first);
        await tester.pump();

        expect(
          tester
              .widget<DesignSystemCheckbox>(
                find.byType(DesignSystemCheckbox).first,
              )
              .value,
          isTrue,
        );

        await tester.pumpWidget(buildOverview());
        await tester.pump();

        expect(
          tester
              .widget<DesignSystemCheckbox>(
                find.byType(DesignSystemCheckbox).first,
              )
              .value,
          isTrue,
        );
      },
    );
  });
}
