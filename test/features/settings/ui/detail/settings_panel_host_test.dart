import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/detail/settings_panel_host.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../routing/test_route_table.dart';

DesktopSettingsRoute _route(String url) {
  final uri = Uri.parse(url);
  return (
    path: uri.path,
    pathParameters: const <String, String>{},
    queryParameters: uri.queryParameters,
  );
}

void main() {
  final table = testRouteTable();

  Future<ValueNotifier<DesktopSettingsRoute?>> pump(
    WidgetTester tester,
    String nodeId, {
    String? url,
  }) async {
    final route = ValueNotifier<DesktopSettingsRoute?>(
      url == null ? null : _route(url),
    );
    addTearDown(route.dispose);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Material(
          child: SizedBox(
            width: 800,
            height: 600,
            child: SettingsPanelHost(
              nodeId: nodeId,
              table: table,
              listenable: route,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return route;
  }

  Future<void> go(
    WidgetTester tester,
    ValueNotifier<DesktopSettingsRoute?> route,
    String url,
  ) async {
    route.value = _route(url);
    // The cross-fade completes strictly after its duration, and the
    // outgoing body leaves the tree on the frame after that.
    await tester.pump();
    await tester.pump(kSettingsPanelSwapDuration);
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('shows the node panel before any route is published', (
    tester,
  ) async {
    await pump(tester, 'hub/list');
    expect(find.text('panel:list:0'), findsOneWidget);
  });

  testWidgets('a detail URL under the node swaps the detail into the slot, '
      'and leaving it brings the panel back', (tester) async {
    final route = await pump(tester, 'hub/list', url: '/settings/list');
    expect(find.text('panel:list:0'), findsOneWidget);

    await go(tester, route, '/settings/list/i-1');
    expect(find.text('detail:i-1'), findsOneWidget);
    expect(find.text('panel:list:0'), findsNothing);

    await go(tester, route, '/settings/list/i-1/review');
    expect(find.text('review:i-1'), findsOneWidget);

    await go(tester, route, '/settings/list');
    expect(find.text('panel:list:0'), findsOneWidget);
    expect(find.textContaining('review'), findsNothing);
  });

  testWidgets('each detail is keyed by its URL, so moving between two '
      'details mounts a fresh page', (tester) async {
    final route = await pump(tester, 'hub/list', url: '/settings/list/i-1');
    expect(
      find.byKey(const ValueKey('settings-hub/list:i-1')),
      findsOneWidget,
    );

    await go(tester, route, '/settings/list/i-2');
    expect(
      find.byKey(const ValueKey('settings-hub/list:i-2')),
      findsOneWidget,
    );
    expect(find.text('detail:i-1'), findsNothing);
  });

  testWidgets('the create route receives the query', (tester) async {
    await pump(tester, 'hub/list', url: '/settings/list/create?name=Krill');
    expect(find.text('create:Krill'), findsOneWidget);
  });

  testWidgets('a sub-route with a desktop override renders the override', (
    tester,
  ) async {
    await pump(tester, 'hub/list', url: '/settings/list/search/fish');
    expect(find.text('panel:search:fish'), findsOneWidget);
    expect(find.text('page:search:fish'), findsNothing);
  });

  testWidgets('a URL that belongs to another node leaves this body alone — '
      'a body cached for a sibling keeps showing itself', (tester) async {
    final route = await pump(tester, 'hub/list', url: '/settings/list');
    await tester.tap(find.text('panel:list:0'));
    await tester.pump();

    await go(tester, route, '/settings/section/tab/t-1');
    expect(find.text('panel:list:1'), findsOneWidget);
    expect(find.textContaining('tab-item'), findsNothing);
  });

  testWidgets('a scrollable panel is wrapped in a scroll view; a panel that '
      'scrolls itself is not', (tester) async {
    await pump(tester, 'leaf', url: '/settings/leaf');
    expect(
      find.ancestor(
        of: find.text('panel:leaf'),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );

    await pump(tester, 'section', url: '/settings/section');
    expect(
      find.ancestor(
        of: find.text('panel:section'),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });
}
