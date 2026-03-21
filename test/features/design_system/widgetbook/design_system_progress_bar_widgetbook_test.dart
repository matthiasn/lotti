import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_progress_bar_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemProgressBarWidgetbookComponent', () {
    testWidgets('builds the progress bar overview use case', (tester) async {
      final component = buildDesignSystemProgressBarWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Progress bar');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Default'), findsAtLeastNWidgets(1));
      expect(find.text('Chunky'), findsAtLeastNWidgets(1));
      expect(find.text('Label + Percentage'), findsAtLeastNWidgets(1));
      expect(find.text('Label only'), findsAtLeastNWidgets(1));
      expect(find.text('Percentage'), findsAtLeastNWidgets(1));
      expect(find.text('Off'), findsAtLeastNWidgets(1));
      expect(find.text('Quest bar'), findsAtLeastNWidgets(1));
      expect(find.text('70%'), findsAtLeastNWidgets(1));
      expect(find.text('60%'), findsAtLeastNWidgets(1));
      expect(find.text('45/60'), findsOneWidget);
      expect(find.byType(DesignSystemProgressBar), findsNWidgets(10));
    });
  });
}
