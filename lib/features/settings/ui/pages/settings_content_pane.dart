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
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/sync_settings_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/services/nav_service.dart';

/// Maps a [DesktopSettingsRoute] to the corresponding content page widget
/// for the desktop settings split-pane detail area.
///
// TODO(settings): This routing table mirrors SettingsLocation.buildPages —
// keep them in sync when adding new settings sub-pages.
class SettingsContentPane extends StatelessWidget {
  const SettingsContentPane({required this.route, super.key});

  final DesktopSettingsRoute route;

  /// Returns the widget for the given route. Exposed for unit testing the
  /// routing logic without mounting the child widget into a live tree.
  @visibleForTesting
  static Widget resolveRoute(DesktopSettingsRoute route) {
    return _resolveRoute(route);
  }

  @override
  Widget build(BuildContext context) {
    return _resolveRoute(route);
  }

  static Widget _resolveRoute(DesktopSettingsRoute route) {
    final path = route.path;
    final params = route.pathParameters;
    final query = route.queryParameters;

    // Advanced sub-pages (check deeper paths first)
    if (path.startsWith('/settings/advanced/logging_domains')) {
      return const LoggingSettingsPage();
    }
    if (path.startsWith('/settings/advanced/about')) {
      return const AboutPage();
    }
    if (path.startsWith('/settings/advanced/maintenance')) {
      return const MaintenancePage();
    }
    if (path.startsWith('/settings/advanced/conflicts/') &&
        params.containsKey('conflictId')) {
      if (path.endsWith('/edit')) {
        return EntryDetailsPage(itemId: params['conflictId']!);
      }
      return ConflictDetailRoute(conflictId: params['conflictId']!);
    }
    if (path.startsWith('/settings/advanced/conflicts')) {
      return const ConflictsPage();
    }
    if (path.startsWith('/settings/advanced')) {
      return const AdvancedSettingsPage();
    }

    // AI
    if (path == '/settings/ai/profiles') {
      return const InferenceProfilePage();
    }
    if (path.startsWith('/settings/ai')) {
      return const AiSettingsPage();
    }

    // Sync sub-pages
    if (path == '/settings/sync/matrix/maintenance') {
      return const MatrixSyncMaintenancePage();
    }
    if (path == '/settings/sync/backfill') {
      return const BackfillSettingsPage();
    }
    if (path == '/settings/sync/stats') {
      return const SyncStatsPage();
    }
    if (path == '/settings/sync/outbox') {
      return const OutboxMonitorPage();
    }
    if (path.startsWith('/settings/sync')) {
      return const SyncSettingsPage();
    }

    // Labels
    if (path.startsWith('/settings/labels/create')) {
      return LabelDetailsPage(initialName: query['name']);
    }
    if (path.startsWith('/settings/labels') && params.containsKey('labelId')) {
      return LabelDetailsPage(labelId: params['labelId']);
    }
    if (path.startsWith('/settings/labels')) {
      return const LabelsListPage();
    }

    // Categories
    if (path.startsWith('/settings/categories/create')) {
      return const new_category_details.CategoryDetailsPage();
    }
    if (path.startsWith('/settings/categories') &&
        params.containsKey('categoryId') &&
        params['categoryId'] != 'create') {
      return new_category_details.CategoryDetailsPage(
        categoryId: params['categoryId'],
      );
    }
    if (path.startsWith('/settings/categories')) {
      return const new_categories.CategoriesListPage();
    }

    // Projects
    if (path.startsWith('/settings/projects/create')) {
      return ProjectCreatePage(categoryId: query['categoryId']);
    }
    if (path.startsWith('/settings/projects') &&
        params.containsKey('projectId')) {
      return ProjectDetailPage(
        projectId: params['projectId']!,
        categoryId: query['categoryId'],
      );
    }

    // Dashboards
    if (path.startsWith('/settings/dashboards/create')) {
      return CreateDashboardPage();
    }
    if (path.startsWith('/settings/dashboards') &&
        params.containsKey('dashboardId')) {
      return EditDashboardPage(dashboardId: params['dashboardId']!);
    }
    if (path.startsWith('/settings/dashboards')) {
      return const DashboardSettingsPage();
    }

    // Measurables
    if (path.startsWith('/settings/measurables/create')) {
      return CreateMeasurablePage();
    }
    if (path.startsWith('/settings/measurables') &&
        params.containsKey('measurableId')) {
      return EditMeasurablePage(measurableId: params['measurableId']!);
    }
    if (path.startsWith('/settings/measurables')) {
      return const MeasurablesPage();
    }

    // Habits
    if (path.startsWith('/settings/habits/create')) {
      return CreateHabitPage();
    }
    if (path.startsWith('/settings/habits/by_id') &&
        params.containsKey('habitId')) {
      return EditHabitPage(habitId: params['habitId']!);
    }
    if (path.startsWith('/settings/habits/search') &&
        params.containsKey('searchTerm')) {
      return HabitsPage(initialSearchTerm: params['searchTerm']);
    }
    if (path.startsWith('/settings/habits')) {
      return const HabitsPage();
    }

    // Agents
    if (path.startsWith('/settings/agents/templates/create')) {
      return const AgentTemplateDetailPage();
    }
    if (path.startsWith('/settings/agents/templates') &&
        params.containsKey('templateId') &&
        path.endsWith('/review')) {
      return EvolutionReviewPage(templateId: params['templateId']!);
    }
    if (path.startsWith('/settings/agents/templates') &&
        params.containsKey('templateId')) {
      return AgentTemplateDetailPage(templateId: params['templateId']);
    }
    if (path.startsWith('/settings/agents/souls/create')) {
      return const AgentSoulDetailPage();
    }
    if (path.startsWith('/settings/agents/souls') &&
        params.containsKey('soulId') &&
        path.endsWith('/review')) {
      return SoulEvolutionReviewPage(soulId: params['soulId']!);
    }
    if (path.startsWith('/settings/agents/souls') &&
        params.containsKey('soulId')) {
      return AgentSoulDetailPage(soulId: params['soulId']);
    }
    if (path.startsWith('/settings/agents/instances') &&
        params.containsKey('agentId')) {
      return AgentDetailPage(agentId: params['agentId']!);
    }
    if (path.startsWith('/settings/agents')) {
      return const AgentSettingsPage();
    }

    // Flags
    if (path.startsWith('/settings/flags')) {
      return const FlagsPage();
    }

    // Theming
    if (path.startsWith('/settings/theming')) {
      return const ThemingPage();
    }

    // Health Import
    if (path.startsWith('/settings/health_import')) {
      return const HealthImportPage();
    }

    // Fallback
    return const SizedBox.shrink();
  }
}
