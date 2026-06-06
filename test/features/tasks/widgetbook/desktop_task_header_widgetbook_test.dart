import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/widgetbook/desktop_task_header_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  WidgetbookUseCase useCase(String name) {
    final component = buildDesktopTaskHeaderWidgetbookComponent();
    return component.useCases.singleWhere((u) => u.name == name);
  }

  Future<void> pumpUseCase(WidgetTester tester, String name) async {
    await tester.binding.setSurfaceSize(const Size(1900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(builder: useCase(name).builder),
        theme: DesignSystemTheme.dark(),
      ),
    );
    await tester.pump();
  }

  group('buildDesktopTaskHeaderWidgetbookComponent', () {
    test('exposes the expected use cases', () {
      final component = buildDesktopTaskHeaderWidgetbookComponent();

      expect(component.name, 'Desktop task header');
      expect(
        component.useCases.map((u) => u.name),
        [
          'Default',
          'Editing',
          'Long title (wraps)',
          'Empty classification + metadata',
          'Playground',
        ],
      );
    });

    testWidgets('the default use case renders the fixture header', (
      tester,
    ) async {
      await pumpUseCase(tester, 'Default');

      expect(find.text('Payment confirmation'), findsOneWidget);
      expect(
        find.text('Device Sync - Lotti Mobile App Implementation'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('playground toggles hide the project chip', (tester) async {
      await pumpUseCase(tester, 'Playground');

      expect(
        find.text('Device Sync - Lotti Mobile App Implementation'),
        findsOneWidget,
      );

      // Flip the "Show project" toggle: the chip disappears from the header.
      final toggle = find.widgetWithText(SwitchListTile, 'Show project');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();

      expect(
        find.text('Device Sync - Lotti Mobile App Implementation'),
        findsNothing,
      );
    });
  });
}
