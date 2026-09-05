import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Localized label for a [ProjectStatus], for the showcase/detail surfaces.
String showcaseProjectStatusLabel(
  BuildContext context,
  ProjectStatus status,
) => switch (status) {
  ProjectActive() => context.messages.projectStatusActive,
  ProjectMonitoring() => context.messages.projectStatusMonitoring,
  ProjectCompleted() => context.messages.projectStatusCompleted,
  ProjectArchived() => context.messages.projectStatusArchived,
  ProjectOnHold() => context.messages.projectStatusOnHold,
  ProjectOpen() => context.messages.projectStatusOpen,
};

/// Glyph for a [ProjectStatus] used by the showcase status pills/labels.
IconData showcaseProjectStatusIcon(ProjectStatus status) => switch (status) {
  ProjectActive() => LottiIcons.play,
  ProjectMonitoring() => LottiIcons.visible,
  ProjectCompleted() => LottiIcons.confirmCircled,
  ProjectArchived() => LottiIcons.archive,
  ProjectOnHold() => LottiIcons.pauseCircled,
  ProjectOpen() => LottiIcons.radioUnselected,
};

/// Accent color for a [ProjectStatus], drawn from [ShowcasePalette].
Color showcaseProjectStatusColor(
  BuildContext context,
  ProjectStatus status,
) => switch (status) {
  ProjectActive() => ShowcasePalette.amber(context),
  ProjectMonitoring() => ShowcasePalette.teal(context),
  ProjectCompleted() => ShowcasePalette.timeGreen(context),
  ProjectArchived() => ShowcasePalette.mediumText(context),
  ProjectOnHold() => ShowcasePalette.amber(context),
  ProjectOpen() => ShowcasePalette.infoBlue(context),
};

/// Formats a [Duration] compactly for task/estimate chips: `Xh Ym` when there
/// are whole hours, otherwise `Xm Ys` / `Xm` / `Xs` down to seconds.
String showcaseFormatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0 && seconds > 0) {
    return '${minutes}m ${seconds}s';
  }
  if (minutes > 0) {
    return '${minutes}m';
  }
  return '${seconds}s';
}
