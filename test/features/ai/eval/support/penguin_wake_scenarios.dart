import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

import 'penguin_wake_world_seed.dart';

/// The wake scenarios the penguin world can be posed in.
///
/// One seeded task, several situations. Splitting the *situation* from the
/// *data* is what makes a new scenario cheap: the fourteen items, the notes and
/// the logged time are written once, and a scenario only says what state the
/// agent finds them in and what a correct wake does about it.
///
/// The first scenario measured every model at roughly the same score, which is
/// the signal that one scenario is not enough — a suite that cannot separate
/// Kimi from a 27B is not ranking models, it is only catching broken ones.
enum PenguinWakeScenarioId {
  /// The original: unblocked overnight, one item genuinely done, a superseded
  /// deadline request, and a debt that reads like a completion.
  requalification,

  /// Nothing report-worthy happened since the last wake.
  ///
  /// The hardest thing to ask of a task agent is nothing. A prior report
  /// already describes the state accurately and the newest note adds no fact
  /// that changes it, so a correct wake proposes no changes and does not
  /// rewrite the report. Models reliably fail this by finding something to do.
  noOp,

  /// A proposal for the very change the model is about to suggest is already
  /// queued and awaiting the user.
  ///
  /// Re-proposing it puts the same decision in front of the user twice. The
  /// context carries pending proposals precisely so the agent can see them.
  pendingProposal,
}

/// What a scenario needs seeded beyond the shared world.
class PenguinWakeScenario {
  const PenguinWakeScenario({
    required this.id,
    required this.summary,
    required this.expectsProposals,
    required this.expectsReport,
    this.forbiddenToolNames = const {},
  });

  final PenguinWakeScenarioId id;

  /// One line for the artifact, so a result file explains itself.
  final String summary;

  /// Whether a correct wake queues any proposal at all.
  final bool expectsProposals;

  /// Whether a correct wake writes or revises a report.
  final bool expectsReport;

  /// Tools a correct wake must not call, even though it may call others.
  ///
  /// The pending-proposal guard needs this: completing the swapped-cartridge
  /// item is still correct, while re-proposing the status change that is
  /// already queued is not. A blanket "propose nothing" would fail a model for
  /// the half of the wake it got right.
  final Set<String> forbiddenToolNames;

  static const _byId = <PenguinWakeScenarioId, PenguinWakeScenario>{
    PenguinWakeScenarioId.requalification: PenguinWakeScenario(
      id: PenguinWakeScenarioId.requalification,
      summary:
          'Unblocked overnight: complete the one supported item, clear the '
          'blocked status, leave the superseded deadline alone.',
      expectsProposals: true,
      expectsReport: true,
    ),
    PenguinWakeScenarioId.noOp: PenguinWakeScenario(
      id: PenguinWakeScenarioId.noOp,
      summary:
          'Nothing changed since the last report: propose nothing and do not '
          'rewrite the report.',
      expectsProposals: false,
      expectsReport: false,
    ),
    PenguinWakeScenarioId.pendingProposal: PenguinWakeScenario(
      id: PenguinWakeScenarioId.pendingProposal,
      summary:
          'The status change is already queued and awaiting the user: do not '
          'queue it a second time.',
      expectsProposals: true,
      expectsReport: true,
      forbiddenToolNames: {TaskAgentToolNames.setTaskStatus},
    ),
  };

  static PenguinWakeScenario of(PenguinWakeScenarioId id) => _byId[id]!;

  static PenguinWakeScenario fromName(String? name) {
    if (name == null || name.isEmpty) {
      return of(PenguinWakeScenarioId.requalification);
    }
    final match = PenguinWakeScenarioId.values.where((id) => id.name == name);
    if (match.isEmpty) {
      throw ArgumentError(
        'Unknown penguin wake scenario "$name". Known: '
        '${PenguinWakeScenarioId.values.map((id) => id.name).join(', ')}',
      );
    }
    return of(match.first);
  }
}

/// The report a previous wake left behind, for scenarios that are not a first
/// wake.
///
/// Most real wakes are follow-ups. Seeding an accurate prior report is what
/// turns "write a report" into the harder question the app actually asks:
/// whether anything has changed enough to be worth rewriting.
const String penguinWakePriorReportOneLiner =
    'Blocked on customs; hold test cannot start until the cartridges clear';
const String penguinWakePriorReportTldr =
    'Bay C is blocked pending a Ross Station customs hold on the replacement '
    'desiccant cartridges, and the due date has been moved to Aug 14 to match. '
    'The airlock gasket was reseated on Aug 2 and an informal check held 49%, '
    'but the qualifying hold test needs the real stock. Nothing can move until '
    'customs releases the shipment.';
const String penguinWakePriorReportContent = '''
## Blockers

Ross Station placed a formal hold on the replacement desiccant cartridges on
Jul 29, pending a duty reclassification. The 24-hour hold test cannot start on
borrowed cartridges from Bay E, so the cold-chain certificate stays suspended
until the shipment clears.

## Progress

The airlock gasket was reseated on Aug 2. An informal two-hour check afterwards
held Bay C at 49% relative humidity, the first in-band reading since the
incident, which points at the gasket as the original leak. That is not a
qualifying test.

## Next actions

Chase the customs hold, then run the 24-hour hold test, have Nima counter-sign
the certificate, file the re-qualification and restore the shared return duct.

The due date was moved out to Aug 14 on request, since none of this can start
until the shipment clears.
''';

/// Seeds a prior report and its head pointer, so the wake is a follow-up.
Future<void> seedPenguinWakePriorReport({
  required AgentSyncService syncService,
  required String agentId,
  DateTime? createdAt,
}) async {
  final at = createdAt ?? DateTime.utc(2026, 8, 4, 7);

  await syncService.upsertEntity(
    AgentDomainEntity.agentReport(
      id: 'penguin-wake-prior-report',
      agentId: agentId,
      scope: AgentReportScopes.current,
      createdAt: at,
      vectorClock: null,
      content: penguinWakePriorReportContent,
      tldr: penguinWakePriorReportTldr,
      oneLiner: penguinWakePriorReportOneLiner,
    ),
  );

  // Without the head pointer `getLatestReport` returns null and the wake reads
  // as a first wake, which would quietly turn a no-op scenario back into the
  // easy case it was written to replace.
  await syncService.upsertEntity(
    AgentDomainEntity.agentReportHead(
      id: 'penguin-wake-prior-report-head',
      agentId: agentId,
      scope: AgentReportScopes.current,
      reportId: 'penguin-wake-prior-report',
      updatedAt: at,
      vectorClock: null,
    ),
  );
}

/// A note that reports genuinely nothing new, for [PenguinWakeScenarioId.noOp].
///
/// It restates what the prior report already says. There is no instruction, no
/// completion and no new fact — a wake that finds work here is inventing it.
const String penguinWakeNoOpNote =
    'Rang Ross Station again about the customs hold. Still no movement and no '
    'date from them. Nothing else to report — the bay is holding on the '
    'borrowed cartridges and the gasket reseat is still looking like the fix.';

/// Seeds a change set that is already queued and awaiting the user.
///
/// The wake is the unblocking one, so a model will want to move the task off
/// BLOCKED — but a previous wake already proposed exactly that and the user has
/// not answered yet. Proposing it again puts the same decision in front of them
/// twice, which is why the context carries pending proposals at all.
///
/// Only the status change is queued. Completing the swapped-cartridge item is
/// still outstanding and still correct, so the scenario distinguishes a model
/// that reads the pending list from one that simply does less.
Future<void> seedPenguinWakePendingProposal({
  required AgentSyncService syncService,
  required String agentId,
  required String threadId,
  DateTime? createdAt,
}) async {
  final at = createdAt ?? DateTime.utc(2026, 8, 5, 8, 20);

  await syncService.upsertEntity(
    AgentDomainEntity.changeSet(
      id: 'penguin-wake-pending-change-set',
      agentId: agentId,
      taskId: penguinWakeTaskId,
      threadId: threadId,
      runKey: 'run-penguin-wake-previous',
      status: ChangeSetStatus.pending,
      createdAt: at,
      vectorClock: null,
      items: const [
        ChangeItem(
          toolName: TaskAgentToolNames.setTaskStatus,
          args: {'status': 'IN PROGRESS'},
          humanSummary: 'Set status to IN PROGRESS',
        ),
      ],
    ),
  );
}
