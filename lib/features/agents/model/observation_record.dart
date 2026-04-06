import 'package:lotti/features/agents/model/agent_enums.dart';

/// A structured observation record with optional priority, category, and
/// target.
///
/// The [text] field holds the observation content. The [priority],
/// [category], and [target] fields are populated when the agent uses the
/// structured observation format; for legacy bare-string observations they
/// default to [ObservationPriority.routine],
/// [ObservationCategory.operational], and [ObservationTarget.template].
///
/// Shared across agent types (task agent, project agent, etc.).
class ObservationRecord {
  const ObservationRecord({
    required this.text,
    this.priority = ObservationPriority.routine,
    this.category = ObservationCategory.operational,
    this.target = ObservationTarget.template,
  });

  final String text;
  final ObservationPriority priority;
  final ObservationCategory category;

  /// Where this observation applies: template skills, soul personality, or
  /// both. Used by the evolution agent to triage feedback.
  final ObservationTarget target;
}
