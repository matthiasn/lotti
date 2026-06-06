import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/why_chip.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('renders the WHY label inside a tooltip with the reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(
          body: WhyChip(reason: 'Scheduled after your standup'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('WHY'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'Scheduled after your standup');
    expect(tooltip.preferBelow, isFalse);
  });
}
