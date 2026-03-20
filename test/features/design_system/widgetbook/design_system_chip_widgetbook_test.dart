import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_chip_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemChipWidgetbookComponent', () {
    testWidgets('builds the chip overview use case', (tester) async {
      final component = buildDesignSystemChipWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Chips');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Combination Scale'), findsOneWidget);
      expect(find.text('State Matrix'), findsOneWidget);
      expect(find.text('Activated'), findsOneWidget);
      expect(find.text('Chip label'), findsAtLeastNWidgets(1));

      await tester.tap(find.byType(DesignSystemChip).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
