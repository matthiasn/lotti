import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_diff.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_parser.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

part 'day_agent_plan_tool_dispatcher.dart';

part 'day_agent_plan_planning.dart';
part 'day_agent_plan_resolve.dart';

const _uuid = Uuid();

DayAgentLearningCard _gentleNudgeCard({
  required bool plansIsEmpty,
  required int averageScheduled,
  required int averageCapacity,
}) {
  if (plansIsEmpty) {
    return DayAgentLearningCard(
      id: 'gentle_nudge',
      overline: 'Gentle nudge',
      summary:
          'No recent drafts to compare against; start small and adjust as '
          'patterns emerge.',
      kind: 'nudge',
      bullets: const [
        DayAgentLearningBullet(
          text: 'Treat today as the first data point.',
          tone: DayAgentLearningBulletTone.info,
        ),
      ],
    );
  }
  final overCapacity = averageScheduled > averageCapacity;
  return DayAgentLearningCard(
    id: 'gentle_nudge',
    overline: 'Gentle nudge',
    summary: overCapacity
        ? 'Your recent drafts run over capacity; protect a buffer before '
              'adding more work.'
        : 'Your recent drafts fit capacity; place demanding work in the '
              'highest-energy window.',
    kind: 'nudge',
    bullets: [
      DayAgentLearningBullet(
        text: overCapacity
            ? 'Leave at least one transition block unassigned.'
            : 'Keep the plan specific enough to act on.',
        tone: overCapacity
            ? DayAgentLearningBulletTone.warning
            : DayAgentLearningBulletTone.positive,
      ),
    ],
  );
}

/// Backend implementation for Daily OS day-plan drafting tools.
abstract class _DayAgentPlanServiceBase {
  _DayAgentPlanServiceBase({
    required this.agentRepository,
    required this.syncService,
    required this.journalDb,
    required this.domainLogger,
    this.onPersistedStateChanged,
  });

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

  // Cross-mixin contracts implemented by the method-group mixins.
  Future<ChangeSetEntity> acceptPlanDiff({
    required String agentId,
    required String changeSetId,
    List<int>? itemIndices,
  });

  Future<CaptureEntity?> _captureOrNull(String captureId);

  Future<DayPlanEntity> commitDay({
    required String agentId,
    required String dayId,
  });

  Future<Map<String, Object?>> _draftDayPlanTool(
    String agentId,
    Map<String, dynamic> args,
  );

  Future<DayPlanEntity?> draftPlanForDay({
    required String agentId,
    required String dayId,
  });

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
  });

  Future<ChangeSetEntity> proposePlanDiff({
    required String agentId,
    required String threadId,
    required String runKey,
    required String dayId,
    required List<Object?> rawChanges,
    String? baselinePlanId,
    String? captureId,
  });

  Future<Map<String, Object?>> _proposePlanDiffTool({
    required String agentId,
    required String threadId,
    required String runKey,
    required Map<String, dynamic> args,
  });

  Future<AgentIdentityEntity> _requireIdentity(String agentId);

  Future<ChangeSetEntity> _resolvePlanDiff({
    required String agentId,
    required String changeSetId,
    required List<int>? itemIndices,
    required bool apply,
  });

  Future<ChangeSetEntity> revertPlanDiff({
    required String agentId,
    required String changeSetId,
    List<int>? itemIndices,
  });

  Future<List<DayAgentLearningCard>> summarizeRecentPatterns({
    required String agentId,
    required DateTime asOf,
    int lookbackDays = 7,
  });

  Future<Map<String, Object?>> _summarizeRecentPatternsTool(
    String agentId,
    Map<String, dynamic> args,
  );

  Future<DayPlanEntity> uncommitDay({
    required String agentId,
    required String dayId,
  });
}

class DayAgentPlanService extends _DayAgentPlanServiceBase
    with
        _DayAgentPlanToolDispatcher,
        _DayAgentPlanPlanning,
        _DayAgentPlanResolve {
  DayAgentPlanService({
    required super.agentRepository,
    required super.syncService,
    required super.journalDb,
    required super.domainLogger,
    super.onPersistedStateChanged,
  });
}
