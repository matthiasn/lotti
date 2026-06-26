import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_knowledge_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_week_context_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';

/// The Daily OS day-agent service.
final dayAgentServiceProvider = Provider<DayAgentService>(
  dayAgentService,
  name: 'dayAgentServiceProvider',
);
DayAgentService dayAgentService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return DayAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// The Daily OS day-agent capture/reconcile service.
final dayAgentCaptureServiceProvider = Provider<DayAgentCaptureService>(
  dayAgentCaptureService,
  name: 'dayAgentCaptureServiceProvider',
);
DayAgentCaptureService dayAgentCaptureService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return DayAgentCaptureService(
    agentRepository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    journalDb: ref.watch(journalDbProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    fts5Db: getIt<Fts5Db>(),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// The Daily OS durable-knowledge service (ADR 0022).
final dayAgentKnowledgeServiceProvider = Provider<DayAgentKnowledgeService>(
  dayAgentKnowledgeService,
  name: 'dayAgentKnowledgeServiceProvider',
);
DayAgentKnowledgeService dayAgentKnowledgeService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return DayAgentKnowledgeService(
    agentRepository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// The Daily OS week-context service: lookback/lookahead prompt sections and
/// the `write_day_summary` tool backend.
final dayAgentWeekContextServiceProvider = Provider<DayAgentWeekContextService>(
  dayAgentWeekContextService,
  name: 'dayAgentWeekContextServiceProvider',
);
DayAgentWeekContextService dayAgentWeekContextService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return DayAgentWeekContextService(
    agentRepository: ref.watch(agentRepositoryProvider),
    journalDb: ref.watch(journalDbProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// The Daily OS day-agent drafting service.
final dayAgentPlanServiceProvider = Provider<DayAgentPlanService>(
  dayAgentPlanService,
  name: 'dayAgentPlanServiceProvider',
);
DayAgentPlanService dayAgentPlanService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return DayAgentPlanService(
    agentRepository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    journalDb: ref.watch(journalDbProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// Fetch the active Daily OS day agent for date, if one exists.
final FutureProviderFamily<AgentDomainEntity?, DateTime> dayAgentProvider =
    FutureProvider.autoDispose.family<AgentDomainEntity?, DateTime>(
      dayAgent,
      name: 'dayAgentProvider',
    );
Future<AgentDomainEntity?> dayAgent(
  Ref ref,
  DateTime date,
) async {
  final dayId = dayAgentIdForDate(date);
  ref.watch(agentUpdateStreamProvider(dayId));
  final service = ref.watch(dayAgentServiceProvider);
  return service.getDayAgentForDate(date);
}

/// Stream-refreshed parsed items for one capture.
final FutureProviderFamily<List<AgentDomainEntity>, String>
parsedItemsForCaptureProvider = FutureProvider.autoDispose
    .family<List<AgentDomainEntity>, String>(
      parsedItemsForCapture,
      name: 'parsedItemsForCaptureProvider',
    );
Future<List<AgentDomainEntity>> parsedItemsForCapture(
  Ref ref,
  String captureId,
) async {
  final service = ref.watch(dayAgentCaptureServiceProvider);
  final capture = await service.getCapture(captureId);
  if (capture != null) {
    ref.watch(agentUpdateStreamProvider(capture.agentId));
  }
  return service.parsedItemsForCapture(captureId);
}

/// Pending reconcile decisions for date.
final FutureProviderFamily<List<DayAgentPendingItem>, DateTime>
pendingDecisionsForDateProvider = FutureProvider.autoDispose
    .family<List<DayAgentPendingItem>, DateTime>(
      pendingDecisionsForDate,
      name: 'pendingDecisionsForDateProvider',
    );
Future<List<DayAgentPendingItem>> pendingDecisionsForDate(
  Ref ref,
  DateTime date,
) async {
  final dayId = dayAgentIdForDate(date);
  final dayAgentService = ref.watch(dayAgentServiceProvider);
  final captureService = ref.watch(dayAgentCaptureServiceProvider);
  ref.watch(agentUpdateStreamProvider(dayId));

  final agent = await dayAgentService.getDayAgentForDate(date);
  if (agent == null) return const [];
  return captureService.surfacePendingDecisions(
    agentId: agent.agentId,
    dayId: dayId,
  );
}

/// Currently drafted day plan for date, if any.
///
/// Returns the base [AgentDomainEntity] to match the repository surface.
/// Consumers should unwrap via `mapOrNull(dayPlan: (e) => e)` to get the typed
/// [DayPlanEntity] view.
final FutureProviderFamily<AgentDomainEntity?, DateTime>
draftedPlanForDateProvider = FutureProvider.autoDispose
    .family<AgentDomainEntity?, DateTime>(
      draftedPlanForDate,
      name: 'draftedPlanForDateProvider',
    );
Future<AgentDomainEntity?> draftedPlanForDate(
  Ref ref,
  DateTime date,
) async {
  final dayId = dayAgentIdForDate(date);
  final dayAgentService = ref.watch(dayAgentServiceProvider);
  final planService = ref.watch(dayAgentPlanServiceProvider);
  ref.watch(agentUpdateStreamProvider(dayId));

  final agent = await dayAgentService.getDayAgentForDate(date);
  if (agent == null) return null;
  return planService.draftPlanForDay(
    agentId: agent.agentId,
    dayId: dayId,
  );
}
