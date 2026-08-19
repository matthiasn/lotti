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
  /// A prior report already describes the state accurately and the newest note
  /// adds no fact that changes it, so a correct wake proposes no data changes.
  ///
  /// It also publishes no report. The live contract is
  /// `TaskAgentEvidenceSynthesis.reportDirective`, which
  /// `TaskAgentPromptBuilder.effectiveReportDirective` substitutes for every
  /// stock agent: "Otherwise finish with a brief plain-text note and do not
  /// republish unchanged content."
  ///
  /// The seeded `taskAgentReportDirective` constant says the opposite — "You
  /// MUST call `update_report` ... do not end your turn with a plain text
  /// message" — and is **never sent to a stock agent**, because both an empty
  /// and a stock directive count as built-in and are replaced. Reading that
  /// constant as the rule once caused this scenario's results to be retracted
  /// in error. Verify against a built prompt, not a seeded constant.
  ///
  /// Fabrication is checked alongside: a wake with no news must not invent
  /// progress it cannot support.
  noOp,

  /// A follow-up wake where something genuinely DID change.
  ///
  /// The counterweight to the no-op scenario, and the reason it has to exist:
  /// every fix for no-op churn pushes a model toward doing less, and nothing
  /// in this catalog could tell "correctly restrained" from "too timid to
  /// report real news". The prior report says Bay C is blocked on the sensor
  /// swap; the closing note says the swap is done, the seam was walked and the
  /// leak was found. Standing pat here is a failure, not restraint.
  materialChange,

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
    this.allowedProposalTools = const {},
  });

  final PenguinWakeScenarioId id;

  /// One line for the artifact, so a result file explains itself.
  final String summary;

  /// Whether a correct wake queues any proposal at all.
  final bool expectsProposals;

  /// Whether a correct wake writes or revises a report.
  ///
  /// Asserted by the live test, in both directions: a scenario that expects a
  /// report fails if the standing one is left untouched, and the no-op case
  /// fails if it is rewritten. The field was declared on every scenario and
  /// checked by nothing until 2026-08-18, which made "the report must change"
  /// an expectation the suite stated and never tested.
  final bool expectsReport;

  /// Tools a wake may propose even when it should otherwise propose nothing.
  ///
  /// The no-op wake is the case. Its note reports no movement — "still no date
  /// from the parts store" — and every evaluated model responded by proposing
  /// the `waiting-on` label. That is supported by the evidence, is not a
  /// duplicate (the task carries `blocked`, not `waiting-on`), and is not
  /// speculative, so the contract's "skip no-ops, duplicates, speculative
  /// changes" does not forbid it. Asserting against it made four models from
  /// three vendors fail for doing something reasonable.
  ///
  /// Everything else stays forbidden, and the label itself is still checked:
  /// permission to add `waiting-on` is not permission to invent a label.
  final Set<String> allowedProposalTools;

  /// Tools a correct wake must not call, even though it may call others.
  ///
  /// The pending-proposal guard needs this: completing the sensor-swap
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
          'The note reports no movement: do not republish the report and do '
          'not invent progress. Labelling what the note describes is fine.',
      expectsProposals: false,
      expectsReport: false,
      allowedProposalTools: {TaskAgentToolNames.assignTaskLabel},
    ),
    PenguinWakeScenarioId.materialChange: PenguinWakeScenario(
      id: PenguinWakeScenarioId.materialChange,
      summary:
          'The blocker cleared and the leak was found since the last report: '
          'publish the change and propose the work the note supports.',
      expectsProposals: true,
      expectsReport: true,
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
    'Blocked on the Bay C sensor swap; humidity still nine points high';
const String penguinWakePriorReportTldr =
    'Bay C is blocked waiting on the wall-sensor swap. Humidity is still about '
    'nine points above band and the readings have been charted, but the seam '
    'line cannot be walked until the sensor reports again.';
const String penguinWakePriorReportContent = '''
## Blockers

Bay C is waiting on the wall-sensor swap. Until the new sensor reports, the
seam line cannot be walked with the thermal camera and the leak can be neither
found nor ruled out.

## Progress

The humidity readings have been charted by day, which is what established that
nine points over three days is a leak rather than weather.

## Next actions

Wait for the sensor swap, then walk the seam line with the thermal camera and
either report the leak or clear the bay.
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

/// Seeds a change set that is already queued and awaiting the user.
///
/// The wake is the unblocking one, so a model will want to move the task off
/// BLOCKED — but a previous wake already proposed exactly that and the user has
/// not answered. Proposing it again puts the same decision in front of them
/// twice, which is what the pending list in the context exists to prevent.
///
/// Only the status change is queued. The checklist completions the note
/// supports are still outstanding and still correct, so the scenario
/// distinguishes a model that reads the pending list from one that simply does
/// less.
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
