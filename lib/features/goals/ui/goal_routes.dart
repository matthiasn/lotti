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

/// The root path of the goal surface the user is currently on: `/goals` when
/// the current route lives under the unified Goals tab, `/agents` otherwise
/// (including when no [NavService] is registered — widget tests exercise the
/// goal pages without one, and `/agents` is the pre-merge behavior).
String goalSurfaceRootPath() {
  if (!getIt.isRegistered<NavService>()) return '/agents';
  final currentPath = getIt<NavService>().currentPath;
  return currentPath == '/goals' || currentPath.startsWith('/goals/')
      ? '/goals'
      : '/agents';
}

/// The current surface's goal-creation wizard route.
String goalCreatePath() => '${goalSurfaceRootPath()}/create';

/// The current surface's detail route for [agentId].
String goalDetailPath(String agentId) =>
    '${goalSurfaceRootPath()}/details/$agentId';

/// The current surface's chat route for [agentId].
String goalChatPath(String agentId) => '${goalDetailPath(agentId)}/chat';

/// The current surface's edit-wizard route for [agentId].
String goalEditPath(String agentId) => '${goalDetailPath(agentId)}/edit';
