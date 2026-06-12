import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';

import '../../test_helper.dart';

void main() {
  testWidgets('renders title, subtitle, and icon', (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: SettingsSwitchRow(
          title: 'Private',
          subtitle: 'Hide from shared views',
          icon: Icons.lock_outline,
          value: false,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Private'), findsOneWidget);
    expect(find.text('Hide from shared views'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(DesignSystemToggle), findsOneWidget);
  });

  testWidgets('tapping anywhere on the row flips the value', (tester) async {
    bool? received;
    await tester.pumpWidget(
      WidgetTestBench(
        child: SettingsSwitchRow(
          title: 'Private',
          value: false,
          onChanged: (value) => received = value,
        ),
      ),
    );

    await tester.tap(find.text('Private'));
    expect(received, isTrue);
  });

  testWidgets('tapping reports the inverse of the current value', (
    tester,
  ) async {
    bool? received;
    await tester.pumpWidget(
      WidgetTestBench(
        child: SettingsSwitchRow(
          title: 'Private',
          value: true,
          onChanged: (value) => received = value,
        ),
      ),
    );

    await tester.tap(find.text('Private'));
    expect(received, isFalse);
  });

  testWidgets('disabled row ignores taps', (tester) async {
    var called = false;
    await tester.pumpWidget(
      WidgetTestBench(
        child: SettingsSwitchRow(
          title: 'Private',
          value: false,
          enabled: false,
          onChanged: (_) => called = true,
        ),
      ),
    );

    await tester.tap(find.text('Private'));
    expect(called, isFalse);
  });

  testWidgets('null onChanged renders a non-interactive row', (tester) async {
    await tester.pumpWidget(
      const WidgetTestBench(
        child: SettingsSwitchRow(
          title: 'Private',
          value: true,
          onChanged: null,
        ),
      ),
    );

    // Tap must not throw and the toggle reports disabled.
    await tester.tap(find.text('Private'));
    final toggle = tester.widget<DesignSystemToggle>(
      find.byType(DesignSystemToggle),
    );
    expect(toggle.enabled, isFalse);
  });
}
