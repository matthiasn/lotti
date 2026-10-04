import 'package:flutter/widgets.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_review_page.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_review_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_page.dart';
import 'package:lotti/features/ai_consumption/ui/impact_analysis_body.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_settings_page.dart';
import 'package:lotti/features/dashboards/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/dashboards/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/dashboards/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/dashboards/ui/settings/create_dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/settings/dashboard_definition_page.dart';
import 'package:lotti/features/dashboards/ui/settings/dashboard_settings_page.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/ui/github_settings_page.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_page.dart';
import 'package:lotti/features/habits/ui/pages/habit_settings_page.dart';
import 'package:lotti/features/keyboard/ui/keyboard_shortcuts_page.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/notifications/ui/notification_settings_page.dart';
import 'package:lotti/features/onboarding/ui/onboarding_metrics_page.dart';
import 'package:lotti/features/onboarding/ui/onboarding_settings_panel.dart';
import 'package:lotti/features/onboarding/ui/recording_style_settings_page.dart';
import 'package:lotti/features/projects/ui/pages/project_detail_page.dart';
import 'package:lotti/features/settings/routing/settings_route.dart';
import 'package:lotti/features/settings/ui/mobile/settings_mobile_branch_page.dart';
import 'package:lotti/features/settings/ui/mobile/settings_mobile_root_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/manual_language_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/categories/category_details_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/settings/ui/pages/sections_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/pages/sync_node_profile_page.dart';
import 'package:lotti/features/sync/ui/provisioned_sync_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/features/system_health/ui/pages/logging_settings_page.dart';
import 'package:lotti/features/system_health/ui/system_health_page.dart';
import 'package:lotti/features/theming/ui/theming_page.dart';
import 'package:lotti/features/tts/ui/speech_settings_body.dart';
import 'package:lotti/features/tts/ui/speech_settings_page.dart';

/// Every settings destination, keyed by its node id in `buildSettingsTree`.
///
/// This is the one place a settings page is wired up. The mobile page stack
/// (`SettingsLocation`), the desktop detail pane, the tree's URLs in both
/// directions, the deep-link patterns and the bottom-nav rule are all read
/// from it; a test pins that every navigable tree node has an entry.
///
/// URLs are written out in full as string literals, sub-routes included —
/// even the two that also exist as constants (`settingsRootUrl`,
/// `aiSettingsParentRoute`, pinned equal by a test). They are the deep links
/// the app has shipped, and `docs-site/scripts/validate-manual.mjs` reads
/// them out of this file to check the manual's route inventory. A node keeps its URL when it moves between branches, which
/// is why several do not nest under their parent's — the Definitions and
/// Preferences leaves kept the flat URLs they had at the root, Conflicts and
/// Animations kept theirs under `/settings/advanced/`.
final SettingsRouteTable settingsRoutes = SettingsRouteTable(
  root: SettingsRoute(
    url: '/settings',
    page: (_, _) => const SettingsMobileRootPage(),
    keepsBottomNav: true,
    subRoutes: [
      // Opened from a category's projects. Creation runs in a modal, so
      // there is no create route; the reserved `create` segment therefore
      // falls back to the root instead of opening a project called "create".
      SettingsSubRoute(
        '/settings/projects/:projectId',
        build: (_, m) => ProjectDetailPage(
          projectId: m.pathParameters['projectId']!,
          categoryId: m.queryParameters['categoryId'],
          returnPath: m.queryParameters['returnTo'],
        ),
      ),
    ],
  ),
  // `/settings/maintenance` was once advertised as a route without a page
  // behind it; bookmarks of it land on Maintenance.
  aliases: const {'/settings/maintenance': '/settings/advanced/maintenance'},
  routes: {
    'onboarding': SettingsRoute(
      url: '/settings/onboarding',
      page: (_, _) => const OnboardingSettingsPage(),
      panel: (_, _) => const OnboardingSettingsBody(),
      scrollable: true,
    ),
    // The one leaf that keeps the bottom nav: its switches add and remove the
    // bar's own tabs, so the bar is where the user sees each toggle land.
    'sections': SettingsRoute(
      url: '/settings/sections',
      page: (_, _) => const SectionsPage(),
      panel: (_, _) => const SectionsBody(),
      scrollable: true,
      keepsBottomNav: true,
    ),

    // AI keeps its own page on mobile, whose tabs are the tree's AI children;
    // so the children add no page there. On desktop each child is a panel of
    // its own showing one tab. Every AI detail returns to the AI list.
    'ai': SettingsRoute(
      url: '/settings/ai',
      page: (_, _) => const AiSettingsPage(),
      panel: (_, _) => const AiSettingsBody(hideTabBar: true, hideHeader: true),
      subRoutes: [
        SettingsSubRoute(
          '/settings/ai/provider/:providerId',
          build: (_, m) => AiProviderDetailPage(
            providerId: m.pathParameters['providerId']!,
            focusApiKey: m.queryParameters['focusApiKey'] == 'true',
          ),
        ),
        SettingsSubRoute(
          '/settings/ai/model/:modelId',
          build: (_, m) =>
              InferenceModelEditPage(configId: m.pathParameters['modelId']),
        ),
        SettingsSubRoute(
          '/settings/ai/profile/:profileId',
          build: (_, m) => InferenceProfileDetailPage(
            profileId: m.pathParameters['profileId']!,
          ),
        ),
      ],
    ),
    'ai/providers': SettingsRoute(
      url: '/settings/ai/providers',
      panel: (_, _) => const AiSettingsBody(
        initialTab: AiSettingsTab.providers,
        hideTabBar: true,
        hideHeader: true,
      ),
    ),
    'ai/models': SettingsRoute(
      url: '/settings/ai/models',
      panel: (_, _) => const AiSettingsBody(
        initialTab: AiSettingsTab.models,
        hideTabBar: true,
        hideHeader: true,
      ),
    ),
    // The one AI child with a mobile page: the seeded-profile list, which
    // shipped on this URL before the tree existed.
    'ai/profiles': SettingsRoute(
      url: '/settings/ai/profiles',
      page: (_, _) => const InferenceProfilePage(),
      panel: (_, _) => const AiSettingsBody(
        initialTab: AiSettingsTab.profiles,
        hideTabBar: true,
        hideHeader: true,
      ),
    ),
    'ai/usage': SettingsRoute(
      url: '/settings/ai/usage',
      panel: (_, _) => const ImpactAnalysisBody(showTitle: false),
      scrollable: true,
    ),

    // Agents, like AI: one page on mobile whose tabs are the children, one
    // panel per tab on desktop. The tabs' editors and one-on-one reviews hang
    // below the tab URL.
    'agents': SettingsRoute(
      url: '/settings/agents',
      page: (_, _) => const AgentSettingsPage(),
      panel: (_, _) => const AgentSettingsBody(),
    ),
    'agents/templates': SettingsRoute(
      url: '/settings/agents/templates',
      panel: (_, _) =>
          const AgentSettingsBody(initialTab: AgentSettingsTab.templates),
      subRoutes: [
        SettingsSubRoute(
          '/settings/agents/templates/create',
          build: (_, _) => const AgentTemplateDetailPage(),
        ),
        SettingsSubRoute(
          '/settings/agents/templates/:templateId',
          build: (_, m) => AgentTemplateDetailPage(
            templateId: m.pathParameters['templateId'],
          ),
        ),
        SettingsSubRoute(
          '/settings/agents/templates/:templateId/review',
          build: (_, m) => EvolutionReviewPage(
            templateId: m.pathParameters['templateId']!,
          ),
        ),
      ],
    ),
    'agents/instances': SettingsRoute(
      url: '/settings/agents/instances',
      panel: (_, _) =>
          const AgentSettingsBody(initialTab: AgentSettingsTab.instances),
      // Instances are created from a template, so there is no create route.
      subRoutes: [
        SettingsSubRoute(
          '/settings/agents/instances/:agentId',
          build: (_, m) =>
              AgentDetailPage(agentId: m.pathParameters['agentId']!),
        ),
      ],
    ),
    'agents/souls': SettingsRoute(
      url: '/settings/agents/souls',
      panel: (_, _) =>
          const AgentSettingsBody(initialTab: AgentSettingsTab.souls),
      subRoutes: [
        SettingsSubRoute(
          '/settings/agents/souls/create',
          build: (_, _) => const AgentSoulDetailPage(),
        ),
        SettingsSubRoute(
          '/settings/agents/souls/:soulId',
          build: (_, m) =>
              AgentSoulDetailPage(soulId: m.pathParameters['soulId']),
        ),
        SettingsSubRoute(
          '/settings/agents/souls/:soulId/review',
          build: (_, m) =>
              SoulEvolutionReviewPage(soulId: m.pathParameters['soulId']!),
        ),
      ],
    ),
    'agents/pending-wakes': SettingsRoute(
      url: '/settings/agents/pending-wakes',
      panel: (_, _) =>
          const AgentSettingsBody(initialTab: AgentSettingsTab.pendingWakes),
    ),

    'daily-os': SettingsRoute(
      url: '/settings/daily-os',
      page: (_, _) => const DailyOsSettingsPage(),
      panel: (_, _) => const DailyOsSettingsBody(),
      scrollable: true,
    ),

    // Demo worlds show this explainer tile in place of Sync. It goes nowhere:
    // the world has no Matrix stack to configure.
    'sync-unavailable': const SettingsRoute(),

    // Sync. The hub and the pages without a gate of their own are wrapped in
    // `SyncFeatureGate`, which sends a stale deep link back to Settings when
    // sync is off or absent.
    'sync': SettingsRoute(
      url: '/settings/sync',
      page: (_, _) => const SyncFeatureGate(
        child: SettingsMobileBranchPage(branchId: 'sync'),
      ),
      keepsBottomNav: true,
    ),
    'sync/provisioned': SettingsRoute(
      url: '/settings/sync/provisioned',
      page: (_, _) => const ProvisionedSyncPage(),
      panel: (_, _) => const ProvisionedSyncBody(),
      scrollable: true,
    ),
    'sync/node-profile': SettingsRoute(
      url: '/settings/sync/node-profile',
      page: (_, _) => const SyncFeatureGate(child: SyncNodeProfilePage()),
      panel: (_, _) => const SyncNodeProfileBody(),
    ),
    // Shown as "Sync health"; the id and URL keep their first name because a
    // restored route or a shipped link must keep opening it.
    'sync/backfill': SettingsRoute(
      url: '/settings/sync/backfill',
      page: (_, _) => const BackfillSettingsPage(),
      panel: (context, _) => Padding(
        // The mobile page supplies a horizontal gutter; the pane needs the
        // same breathing room the Stats card margin gives its panel.
        padding: EdgeInsets.symmetric(
          horizontal: context.designTokens.spacing.step3,
        ),
        child: const BackfillSettingsBody(),
      ),
      scrollable: true,
    ),
    'sync/stats': SettingsRoute(
      url: '/settings/sync/stats',
      page: (_, _) => const SyncStatsPage(),
      panel: (_, _) => const SyncStatsBody(),
      scrollable: true,
    ),
    'sync/outbox': SettingsRoute(
      url: '/settings/sync/outbox',
      page: (_, _) => const SyncFeatureGate(child: OutboxMonitorPage()),
      panel: (_, _) => const OutboxMonitorBody(),
    ),
    'sync/conflicts': SettingsRoute(
      url: '/settings/advanced/conflicts',
      page: (_, _) => const ConflictsPage(),
      panel: (_, _) => const ConflictsBody(),
      keepsBottomNav: true,
      subRoutes: [
        SettingsSubRoute(
          '/settings/advanced/conflicts/:conflictId',
          build: (_, m) => ConflictDetailRoute(
            conflictId: m.pathParameters['conflictId']!,
            versionKey: m.queryParameters['version'],
          ),
        ),
      ],
    ),
    'sync/matrix-maintenance': SettingsRoute(
      url: '/settings/sync/matrix/maintenance',
      page: (_, _) => const MatrixSyncMaintenancePage(),
      panel: (_, _) => const MatrixSyncMaintenanceBody(),
      scrollable: true,
    ),

    // Definitions: browse lists that keep the bottom nav, with their editors
    // below.
    'definitions': SettingsRoute(
      url: '/settings/definitions',
      page: (_, _) => const SettingsMobileBranchPage(branchId: 'definitions'),
      keepsBottomNav: true,
    ),
    'definitions/categories': SettingsRoute(
      url: '/settings/categories',
      page: (_, _) => const CategoriesListPage(),
      panel: (_, _) => const CategoriesListBody(),
      keepsBottomNav: true,
      subRoutes: [
        SettingsSubRoute(
          '/settings/categories/create',
          build: (_, _) => const CategoryDetailsPage(),
        ),
        SettingsSubRoute(
          '/settings/categories/:categoryId',
          build: (_, m) =>
              CategoryDetailsPage(categoryId: m.pathParameters['categoryId']),
        ),
      ],
    ),
    'definitions/labels': SettingsRoute(
      url: '/settings/labels',
      page: (_, _) => const LabelsListPage(),
      panel: (_, _) => const LabelsListBody(),
      keepsBottomNav: true,
      subRoutes: [
        SettingsSubRoute(
          '/settings/labels/create',
          build: (_, m) =>
              LabelDetailsPage(initialName: m.queryParameters['name']),
        ),
        SettingsSubRoute(
          '/settings/labels/:labelId',
          build: (_, m) =>
              LabelDetailsPage(labelId: m.pathParameters['labelId']),
        ),
      ],
    ),
    'definitions/habits': SettingsRoute(
      url: '/settings/habits',
      page: (_, _) => const HabitSettingsPage(),
      panel: (_, _) => const HabitSettingsBody(),
      keepsBottomNav: true,
      subRoutes: [
        SettingsSubRoute(
          '/settings/habits/create',
          build: (_, _) =>
              const HabitEditorPage(returnPath: '/settings/habits'),
        ),
        SettingsSubRoute(
          '/settings/habits/by_id/:habitId',
          build: (_, m) => HabitEditorPage(
            habitId: m.pathParameters['habitId'],
            returnPath: '/settings/habits',
          ),
        ),
        // The list with a filter applied: it stands in for the list rather
        // than stacking a second list above it.
        SettingsSubRoute(
          '/settings/habits/search/:searchTerm',
          build: (_, m) => HabitSettingsPage(
            initialSearchTerm: m.pathParameters['searchTerm'],
          ),
          panel: (_, m) => HabitSettingsBody(
            initialSearchTerm: m.pathParameters['searchTerm'],
          ),
          replacesParent: true,
          keepsBottomNav: true,
        ),
      ],
    ),
    'definitions/dashboards': SettingsRoute(
      url: '/settings/dashboards',
      page: (_, _) => const DashboardSettingsPage(),
      panel: (_, _) => const DashboardSettingsBody(),
      keepsBottomNav: true,
      subRoutes: [
        SettingsSubRoute(
          '/settings/dashboards/create',
          build: (_, _) => CreateDashboardPage(),
        ),
        SettingsSubRoute(
          '/settings/dashboards/:dashboardId',
          build: (_, m) => EditDashboardPage(
            dashboardId: m.pathParameters['dashboardId']!,
          ),
        ),
      ],
    ),
    'definitions/measurables': SettingsRoute(
      url: '/settings/measurables',
      page: (_, _) => const MeasurablesPage(),
      panel: (_, _) => const MeasurablesBody(),
      keepsBottomNav: true,
      subRoutes: [
        SettingsSubRoute(
          '/settings/measurables/create',
          build: (_, _) => CreateMeasurablePage(),
        ),
        SettingsSubRoute(
          '/settings/measurables/:measurableId',
          build: (_, m) => EditMeasurablePage(
            measurableId: m.pathParameters['measurableId']!,
          ),
        ),
      ],
    ),

    'preferences': SettingsRoute(
      url: '/settings/preferences',
      page: (_, _) => const SettingsMobileBranchPage(branchId: 'preferences'),
      keepsBottomNav: true,
    ),
    'preferences/theming': SettingsRoute(
      url: '/settings/theming',
      page: (_, _) => const ThemingPage(),
      panel: (_, _) => const ThemingBody(),
      scrollable: true,
    ),
    'preferences/animations': SettingsRoute(
      url: '/settings/advanced/animations',
      page: (_, _) => const CelebrationSettingsPage(),
      panel: (_, _) => const CelebrationSettingsBody(),
      scrollable: true,
    ),
    'preferences/notifications': SettingsRoute(
      url: '/settings/notifications',
      page: (_, _) => const NotificationSettingsPage(),
      panel: (_, _) => const NotificationSettingsBody(),
      scrollable: true,
    ),
    'preferences/recording-style': SettingsRoute(
      url: '/settings/recording-style',
      page: (_, _) => const RecordingStyleSettingsPage(),
      panel: (_, _) => const RecordingStyleSettingsBody(),
      scrollable: true,
    ),
    'preferences/speech': SettingsRoute(
      url: '/settings/speech',
      page: (_, _) => const SpeechSettingsPage(),
      panel: (_, _) => const SpeechSettingsBody(),
      scrollable: true,
    ),
    'preferences/keyboard-shortcuts': SettingsRoute(
      url: '/settings/keyboard-shortcuts',
      page: (_, _) => const KeyboardShortcutsPage(),
      panel: (_, _) => const KeyboardShortcutsBody(),
    ),

    'advanced': SettingsRoute(
      url: '/settings/advanced',
      page: (_, _) => const SettingsMobileBranchPage(branchId: 'advanced'),
      keepsBottomNav: true,
    ),
    // FlagsBody is a fixed search field above its own scrolling list, so it
    // must not be wrapped in a scroll view.
    'advanced/flags': SettingsRoute(
      url: '/settings/flags',
      page: (_, _) => const FlagsPage(),
      panel: (_, _) => const FlagsBody(),
    ),
    'advanced/github': SettingsRoute(
      url: '/settings/advanced/github',
      page: (_, _) => const GitHubSettingsPage(),
      panel: (_, _) => const GitHubSettingsBody(),
      scrollable: true,
    ),
    'advanced/manual-language': SettingsRoute(
      url: '/settings/advanced/manual-language',
      page: (_, _) => const ManualLanguageSettingsPage(),
      panel: (_, _) => const ManualLanguageSettingsBody(),
      scrollable: true,
    ),
    'advanced/logging': SettingsRoute(
      url: '/settings/advanced/logging_domains',
      page: (_, _) => const LoggingSettingsPage(),
      panel: (_, _) => const LoggingSettingsBody(),
      scrollable: true,
    ),
    'advanced/system-health': SettingsRoute(
      url: '/settings/advanced/system_health',
      page: (_, _) => const SystemHealthPage(),
      panel: (_, _) => const SystemHealthBody(),
      scrollable: true,
    ),
    // HealthKit / Health Connect import exists on phones only, so the leaf is
    // only in the mobile tree and has no desktop panel.
    'advanced/health-import': SettingsRoute(
      url: '/settings/health_import',
      page: (_, _) => const HealthImportPage(),
    ),
    'advanced/maintenance': SettingsRoute(
      url: '/settings/advanced/maintenance',
      page: (_, _) => const MaintenancePage(),
      panel: (_, _) => const MaintenanceBody(),
      scrollable: true,
    ),
    'advanced/onboarding-metrics': SettingsRoute(
      url: '/settings/advanced/onboarding_metrics',
      page: (_, _) => const OnboardingMetricsPage(),
      panel: (_, _) => const OnboardingMetricsBody(),
      scrollable: true,
    ),
    'advanced/about': SettingsRoute(
      url: '/settings/advanced/about',
      page: (_, _) => const AboutPage(),
      panel: (_, _) => const AboutBody(),
      scrollable: true,
    ),
  },
);

/// The canonical URL for a tree path. See [SettingsRouteTable.urlForPath].
String pathToBeamUrl(List<String> path) => settingsRoutes.urlForPath(path);

/// The tree path a settings URL belongs to. See
/// [SettingsRouteTable.pathForUrl].
List<String> beamUrlToPath(String url) => settingsRoutes.pathForUrl(url);
