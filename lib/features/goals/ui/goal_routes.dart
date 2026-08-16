/// Route helpers for the unified Goals surface (`/goals/...`).
///
/// The goal detail, chat and wizard pages are hosted exclusively by
/// `GoalsLocation` under the unified Goals tab, so every goal route is a
/// plain path under [goalsRootPath]. Keeping the paths behind these helpers
/// (rather than inlining string literals at each call site) keeps the route
/// shape a single seam shared by pages, banners and the shell dock.
library;

/// The root path of the unified Goals tab.
const String goalsRootPath = '/goals';

/// The goal-creation wizard route.
const String goalCreatePath = '$goalsRootPath/create';

/// The detail route for [agentId].
String goalDetailPath(String agentId) => '$goalsRootPath/details/$agentId';

/// The chat route for [agentId].
String goalChatPath(String agentId) => '${goalDetailPath(agentId)}/chat';

/// The edit-wizard route for [agentId].
String goalEditPath(String agentId) => '${goalDetailPath(agentId)}/edit';
