import 'package:lotti/features/agents/model/agent_enums.dart';

/// One row of the template's instance list.
///
/// Everything here is cheap to compute in bulk — identity fields plus two
/// values read from the instance's state snapshot — so a template with
/// thousands of instances still builds the list from two queries. The task
/// *title* is deliberately absent: resolving it per instance would be a
/// journal read each, so the row widget looks it up lazily for the handful of
/// rows actually on screen.
class TemplateInstanceOverview {
  const TemplateInstanceOverview({
    required this.agentId,
    required this.displayName,
    required this.lifecycle,
    required this.createdAt,
    required this.totalTokens,
    this.lastWakeAt,
    this.taskId,
  });

  /// The instance's `agentId` — the id `/settings/agents/instances/{id}`
  /// deep-links to.
  final String agentId;

  final String displayName;
  final AgentLifecycle lifecycle;

  /// When the instance was created: the "since when has this agent existed"
  /// column, which is what distinguishes a long-lived agent from one spawned
  /// by yesterday's task.
  final DateTime createdAt;

  /// Last completed wake, or `null` for an instance that has never woken.
  final DateTime? lastWakeAt;

  /// The task this instance is bound to, when it still has one. Drives the
  /// row's link into the task itself.
  final String? taskId;

  /// Tokens across every model this instance has used, `0` when it has never
  /// run inference.
  final int totalTokens;

  /// Sort key for "most recently active first", falling back to creation for
  /// an instance that has never woken so it still lands in a sensible place.
  DateTime get lastActiveAt => lastWakeAt ?? createdAt;
}
