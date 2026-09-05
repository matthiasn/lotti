import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Shared mapping from [ProjectStatus] to its display attributes:
/// label, color (brightness-aware), and icon.
///
/// Used by both `ProjectStatusChip` and `ProjectStatusPicker` to ensure
/// consistent visual representation across all project status surfaces.
(String, Color, IconData) projectStatusAttributes(
  BuildContext context,
  ProjectStatus status,
) {
  final messages = context.messages;
  final brightness = Theme.of(context).brightness;
  final isLight = brightness == Brightness.light;
  final tokens = context.designTokens;

  return switch (status) {
    ProjectOpen() => (
      messages.projectStatusOpen,
      isLight ? projectStatusDarkBlue : projectStatusBlue,
      LottiIcons.radioUnselected,
    ),
    ProjectActive() => (
      messages.projectStatusActive,
      isLight ? projectStatusDarkGreen : projectStatusGreen,
      LottiIcons.playCircled,
    ),
    ProjectMonitoring() => (
      messages.projectStatusMonitoring,
      tokens.colors.interactive.enabled,
      LottiIcons.visible,
    ),
    ProjectOnHold() => (
      messages.projectStatusOnHold,
      isLight ? projectStatusDarkOrange : projectStatusOrange,
      LottiIcons.pauseCircled,
    ),
    ProjectCompleted() => (
      messages.projectStatusCompleted,
      isLight ? projectStatusDarkTeal : projectStatusTeal,
      LottiIcons.confirmCircled,
    ),
    ProjectArchived() => (
      messages.projectStatusArchived,
      tokens.colors.text.highEmphasis,
      LottiIcons.archive,
    ),
  };
}

/// The six canonical project-status variants.
///
/// Shared so that status-picker UIs do not each need a private copy.
enum ProjectStatusKind { open, active, monitoring, onHold, completed, archived }

/// All status kinds in display order.
const List<ProjectStatusKind> allProjectStatusKinds = ProjectStatusKind.values;

/// Maps a [ProjectStatusFilterIds] string to a [ProjectStatusKind].
///
/// Returns [ProjectStatusKind.open] for unrecognised IDs.
ProjectStatusKind projectStatusKindFromFilterId(String filterId) {
  return switch (filterId) {
    ProjectStatusFilterIds.open => ProjectStatusKind.open,
    ProjectStatusFilterIds.active => ProjectStatusKind.active,
    ProjectStatusFilterIds.monitoring => ProjectStatusKind.monitoring,
    ProjectStatusFilterIds.onHold => ProjectStatusKind.onHold,
    ProjectStatusFilterIds.completed => ProjectStatusKind.completed,
    ProjectStatusFilterIds.archived => ProjectStatusKind.archived,
    _ => ProjectStatusKind.open,
  };
}

/// Builds a [ProjectStatus] of the given [kind] at the given [at] time.
ProjectStatus buildProjectStatus(ProjectStatusKind kind, DateTime at) {
  final utcOffset = at.timeZoneOffset.inMinutes;
  return switch (kind) {
    ProjectStatusKind.open => ProjectStatus.open(
      id: uuid.v1(),
      createdAt: at,
      utcOffset: utcOffset,
    ),
    ProjectStatusKind.active => ProjectStatus.active(
      id: uuid.v1(),
      createdAt: at,
      utcOffset: utcOffset,
    ),
    ProjectStatusKind.monitoring => ProjectStatus.monitoring(
      id: uuid.v1(),
      createdAt: at,
      utcOffset: utcOffset,
    ),
    ProjectStatusKind.onHold => ProjectStatus.onHold(
      id: uuid.v1(),
      createdAt: at,
      utcOffset: utcOffset,
      reason: '',
    ),
    ProjectStatusKind.completed => ProjectStatus.completed(
      id: uuid.v1(),
      createdAt: at,
      utcOffset: utcOffset,
    ),
    ProjectStatusKind.archived => ProjectStatus.archived(
      id: uuid.v1(),
      createdAt: at,
      utcOffset: utcOffset,
    ),
  };
}
