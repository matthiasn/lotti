import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_spinner_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemSpinnerWidgetbookComponent', () {
    testWidgets('builds the spinner overview use case', (tester) async {
      final component = buildDesignSystemSpinnerWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Spinner & loaders');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Spinners'), findsOneWidget);
      expect(find.text('Skeletons'), findsOneWidget);
      expect(find.byType(DesignSystemSpinner), findsNWidgets(2));
      expect(find.byType(DesignSystemSkeleton), findsNWidgets(2));
    });
  });
}
