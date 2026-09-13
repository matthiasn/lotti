import 'package:lotti/features/sync/vector_clock.dart';

/// A wake whose workflow reported failure through [WakeResult.error].
///
/// Thrown by the wake executor wiring so the drain engine's failure log can
/// name the agent kind and the workflow's reason. Before this the wiring
/// rethrew a bare `StateError`, which the PII-safe error log reduced to
/// `errorType=StateError` — indistinguishable from a genuine `StateError`
/// (a closed database transaction, say) and silent about which of the
/// workflows' reasons it was. [reason] is a workflow-authored string, never
/// user content — see the contract on [WakeResult.error].
class WakeFailedException implements Exception {
  const WakeFailedException({required this.kind, required this.reason});

  /// The agent kind whose workflow failed, e.g. `task` or `goal`.
  final String kind;

  /// The workflow's [WakeResult.error], or a kind-specific default.
  final String reason;

  @override
  String toString() => 'WakeFailedException($kind): $reason';
}

/// Result of a wake cycle execution.
class WakeResult {
  const WakeResult({
    required this.success,
    this.mutatedEntries = const {},
    this.reportUpdated = false,
    this.error,
  });

  /// A failed wake whose workflow caught [error], with a bounded [WakeResult.error].
  ///
  /// A [StateError] is the workflows' own abort signal (`No active project
  /// ID`, `no visible reply`, drift's closed-transaction message) and its
  /// message is kept; every other exception is reported by type only, since
  /// provider and filesystem exceptions carry response bodies and paths that
  /// must not reach the PII-safe error log. The catch site logs the raw
  /// exception with its stack trace to the full log.
  factory WakeResult.failed({required String kind, required Object error}) =>
      WakeResult(
        success: false,
        error: error is StateError
            ? '$kind workflow failed: ${error.message}'
            : '$kind workflow failed (${error.runtimeType})',
      );

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
  ///
  /// Workflow-authored telemetry, never exception text or user content: the
  /// wake wiring rethrows it as [WakeFailedException.reason] and the drain
  /// engine writes that into its failure *message*, which the PII-safe error
  /// log keeps verbatim. A caught exception is reported by type —
  /// `'Task agent workflow failed (MeliousInferenceException)'` — and logged
  /// in full, with its stack trace, at the catch site.
  final String? error;
}
