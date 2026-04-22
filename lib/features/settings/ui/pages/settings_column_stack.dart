import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_review_page.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_review_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart'
    as new_categories;
import 'package:lotti/features/categories/ui/pages/category_details_page.dart'
    as new_category_details;
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/projects/ui/pages/project_create_page.dart';
import 'package:lotti/features/projects/ui/pages/project_detail_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_create_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/sync_settings_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/services/nav_service.dart';

/// A single navigation column in the multi-pane settings layout.
///
/// Each column corresponds to one meaningful level of the settings
/// navigation hierarchy — the top-level menu, a category's sub-menu, a
/// detail page, etc. The [key] is stable per path so Flutter preserves
/// widget state as the stack grows or shrinks.
@immutable
class SettingsColumn {
  const SettingsColumn({required this.key, required this.child});

  final Key key;
  final Widget child;
}

/// Signature of a per-feature resolver. Returns the columns to append
/// after the root [SettingsPage] when the resolver claims ownership of
/// [path], or `null` when the path belongs to a different subtree.
///
/// Returning an empty list means "I own this prefix but add no further
/// columns" (e.g. `/settings/projects` with no id) — the dispatcher
/// still stops iterating so later resolvers don't see paths they
/// shouldn't.
typedef _SubtreeResolver =
    List<SettingsColumn>? Function(
      String path,
      Map<String, String> params,
      Map<String, String> query,
    );

const SettingsColumn _rootColumn = SettingsColumn(
  key: ValueKey('/settings'),
  child: SettingsPage(),
);

/// Builds the ordered list of navigation columns for a given settings
/// route. The first column is always the root settings menu; each
/// subsequent column corresponds to a deeper level of the route tree
/// that has its own explicit page widget.
///
/// Example stacks:
///
/// * `null` or `/settings` → `[SettingsPage]`
/// * `/settings/sync` → `[SettingsPage, SyncSettingsPage]`
/// * `/settings/sync/backfill` → `[SettingsPage, SyncSettingsPage,
///   BackfillSettingsPage]`
/// * `/settings/labels/<id>` → `[SettingsPage, LabelsListPage,
///   LabelDetailsPage]`
///
/// The per-subtree logic lives in the `_resolve*` functions below; this
/// dispatcher just picks the first one that claims ownership of the
/// path. Adding a new settings subtree = add one resolver and register
/// it in [_subtreeResolvers].
List<SettingsColumn> resolveSettingsColumnStack(DesktopSettingsRoute? route) {
  if (route == null || route.path == '/settings') {
    return const <SettingsColumn>[_rootColumn];
  }
  final path = route.path;
  final params = route.pathParameters;
  final query = route.queryParameters;

  for (final resolve in _subtreeResolvers) {
    final extension = resolve(path, params, query);
    if (extension != null) {
      if (extension.isEmpty) return const <SettingsColumn>[_rootColumn];
      return <SettingsColumn>[_rootColumn, ...extension];
    }
  }

  return const <SettingsColumn>[_rootColumn];
}

/// Ordered list of subtree resolvers. The first one to return non-null
/// wins; none of the current prefixes overlap, so ordering is purely
/// cosmetic — sorted roughly by how commonly the subtree is visited.
const List<_SubtreeResolver> _subtreeResolvers = <_SubtreeResolver>[
  _resolveAi,
  _resolveSync,
  _resolveLabels,
  _resolveCategories,
  _resolveProjects,
  _resolveDashboards,
  _resolveMeasurables,
  _resolveHabits,
  _resolveAgents,
  _resolveFlags,
  _resolveTheming,
  _resolveHealthImport,
  _resolveAdvanced,
];

List<SettingsColumn>? _resolveAi(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/ai')) return null;
  final columns = <SettingsColumn>[
    const SettingsColumn(
      key: ValueKey('/settings/ai'),
      child: AiSettingsPage(),
    ),
  ];
  if (path == '/settings/ai/profiles') {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/ai/profiles'),
        child: InferenceProfilePage(),
      ),
    );
  }
  return columns;
}

List<SettingsColumn>? _resolveSync(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/sync')) return null;
  final columns = <SettingsColumn>[
    const SettingsColumn(
      key: ValueKey('/settings/sync'),
      child: SyncSettingsPage(),
    ),
  ];
  if (path == '/settings/sync/matrix/maintenance') {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/sync/matrix/maintenance'),
        child: MatrixSyncMaintenancePage(),
      ),
    );
  } else if (path == '/settings/sync/backfill') {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/sync/backfill'),
        child: BackfillSettingsPage(),
      ),
    );
  } else if (path == '/settings/sync/stats') {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/sync/stats'),
        child: SyncStatsPage(),
      ),
    );
  } else if (path == '/settings/sync/outbox') {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/sync/outbox'),
        child: OutboxMonitorPage(),
      ),
    );
  }
  return columns;
}

List<SettingsColumn>? _resolveLabels(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/labels')) return null;
  final columns = <SettingsColumn>[
    const SettingsColumn(
      key: ValueKey('/settings/labels'),
      child: LabelsListPage(),
    ),
  ];
  if (path.startsWith('/settings/labels/create')) {
    final initialName = query['name'];
    columns.add(
      SettingsColumn(
        // Include the name seed in the key so initState() re-seeds the
        // text controller when the user navigates between different
        // `?name=` presets.
        key: ValueKey('/settings/labels/create?name=${initialName ?? ''}'),
        child: LabelDetailsPage(initialName: initialName),
      ),
    );
  } else if (params.containsKey('labelId')) {
    final labelId = params['labelId'];
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/labels/$labelId'),
        child: LabelDetailsPage(labelId: labelId),
      ),
    );
  }
  return columns;
}

List<SettingsColumn>? _resolveCategories(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/categories')) return null;
  final columns = <SettingsColumn>[
    const SettingsColumn(
      key: ValueKey('/settings/categories'),
      child: new_categories.CategoriesListPage(),
    ),
  ];
  if (path.startsWith('/settings/categories/create')) {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/categories/create'),
        child: new_category_details.CategoryDetailsPage(),
      ),
    );
  } else if (params.containsKey('categoryId') &&
      params['categoryId'] != 'create') {
    final categoryId = params['categoryId'];
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/categories/$categoryId'),
        child: new_category_details.CategoryDetailsPage(
          categoryId: categoryId,
        ),
      ),
    );
  }
  return columns;
}

/// Projects has no intermediate list page in the route tree, so the
/// project detail/create widget is appended directly onto the root.
List<SettingsColumn>? _resolveProjects(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/projects')) return null;
  if (path.startsWith('/settings/projects/create')) {
    final categoryId = query['categoryId'];
    return [
      SettingsColumn(
        // Include the categoryId seed in the key so the title field /
        // target-date state reset when the user opens a create form
        // for a different category.
        key: ValueKey(
          '/settings/projects/create?categoryId=${categoryId ?? ''}',
        ),
        child: ProjectCreatePage(categoryId: categoryId),
      ),
    ];
  }
  if (params.containsKey('projectId')) {
    final projectId = params['projectId']!;
    return [
      SettingsColumn(
        key: ValueKey('/settings/projects/$projectId'),
        child: ProjectDetailPage(
          projectId: projectId,
          categoryId: query['categoryId'],
        ),
      ),
    ];
  }
  return const <SettingsColumn>[];
}

List<SettingsColumn>? _resolveDashboards(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/dashboards')) return null;
  final columns = <SettingsColumn>[
    const SettingsColumn(
      key: ValueKey('/settings/dashboards'),
      child: DashboardSettingsPage(),
    ),
  ];
  if (path.startsWith('/settings/dashboards/create')) {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/dashboards/create'),
        child: CreateDashboardPage(),
      ),
    );
  } else if (params.containsKey('dashboardId')) {
    final dashboardId = params['dashboardId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/dashboards/$dashboardId'),
        child: EditDashboardPage(dashboardId: dashboardId),
      ),
    );
  }
  return columns;
}

List<SettingsColumn>? _resolveMeasurables(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/measurables')) return null;
  final columns = <SettingsColumn>[
    const SettingsColumn(
      key: ValueKey('/settings/measurables'),
      child: MeasurablesPage(),
    ),
  ];
  if (path.startsWith('/settings/measurables/create')) {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/measurables/create'),
        child: CreateMeasurablePage(),
      ),
    );
  } else if (params.containsKey('measurableId')) {
    final measurableId = params['measurableId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/measurables/$measurableId'),
        child: EditMeasurablePage(measurableId: measurableId),
      ),
    );
  }
  return columns;
}

List<SettingsColumn>? _resolveHabits(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/habits')) return null;
  // The `search` variant swaps the habits list for a search-seeded
  // variant; it doesn't add a new column.
  if (path.startsWith('/settings/habits/search') &&
      params.containsKey('searchTerm')) {
    return [
      SettingsColumn(
        key: ValueKey('/settings/habits/search/${params['searchTerm']}'),
        child: HabitsPage(initialSearchTerm: params['searchTerm']),
      ),
    ];
  }
  final columns = <SettingsColumn>[
    const SettingsColumn(
      key: ValueKey('/settings/habits'),
      child: HabitsPage(),
    ),
  ];
  if (path.startsWith('/settings/habits/create')) {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/habits/create'),
        child: CreateHabitPage(),
      ),
    );
  } else if (path.startsWith('/settings/habits/by_id') &&
      params.containsKey('habitId')) {
    final habitId = params['habitId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/habits/by_id/$habitId'),
        child: EditHabitPage(habitId: habitId),
      ),
    );
  }
  return columns;
}

List<SettingsColumn>? _resolveAgents(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/agents')) return null;
  final columns = <SettingsColumn>[
    const SettingsColumn(
      key: ValueKey('/settings/agents'),
      child: AgentSettingsPage(),
    ),
  ];
  if (path.startsWith('/settings/agents/templates/create')) {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/agents/templates/create'),
        child: AgentTemplateDetailPage(),
      ),
    );
  } else if (path.startsWith('/settings/agents/templates') &&
      params.containsKey('templateId')) {
    final templateId = params['templateId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/agents/templates/$templateId'),
        child: AgentTemplateDetailPage(templateId: templateId),
      ),
    );
    if (path.endsWith('/review')) {
      columns.add(
        SettingsColumn(
          key: ValueKey('/settings/agents/templates/$templateId/review'),
          child: EvolutionReviewPage(templateId: templateId),
        ),
      );
    }
  } else if (path.startsWith('/settings/agents/souls/create')) {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/agents/souls/create'),
        child: AgentSoulDetailPage(),
      ),
    );
  } else if (path.startsWith('/settings/agents/souls') &&
      params.containsKey('soulId')) {
    final soulId = params['soulId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/agents/souls/$soulId'),
        child: AgentSoulDetailPage(soulId: soulId),
      ),
    );
    if (path.endsWith('/review')) {
      columns.add(
        SettingsColumn(
          key: ValueKey('/settings/agents/souls/$soulId/review'),
          child: SoulEvolutionReviewPage(soulId: soulId),
        ),
      );
    }
  } else if (path.startsWith('/settings/agents/instances') &&
      params.containsKey('agentId')) {
    final agentId = params['agentId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/agents/instances/$agentId'),
        child: AgentDetailPage(agentId: agentId),
      ),
    );
  }
  return columns;
}

List<SettingsColumn>? _resolveFlags(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/flags')) return null;
  return const [
    SettingsColumn(
      key: ValueKey('/settings/flags'),
      child: FlagsPage(),
    ),
  ];
}

List<SettingsColumn>? _resolveTheming(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/theming')) return null;
  return const [
    SettingsColumn(
      key: ValueKey('/settings/theming'),
      child: ThemingPage(),
    ),
  ];
}

List<SettingsColumn>? _resolveHealthImport(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/health_import')) return null;
  return const [
    SettingsColumn(
      key: ValueKey('/settings/health_import'),
      child: HealthImportPage(),
    ),
  ];
}

/// Advanced has its own sub-menu and multiple leaves, including the
/// conflicts subtree (list → detail → edit-entry).
List<SettingsColumn>? _resolveAdvanced(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/advanced')) return null;
  final columns = <SettingsColumn>[
    const SettingsColumn(
      key: ValueKey('/settings/advanced'),
      child: AdvancedSettingsPage(),
    ),
  ];
  if (path.startsWith('/settings/advanced/logging_domains')) {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/advanced/logging_domains'),
        child: LoggingSettingsPage(),
      ),
    );
  } else if (path.startsWith('/settings/advanced/about')) {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/advanced/about'),
        child: AboutPage(),
      ),
    );
  } else if (path.startsWith('/settings/advanced/maintenance')) {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/advanced/maintenance'),
        child: MaintenancePage(),
      ),
    );
  } else if (path.startsWith('/settings/advanced/conflicts')) {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/advanced/conflicts'),
        child: ConflictsPage(),
      ),
    );
    if (path.startsWith('/settings/advanced/conflicts/') &&
        params.containsKey('conflictId')) {
      final conflictId = params['conflictId']!;
      columns.add(
        SettingsColumn(
          key: ValueKey('/settings/advanced/conflicts/$conflictId'),
          child: ConflictDetailRoute(conflictId: conflictId),
        ),
      );
      if (path.endsWith('/edit')) {
        columns.add(
          SettingsColumn(
            key: ValueKey(
              '/settings/advanced/conflicts/$conflictId/edit',
            ),
            child: EntryDetailsPage(itemId: conflictId),
          ),
        );
      }
    }
  }
  return columns;
}
