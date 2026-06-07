import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';

import '../../../../test_helper.dart';

void main() {
  testWidgets('renders title, subtitle, leading and trailing', (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: SettingsCard(
          onTap: () {},
          title: 'Sync',
          subtitle: const Text('Everything in order'),
          leading: const Icon(Icons.sync),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );

    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Everything in order'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('invokes onTap when the tile is tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      WidgetTestBench(
        child: SettingsCard(
          onTap: () => taps++,
          title: 'Tappable',
        ),
      ),
    );

    await tester.tap(find.text('Tappable'));
    expect(taps, 1);
  });

  testWidgets('applies the given title color', (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: SettingsCard(
          onTap: () {},
          title: 'Danger',
          titleColor: Colors.red,
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Danger'));
    expect(text.style?.color, Colors.red);
  });
}
