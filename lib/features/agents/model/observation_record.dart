import 'package:lotti/features/agents/model/agent_enums.dart';

/// A structured observation record with optional priority and category.
///
/// The [text] field holds the observation content. The [priority] and
/// [category] fields are populated when the agent uses the structured
/// observation format; for legacy bare-string observations they default
/// to [ObservationPriority.routine] and [ObservationCategory.operational].
///
/// Shared across agent types (task agent, project agent, etc.).
class ObservationRecord {
  const ObservationRecord({
    required this.text,
    this.priority = ObservationPriority.routine,
    this.category = ObservationCategory.operational,
  });

  final String text;
  final ObservationPriority priority;
  final ObservationCategory category;
}
