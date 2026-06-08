import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_toast_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemToastWidgetbookComponent', () {
    testWidgets('builds the toast overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemToastWidgetbookComponent(),
        expectedName: 'Toast',
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

      // Cleanup: drain the live countdown bars so the test doesn't tear down
      // with a still-ticking AnimationController. The two countdown toasts
      // reverse from 1.0 over 5s and from 0.6 over 8s (= 4.8s real time), so a
      // single 5-second pump fully drains both — 10s was unnecessary slack.
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });
}
