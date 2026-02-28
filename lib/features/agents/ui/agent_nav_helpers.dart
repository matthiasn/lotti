import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

/// Navigate back using Beamer if we're in the settings navigation stack,
/// otherwise use Flutter's pop (e.g. when pushed from a task detail).
void navigateBackFromAgent(BuildContext context) {
  final navService = getIt<NavService>();
  if (navService.currentPath.startsWith('/settings/agents')) {
    navService.beamBack();
  } else {
    Navigator.of(context).pop();
  }
}

/// Standard back button used across agent UI pages.
///
/// Uses [Icons.chevron_left] at size 30 with the outline color from
/// the current theme, and includes a localized back-button tooltip.
IconButton agentBackButton(BuildContext context, {VoidCallback? onPressed}) {
  return IconButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    icon: Icon(
      Icons.chevron_left,
      size: 30,
      color: Theme.of(context).colorScheme.outline,
    ),
    onPressed: onPressed ?? () => navigateBackFromAgent(context),
  );
}
