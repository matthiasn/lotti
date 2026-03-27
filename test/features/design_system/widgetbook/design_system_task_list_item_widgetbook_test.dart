import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_task_list_item_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemTaskListItemWidgetbookComponent', () {
    testWidgets('renders the overview page with all variants', (
      tester,
    ) async {
      final component = buildDesignSystemTaskListItemWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Task list item');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Verify section title is rendered
      expect(find.textContaining('Task List Item'), findsOneWidget);

      // Verify sample content is rendered
      expect(find.text('User Testing'), findsAtLeast(1));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('P2'),
        ),
        findsAtLeast(1),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('P0'),
        ),
        findsAtLeast(1),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('P1'),
        ),
        findsAtLeast(1),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('P3'),
        ),
        findsAtLeast(1),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
