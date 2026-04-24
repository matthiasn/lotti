import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/url_sync/settings_tree_url_sync.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../widget_test_utils.dart';

class _FakeNavService implements NavService {
  @override
  final ValueNotifier<DesktopSettingsRoute?> desktopSelectedSettingsRoute =
      ValueNotifier<DesktopSettingsRoute?>(null);

  // Everything else is unused by SettingsTreeUrlSync so we trap any
  // stray access rather than quietly returning defaults.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Unexpected NavService call: ${invocation.memberName}',
  );
}

class _BeamSpy {
  final List<String> uris = [];
  void call(BuildContext context, String uri) => uris.add(uri);
}

Future<({ProviderContainer container, _BeamSpy spy, _FakeNavService nav})>
_pumpBridge(
  WidgetTester tester, {
  DesktopSettingsRoute? initialRoute,
}) async {
  await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  // Replace the default mock-wired NavService with our stub so we
  // can drive `desktopSelectedSettingsRoute` directly from tests.
  final nav = _FakeNavService();
  if (initialRoute != null) {
    nav.desktopSelectedSettingsRoute.value = initialRoute;
  }
  if (getIt.isRegistered<NavService>()) {
    getIt.unregister<NavService>();
  }
  getIt.registerSingleton<NavService>(nav);
  addTearDown(() async {
    if (getIt.isRegistered<NavService>()) {
      getIt.unregister<NavService>();
    }
    nav.desktopSelectedSettingsRoute.dispose();
  });

  final spy = _BeamSpy();
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Material(
        child: SettingsTreeUrlSync(beamToReplacementNamed: spy.call),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(SettingsTreeUrlSync)),
    listen: false,
  );
  return (container: container, spy: spy, nav: nav);
}

DesktopSettingsRoute _route(String path) => (
  path: path,
  pathParameters: const <String, String>{},
  queryParameters: const <String, String>{},
);

void main() {
  group('SettingsTreeUrlSync — URL → tree', () {
    testWidgets(
      'seeds the tree from a deep-linked route on first frame',
      (tester) async {
        final harness = await _pumpBridge(
          tester,
          initialRoute: _route('/settings/sync/backfill'),
        );
        expect(
          harness.container.read(settingsTreePathProvider),
          ['sync', 'sync/backfill'],
        );
      },
    );

    testWidgets(
      'later Beamer-driven route changes flow into the tree state',
      (tester) async {
        final harness = await _pumpBridge(tester);
        expect(harness.container.read(settingsTreePathProvider), isEmpty);

        harness.nav.desktopSelectedSettingsRoute.value = _route(
          '/settings/advanced/about',
        );
        await tester.pump();
        await tester.pump();

        expect(harness.container.read(settingsTreePathProvider), [
          'advanced',
          'advanced/about',
        ]);
      },
    );

    testWidgets(
      'panel-local UUID trailing segments leave the tree path intact',
      (tester) async {
        final harness = await _pumpBridge(
          tester,
          initialRoute: _route('/settings/categories'),
        );
        expect(harness.container.read(settingsTreePathProvider), [
          'categories',
        ]);

        // Drill into a category detail — should NOT re-seed the tree
        // path (greedy longest-prefix match still lands on
        // 'categories'), and must not re-emit a beam.
        final spyCountBefore = harness.spy.uris.length;
        harness.nav.desktopSelectedSettingsRoute.value = _route(
          '/settings/categories/abc-123',
        );
        await tester.pump();
        await tester.pump();

        expect(harness.container.read(settingsTreePathProvider), [
          'categories',
        ]);
        expect(harness.spy.uris.length, spyCountBefore);
      },
    );
  });

  group('SettingsTreeUrlSync — tree → URL', () {
    testWidgets(
      'mutating the tree beams to the matching canonical URL',
      (tester) async {
        final harness = await _pumpBridge(tester);
        harness.container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('flags', depth: 0, hasChildren: false);
        await tester.pump();

        expect(harness.spy.uris, ['/settings/flags']);
      },
    );

    testWidgets(
      'opening a nested branch beams to the branch URL at that depth',
      (tester) async {
        final harness = await _pumpBridge(tester);
        harness.container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('sync', depth: 0, hasChildren: true);
        await tester.pump();
        harness.container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('sync/backfill', depth: 1, hasChildren: false);
        await tester.pump();

        expect(harness.spy.uris, ['/settings/sync', '/settings/sync/backfill']);
      },
    );

    testWidgets(
      'sync/matrix-maintenance is beamed as /settings/sync/matrix/maintenance',
      (tester) async {
        final harness = await _pumpBridge(tester);
        harness.container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('sync', depth: 0, hasChildren: true);
        harness.container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('sync/matrix-maintenance', depth: 1, hasChildren: false);
        await tester.pump();

        expect(harness.spy.uris.last, '/settings/sync/matrix/maintenance');
      },
    );

    testWidgets(
      'truncating back to the root beams to /settings',
      (tester) async {
        final harness = await _pumpBridge(
          tester,
          initialRoute: _route('/settings/flags'),
        );
        harness.container.read(settingsTreePathProvider.notifier).truncateTo(0);
        await tester.pump();

        expect(harness.spy.uris.last, '/settings');
      },
    );

    testWidgets(
      'when the beam target already matches the current route, does NOT '
      'emit a redundant beam',
      (tester) async {
        final harness = await _pumpBridge(
          tester,
          initialRoute: _route('/settings/flags'),
        );
        // Tree was seeded to ['flags'] on mount; tapping 'flags' again
        // is a rule-4 no-op anyway, but even if an upstream flip
        // produced the same path, we don't want a beam storm.
        harness.container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('flags', depth: 0, hasChildren: false);
        await tester.pump();

        expect(harness.spy.uris, isEmpty);
      },
    );
  });

  group('SettingsTreeUrlSync — feedback-loop guard', () {
    testWidgets(
      'a tree-triggered beam that round-trips through the route notifier '
      'does not re-fire a second beam',
      (tester) async {
        final harness = await _pumpBridge(tester);
        harness.container
            .read(settingsTreePathProvider.notifier)
            .onNodeTap('flags', depth: 0, hasChildren: false);
        await tester.pump();

        // Simulate Beamer updating the route in response to our
        // beam (the real integration path would go app-router →
        // SettingsLocation → desktopSelectedSettingsRoute).
        harness.nav.desktopSelectedSettingsRoute.value = _route(
          '/settings/flags',
        );
        await tester.pump();
        await tester.pump();

        // Exactly one beam — the original tree-driven call.
        expect(harness.spy.uris, ['/settings/flags']);
        expect(harness.container.read(settingsTreePathProvider), ['flags']);
      },
    );
  });
}
