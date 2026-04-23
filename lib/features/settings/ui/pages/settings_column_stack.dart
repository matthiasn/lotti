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

/// Identifier for the crumb label a [SettingsColumn] contributes to
/// the top-bar breadcrumb trail. Stored as an enum so the resolver
/// stays independent of [BuildContext] — localisations are only
/// bound when the trail is rendered, by
/// `resolveSettingsBreadcrumbTrail`.
enum SettingsCrumbLabel {
  root,
  ai,
  aiProfiles,
  sync,
  syncMatrixMaintenance,
  syncBackfill,
  syncStats,
  syncOutbox,
  labels,
  labelsCreate,
  labelsEdit,
  categories,
  categoriesCreate,
  categoriesEdit,
  projectsCreate,
  projectsEdit,
  dashboards,
  dashboardsCreate,
  dashboardsEdit,
  measurables,
  measurablesCreate,
  measurablesEdit,
  habits,
  habitsCreate,
  habitsEdit,
  agents,
  agentsTemplateCreate,
  agentsTemplateEdit,
  agentsTemplateReview,
  agentsSoulCreate,
  agentsSoulEdit,
  agentsSoulReview,
  agentsInstance,
  flags,
  theming,
  healthImport,
  advanced,
  advancedLoggingDomains,
  advancedAbout,
  advancedMaintenance,
  advancedConflicts,
  advancedConflictsResolution,
  advancedConflictsEdit,
}

/// Breadcrumb metadata attached to a [SettingsColumn].
///
/// The column stack and the top-bar breadcrumb trail are two views of
/// the same navigation state; declaring the crumb directly on the
/// column keeps them in lockstep and forces a decision about the
/// trail whenever a new column is introduced.
@immutable
class SettingsColumnCrumb {
  const SettingsColumnCrumb({required this.label, required this.path});

  /// Identifier resolved to a localised string at render time.
  final SettingsCrumbLabel label;

  /// Beamable path the breadcrumb chip navigates to when tapped. The
  /// leaf crumb's path is never used for navigation (the leaf is
  /// rendered as selected and non-interactive); storing it keeps the
  /// trail uniformly addressable and makes testing straightforward.
  final String path;
}

/// A single navigation column in the multi-pane settings layout.
///
/// Each column corresponds to one meaningful level of the settings
/// navigation hierarchy — the top-level menu, a category's sub-menu, a
/// detail page, etc. The [key] is stable per path so Flutter preserves
/// widget state as the stack grows or shrinks. The [crumb] declares
/// how the column appears in the top-bar breadcrumb trail.
///
/// [childBuilder] is a lazy factory — the child widget is only
/// instantiated when the column is rendered. The breadcrumb resolver
/// derives its trail from the same column list, and some detail
/// pages read services from GetIt in their constructor; eagerly
/// building them from a non-rendering context (e.g. to compute a
/// breadcrumb) would trip those lookups.
@immutable
class SettingsColumn {
  const SettingsColumn({
    required this.key,
    required this.childBuilder,
    required this.crumb,
  });

  final Key key;
  final Widget Function() childBuilder;
  final SettingsColumnCrumb crumb;
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

SettingsColumn _rootColumn() => SettingsColumn(
  key: const ValueKey('/settings'),
  childBuilder: () => const SettingsPage(),
  crumb: const SettingsColumnCrumb(
    label: SettingsCrumbLabel.root,
    path: '/settings',
  ),
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
    return <SettingsColumn>[_rootColumn()];
  }
  final path = route.path;
  final params = route.pathParameters;
  final query = route.queryParameters;

  for (final resolve in _subtreeResolvers) {
    final extension = resolve(path, params, query);
    if (extension != null) {
      if (extension.isEmpty) return <SettingsColumn>[_rootColumn()];
      return <SettingsColumn>[_rootColumn(), ...extension];
    }
  }

  return <SettingsColumn>[_rootColumn()];
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
    SettingsColumn(
      key: const ValueKey('/settings/ai'),
      childBuilder: () => const AiSettingsPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.ai,
        path: '/settings/ai',
      ),
    ),
  ];
  if (path == '/settings/ai/profiles') {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/ai/profiles'),
        childBuilder: () => const InferenceProfilePage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.aiProfiles,
          path: '/settings/ai/profiles',
        ),
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
    SettingsColumn(
      key: const ValueKey('/settings/sync'),
      childBuilder: () => const SyncSettingsPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.sync,
        path: '/settings/sync',
      ),
    ),
  ];
  if (path == '/settings/sync/matrix/maintenance') {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/sync/matrix/maintenance'),
        childBuilder: () => const MatrixSyncMaintenancePage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.syncMatrixMaintenance,
          path: '/settings/sync/matrix/maintenance',
        ),
      ),
    );
  } else if (path == '/settings/sync/backfill') {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/sync/backfill'),
        childBuilder: () => const BackfillSettingsPage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.syncBackfill,
          path: '/settings/sync/backfill',
        ),
      ),
    );
  } else if (path == '/settings/sync/stats') {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/sync/stats'),
        childBuilder: () => const SyncStatsPage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.syncStats,
          path: '/settings/sync/stats',
        ),
      ),
    );
  } else if (path == '/settings/sync/outbox') {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/sync/outbox'),
        childBuilder: () => const OutboxMonitorPage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.syncOutbox,
          path: '/settings/sync/outbox',
        ),
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
    SettingsColumn(
      key: const ValueKey('/settings/labels'),
      childBuilder: () => const LabelsListPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.labels,
        path: '/settings/labels',
      ),
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
        childBuilder: () => LabelDetailsPage(initialName: initialName),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.labelsCreate,
          path: '/settings/labels/create',
        ),
      ),
    );
  } else if (params.containsKey('labelId')) {
    final labelId = params['labelId'];
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/labels/$labelId'),
        childBuilder: () => LabelDetailsPage(labelId: labelId),
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.labelsEdit,
          path: '/settings/labels/$labelId',
        ),
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
    SettingsColumn(
      key: const ValueKey('/settings/categories'),
      childBuilder: () => const new_categories.CategoriesListPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.categories,
        path: '/settings/categories',
      ),
    ),
  ];
  if (path.startsWith('/settings/categories/create')) {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/categories/create'),
        childBuilder: () => const new_category_details.CategoryDetailsPage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.categoriesCreate,
          path: '/settings/categories/create',
        ),
      ),
    );
  } else if (params.containsKey('categoryId') &&
      params['categoryId'] != 'create') {
    final categoryId = params['categoryId'];
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/categories/$categoryId'),
        childBuilder: () => new_category_details.CategoryDetailsPage(
          categoryId: categoryId,
        ),
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.categoriesEdit,
          path: '/settings/categories/$categoryId',
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
        childBuilder: () => ProjectCreatePage(categoryId: categoryId),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.projectsCreate,
          path: '/settings/projects/create',
        ),
      ),
    ];
  }
  if (params.containsKey('projectId')) {
    final projectId = params['projectId']!;
    return [
      SettingsColumn(
        key: ValueKey('/settings/projects/$projectId'),
        childBuilder: () => ProjectDetailPage(
          projectId: projectId,
          categoryId: query['categoryId'],
        ),
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.projectsEdit,
          path: '/settings/projects/$projectId',
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
    SettingsColumn(
      key: const ValueKey('/settings/dashboards'),
      childBuilder: () => const DashboardSettingsPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.dashboards,
        path: '/settings/dashboards',
      ),
    ),
  ];
  if (path.startsWith('/settings/dashboards/create')) {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/dashboards/create'),
        childBuilder: CreateDashboardPage.new,
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.dashboardsCreate,
          path: '/settings/dashboards/create',
        ),
      ),
    );
  } else if (params.containsKey('dashboardId')) {
    final dashboardId = params['dashboardId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/dashboards/$dashboardId'),
        childBuilder: () => EditDashboardPage(dashboardId: dashboardId),
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.dashboardsEdit,
          path: '/settings/dashboards/$dashboardId',
        ),
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
    SettingsColumn(
      key: const ValueKey('/settings/measurables'),
      childBuilder: () => const MeasurablesPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.measurables,
        path: '/settings/measurables',
      ),
    ),
  ];
  if (path.startsWith('/settings/measurables/create')) {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/measurables/create'),
        childBuilder: CreateMeasurablePage.new,
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.measurablesCreate,
          path: '/settings/measurables/create',
        ),
      ),
    );
  } else if (params.containsKey('measurableId')) {
    final measurableId = params['measurableId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/measurables/$measurableId'),
        childBuilder: () => EditMeasurablePage(measurableId: measurableId),
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.measurablesEdit,
          path: '/settings/measurables/$measurableId',
        ),
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
  // variant; it doesn't add a new column. The crumb still reads as
  // the plain Habits entry, and links back to the clean list.
  if (path.startsWith('/settings/habits/search') &&
      params.containsKey('searchTerm')) {
    return [
      SettingsColumn(
        key: ValueKey('/settings/habits/search/${params['searchTerm']}'),
        childBuilder: () => HabitsPage(initialSearchTerm: params['searchTerm']),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.habits,
          path: '/settings/habits',
        ),
      ),
    ];
  }
  final columns = <SettingsColumn>[
    SettingsColumn(
      key: const ValueKey('/settings/habits'),
      childBuilder: () => const HabitsPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.habits,
        path: '/settings/habits',
      ),
    ),
  ];
  if (path.startsWith('/settings/habits/create')) {
    columns.add(
      const SettingsColumn(
        key: ValueKey('/settings/habits/create'),
        childBuilder: CreateHabitPage.new,
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.habitsCreate,
          path: '/settings/habits/create',
        ),
      ),
    );
  } else if (path.startsWith('/settings/habits/by_id') &&
      params.containsKey('habitId')) {
    final habitId = params['habitId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/habits/by_id/$habitId'),
        childBuilder: () => EditHabitPage(habitId: habitId),
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.habitsEdit,
          path: '/settings/habits/by_id/$habitId',
        ),
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
    SettingsColumn(
      key: const ValueKey('/settings/agents'),
      childBuilder: () => const AgentSettingsPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.agents,
        path: '/settings/agents',
      ),
    ),
  ];
  if (path.startsWith('/settings/agents/templates/create')) {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/agents/templates/create'),
        childBuilder: () => const AgentTemplateDetailPage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.agentsTemplateCreate,
          path: '/settings/agents/templates/create',
        ),
      ),
    );
  } else if (path.startsWith('/settings/agents/templates') &&
      params.containsKey('templateId')) {
    final templateId = params['templateId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/agents/templates/$templateId'),
        childBuilder: () => AgentTemplateDetailPage(templateId: templateId),
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.agentsTemplateEdit,
          path: '/settings/agents/templates/$templateId',
        ),
      ),
    );
    if (path.endsWith('/review')) {
      columns.add(
        SettingsColumn(
          key: ValueKey('/settings/agents/templates/$templateId/review'),
          childBuilder: () => EvolutionReviewPage(templateId: templateId),
          crumb: SettingsColumnCrumb(
            label: SettingsCrumbLabel.agentsTemplateReview,
            path: '/settings/agents/templates/$templateId/review',
          ),
        ),
      );
    }
  } else if (path.startsWith('/settings/agents/souls/create')) {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/agents/souls/create'),
        childBuilder: () => const AgentSoulDetailPage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.agentsSoulCreate,
          path: '/settings/agents/souls/create',
        ),
      ),
    );
  } else if (path.startsWith('/settings/agents/souls') &&
      params.containsKey('soulId')) {
    final soulId = params['soulId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/agents/souls/$soulId'),
        childBuilder: () => AgentSoulDetailPage(soulId: soulId),
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.agentsSoulEdit,
          path: '/settings/agents/souls/$soulId',
        ),
      ),
    );
    if (path.endsWith('/review')) {
      columns.add(
        SettingsColumn(
          key: ValueKey('/settings/agents/souls/$soulId/review'),
          childBuilder: () => SoulEvolutionReviewPage(soulId: soulId),
          crumb: SettingsColumnCrumb(
            label: SettingsCrumbLabel.agentsSoulReview,
            path: '/settings/agents/souls/$soulId/review',
          ),
        ),
      );
    }
  } else if (path.startsWith('/settings/agents/instances') &&
      params.containsKey('agentId')) {
    final agentId = params['agentId']!;
    columns.add(
      SettingsColumn(
        key: ValueKey('/settings/agents/instances/$agentId'),
        childBuilder: () => AgentDetailPage(agentId: agentId),
        crumb: SettingsColumnCrumb(
          label: SettingsCrumbLabel.agentsInstance,
          path: '/settings/agents/instances/$agentId',
        ),
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
  return [
    SettingsColumn(
      key: const ValueKey('/settings/flags'),
      childBuilder: () => const FlagsPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.flags,
        path: '/settings/flags',
      ),
    ),
  ];
}

List<SettingsColumn>? _resolveTheming(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/theming')) return null;
  return [
    SettingsColumn(
      key: const ValueKey('/settings/theming'),
      childBuilder: () => const ThemingPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.theming,
        path: '/settings/theming',
      ),
    ),
  ];
}

List<SettingsColumn>? _resolveHealthImport(
  String path,
  Map<String, String> params,
  Map<String, String> query,
) {
  if (!path.startsWith('/settings/health_import')) return null;
  return [
    SettingsColumn(
      key: const ValueKey('/settings/health_import'),
      childBuilder: () => const HealthImportPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.healthImport,
        path: '/settings/health_import',
      ),
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
    SettingsColumn(
      key: const ValueKey('/settings/advanced'),
      childBuilder: () => const AdvancedSettingsPage(),
      crumb: const SettingsColumnCrumb(
        label: SettingsCrumbLabel.advanced,
        path: '/settings/advanced',
      ),
    ),
  ];
  if (path.startsWith('/settings/advanced/logging_domains')) {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/advanced/logging_domains'),
        childBuilder: () => const LoggingSettingsPage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.advancedLoggingDomains,
          path: '/settings/advanced/logging_domains',
        ),
      ),
    );
  } else if (path.startsWith('/settings/advanced/about')) {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/advanced/about'),
        childBuilder: () => const AboutPage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.advancedAbout,
          path: '/settings/advanced/about',
        ),
      ),
    );
  } else if (path.startsWith('/settings/advanced/maintenance')) {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/advanced/maintenance'),
        childBuilder: () => const MaintenancePage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.advancedMaintenance,
          path: '/settings/advanced/maintenance',
        ),
      ),
    );
  } else if (path.startsWith('/settings/advanced/conflicts')) {
    columns.add(
      SettingsColumn(
        key: const ValueKey('/settings/advanced/conflicts'),
        childBuilder: () => const ConflictsPage(),
        crumb: const SettingsColumnCrumb(
          label: SettingsCrumbLabel.advancedConflicts,
          path: '/settings/advanced/conflicts',
        ),
      ),
    );
    if (path.startsWith('/settings/advanced/conflicts/') &&
        params.containsKey('conflictId')) {
      final conflictId = params['conflictId']!;
      columns.add(
        SettingsColumn(
          key: ValueKey('/settings/advanced/conflicts/$conflictId'),
          childBuilder: () => ConflictDetailRoute(conflictId: conflictId),
          crumb: SettingsColumnCrumb(
            label: SettingsCrumbLabel.advancedConflictsResolution,
            path: '/settings/advanced/conflicts/$conflictId',
          ),
        ),
      );
      if (path.endsWith('/edit')) {
        columns.add(
          SettingsColumn(
            key: ValueKey(
              '/settings/advanced/conflicts/$conflictId/edit',
            ),
            childBuilder: () => EntryDetailsPage(itemId: conflictId),
            crumb: SettingsColumnCrumb(
              label: SettingsCrumbLabel.advancedConflictsEdit,
              path: '/settings/advanced/conflicts/$conflictId/edit',
            ),
          ),
        );
      }
    }
  }
  return columns;
}
