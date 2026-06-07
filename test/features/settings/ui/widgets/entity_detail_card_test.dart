import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/widgets/entity_detail_card.dart';

import '../../../../test_helper.dart';

void main() {
  testWidgets('renders the child inside a scrollable card with the default '
      'content padding', (tester) async {
    await tester.pumpWidget(
      const WidgetTestBench(
        child: EntityDetailCard(
          child: Text('card body'),
        ),
      ),
    );

    expect(find.text('card body'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
      find.ancestor(of: find.text('card body'), matching: find.byType(Card)),
      findsOneWidget,
    );

    final innerPadding = tester.widget<Padding>(
      find
          .ancestor(of: find.text('card body'), matching: find.byType(Padding))
          .first,
    );
    expect(innerPadding.padding, const EdgeInsets.all(20));
  });

  testWidgets('honours a custom contentPadding', (tester) async {
    const custom = EdgeInsets.symmetric(horizontal: 4, vertical: 2);
    await tester.pumpWidget(
      const WidgetTestBench(
        child: EntityDetailCard(
          contentPadding: custom,
          child: Text('padded'),
        ),
      ),
    );

    final innerPadding = tester.widget<Padding>(
      find
          .ancestor(of: find.text('padded'), matching: find.byType(Padding))
          .first,
    );
    expect(innerPadding.padding, custom);
  });
}
