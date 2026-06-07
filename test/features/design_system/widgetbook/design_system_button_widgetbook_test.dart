import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_button_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

/// Sorted catalogue membership — additions/removals show up as a one-line
/// diff here instead of a churn through thirty singleWhere blocks.
const _expectedComponentNames = [
  'Avatars',
  'Badges',
  'Branding',
  'Breadcrumbs',
  'Buttons',
  'Calendar picker',
  'Caption',
  'Checkbox',
  'Chips',
  'Context menu',
  'Divider',
  'Dropdowns',
  'File upload',
  'Header',
  'List',
  'Navigation Sidebar',
  'Progress bar',
  'Radio buttons',
  'Scrollbar',
  'Search',
  'Spinner & loaders',
  'Split Buttons',
  'Tab bar',
  'Tabs',
  'Task filter modal',
  'Task list item',
  'Text input',
  'Textarea',
  'Time picker',
  'Toast',
  'Toggle',
  'Tooltip icon',
  'Typography',
];

void main() {
  group('buildDesignSystemWidgetbookFolder', () {
    testWidgets('builds the button overview use case and includes components', (
      tester,
    ) async {
      final folder = buildDesignSystemWidgetbookFolder();
      final components = folder.children!
          .whereType<WidgetbookComponent>()
          .toList();
      final buttonComponent = components.singleWhere(
        (component) => component.name == 'Buttons',
      );
      final useCase = buttonComponent.useCases.single;

      expect(folder.name, 'Design System');
      expect(
        components.map((component) => component.name),
        unorderedEquals(_expectedComponentNames),
      );
      // Every catalogued component exposes an 'Overview' first use case.
      for (final component in components) {
        expect(
          component.useCases.first.name,
          'Overview',
          reason: component.name,
        );
      }
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);

      await tester.tap(find.byType(DesignSystemButton).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
