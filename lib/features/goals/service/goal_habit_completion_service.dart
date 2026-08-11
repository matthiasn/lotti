import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';

/// Records the success or failure of a habit watched by a goal agent.
///
/// The service deliberately uses the established habit-completion persistence
/// path, preserving privacy metadata, sync notifications, and reminder
/// scheduling instead of introducing a goal-specific completion record.
class GoalHabitCompletionService {
  const GoalHabitCompletionService({
    required this.agentRepository,
    required this.journalDb,
    required this.persistenceLogic,
    required this.orchestrator,
  });

  final AgentRepository agentRepository;
  final JournalDb journalDb;
  final PersistenceLogic persistenceLogic;
  final WakeOrchestrator orchestrator;

  /// Writes [outcome] for the selected local calendar [day].
  ///
  /// Historical corrections borrow the current wall-clock time while keeping
  /// the selected calendar date. Habit-completion IDs are derived from their
  /// data, so pinning every correction to 23:59:59 made a later switch back to
  /// an earlier outcome collide with the original row and report a failed
  /// save. Write recency still comes from metadata, so the habits read path
  /// correctly resolves the newest correction for that day.
  Future<bool> record({
    required String agentId,
    required String habitId,
    required DateTime day,
    required HabitCompletionType outcome,
  }) async {
    final identity = await agentRepository.getEntity(agentId);
    if (identity is! AgentIdentityEntity ||
        identity.lifecycle != AgentLifecycle.active) {
      return false;
    }

    final habitDefinition = await journalDb.getHabitById(habitId);
    if (habitDefinition == null) return false;

    final now = clock.now();
    final selectedDay = DateTime(day.year, day.month, day.day);
    final today = DateTime(now.year, now.month, now.day);
    final activeFrom = habitDefinition.activeFrom;
    final activeUntil = habitDefinition.activeUntil;
    if (!habitDefinition.active ||
        selectedDay.isAfter(today) ||
        (activeFrom != null &&
            selectedDay.isBefore(
              DateTime(activeFrom.year, activeFrom.month, activeFrom.day),
            )) ||
        (activeUntil != null &&
            !selectedDay.isBefore(
              DateTime(activeUntil.year, activeUntil.month, activeUntil.day),
            ))) {
      return false;
    }
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final recordedAt = isToday
        ? now
        : DateTime(
            day.year,
            day.month,
            day.day,
            now.hour,
            now.minute,
            now.second,
            now.millisecond,
            now.microsecond,
          );
    final saved = await persistenceLogic.createHabitCompletionEntry(
      data: HabitCompletionData(
        habitId: habitId,
        dateFrom: recordedAt,
        dateTo: recordedAt,
        completionType: outcome,
      ),
      habitDefinition: habitDefinition,
      comment: '',
    );
    if (saved == null) return false;
    requestReportRefresh(agentId);
    return true;
  }

  /// Requests an immediate fact-grounded standing-report refresh.
  String requestReportRefresh(String agentId) => orchestrator.enqueueManualWake(
    agentId: agentId,
    reason: WakeReason.reanalysis.name,
    triggerTokens: const {goalReportRefreshTriggerToken},
    workspaceKey: goalReportRefreshTriggerToken,
  );
}

final goalHabitCompletionServiceProvider = Provider<GoalHabitCompletionService>(
  (ref) => GoalHabitCompletionService(
    agentRepository: ref.watch(agentRepositoryProvider),
    journalDb: ref.watch(journalDbProvider),
    persistenceLogic: getIt<PersistenceLogic>(),
    orchestrator: ref.watch(wakeOrchestratorProvider),
  ),
  name: 'goalHabitCompletionServiceProvider',
);
