import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/cards/ds_rows_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// A row that counts its own state objects, so a test can tell a row that
/// kept its element from one rebuilt in its place.
class _StatefulRow extends StatefulWidget {
  const _StatefulRow(this.label, {super.key});

  final String label;

  static int created = 0;

  @override
  State<_StatefulRow> createState() => _StatefulRowState();
}

class _StatefulRowState extends State<_StatefulRow> {
  @override
  void initState() {
    super.initState();
    _StatefulRow.created++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

void main() {
  Future<BuildContext> pumpCard(WidgetTester tester, List<Widget> rows) async {
    late BuildContext captured;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            captured = context;
            // A column, so the card takes its own height rather than the
            // host's.
            return Column(children: [DsRowsCard(rows: rows)]);
          },
        ),
      ),
    );
    return captured;
  }

  setUp(() => _StatefulRow.created = 0);

  testWidgets('paints a borderless level02 card at radii.l that clips', (
    tester,
  ) async {
    final context = await pumpCard(tester, const [Text('only')]);
    final tokens = context.designTokens;

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(DsRowsCard),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, tokens.colors.background.level02);
    expect(decoration.borderRadius, BorderRadius.circular(tokens.radii.l));
    expect(decoration.border, isNull);
    expect(container.clipBehavior, Clip.antiAlias);
  });

  testWidgets('a single row has no divider', (tester) async {
    await pumpCard(tester, const [Text('only')]);

    expect(find.text('only'), findsOneWidget);
    expect(find.byType(DesignSystemDivider), findsNothing);
  });

  testWidgets('puts one divider between each two rows, none outside', (
    tester,
  ) async {
    await pumpCard(tester, const [Text('a'), Text('b'), Text('c')]);

    expect(find.byType(DesignSystemDivider), findsNWidgets(2));
    final aTop = tester.getTopLeft(find.text('a')).dy;
    final bTop = tester.getTopLeft(find.text('b')).dy;
    final cTop = tester.getTopLeft(find.text('c')).dy;
    final dividers = find.byType(DesignSystemDivider);
    final dividerTops = [
      for (var i = 0; i < 2; i++) tester.getTopLeft(dividers.at(i)).dy,
    ];
    expect(aTop, lessThan(dividerTops[0]));
    expect(dividerTops[0], lessThan(bTop));
    expect(bTop, lessThan(dividerTops[1]));
    expect(dividerTops[1], lessThan(cTop));
  });

  testWidgets('renders an empty card when there are no rows', (tester) async {
    await pumpCard(tester, const []);

    expect(find.byType(DsRowsCard), findsOneWidget);
    expect(find.byType(DesignSystemDivider), findsNothing);
    expect(tester.getSize(find.byType(DsRowsCard)).height, 0);
  });

  testWidgets('keyed rows keep their state when a row is inserted above', (
    tester,
  ) async {
    await pumpCard(tester, const [
      _StatefulRow('b', key: ValueKey('b')),
      _StatefulRow('c', key: ValueKey('c')),
    ]);
    expect(_StatefulRow.created, 2);

    await pumpCard(tester, const [
      _StatefulRow('a', key: ValueKey('a')),
      _StatefulRow('b', key: ValueKey('b')),
      _StatefulRow('c', key: ValueKey('c')),
    ]);

    // Only the new row built a state; b and c moved with theirs.
    expect(_StatefulRow.created, 3);
    expect(find.byType(DesignSystemDivider), findsNWidgets(2));
  });

  testWidgets('a keyed row keeps its state when it moves to the top', (
    tester,
  ) async {
    await pumpCard(tester, const [
      _StatefulRow('a', key: ValueKey('a')),
      _StatefulRow('b', key: ValueKey('b')),
    ]);
    expect(_StatefulRow.created, 2);

    await pumpCard(tester, const [_StatefulRow('b', key: ValueKey('b'))]);

    expect(_StatefulRow.created, 2);
    expect(find.text('b'), findsOneWidget);
    expect(find.byType(DesignSystemDivider), findsNothing);
  });

  testWidgets('unkeyed rows are matched by position', (tester) async {
    await pumpCard(tester, const [_StatefulRow('x'), _StatefulRow('y')]);
    await pumpCard(tester, const [_StatefulRow('x2'), _StatefulRow('y2')]);

    expect(_StatefulRow.created, 2);
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('y2'), findsOneWidget);
  });
}
