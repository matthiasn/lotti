import 'package:flutter/material.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';

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

  return switch (status) {
    ProjectOpen() => (
      messages.projectStatusOpen,
      isLight ? projectStatusDarkBlue : projectStatusBlue,
      Icons.radio_button_unchecked,
    ),
    ProjectActive() => (
      messages.projectStatusActive,
      isLight ? projectStatusDarkGreen : projectStatusGreen,
      Icons.play_circle_outline,
    ),
    ProjectOnHold() => (
      messages.projectStatusOnHold,
      isLight ? projectStatusDarkOrange : projectStatusOrange,
      Icons.pause_circle_outline,
    ),
    ProjectCompleted() => (
      messages.projectStatusCompleted,
      isLight ? projectStatusDarkTeal : projectStatusTeal,
      Icons.check_circle_outline,
    ),
    ProjectArchived() => (
      messages.projectStatusArchived,
      isLight
          ? Theme.of(context).colorScheme.outline
          : Theme.of(context).colorScheme.outlineVariant,
      Icons.archive_outlined,
    ),
  };
}
