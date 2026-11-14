import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/markdown/citation_badge.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget badge, {double scale = 1}) =>
      tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Center(child: badge),
          ),
        ),
      );

  testWidgets('standing alone, before a listed source, it grows with large '
      'text', (tester) async {
    await pump(tester, const CitationBadge('3'));
    final regular = tester.getSize(find.byType(CitationBadge)).height;
    await pump(tester, const CitationBadge('3'), scale: 2);
    final enlarged = tester.getSize(find.byType(CitationBadge)).height;

    expect(enlarged / regular, closeTo(2, 0.1));
  });

  testWidgets('with a tap it is a link named for its source', (tester) async {
    var taps = 0;
    await pump(tester, CitationBadge('3', onTap: () => taps++));

    await tester.tap(find.byType(CitationBadge));
    expect(taps, 1);
    final node = tester.getSemantics(find.byType(CitationBadge));
    expect(node.label, 'Source 3');
    expect(node.flagsCollection.isLink, isTrue);
  });

  testWidgets('without one it only names its source', (tester) async {
    await pump(tester, const CitationBadge('3'));

    expect(find.byType(InkWell), findsNothing);
    final node = tester.getSemantics(find.byType(CitationBadge));
    expect(node.label, 'Source 3');
    expect(node.flagsCollection.isLink, isFalse);
  });
}
