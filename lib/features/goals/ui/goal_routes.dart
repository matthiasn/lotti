import 'package:beamer/beamer.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

/// Route helpers for the goal surfaces during the flagged unified-Goals
/// rollout.
///
/// The goal detail, chat and wizard pages are hosted under BOTH top-level
/// tabs — the legacy Agents tab (`/agents/...`) and the unified Goals tab
/// (`/goals/...`, flag `enable_unified_goals`). Their internal navigation
/// (back buttons, post-save redirects, deletion exits, chat/edit links) must
/// stay inside the tab that opened them: a hardcoded `/agents/...` target
/// strands the user on the wrong tab when they arrived from Goals, and is
/// silently normalized to `/tasks` when only the Goals flag is enabled.

/// The root path of the goal surface the page at [context] belongs to:
/// `/goals` when the page is hosted inside the unified Goals tab's own
/// Beamer, `/agents` otherwise.
///
/// Resolved from the ENCLOSING delegate's current route, not from
/// `NavService.currentPath`: tab taps change only the active index, so the
/// global path can still point at a different tab while a retained goal page
/// acts — and both tabs can retain goal pages simultaneously. Without an
/// enclosing Beamer (widget tests, previews) this falls back to `/agents`,
/// the pre-merge behavior.
String goalSurfaceRootPath(BuildContext context) {
  String? path;
  try {
    path = Beamer.of(context).configuration.uri.path;
  } catch (_) {
    path = null;
  }
  return path == '/goals' || (path?.startsWith('/goals/') ?? false)
      ? '/goals'
      : '/agents';
}

/// The current surface's goal-creation wizard route.
String goalCreatePath(BuildContext context) =>
    '${goalSurfaceRootPath(context)}/create';

/// The current surface's detail route for [agentId].
String goalDetailPath(BuildContext context, String agentId) =>
    '${goalSurfaceRootPath(context)}/details/$agentId';

/// The current surface's chat route for [agentId].
String goalChatPath(BuildContext context, String agentId) =>
    '${goalDetailPath(context, agentId)}/chat';

/// The current surface's edit-wizard route for [agentId].
String goalEditPath(BuildContext context, String agentId) =>
    '${goalDetailPath(context, agentId)}/edit';

/// The goal detail route for [agentId] from a surface OUTSIDE both goal
/// tabs — the shell banner dock on Tasks/DailyOS/Habits, where no goal
/// Beamer encloses the tap. The legacy Agents tab keeps its pre-merge
/// target while enabled; with only the unified Goals flag on, the route
/// moves there so dock nudges stay actionable (a disabled tab's route is
/// normalized to /tasks).
String goalDetailPathFromShell(String agentId) {
  final navService = getIt.isRegistered<NavService>()
      ? getIt<NavService>()
      : null;
  final root =
      navService != null &&
          !navService.isAgentsPageEnabled &&
          navService.isUnifiedGoalsPageEnabled
      ? '/goals'
      : '/agents';
  return '$root/details/$agentId';
}
