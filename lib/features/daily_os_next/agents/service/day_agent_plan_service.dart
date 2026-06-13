import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_editor.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_tool_dispatcher.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_writer.dart';
import 'package:lotti/services/domain_logging.dart';

/// Backend implementation for Daily OS day-plan drafting tools.
///
/// A thin facade over four collaborators that own the actual work:
///   * [DayAgentPlanReads] — shared soft-delete-aware plan/identity reads.
///   * [DayAgentPlanWriter] — persisting drafts, resolving diffs, summaries.
///   * [DayAgentPlanEditor] — in-place edits (propose/accept/commit/rename).
///   * [DayAgentPlanToolDispatcher] — the foundation tool-call switch.
///
/// The facade keeps every public method as a one-line delegator so the
/// mocked surface (`MockDayAgentPlanService`) stays stable.
class DayAgentPlanService {
  /// Creates a day-plan service and wires its collaborators.
  DayAgentPlanService({
    required this.agentRepository,
    required this.syncService,
    required this.journalDb,
    required this.domainLogger,
    this.onPersistedStateChanged,
  }) : _reads = DayAgentPlanReads(agentRepository: agentRepository) {
    _writer = DayAgentPlanWriter(
      agentRepository: agentRepository,
      syncService: syncService,
      journalDb: journalDb,
      reads: _reads,
      onPersistedStateChanged: onPersistedStateChanged,
    );
    _editor = DayAgentPlanEditor(
      agentRepository: agentRepository,
      syncService: syncService,
      journalDb: journalDb,
      reads: _reads,
      writer: _writer,
      onPersistedStateChanged: onPersistedStateChanged,
    );
    _dispatcher = DayAgentPlanToolDispatcher(
      writer: _writer,
      editor: _editor,
      domainLogger: domainLogger,
    );
  }

  /// Agent entity/link repository.
  final AgentRepository agentRepository;

  /// Sync-aware agent writer.
  final AgentSyncService syncService;

  /// Journal DB used for task/category reads while drafting.
  final JournalDb journalDb;

  /// Structured logger.
  final DomainLogger domainLogger;

  /// Callback fired when persisted state changes.
  final void Function(String id)? onPersistedStateChanged;

  final DayAgentPlanReads _reads;
  late final DayAgentPlanWriter _writer;
  late final DayAgentPlanEditor _editor;
  late final DayAgentPlanToolDispatcher _dispatcher;

  /// Executes a foundation day-plan tool.
  Future<DayAgentDirectToolResult> executeTool({
    required String agentId,
    required String threadId,
    required String runKey,
    required String toolName,
    required Map<String, dynamic> args,
  }) => _dispatcher.executeTool(
    agentId: agentId,
    threadId: threadId,
    runKey: runKey,
    toolName: toolName,
    args: args,
  );

  /// Fetch the persisted draft plan for one day.
  Future<DayPlanEntity?> draftPlanForDay({
    required String agentId,
    required String dayId,
  }) => _reads.draftPlanForDay(agentId: agentId, dayId: dayId);

  /// Pending plan-diff change sets for [agentId]'s plan on [dayId].
  Future<List<ChangeSetEntity>> pendingPlanDiffsForDay({
    required String agentId,
    required String dayId,
  }) => _editor.pendingPlanDiffsForDay(agentId: agentId, dayId: dayId);

  /// Soft-deletes the persisted plan for [dayId] and its capture links.
  Future<bool> deletePlanForDay({
    required String agentId,
    required String dayId,
  }) => _editor.deletePlanForDay(agentId: agentId, dayId: dayId);

  /// Hydrate the set of tasks the model should know about when drafting.
  Future<List<DecidedTaskRef>> hydrateDecidedTasks({
    required Set<String> allowedCategoryIds,
    List<String> explicitTaskIds = const [],
    List<ParsedItemEntity> parsedItems = const [],
  }) => _editor.hydrateDecidedTasks(
    allowedCategoryIds: allowedCategoryIds,
    explicitTaskIds: explicitTaskIds,
    parsedItems: parsedItems,
  );

  /// Persist a structured plan diff against the current plan for [dayId].
  Future<ChangeSetEntity> proposePlanDiff({
    required String agentId,
    required String threadId,
    required String runKey,
    required String dayId,
    required List<Object?> rawChanges,
    String? baselinePlanId,
    String? captureId,
  }) => _editor.proposePlanDiff(
    agentId: agentId,
    threadId: threadId,
    runKey: runKey,
    dayId: dayId,
    rawChanges: rawChanges,
    baselinePlanId: baselinePlanId,
    captureId: captureId,
  );

  /// Apply some or all changes of [changeSetId] to the live plan.
  Future<ChangeSetEntity> acceptPlanDiff({
    required String agentId,
    required String changeSetId,
    List<int>? itemIndices,
  }) => _editor.acceptPlanDiff(
    agentId: agentId,
    changeSetId: changeSetId,
    itemIndices: itemIndices,
  );

  /// Retract some or all changes of [changeSetId] without mutating the plan.
  Future<ChangeSetEntity> revertPlanDiff({
    required String agentId,
    required String changeSetId,
    List<int>? itemIndices,
  }) => _editor.revertPlanDiff(
    agentId: agentId,
    changeSetId: changeSetId,
    itemIndices: itemIndices,
  );

  /// Commit the day's draft plan.
  Future<DayPlanEntity> commitDay({
    required String agentId,
    required String dayId,
  }) => _editor.commitDay(agentId: agentId, dayId: dayId);

  /// Rename a standalone planned block in place.
  Future<DayPlanEntity> renameBlock({
    required String agentId,
    required String dayId,
    required String blockId,
    required String title,
  }) => _editor.renameBlock(
    agentId: agentId,
    dayId: dayId,
    blockId: blockId,
    title: title,
  );

  /// Revert a committed day plan back to draft.
  Future<DayPlanEntity> uncommitDay({
    required String agentId,
    required String dayId,
  }) => _editor.uncommitDay(agentId: agentId, dayId: dayId);

  /// Persist a model-emitted draft plan.
  Future<DayPlanEntity> persistDraftPlan({
    required String agentId,
    required String dayId,
    required DateTime planDate,
    required List<Object?> rawBlocks,
    String? captureId,
    List<Object?> rawEnergyBands = const [],
    List<String> decidedTaskIds = const [],
    int capacityMinutes = 480,
    String? dayLabel,
  }) => _writer.persistDraftPlan(
    agentId: agentId,
    dayId: dayId,
    planDate: planDate,
    rawBlocks: rawBlocks,
    captureId: captureId,
    rawEnergyBands: rawEnergyBands,
    decidedTaskIds: decidedTaskIds,
    capacityMinutes: capacityMinutes,
    dayLabel: dayLabel,
  );

  /// Build transient learning cards from recently drafted day plans.
  Future<List<DayAgentLearningCard>> summarizeRecentPatterns({
    required String agentId,
    required DateTime asOf,
    int lookbackDays = 7,
  }) => _writer.summarizeRecentPatterns(
    agentId: agentId,
    asOf: asOf,
    lookbackDays: lookbackDays,
  );
}
