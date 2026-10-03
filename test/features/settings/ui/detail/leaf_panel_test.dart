import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/detail/leaf_panel.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../routing/test_route_table.dart';

void main() {
  final table = testRouteTable();

  /// Pumps a [LeafPanel] whose selected node is driven by [selected], so a
  /// selection change reaches the same panel state instead of remounting it.
  Future<ValueNotifier<String>> pump(
    WidgetTester tester, {
    String initial = 'hub/list',
    double width = 1000,
    double height = 800,
  }) async {
    final selected = ValueNotifier(initial);
    addTearDown(selected.dispose);
    final route = ValueNotifier<DesktopSettingsRoute?>(null);
    addTearDown(route.dispose);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Material(
          child: SizedBox(
            width: width,
            height: height,
            child: ValueListenableBuilder<String>(
              valueListenable: selected,
              builder: (_, id, _) =>
                  LeafPanel(nodeId: id, table: table, listenable: route),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return selected;
  }

  IndexedStack stackOf(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack));

  testWidgets('renders the selected node panel', (tester) async {
    await pump(tester);

    expect(find.text('panel:list:0'), findsOneWidget);
    expect(stackOf(tester).children, hasLength(1));
  });

  testWidgets('a visited panel keeps its state while a sibling is shown, and '
      'is shown again as it was left', (tester) async {
    final selected = await pump(tester);

    await tester.tap(find.text('panel:list:0'));
    await tester.pump();
    expect(find.text('panel:list:1'), findsOneWidget);

    selected.value = 'leaf';
    await tester.pump();
    expect(find.text('panel:leaf'), findsOneWidget);
    expect(stackOf(tester).children, hasLength(2));
    expect(stackOf(tester).index, 1);

    selected.value = 'hub/list';
    await tester.pump();
    // The same body, not a fresh one: its tap count survived the round trip,
    // and revisiting reused its slot instead of growing the cache.
    expect(find.text('panel:list:1'), findsOneWidget);
    expect(stackOf(tester).children, hasLength(2));
    expect(stackOf(tester).index, 0);
  });

  testWidgets('the body fills the whole pane, with no gutter or width cap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pump(tester, width: 1500, height: 900);

    expect(tester.getSize(find.byType(LeafPanel)), const Size(1500, 900));
    expect(
      tester.getSize(find.byKey(const ValueKey('leaf-body:hub/list'))),
      const Size(1500, 900),
    );
  });
}
