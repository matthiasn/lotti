import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_toggle_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemToggleWidgetbookComponent', () {
    testWidgets('builds the toggle overview use case', (tester) async {
      final component = buildDesignSystemToggleWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Toggle');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Small'), findsAtLeastNWidgets(1));
      expect(find.text('Default'), findsAtLeastNWidgets(2));
      expect(find.text('Hover'), findsAtLeastNWidgets(1));
      expect(find.text('Disabled'), findsAtLeastNWidgets(1));
      expect(find.byType(DesignSystemToggle), findsNWidgets(38));

      // The overview previews are display-only (no-op onChanged), so a tap
      // can't flip state; instead verify the toggled SEMANTICS property
      // mirrors each preview's configured value for on and off samples
      // (the same pattern the radio-button test uses with `selected`).
      final onToggle = find.byWidgetPredicate(
        (w) => w is DesignSystemToggle && w.value,
      );
      final offToggle = find.byWidgetPredicate(
        (w) => w is DesignSystemToggle && !w.value,
      );
      expect(onToggle, findsAtLeastNWidgets(1));
      expect(offToggle, findsAtLeastNWidgets(1));

      Semantics innerSemantics(Finder toggle) => tester.widget<Semantics>(
        find
            .descendant(
              of: toggle.first,
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.toggled != null,
              ),
            )
            .first,
      );
      expect(innerSemantics(onToggle).properties.toggled, isTrue);
      expect(innerSemantics(offToggle).properties.toggled, isFalse);

      await tester.tap(find.byType(DesignSystemToggle).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
