import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_toast_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemToastWidgetbookComponent', () {
    testWidgets('builds the toast overview use case', (tester) async {
      final component = buildDesignSystemToastWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Toast');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Title Only Variant'), findsOneWidget);

      // Each tone label appears twice: once in the matrix section,
      // once in the title-only section.
      expect(find.text('Success'), findsNWidgets(2));
      expect(find.text('Warning'), findsNWidgets(2));
      expect(find.text('Error'), findsNWidgets(2));

      // 3 matrix toasts + 3 title-only toasts.
      expect(find.byType(DesignSystemToast), findsNWidgets(6));
    });
  });
}
