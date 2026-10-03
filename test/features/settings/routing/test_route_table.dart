import 'package:lotti/features/settings/routing/settings_route.dart';
import 'package:material_ui/material_ui.dart';

/// A small stand-in for `settingsRoutes`, shaped like the real tree, whose
/// pages and panels are cheap labelled widgets. Lets the resolver, the panel
/// host and the leaf panel be tested without the provider graph behind every
/// real settings page.
///
///     root ─┬─ hub ─┬─ hub/list   /settings/list   (flat URL, sub-routes)
///           │       └─ hub/nested /settings/hub/nested/deep
///           ├─ section            /settings/section (page, no-page tabs)
///           │   └─ section/tab    /settings/section/tab
///           └─ leaf               /settings/leaf    (scrollable panel)
SettingsRouteTable testRouteTable() => SettingsRouteTable(
  root: SettingsRoute(
    url: '/settings',
    page: (_, _) => const Text('page:root'),
    keepsBottomNav: true,
    subRoutes: [
      SettingsSubRoute(
        '/settings/orphan/:orphanId',
        build: (_, m) => Text('orphan:${m.pathParameters['orphanId']}'),
      ),
    ],
  ),
  aliases: const {'/settings/old-leaf': '/settings/leaf'},
  routes: {
    'hub': SettingsRoute(
      url: '/settings/hub',
      page: (_, _) => const Text('page:hub'),
      keepsBottomNav: true,
    ),
    'hub/list': SettingsRoute(
      url: '/settings/list',
      page: (_, _) => const Text('page:list'),
      panel: (_, _) => const TestCounter(label: 'panel:list'),
      keepsBottomNav: true,
      subRoutes: [
        SettingsSubRoute(
          '/settings/list/create',
          build: (_, m) => Text('create:${m.queryParameters['name'] ?? ''}'),
        ),
        SettingsSubRoute(
          '/settings/list/:itemId',
          build: (_, m) => Text('detail:${m.pathParameters['itemId']}'),
        ),
        SettingsSubRoute(
          '/settings/list/:itemId/review',
          build: (_, m) => Text('review:${m.pathParameters['itemId']}'),
        ),
        SettingsSubRoute(
          '/settings/list/search/:term',
          build: (_, m) => Text('page:search:${m.pathParameters['term']}'),
          panel: (_, m) => Text('panel:search:${m.pathParameters['term']}'),
          replacesParent: true,
          keepsBottomNav: true,
        ),
      ],
    ),
    'hub/nested': SettingsRoute(
      url: '/settings/hub/nested/deep',
      page: (_, _) => const Text('page:nested'),
      panel: (_, _) => const Text('panel:nested'),
    ),
    'section': SettingsRoute(
      url: '/settings/section',
      page: (_, _) => const Text('page:section'),
      panel: (_, _) => const Text('panel:section'),
    ),
    'section/tab': SettingsRoute(
      url: '/settings/section/tab',
      panel: (_, _) => const Text('panel:tab'),
      subRoutes: [
        SettingsSubRoute(
          '/settings/section/tab/:tabItemId',
          build: (_, m) => Text('tab-item:${m.pathParameters['tabItemId']}'),
        ),
      ],
    ),
    'leaf': SettingsRoute(
      url: '/settings/leaf',
      page: (_, _) => const Text('page:leaf'),
      panel: (_, _) => const Column(children: [Text('panel:leaf')]),
      scrollable: true,
    ),
    'inert': const SettingsRoute(),
  },
);

/// A panel body with state of its own: a tap count, rendered as
/// `<label>:<count>`. Lets a test tell a body that survived a navigation
/// apart from one that was torn down and rebuilt.
class TestCounter extends StatefulWidget {
  const TestCounter({required this.label, super.key});

  final String label;

  @override
  State<TestCounter> createState() => _TestCounterState();
}

class _TestCounterState extends State<TestCounter> {
  var _count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => _count++),
    child: Text('${widget.label}:$_count'),
  );
}
