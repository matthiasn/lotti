import 'dart:async';

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

/// Settings sub-route for a single agent's instance detail page.
///
/// Kept here so any feature can deep-link to the existing agent detail
/// UI without depending on the sidebar wake queue file.
String agentInstanceRoute(String agentId) =>
    '/settings/agents/instances/$agentId';

/// Navigates from anywhere to the agent detail page for [agentId].
///
/// Mirrors the sidebar wake-queue navigation flow: switch to the
/// Settings tab via [NavService.setIndex] (not `tapIndex`, which would
/// re-root the delegate), beam the Settings delegate to the target
/// route, and persist the named route so reload returns to the same
/// page.
void navigateToAgentInstance(String agentId) {
  final navService = getIt<NavService>();
  final route = agentInstanceRoute(agentId);
  if (navService.index != navService.settingsIndex) {
    navService.setIndex(navService.settingsIndex);
  }
  navService.settingsDelegate.beamToNamed(route);
  unawaited(navService.persistNamedRoute(route));
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
