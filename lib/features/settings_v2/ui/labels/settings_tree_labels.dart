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
      case 'ai/profiles':
        return (
          title: m.settingsAiProfilesTitle,
          desc: m.settingsAiProfilesSubtitle,
        );
      case 'agents':
        return (title: m.agentSettingsTitle, desc: m.agentSettingsSubtitle);
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
      case 'habits':
        return (title: m.settingsHabitsTitle, desc: m.settingsHabitsSubtitle);
      case 'categories':
        return (
          title: m.settingsCategoriesTitle,
          desc: m.settingsCategoriesSubtitle,
        );
      case 'labels':
        return (
          title: m.settingsLabelsTitle,
          desc: m.settingsLabelsSubtitle,
        );
      case 'sync':
        return (title: m.settingsMatrixTitle, desc: m.settingsSyncSubtitle);
      case 'sync/backfill':
        return (
          title: m.backfillSettingsTitle,
          desc: m.backfillSettingsSubtitle,
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
      case 'dashboards':
        return (
          title: m.settingsDashboardsTitle,
          desc: m.settingsDashboardsSubtitle,
        );
      case 'measurables':
        return (
          title: m.settingsMeasurablesTitle,
          desc: m.settingsMeasurablesSubtitle,
        );
      case 'theming':
        return (
          title: m.settingsThemingTitle,
          desc: m.settingsThemingSubtitle,
        );
      case 'flags':
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
      case 'advanced/conflicts':
        return (
          title: m.settingsConflictsTitle,
          desc: m.settingsAdvancedConflictsSubtitle,
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
