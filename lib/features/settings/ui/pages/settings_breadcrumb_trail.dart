import 'package:flutter/material.dart';
import 'package:lotti/features/settings/ui/pages/settings_column_stack.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// A single level in the settings navigation trail shown by the top
/// bar's breadcrumb.
///
/// [label] is already localised, [path] is the route the breadcrumb
/// chip navigates to when tapped. The last entry in the trail
/// represents the current leaf and is rendered as selected.
@immutable
class SettingsBreadcrumbEntry {
  const SettingsBreadcrumbEntry({
    required this.label,
    required this.path,
  });

  final String label;
  final String path;
}

/// Builds the ordered breadcrumb trail for [route] by delegating to
/// [resolveSettingsColumnStack] and mapping each column's declared
/// [SettingsColumnCrumb] to a localised [SettingsBreadcrumbEntry].
///
/// Keeping the two resolvers in lockstep this way means adding a new
/// settings column forces a decision about how it appears in the
/// trail — there is no second source of truth to drift.
List<SettingsBreadcrumbEntry> resolveSettingsBreadcrumbTrail(
  BuildContext context,
  DesktopSettingsRoute? route,
) {
  final messages = context.messages;
  final columns = resolveSettingsColumnStack(route);
  return [
    for (final column in columns)
      SettingsBreadcrumbEntry(
        label: _localiseCrumb(messages, column.crumb.label),
        path: column.crumb.path,
      ),
  ];
}

String _localiseCrumb(AppLocalizations m, SettingsCrumbLabel label) {
  switch (label) {
    case SettingsCrumbLabel.root:
      return m.navTabTitleSettings;
    case SettingsCrumbLabel.ai:
      return m.settingsAiTitle;
    case SettingsCrumbLabel.aiProfiles:
      return m.inferenceProfilesTitle;
    case SettingsCrumbLabel.sync:
      return m.settingsMatrixTitle;
    case SettingsCrumbLabel.syncMatrixMaintenance:
      return m.settingsMatrixMaintenanceTitle;
    case SettingsCrumbLabel.syncBackfill:
      return m.backfillSettingsTitle;
    case SettingsCrumbLabel.syncStats:
      return m.settingsMatrixStatsTitle;
    case SettingsCrumbLabel.syncOutbox:
      return m.settingsSyncOutboxTitle;
    case SettingsCrumbLabel.labels:
      return m.settingsLabelsTitle;
    case SettingsCrumbLabel.labelsCreate:
      return m.settingsLabelsCreateTitle;
    case SettingsCrumbLabel.labelsEdit:
      return m.settingsLabelsEditTitle;
    case SettingsCrumbLabel.categories:
      return m.settingsCategoriesTitle;
    case SettingsCrumbLabel.categoriesCreate:
      return m.createButton;
    case SettingsCrumbLabel.categoriesEdit:
      return m.editMenuTitle;
    case SettingsCrumbLabel.projectsCreate:
      return m.projectCreateTitle;
    case SettingsCrumbLabel.projectsEdit:
      return m.projectDetailTitle;
    case SettingsCrumbLabel.dashboards:
      return m.settingsDashboardsTitle;
    case SettingsCrumbLabel.dashboardsCreate:
      return m.createButton;
    case SettingsCrumbLabel.dashboardsEdit:
      return m.editMenuTitle;
    case SettingsCrumbLabel.measurables:
      return m.settingsMeasurablesTitle;
    case SettingsCrumbLabel.measurablesCreate:
      return m.createButton;
    case SettingsCrumbLabel.measurablesEdit:
      return m.editMenuTitle;
    case SettingsCrumbLabel.habits:
      return m.settingsHabitsTitle;
    case SettingsCrumbLabel.habitsCreate:
      return m.createButton;
    case SettingsCrumbLabel.habitsEdit:
      return m.editMenuTitle;
    case SettingsCrumbLabel.agents:
      return m.agentSettingsTitle;
    case SettingsCrumbLabel.agentsTemplateCreate:
      return m.agentTemplateCreateTitle;
    case SettingsCrumbLabel.agentsTemplateEdit:
      return m.agentTemplateEditTitle;
    case SettingsCrumbLabel.agentsTemplateReview:
      return m.agentEvolutionHistoryTitle;
    case SettingsCrumbLabel.agentsSoulCreate:
      return m.agentSoulCreateTitle;
    case SettingsCrumbLabel.agentsSoulEdit:
      return m.agentSoulDetailTitle;
    case SettingsCrumbLabel.agentsSoulReview:
      return m.agentSoulReviewTitle;
    case SettingsCrumbLabel.agentsInstance:
      return m.agentInstancesTitle;
    case SettingsCrumbLabel.flags:
      return m.settingsFlagsTitle;
    case SettingsCrumbLabel.theming:
      return m.settingsThemingTitle;
    case SettingsCrumbLabel.healthImport:
      return m.settingsHealthImportTitle;
    case SettingsCrumbLabel.advanced:
      return m.settingsAdvancedTitle;
    case SettingsCrumbLabel.advancedLoggingDomains:
      return m.settingsLoggingDomainsTitle;
    case SettingsCrumbLabel.advancedAbout:
      return m.settingsAboutTitle;
    case SettingsCrumbLabel.advancedMaintenance:
      return m.settingsMaintenanceTitle;
    case SettingsCrumbLabel.advancedConflicts:
      return m.settingsConflictsTitle;
    case SettingsCrumbLabel.advancedConflictsResolution:
      return m.settingsConflictsResolutionTitle;
    case SettingsCrumbLabel.advancedConflictsEdit:
      return m.editMenuTitle;
  }
}
