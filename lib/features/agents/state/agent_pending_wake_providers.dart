import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';

final pendingWakeRecordsProvider = FutureProvider<List<PendingWakeRecord>>((
  ref,
) async {
  ref.watch(agentUpdateStreamProvider(agentNotification));

  final agentService = ref.watch(agentServiceProvider);
  final repository = ref.watch(agentRepositoryProvider);
  final identities = await agentService.listAgents();
  final statesByAgentId = await repository.getAgentStatesByAgentIds(
    identities.map((identity) => identity.agentId).toList(),
  );

  final records = <PendingWakeRecord>[];
  for (final identity in identities) {
    final state = statesByAgentId[identity.agentId];
    if (state == null || state.deletedAt != null) {
      continue;
    }

    final nextWakeAt = state.nextWakeAt;
    if (nextWakeAt != null) {
      records.add(
        PendingWakeRecord(
          agent: identity,
          state: state,
          type: PendingWakeType.pending,
          dueAt: nextWakeAt,
        ),
      );
    }

    final scheduledWakeAt = state.scheduledWakeAt;
    if (scheduledWakeAt != null) {
      records.add(
        PendingWakeRecord(
          agent: identity,
          state: state,
          type: PendingWakeType.scheduled,
          dueAt: scheduledWakeAt,
        ),
      );
    }
  }

  records.sort((a, b) => a.dueAt.compareTo(b.dueAt));
  return records;
});

final StreamProviderFamily<void, String> _entryUpdateProvider = StreamProvider
    .autoDispose
    .family<void, String>((
      ref,
      entryId,
    ) {
      final notifications = ref.watch(updateNotificationsProvider);
      return notifications.updateStream
          .where((ids) => ids.contains(entryId))
          .map<void>((_) {});
    });

final FutureProviderFamily<String?, String?> pendingWakeTargetTitleProvider =
    FutureProvider.family<String?, String?>((
      ref,
      String? entryId,
    ) async {
      if (entryId == null || entryId.isEmpty) {
        return null;
      }

      ref.watch(_entryUpdateProvider(entryId));

      final journalDb = ref.watch(journalDbProvider);
      final entry = await journalDb.journalEntityById(entryId);

      final raw = switch (entry) {
        Task(:final data) => data.title,
        ProjectEntry(:final data) => data.title,
        _ => null,
      };
      // Treat empty / whitespace titles as "no title" so callers can fall
      // through to the agent's display-name fallback rather than rendering
      // a blank row.
      final trimmed = raw?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    });

/// Snapshot of currently-running agent wake instances paired with the
/// linked task / project title the agent is acting on. Falls back to
/// the agent's own displayName when the agent has no linked subject
/// (e.g. an improver agent), and finally to the agentId so the row
/// never renders empty.
///
/// [title] is the resolved-at-snapshot title — fine as a one-shot read,
/// but it does NOT update when the underlying task is renamed because
/// `ongoingWakeRecordsProvider` only re-runs on running-set changes.
/// Renderers that want a live title should watch
/// [pendingWakeTargetTitleProvider] for [subjectId] and fall back to
/// [title] when that returns null or empty.
class OngoingWakeRecord {
  const OngoingWakeRecord({
    required this.agentId,
    required this.title,
    required this.startedAt,
    this.subjectId,
  });

  final String agentId;
  final String title;

  /// The active task or project ID the agent is operating on, when one
  /// exists. Lets renderers subscribe to [pendingWakeTargetTitleProvider]
  /// so a rename of the linked entry refreshes the row title without the
  /// running set churning.
  final String? subjectId;
  final DateTime startedAt;

  String get id => 'ongoing:$agentId';
}

/// Stream over `WakeRunner.runningAgentIds` used to invalidate
/// `ongoingWakeRecordsProvider` whenever the set of active agents
/// changes. Kept private so callers reach for the structured record
/// list above instead of the raw IDs.
final StreamProvider<Set<String>> _runningAgentIdsStreamProvider =
    StreamProvider.autoDispose<Set<String>>((ref) {
      final runner = ref.watch(wakeRunnerProvider);
      return runner.runningAgentIds;
    });

/// Currently-running wakes with their start timestamps and a
/// human-readable title. Re-emits whenever the WakeRunner's running
/// set changes. Per-agent title lookups (state → subject → journal
/// title, then agent display-name as fallback) run in parallel via
/// `Future.wait`.
final FutureProvider<List<OngoingWakeRecord>> ongoingWakeRecordsProvider =
    FutureProvider.autoDispose<List<OngoingWakeRecord>>((ref) async {
      final runner = ref.watch(wakeRunnerProvider);
      // Watching the stream provider re-runs this Future automatically
      // whenever the WakeRunner's running set changes — no manual
      // `invalidateSelf` needed.
      ref.watch(_runningAgentIdsStreamProvider);

      final startedById = runner.activeStartedAtById;
      if (startedById.isEmpty) return const <OngoingWakeRecord>[];

      final service = ref.watch(agentServiceProvider);
      final repository = ref.watch(agentRepositoryProvider);

      final futures = startedById.entries.map(
        (entry) => _resolveOngoingRecord(
          ref,
          service,
          repository,
          entry.key,
          entry.value,
        ),
      );
      final results = await Future.wait(futures);
      results.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      return results;
    });

Future<OngoingWakeRecord> _resolveOngoingRecord(
  Ref ref,
  AgentService service,
  AgentRepository repository,
  String agentId,
  DateTime startedAt,
) async {
  String? title;
  String? resolvedSubjectId;
  try {
    final stateEntity = await repository.getAgentState(agentId);
    final slots = stateEntity?.mapOrNull(agentState: (s) => s.slots);

    // Try task first, then project. Earlier code chose `activeTaskId
    // ?? activeProjectId` and stopped — so an agent whose task ID
    // pointed at a missing/blank entry never tried its project ID and
    // collapsed all the way to the agent's displayName ("Task Agent").
    // Falling through to the project-title lookup recovers that path
    // without abandoning the task-first preference.
    for (final candidate in <String?>[
      slots?.activeTaskId,
      slots?.activeProjectId,
    ]) {
      if (candidate == null || candidate.isEmpty) continue;
      // `ref.read(...).future` rather than `ref.watch(...)` — `watch`
      // would attempt to register a dependency after an `await`, which
      // Riverpod doesn't support inside async provider bodies. Live
      // title updates after the snapshot are surfaced by the renderer
      // re-watching pendingWakeTargetTitleProvider for the recorded
      // subjectId.
      final candidateTitle = await ref.read(
        pendingWakeTargetTitleProvider(candidate).future,
      );
      if (candidateTitle != null && candidateTitle.isNotEmpty) {
        title = candidateTitle;
        resolvedSubjectId = candidate;
        break;
      }
      // Even when a candidate ID didn't yield a usable title right now,
      // keep the first non-empty ID so the renderer can re-watch it and
      // pick up a future rename that promotes a previously-blank task
      // into a usable title.
      resolvedSubjectId ??= candidate;
    }
  } catch (_) {
    // Subject lookup is best-effort — fall through to the agent
    // display-name below.
  }

  if (title == null || title.isEmpty) {
    try {
      final identity = await service.getAgent(agentId);
      if (identity is AgentIdentityEntity) {
        title = identity.displayName.trim();
      }
    } catch (_) {
      // Display-name lookup is also best-effort; falls through to
      // `agentId` below so a single bad lookup can't fail the whole
      // running-wakes provider via `Future.wait`.
    }
  }

  return OngoingWakeRecord(
    agentId: agentId,
    title: title != null && title.isNotEmpty ? title : agentId,
    subjectId: resolvedSubjectId,
    startedAt: startedAt,
  );
}

final hourlyWakeActivityProvider = FutureProvider<List<HourlyWakeActivity>>((
  ref,
) async {
  ref.watch(agentUpdateStreamProvider(agentNotification));

  final repository = ref.watch(agentRepositoryProvider);
  final now = clock.now();
  final currentHour = DateTime(now.year, now.month, now.day, now.hour);
  final since = currentHour.subtract(const Duration(hours: 23));
  final runs = await repository.getWakeRunsInWindow(since: since, until: now);

  final buckets = <DateTime, Map<String, int>>{};
  for (final run in runs) {
    final created = run.createdAt.toLocal();
    final hourKey = DateTime(
      created.year,
      created.month,
      created.day,
      created.hour,
    );
    final reasons = buckets.putIfAbsent(hourKey, () => <String, int>{});
    reasons[run.reason] = (reasons[run.reason] ?? 0) + 1;
  }

  final result = <HourlyWakeActivity>[];
  for (var i = 23; i >= 0; i--) {
    final hourStart = currentHour.subtract(Duration(hours: i));
    final reasons = buckets[hourStart] ?? const {};
    final count = reasons.values.fold<int>(0, (sum, c) => sum + c);
    result.add(
      HourlyWakeActivity(hour: hourStart, count: count, reasons: reasons),
    );
  }
  return result;
});
