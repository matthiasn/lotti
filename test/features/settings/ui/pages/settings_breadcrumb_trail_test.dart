import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/settings_breadcrumb_trail.dart';
import 'package:lotti/features/settings/ui/pages/settings_column_stack.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';

DesktopSettingsRoute _route(
  String path, {
  Map<String, String> params = const {},
  Map<String, String> query = const {},
}) {
  return (path: path, pathParameters: params, queryParameters: query);
}

/// Renders a MaterialApp that wires up [AppLocalizations] and runs
/// [resolveSettingsBreadcrumbTrail] inside a `Builder` so the resolver
/// has a real, localised [BuildContext].
Future<List<SettingsBreadcrumbEntry>> _resolve(
  WidgetTester tester, {
  required DesktopSettingsRoute? route,
}) async {
  late List<SettingsBreadcrumbEntry> trail;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          trail = resolveSettingsBreadcrumbTrail(context, route);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return trail;
}

List<String> _paths(List<SettingsBreadcrumbEntry> trail) =>
    trail.map((e) => e.path).toList();

/// Canonical set of routes that exercise every branch of the column
/// stack resolver. Used by the parity test to assert that the trail
/// length always matches the column count — the invariant that the
/// unified resolver design enforces by construction.
final List<DesktopSettingsRoute> _canonicalRoutes = [
  _route('/settings'),
  _route('/settings/ai'),
  _route('/settings/ai/profiles'),
  _route('/settings/sync'),
  _route('/settings/sync/matrix/maintenance'),
  _route('/settings/sync/backfill'),
  _route('/settings/sync/stats'),
  _route('/settings/sync/outbox'),
  _route('/settings/labels'),
  _route('/settings/labels/create'),
  _route(
    '/settings/labels/lbl-1',
    params: {'labelId': 'lbl-1'},
  ),
  _route('/settings/categories'),
  _route('/settings/categories/create'),
  _route(
    '/settings/categories/cat-1',
    params: {'categoryId': 'cat-1'},
  ),
  _route('/settings/projects/create'),
  _route(
    '/settings/projects/proj-1',
    params: {'projectId': 'proj-1'},
  ),
  _route('/settings/dashboards'),
  _route('/settings/dashboards/create'),
  _route(
    '/settings/dashboards/dash-1',
    params: {'dashboardId': 'dash-1'},
  ),
  _route('/settings/measurables'),
  _route('/settings/measurables/create'),
  _route(
    '/settings/measurables/meas-1',
    params: {'measurableId': 'meas-1'},
  ),
  _route('/settings/habits'),
  _route(
    '/settings/habits/search/run',
    params: {'searchTerm': 'run'},
  ),
  _route('/settings/habits/create'),
  _route(
    '/settings/habits/by_id/hab-1',
    params: {'habitId': 'hab-1'},
  ),
  _route('/settings/agents'),
  _route('/settings/agents/templates/create'),
  _route(
    '/settings/agents/templates/tpl-1',
    params: {'templateId': 'tpl-1'},
  ),
  _route(
    '/settings/agents/templates/tpl-1/review',
    params: {'templateId': 'tpl-1'},
  ),
  _route('/settings/agents/souls/create'),
  _route(
    '/settings/agents/souls/soul-1',
    params: {'soulId': 'soul-1'},
  ),
  _route(
    '/settings/agents/souls/soul-1/review',
    params: {'soulId': 'soul-1'},
  ),
  _route(
    '/settings/agents/instances/agent-1',
    params: {'agentId': 'agent-1'},
  ),
  _route('/settings/flags'),
  _route('/settings/theming'),
  _route('/settings/health_import'),
  _route('/settings/advanced'),
  _route('/settings/advanced/logging_domains'),
  _route('/settings/advanced/about'),
  _route('/settings/advanced/maintenance'),
  _route('/settings/advanced/conflicts'),
  _route(
    '/settings/advanced/conflicts/c-1',
    params: {'conflictId': 'c-1'},
  ),
  _route(
    '/settings/advanced/conflicts/c-1/edit',
    params: {'conflictId': 'c-1'},
  ),
];

void main() {
  group('resolveSettingsBreadcrumbTrail', () {
    testWidgets('null route yields just the root Settings crumb', (
      tester,
    ) async {
      final trail = await _resolve(tester, route: null);
      expect(_paths(trail), ['/settings']);
      expect(trail.single.label.isNotEmpty, isTrue);
    });

    testWidgets('/settings root yields just the root crumb', (tester) async {
      final trail = await _resolve(tester, route: _route('/settings'));
      expect(_paths(trail), ['/settings']);
    });

    testWidgets('/settings/ai adds the AI crumb', (tester) async {
      final trail = await _resolve(tester, route: _route('/settings/ai'));
      expect(_paths(trail), ['/settings', '/settings/ai']);
    });

    testWidgets(
      '/settings/ai/profiles adds the profiles leaf that the column '
      'stack opens — parity with the drill-down',
      (tester) async {
        final trail = await _resolve(
          tester,
          route: _route('/settings/ai/profiles'),
        );
        expect(
          _paths(trail),
          ['/settings', '/settings/ai', '/settings/ai/profiles'],
        );
      },
    );

    testWidgets('/settings/sync stacks the Sync crumb', (tester) async {
      final trail = await _resolve(tester, route: _route('/settings/sync'));
      expect(_paths(trail), ['/settings', '/settings/sync']);
    });

    testWidgets(
      '/settings/sync/backfill adds the leaf Backfill crumb — the drill '
      'the user called out in the task',
      (tester) async {
        final trail = await _resolve(
          tester,
          route: _route('/settings/sync/backfill'),
        );
        expect(
          _paths(trail),
          ['/settings', '/settings/sync', '/settings/sync/backfill'],
        );
      },
    );

    testWidgets('/settings/sync/matrix/maintenance adds the maintenance leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/sync/matrix/maintenance'),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/sync/matrix/maintenance');
    });

    testWidgets('/settings/labels stacks the Labels crumb', (tester) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/labels'),
      );
      expect(_paths(trail), ['/settings', '/settings/labels']);
    });

    testWidgets('/settings/labels/create adds the create-label crumb', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/labels/create'),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/labels/create');
    });

    testWidgets('/settings/labels/<id> adds the edit-label crumb', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route(
          '/settings/labels/lbl-1',
          params: {'labelId': 'lbl-1'},
        ),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/labels/lbl-1');
    });

    testWidgets('/settings/categories stacks the Categories crumb', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/categories'),
      );
      expect(_paths(trail), ['/settings', '/settings/categories']);
    });

    testWidgets(
      '/settings/categories/create adds the create-category leaf — '
      'previously missing from the trail even though the column stack '
      'rendered the details column',
      (tester) async {
        final trail = await _resolve(
          tester,
          route: _route('/settings/categories/create'),
        );
        expect(trail.length, 3);
        expect(trail.last.path, '/settings/categories/create');
      },
    );

    testWidgets('/settings/categories/<id> adds the edit-category leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route(
          '/settings/categories/cat-1',
          params: {'categoryId': 'cat-1'},
        ),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/categories/cat-1');
    });

    testWidgets(
      '/settings/projects/create adds the project create leaf on top '
      'of the root (projects has no intermediate list column)',
      (tester) async {
        final trail = await _resolve(
          tester,
          route: _route('/settings/projects/create'),
        );
        expect(trail.length, 2);
        expect(trail.last.path, '/settings/projects/create');
      },
    );

    testWidgets('/settings/projects/<id> adds the project detail leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route(
          '/settings/projects/proj-1',
          params: {'projectId': 'proj-1'},
        ),
      );
      expect(trail.length, 2);
      expect(trail.last.path, '/settings/projects/proj-1');
    });

    testWidgets(
      '/settings/projects with no id falls back to just the root crumb',
      (tester) async {
        final trail = await _resolve(
          tester,
          route: _route('/settings/projects'),
        );
        expect(_paths(trail), ['/settings']);
      },
    );

    testWidgets('/settings/dashboards stacks the Dashboards crumb', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/dashboards'),
      );
      expect(_paths(trail), ['/settings', '/settings/dashboards']);
    });

    testWidgets('/settings/dashboards/create adds the create-dashboard leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/dashboards/create'),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/dashboards/create');
    });

    testWidgets('/settings/dashboards/<id> adds the edit-dashboard leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route(
          '/settings/dashboards/dash-1',
          params: {'dashboardId': 'dash-1'},
        ),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/dashboards/dash-1');
    });

    testWidgets('/settings/measurables stacks the Measurables crumb', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/measurables'),
      );
      expect(_paths(trail), ['/settings', '/settings/measurables']);
    });

    testWidgets('/settings/measurables/create adds the create leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/measurables/create'),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/measurables/create');
    });

    testWidgets('/settings/measurables/<id> adds the edit leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route(
          '/settings/measurables/meas-1',
          params: {'measurableId': 'meas-1'},
        ),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/measurables/meas-1');
    });

    testWidgets('/settings/habits stacks the Habits crumb', (tester) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/habits'),
      );
      expect(_paths(trail), ['/settings', '/settings/habits']);
    });

    testWidgets(
      '/settings/habits/search variant still reads as Habits and links '
      'back to the clean list (parity with the column-stack variant)',
      (tester) async {
        final trail = await _resolve(
          tester,
          route: _route(
            '/settings/habits/search/run',
            params: {'searchTerm': 'run'},
          ),
        );
        expect(_paths(trail), ['/settings', '/settings/habits']);
      },
    );

    testWidgets('/settings/habits/create adds the create-habit leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/habits/create'),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/habits/create');
    });

    testWidgets('/settings/habits/by_id/<id> adds the edit-habit leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route(
          '/settings/habits/by_id/hab-1',
          params: {'habitId': 'hab-1'},
        ),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/habits/by_id/hab-1');
    });

    testWidgets('/settings/agents stacks the Agents crumb', (tester) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/agents'),
      );
      expect(_paths(trail), ['/settings', '/settings/agents']);
    });

    testWidgets('/settings/agents/templates/create adds the create leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/agents/templates/create'),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/agents/templates/create');
    });

    testWidgets('/settings/agents/templates/<id> adds the edit leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route(
          '/settings/agents/templates/tpl-1',
          params: {'templateId': 'tpl-1'},
        ),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/agents/templates/tpl-1');
    });

    testWidgets(
      '/settings/agents/templates/<id>/review stacks four crumbs deep',
      (tester) async {
        final trail = await _resolve(
          tester,
          route: _route(
            '/settings/agents/templates/tpl-1/review',
            params: {'templateId': 'tpl-1'},
          ),
        );
        expect(trail.length, 4);
        expect(trail.last.path, '/settings/agents/templates/tpl-1/review');
      },
    );

    testWidgets('/settings/agents/souls/create adds the soul-create leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/agents/souls/create'),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/agents/souls/create');
    });

    testWidgets('/settings/agents/souls/<id>/review stacks four crumbs', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route(
          '/settings/agents/souls/soul-1/review',
          params: {'soulId': 'soul-1'},
        ),
      );
      expect(trail.length, 4);
      expect(trail.last.path, '/settings/agents/souls/soul-1/review');
    });

    testWidgets('/settings/agents/instances/<id> adds the instance leaf', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route(
          '/settings/agents/instances/agent-1',
          params: {'agentId': 'agent-1'},
        ),
      );
      expect(trail.length, 3);
      expect(trail.last.path, '/settings/agents/instances/agent-1');
    });

    testWidgets('/settings/flags stacks the Flags crumb', (tester) async {
      final trail = await _resolve(tester, route: _route('/settings/flags'));
      expect(_paths(trail), ['/settings', '/settings/flags']);
    });

    testWidgets('/settings/theming stacks the Theming crumb', (tester) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/theming'),
      );
      expect(_paths(trail), ['/settings', '/settings/theming']);
    });

    testWidgets('/settings/health_import stacks the Health Import crumb', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/health_import'),
      );
      expect(_paths(trail), ['/settings', '/settings/health_import']);
    });

    testWidgets('/settings/advanced stacks the Advanced crumb', (
      tester,
    ) async {
      final trail = await _resolve(
        tester,
        route: _route('/settings/advanced'),
      );
      expect(_paths(trail), ['/settings', '/settings/advanced']);
    });

    testWidgets(
      '/settings/advanced/conflicts/<id> adds the conflict-resolution '
      'crumb on top of the conflicts list',
      (tester) async {
        final trail = await _resolve(
          tester,
          route: _route(
            '/settings/advanced/conflicts/c-1',
            params: {'conflictId': 'c-1'},
          ),
        );
        expect(trail.length, 4);
        expect(
          _paths(trail).sublist(0, 3),
          [
            '/settings',
            '/settings/advanced',
            '/settings/advanced/conflicts',
          ],
        );
        expect(trail.last.path, '/settings/advanced/conflicts/c-1');
      },
    );

    testWidgets(
      '/settings/advanced/conflicts/<id>/edit adds a fifth edit leaf, '
      'matching the column stack depth',
      (tester) async {
        final trail = await _resolve(
          tester,
          route: _route(
            '/settings/advanced/conflicts/c-1/edit',
            params: {'conflictId': 'c-1'},
          ),
        );
        expect(trail.length, 5);
        expect(
          trail.last.path,
          '/settings/advanced/conflicts/c-1/edit',
        );
      },
    );

    testWidgets(
      'unknown /settings/* path falls back to just the root crumb — same '
      'fallback contract the column-stack resolver applies',
      (tester) async {
        final trail = await _resolve(
          tester,
          route: _route('/settings/unknown_section'),
        );
        expect(_paths(trail), ['/settings']);
      },
    );

    testWidgets(
      'trail length equals the column-stack length for every canonical '
      'route — the unification invariant that prevents drift',
      (tester) async {
        for (final route in _canonicalRoutes) {
          final trail = await _resolve(tester, route: route);
          final columns = resolveSettingsColumnStack(route);
          expect(
            trail.length,
            columns.length,
            reason:
                'Trail length must match column count for ${route.path}; '
                'got trail=${_paths(trail)} vs '
                'columns=${columns.map((c) => c.crumb.path).toList()}',
          );
          for (var i = 0; i < trail.length; i++) {
            expect(
              trail[i].path,
              columns[i].crumb.path,
              reason:
                  'Crumb path at index $i must match column crumb path for '
                  '${route.path}',
            );
            expect(
              trail[i].label.isNotEmpty,
              isTrue,
              reason:
                  'Crumb label at index $i must be non-empty for ${route.path}',
            );
          }
        }
      },
    );
  });
}
