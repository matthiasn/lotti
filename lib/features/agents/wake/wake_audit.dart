import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_budget.dart';
import 'package:lotti/services/domain_logging.dart';

/// Why the wake runtime allowed or refused one wake.
///
/// Every decision the runtime takes about a wake is logged once, under the
/// `wakeAudit` sub-domain, with one of these causes — so a field log answers
/// "why did this agent run (or not)?" without reading the code. The causes are
/// stable identifiers: grep for them.
enum WakeDecisionCause {
  /// The wake runs.
  allowed,

  /// The agent is paused, destroyed or not yet created.
  agentInactive,

  /// The agent's inference setup is disabled.
  inferenceDisabled,

  /// Automatic updates are off and the wake was not requested by the user.
  automaticUpdatesOff,

  /// Automatic work used the daily budget; explicit requests still run.
  budgetExhausted,

  /// Even an explicit request is refused: twice the daily budget is used.
  hardCeilingReached,

  /// The budget claim could not be persisted; the wake is refused rather than
  /// run unaccounted.
  budgetClaimFailed,

  /// The agent's policy could not be read; automatic work fails closed.
  policyUnreadable,

  /// The agent's own write came back as a notification.
  selfNotification,

  /// The change only marked the report stale; no wake was queued.
  markedStaleOnly,

  /// An automatic project-agent wake that is not an update slot. Project
  /// agents update on their own only in slots (`ProjectUpdateCadence`); any
  /// other automatic trigger is refused, whatever path queued it.
  notAnUpdateSlot,

  /// An update slot whose report is already fresh: an "Update now" or a
  /// peer's run got there first. Refused before the budget is claimed, so it
  /// costs nothing of the day's allowance.
  reportAlreadyFresh,
}

/// The wake runtime's decision on one queued wake.
class WakePolicyDecision {
  const WakePolicyDecision(this.cause, {this.budgetUsed, this.budgetMax});

  /// A budget [verdict] with today's usage — after the claim, when it ran.
  factory WakePolicyDecision.fromBudget(
    WakeBudgetVerdict verdict, {
    required int used,
    required int max,
  }) => WakePolicyDecision(
    switch (verdict) {
      WakeBudgetVerdict.allowed => WakeDecisionCause.allowed,
      WakeBudgetVerdict.automaticBudgetExhausted =>
        WakeDecisionCause.budgetExhausted,
      WakeBudgetVerdict.hardCeilingReached =>
        WakeDecisionCause.hardCeilingReached,
    },
    budgetUsed: used,
    budgetMax: max,
  );

  /// Allowed by an agent kind that carries no daily budget.
  static const allowedUnbudgeted = WakePolicyDecision(
    WakeDecisionCause.allowed,
  );

  final WakeDecisionCause cause;
  final int? budgetUsed;
  final int? budgetMax;

  bool get allowed => cause == WakeDecisionCause.allowed;
}

/// The error a refused wake completes with, so listeners — the goal read card,
/// the Daily OS job executor — can tell a policy refusal from a failure.
class WakeRefusedError implements Exception {
  const WakeRefusedError(this.cause);

  final WakeDecisionCause cause;

  @override
  String toString() => 'WakeRefusedError(${cause.name})';
}

/// One structured `wakeAudit` line.
///
/// Fields are `key=value` pairs separated by spaces so logs from several
/// devices can be merged and filtered with plain text tools. Ids pass through
/// [DomainLogger.sanitizeId]; trigger tokens are counted, never printed, since
/// they can name journal entities.
String formatWakeAudit({
  required String stage,
  required String agentId,
  required WakeDecisionCause cause,
  String? reason,
  WakeInitiator? initiator,
  String? reasonId,
  int? tokenCount,
  int? budgetUsed,
  int? budgetMax,
  String? detail,
}) {
  final buffer = StringBuffer('wake ')
    ..write(cause == WakeDecisionCause.allowed ? 'allowed' : 'suppressed')
    ..write(' stage=$stage')
    ..write(' agent=${DomainLogger.sanitizeId(agentId)}')
    ..write(' cause=${cause.name}');
  if (reason != null) buffer.write(' reason=$reason');
  if (initiator != null) buffer.write(' initiator=${initiator.name}');
  if (reasonId != null) {
    buffer.write(' source=${DomainLogger.sanitizeId(reasonId)}');
  }
  if (tokenCount != null) buffer.write(' tokens=$tokenCount');
  if (budgetUsed != null && budgetMax != null) {
    buffer.write(' budget=$budgetUsed/$budgetMax');
  }
  if (detail != null) buffer.write(' detail=$detail');
  return buffer.toString();
}
