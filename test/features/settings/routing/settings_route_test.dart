import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/routing/settings_route.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/mocks.dart';
import 'test_route_table.dart';

void main() {
  final table = testRouteTable();
  final context = MockBuildContext();

  SettingsRouteMatch resolve(String url) => table.resolve(Uri.parse(url));
  List<String> keys(String url) => [
    for (final e in resolve(url).stack) e.key,
  ];
  List<String> pops(String url) => [
    for (final e in resolve(url).stack.skip(1)) e.popUrl,
  ];
  String topLabel(String url) {
    final match = resolve(url);
    return (match.stack.last.build(context, match) as Text).data!;
  }

  group('SettingsRouteTable.resolve — node pages', () {
    test('the bare root is a one-page stack that keeps the bottom nav', () {
      final match = resolve('/settings');
      expect(match.nodePath, isEmpty);
      expect(keys('/settings'), ['settings']);
      expect(topLabel('/settings'), 'page:root');
      expect(match.subRoute, isNull);
      expect(match.keepsBottomNav, isTrue);
    });

    test('a flat leaf URL stacks the hub its node hangs from', () {
      expect(resolve('/settings/list').nodePath, ['hub', 'hub/list']);
      expect(keys('/settings/list'), [
        'settings',
        'settings-hub',
        'settings-hub/list',
      ]);
      // Each page pops to the page beneath it by name — the leaf to its
      // hub, though its URL does not nest under the hub's.
      expect(pops('/settings/list'), ['/settings', '/settings/hub']);
    });

    test('a three-segment URL pops straight to its hub, not to the dead URI '
        'one segment up', () {
      expect(keys('/settings/hub/nested/deep'), [
        'settings',
        'settings-hub',
        'settings-hub/nested',
      ]);
      expect(pops('/settings/hub/nested/deep').last, '/settings/hub');
      expect(resolve('/settings/hub/nested/deep').keepsBottomNav, isFalse);
    });

    test('a node without a page adds none, but its URL is what the pages '
        'above it pop back to', () {
      final match = resolve('/settings/section/tab/t-1');
      expect(match.nodePath, ['section', 'section/tab']);
      expect(keys('/settings/section/tab/t-1'), [
        'settings',
        'settings-section',
        'settings-section/tab:t-1',
      ]);
      expect(pops('/settings/section/tab/t-1'), [
        '/settings',
        '/settings/section/tab',
      ]);
      expect(keys('/settings/section/tab'), ['settings', 'settings-section']);
    });

    test('query, fragment and a trailing slash do not change the node', () {
      for (final url in [
        '/settings/list/',
        '/settings/list?focus=x',
        '/settings/list#anchor',
      ]) {
        expect(resolve(url).nodePath, ['hub', 'hub/list'], reason: url);
        expect(resolve(url).subRoute, isNull, reason: url);
      }
    });

    test('an alias resolves to the canonical URL, stack included', () {
      expect(resolve('/settings/old-leaf').nodePath, ['leaf']);
      expect(keys('/settings/old-leaf'), ['settings', 'settings-leaf']);
    });

    test('a URL no node claims shows the root', () {
      expect(resolve('/settings/nope/deeper').nodePath, isEmpty);
      expect(keys('/settings/nope/deeper'), ['settings']);
      expect(resolve('/settings/nope').keepsBottomNav, isTrue);
    });
  });

  group('SettingsRouteTable.resolve — sub-routes', () {
    test('a detail stacks above its list and captures the id', () {
      final match = resolve('/settings/list/i-1');
      expect(match.subRoute?.pattern, '/settings/list/:itemId');
      expect(match.pathParameters, {'itemId': 'i-1'});
      expect(keys('/settings/list/i-1').last, 'settings-hub/list:i-1');
      expect(pops('/settings/list/i-1').last, '/settings/list');
      expect(topLabel('/settings/list/i-1'), 'detail:i-1');
      expect(match.keepsBottomNav, isFalse);
    });

    test('every matching prefix adds a page, so a review stacks above the '
        'item it reviews', () {
      expect(keys('/settings/list/i-1/review'), [
        'settings',
        'settings-hub',
        'settings-hub/list',
        'settings-hub/list:i-1',
        'settings-hub/list:i-1/review',
      ]);
      expect(pops('/settings/list/i-1/review').last, '/settings/list/i-1');
      expect(topLabel('/settings/list/i-1/review'), 'review:i-1');
    });

    test('an unknown trailing segment keeps the deepest matching detail', () {
      expect(topLabel('/settings/list/i-1/unknown'), 'detail:i-1');
    });

    test('create wins over the id pattern, and its query reaches the page '
        'and the page key', () {
      final match = resolve('/settings/list/create?name=Waddle');
      expect(match.subRoute?.pattern, '/settings/list/create');
      expect(match.pathParameters, isEmpty);
      expect(match.queryParameters, {'name': 'Waddle'});
      expect(match.stack.last.key, 'settings-hub/list:create?name=Waddle');
      expect(topLabel('/settings/list/create?name=Waddle'), 'create:Waddle');
    });

    test('an id parameter never captures the reserved create segment', () {
      // `section/tab` has a `:tabItemId` route and no create route.
      final match = resolve('/settings/section/tab/create');
      expect(match.subRoute, isNull);
      expect(keys('/settings/section/tab/create'), [
        'settings',
        'settings-section',
      ]);
    });

    test('a parent-replacing sub-route takes its parent page slot and pops '
        'where the parent would have', () {
      final match = resolve('/settings/list/search/fish');
      expect(keys('/settings/list/search/fish'), [
        'settings',
        'settings-hub',
        'settings-hub/list:search/fish',
      ]);
      expect(pops('/settings/list/search/fish').last, '/settings/hub');
      expect(topLabel('/settings/list/search/fish'), 'page:search:fish');
      expect(match.keepsBottomNav, isTrue);
    });

    test('root sub-routes serve detail pages that belong to no node', () {
      final match = resolve('/settings/orphan/o-1');
      expect(match.nodePath, isEmpty);
      expect(keys('/settings/orphan/o-1'), [
        'settings',
        'settings:orphan/o-1',
      ]);
      expect(pops('/settings/orphan/o-1'), ['/settings']);
      expect(resolve('/settings/orphan/create').stack, hasLength(1));
    });
  });

  group('SettingsRouteTable URL helpers', () {
    test('urlForPath uses the deepest node, falling back to the root', () {
      expect(table.urlForPath(const []), '/settings');
      expect(table.urlForPath(const ['hub', 'hub/list']), '/settings/list');
      expect(table.urlForPath(const ['inert']), '/settings');
      expect(table.urlForPath(const ['missing']), '/settings');
    });

    test('pathForUrl ignores URLs outside /settings', () {
      expect(table.pathForUrl('/journal/list'), isEmpty);
      expect(table.pathForUrl('/settingsx'), isEmpty);
    });

    test('nodeUrls lists every node with a URL, and only those', () {
      expect(table.nodeUrls.keys, isNot(contains('inert')));
      expect(table.nodeUrls['section/tab'], '/settings/section/tab');
    });

    test('patterns cover the root, every node, sub-route and alias once', () {
      expect(table.patterns.first, '/settings');
      expect(
        table.patterns,
        containsAll(<String>[
          '/settings/orphan/:orphanId',
          '/settings/list',
          '/settings/list/:itemId/review',
          '/settings/hub/nested/deep',
          '/settings/old-leaf',
        ]),
      );
      expect(table.patterns.toSet(), hasLength(table.patterns.length));
    });

    test('a table without a root page is rejected', () {
      expect(
        () => SettingsRouteTable(root: const SettingsRoute(), routes: const {}),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
