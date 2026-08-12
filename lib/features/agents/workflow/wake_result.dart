import 'package:lotti/features/sync/vector_clock.dart';

/// Result of a wake cycle execution.
class WakeResult {
  const WakeResult({
    required this.success,
    this.mutatedEntries = const {},
    this.reportUpdated = false,
    this.error,
  });

  /// Whether the wake completed successfully.
  final bool success;

  /// Map of journal entity IDs mutated during this wake to their post-mutation
  /// vector clocks. Used by the orchestrator for self-notification suppression.
  final Map<String, VectorClock> mutatedEntries;

  /// Whether this wake durably replaced the agent's standing report.
  ///
  /// Deterministic maintenance wakes can succeed and update derived state
  /// without producing prose. The shared wake runtime uses this distinction
  /// to keep an existing report visibly stale until a report-producing wake
  /// completes.
  final bool reportUpdated;

  /// Error description when [success] is false.
  final String? error;
}
