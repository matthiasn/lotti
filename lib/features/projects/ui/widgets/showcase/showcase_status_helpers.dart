import 'package:flutter/material.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

String showcaseProjectStatusLabel(
  BuildContext context,
  ProjectStatus status,
) => switch (status) {
  ProjectActive() => context.messages.projectStatusActive,
  ProjectCompleted() => context.messages.projectStatusCompleted,
  ProjectArchived() => context.messages.projectStatusArchived,
  ProjectOnHold() => context.messages.projectStatusOnHold,
  ProjectOpen() => context.messages.projectStatusOpen,
};

IconData showcaseProjectStatusIcon(ProjectStatus status) => switch (status) {
  ProjectActive() => Icons.play_arrow_rounded,
  ProjectCompleted() => Icons.check_circle_outline_rounded,
  ProjectArchived() => Icons.archive_outlined,
  ProjectOnHold() => Icons.pause_circle_outline_rounded,
  ProjectOpen() => Icons.radio_button_unchecked_rounded,
};

Color showcaseProjectStatusColor(
  BuildContext context,
  ProjectStatus status,
) => switch (status) {
  ProjectActive() => ShowcasePalette.amber(context),
  ProjectCompleted() => ShowcasePalette.timeGreen(context),
  ProjectArchived() => ShowcasePalette.mediumText(context),
  ProjectOnHold() => ShowcasePalette.amber(context),
  ProjectOpen() => ShowcasePalette.infoBlue(context),
};

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
