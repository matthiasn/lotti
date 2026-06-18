import 'package:flutter/widgets.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Builds a [SettingsTreeLabelResolver] backed by the active locale's
/// arb entries. Every node id known to `buildSettingsTree` has a
/// dedicated (title, desc) pair sourced from `AppLocalizations`; an
/// unknown id falls back to rendering the raw id so authoring
/// mistakes surface immediately instead of crashing the tree render.
SettingsTreeLabelResolver settingsTreeLabelsFor(BuildContext context) {
  final m = context.messages;

  SettingsTreeLabel resolve(String id) {
    switch (id) {
      case 'whats-new':
        return (
          title: m.settingsWhatsNewTitle,
          desc: m.settingsWhatsNewSubtitle,
        );
      case 'ai':
        return (title: m.settingsAiTitle, desc: m.settingsAiSubtitle);
      case 'ai/providers':
        return (
          title: m.settingsAiProvidersTitle,
          desc: m.settingsAiProvidersSubtitle,
        );
      case 'ai/models':
        return (
          title: m.settingsAiModelsTitle,
          desc: m.settingsAiModelsSubtitle,
        );
      case 'ai/profiles':
        return (
          title: m.settingsAiProfilesTitle,
          desc: m.settingsAiProfilesSubtitle,
        );
      case 'agents':
        return (title: m.agentSettingsTitle, desc: m.agentSettingsSubtitle);
      case 'agents/stats':
        return (
          title: m.agentStatsTabTitle,
          desc: m.settingsAgentsStatsSubtitle,
        );
      case 'agents/templates':
        return (
          title: m.agentTemplatesTitle,
          desc: m.settingsAgentsTemplatesSubtitle,
        );
      case 'agents/souls':
        return (
          title: m.agentSoulsTitle,
          desc: m.settingsAgentsSoulsSubtitle,
        );
      case 'agents/instances':
        return (
          title: m.agentInstancesTitle,
          desc: m.settingsAgentsInstancesSubtitle,
        );
      case 'agents/pending-wakes':
        return (
          title: m.agentPendingWakesTitle,
          desc: m.settingsAgentsPendingWakesSubtitle,
        );
      case 'definitions':
        return (
          title: m.settingsDefinitionsTitle,
          desc: m.settingsDefinitionsSubtitle,
        );
      case 'definitions/habits':
        return (title: m.settingsHabitsTitle, desc: m.settingsHabitsSubtitle);
      case 'definitions/categories':
        return (
          title: m.settingsCategoriesTitle,
          desc: m.settingsCategoriesSubtitle,
        );
      case 'definitions/labels':
        return (
          title: m.settingsLabelsTitle,
          desc: m.settingsLabelsSubtitle,
        );
      case 'sync':
        return (title: m.settingsMatrixTitle, desc: m.settingsSyncSubtitle);
      case 'sync/provisioned':
        return (
          title: m.provisionedSyncTitle,
          desc: m.provisionedSyncSubtitle,
        );
      case 'sync/backfill':
        return (
          title: m.backfillSettingsTitle,
          desc: m.backfillSettingsSubtitle,
        );
      case 'sync/node-profile':
        return (
          title: m.settingsSyncNodeProfileTitle,
          desc: m.settingsSyncNodeProfileSubtitle,
        );
      case 'sync/stats':
        return (
          title: m.settingsMatrixStatsTitle,
          desc: m.settingsSyncStatsSubtitle,
        );
      case 'sync/outbox':
        return (
          title: m.settingsSyncOutboxTitle,
          desc: m.settingsAdvancedOutboxSubtitle,
        );
      case 'sync/matrix-maintenance':
        return (
          title: m.settingsMatrixMaintenanceTitle,
          desc: m.settingsMatrixMaintenanceSubtitle,
        );
      case 'definitions/dashboards':
        return (
          title: m.settingsDashboardsTitle,
          desc: m.settingsDashboardsSubtitle,
        );
      case 'definitions/measurables':
        return (
          title: m.settingsMeasurablesTitle,
          desc: m.settingsMeasurablesSubtitle,
        );
      case 'theming':
        return (
          title: m.settingsThemingTitle,
          desc: m.settingsThemingSubtitle,
        );
      case 'speech':
        return (
          title: m.settingsSpeechTitle,
          desc: m.settingsSpeechSubtitle,
        );
      case 'advanced/flags':
        return (title: m.settingsFlagsTitle, desc: m.settingsFlagsSubtitle);
      case 'advanced':
        return (
          title: m.settingsAdvancedTitle,
          desc: m.settingsAdvancedSubtitle,
        );
      case 'advanced/logging':
        return (
          title: m.settingsLoggingDomainsTitle,
          desc: m.settingsLoggingDomainsSubtitle,
        );
      case 'advanced/health-import':
        return (
          title: m.settingsHealthImportTitle,
          desc: m.settingsAdvancedHealthImportSubtitle,
        );
      case 'sync/conflicts':
        return (
          title: m.settingsConflictsTitle,
          desc: m.settingsSyncConflictsSubtitle,
        );
      case 'advanced/maintenance':
        return (
          title: m.settingsMaintenanceTitle,
          desc: m.settingsAdvancedMaintenanceSubtitle,
        );
      case 'advanced/about':
        return (
          title: m.settingsAboutTitle,
          desc: m.settingsAdvancedAboutSubtitle,
        );
      default:
        // Unknown id — render the raw id so authoring mistakes are
        // visible immediately instead of crashing the tree render.
        return (title: id, desc: '');
    }
  }

  return resolve;
}
