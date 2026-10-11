import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/sticky_action_bar_clearance.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const contentKey = Key('content');

  Widget page(StickyActionBarClearance clearance, double barHeight) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            clearance.content(const SizedBox(key: contentKey, height: 100)),
            clearance.bar(SizedBox(height: barHeight)),
          ],
        ),
      );

  /// The room the content is given under itself.
  double room(WidgetTester tester) =>
      tester
          .getSize(
            find.ancestor(
              of: find.byKey(contentKey),
              matching: find.byType(Padding),
            ),
          )
          .height -
      100;

  testWidgets('the content ends with exactly the bar height of room', (
    tester,
  ) async {
    final clearance = StickyActionBarClearance();
    expect(clearance.height, 0);

    await tester.pumpWidget(page(clearance, 88));
    // Reported after the frame it was laid out in, then built into the
    // content's padding on the next.
    await tester.pump();

    expect(clearance.height, 88);
    expect(room(tester), 88);
  });

  testWidgets('a bar that grows, as one stacking at large text does, takes '
      'its room with it', (tester) async {
    final clearance = StickyActionBarClearance();
    await tester.pumpWidget(page(clearance, 88));
    await tester.pump();

    await tester.pumpWidget(page(clearance, 140));
    await tester.pump();

    expect(room(tester), 140);
  });
}
