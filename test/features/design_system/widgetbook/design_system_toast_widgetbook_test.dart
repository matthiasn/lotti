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

      // Section headers: the first two render in the initial viewport,
      // the action/countdown sections need a scroll because the overview
      // is hosted in a lazily-built ListView.
      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Title Only Variant'), findsOneWidget);
      // The visible sections actually contain rendered toasts, not just
      // their headers.
      expect(find.byType(DesignSystemToast), findsWidgets);

      final listView = find.byType(ListView);
      await tester.scrollUntilVisible(
        find.text('With Action'),
        300,
        scrollable: find.descendant(
          of: listView,
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('With Action'), findsOneWidget);
      expect(find.byType(DesignSystemToast), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('With Countdown'),
        300,
        scrollable: find.descendant(
          of: listView,
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('With Countdown'), findsOneWidget);
      expect(find.byType(DesignSystemToast), findsWidgets);

      // Cleanup: drain animation controllers from the live countdown bars
      // so the test doesn't tear down with pending Timers.
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    });
  });
}
