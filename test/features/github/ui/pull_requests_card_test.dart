import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/github/ui/pull_requests_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('the card holds its parts top to bottom, a hairline between '
      'rows and none above the first', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const PullRequestsCard(
          children: [
            Text('Header'),
            PullRequestRowList(
              rows: [Text('Row 1'), Text('Row 2'), Text('Row 3')],
            ),
          ],
        ),
      ),
    );

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(
      [top('Header'), top('Row 1'), top('Row 2'), top('Row 3')],
      [
        ...[top('Header'), top('Row 1'), top('Row 2'), top('Row 3')]..sort(),
      ],
    );
    expect(find.byType(DesignSystemDivider), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.byType(DesignSystemDivider).first).dy,
      greaterThan(top('Row 1')),
    );
  });

  testWidgets('one row needs no hairline', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const PullRequestRowList(rows: [Text('Only')]),
      ),
    );
    expect(find.text('Only'), findsOneWidget);
    expect(find.byType(DesignSystemDivider), findsNothing);
  });
}
