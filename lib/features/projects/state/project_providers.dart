// ignore_for_file: specify_nonobvious_property_types

import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/projects_overview_models.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';

/// Provider that fetches projects for a category and auto-rebuilds on changes.
final projectsForCategoryProvider = FutureProvider.autoDispose
    .family<List<ProjectEntry>, String>((ref, categoryId) async {
      final repository = ref.watch(projectRepositoryProvider);

      // Rebuild when any project-related notification fires.
      final sub = repository.updateStream
          .where((ids) => ids.contains(projectNotification))
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);

      return repository.getProjectsForCategory(categoryId);
    });

/// Provider that returns the latest agent-authored health metrics for a
/// project, parsed from its most recent project-agent report.
final projectHealthMetricsProvider = FutureProvider.autoDispose
    .family<ProjectHealthMetrics?, String>((
      ref,
      projectId,
    ) async {
      final agentEntity = await ref.watch(
        projectAgentProvider(projectId).future,
      );
      final identity = switch (agentEntity) {
        final AgentIdentityEntity value => value,
        _ => null,
      };
      if (identity == null) return null;

      final reportEntity = await ref.watch(
        agentReportProvider(identity.agentId).future,
      );
      final report = switch (reportEntity) {
        final AgentReportEntity value => value,
        _ => null,
      };
      if (report == null) return null;

      return projectHealthMetricsFromReport(report);
    });

/// Provider that fetches the project a task belongs to.
final projectForTaskProvider = FutureProvider.autoDispose
    .family<ProjectEntry?, String>((ref, taskId) async {
      final repository = ref.watch(projectRepositoryProvider);

      final sub = repository.updateStream
          .where(
            (ids) => ids.contains(taskId) || ids.contains(projectNotification),
          )
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);

      return repository.getProjectForTask(taskId);
    });

/// Keep-alive filter controller for the top-level projects tab.
final projectsFilterControllerProvider =
    NotifierProvider<ProjectsFilterController, ProjectsFilter>(
      ProjectsFilterController.new,
    );

/// Holds the live Projects-tab filter ([ProjectsFilter]) and exposes targeted
/// mutators for the status/category chips, the search field, and the filter
/// sheet.
///
/// The provider is kept alive (not auto-disposed) so filter selections survive
/// navigation away from and back to the tab. [visibleProjectGroupsProvider]
/// re-applies this state to the raw overview snapshot whenever it changes.
class ProjectsFilterController extends Notifier<ProjectsFilter> {
  @override
  ProjectsFilter build() => const ProjectsFilter(
    selectedStatusIds: currentProjectStatusFilterIds,
  );

  ProjectsFilter get filter => state;

  set filter(ProjectsFilter filter) {
    state = filter;
  }

  void setSelectedStatusIds(Set<String> statusIds) {
    state = state.copyWith(selectedStatusIds: statusIds);
  }

  void setSelectedCategoryIds(Set<String> categoryIds) {
    state = state.copyWith(selectedCategoryIds: categoryIds);
  }

  void setSortMode(ProjectsSortMode sortMode) {
    state = state.copyWith(sortMode: sortMode);
  }

  void setOnlyOutOfDate({required bool onlyOutOfDate}) {
    state = state.copyWith(onlyOutOfDate: onlyOutOfDate);
  }

  /// Clears every narrowing filter back to the current-work scope. The
  /// profile pill is a display preference, not a filter, so it survives.
  void resetToCurrent() {
    state = ProjectsFilter(
      selectedStatusIds: currentProjectStatusFilterIds,
      showInferenceProfile: state.showInferenceProfile,
    );
  }

  /// Updates the search text and derives the [ProjectsSearchMode]: an empty
  /// (whitespace-only) query disables text matching, otherwise it switches to
  /// in-memory `localText` substring matching.
  void setTextQuery(String textQuery) {
    final normalizedQuery = textQuery.trim();
    state = state.copyWith(
      textQuery: textQuery,
      searchMode: normalizedQuery.isEmpty
          ? ProjectsSearchMode.disabled
          : ProjectsSearchMode.localText,
    );
  }
}

/// The agent-derived fields of one overview row, as last loaded successfully.
typedef _ProjectAgentSidecar = ({
  String? oneLiner,
  bool hasProjectAgent,
  String? inferenceProfileName,
  bool inferenceProfileMissing,
  bool inferenceProfileLoaded,
  bool reportStale,
});

/// Last successfully loaded agent sidecars, keyed by project id.
final _projectAgentSidecarCacheProvider =
    Provider<Map<String, _ProjectAgentSidecar>>(
      (ref) => <String, _ProjectAgentSidecar>{},
    );

/// Emits only shared agent-update batches that concern project agents.
///
/// Agent writes publish a shared [agentNotification] alongside affected IDs.
/// Resolving those IDs in one batch keeps unrelated task, event, day, and
/// improver agent activity from rebuilding the complete Projects overview.
final projectAgentOverviewUpdateStreamProvider =
    StreamProvider.autoDispose<Set<String>>((ref) async* {
      final notifications = ref.watch(updateNotificationsProvider);
      final agentRepository = ref.watch(agentRepositoryProvider);
      await for (final ids in notifications.updateStream.where(
        (ids) => ids.contains(agentNotification),
      )) {
        final affectedIds = ids.where((id) => id != agentNotification).toSet();
        if (affectedIds.isEmpty) continue;
        if (affectedIds.contains(AgentNotificationScopes.projectOverview)) {
          yield ids;
          continue;
        }

        try {
          final entities = await agentRepository.getEntitiesByIds(affectedIds);
          final concernsProjectAgent = entities.values.any(
            (entity) =>
                entity is AgentIdentityEntity &&
                entity.kind == AgentKinds.projectAgent,
          );
          if (concernsProjectAgent) yield ids;
        } catch (error, stackTrace) {
          // Missing an update would leave a stale one-liner indefinitely.
          // On the rare lookup failure, prefer one conservative refresh.
          developer.log(
            'Failed to scope agent update for the Projects overview',
            name: 'projectAgentOverviewUpdateStreamProvider',
            error: error,
            stackTrace: stackTrace,
          );
          yield ids;
        }
      }
    });

/// Raw grouped projects snapshot for the top-level tab, with each row's
/// project-agent sidecar (one-liner and assigned inference profile) attached
/// in one batch.
///
/// The inference profiles are only looked up while the list shows them
/// ([ProjectsFilter.showInferenceProfile]); flipping that switch reloads the
/// snapshot, which keeps the list on screen while it does.
final projectsOverviewProvider =
    StreamProvider.autoDispose<ProjectsOverviewSnapshot>((ref) {
      final repository = ref.watch(projectRepositoryProvider);
      final agentRepository = ref.watch(agentRepositoryProvider);
      final aiConfigRepository = ref.watch(aiConfigRepositoryProvider);
      final sidecarCache = ref.watch(_projectAgentSidecarCacheProvider);
      final includeInferenceProfiles = ref.watch(
        projectsFilterControllerProvider.select(
          (filter) => filter.showInferenceProfile,
        ),
      );
      ref.watch(projectAgentOverviewUpdateStreamProvider);
      if (includeInferenceProfiles) {
        _reloadOnProfileNameChanges(ref, aiConfigRepository);
      }
      return repository
          .watchProjectsOverview(query: const ProjectsQuery())
          .asyncMap(
            (snapshot) async {
              try {
                final enriched = await _attachProjectAgentSidecars(
                  snapshot,
                  agentRepository,
                  includeInferenceProfiles ? aiConfigRepository : null,
                );
                _replaceProjectAgentSidecarCache(sidecarCache, enriched);
                return enriched;
              } catch (error, stackTrace) {
                // Agent sidecars are optional enrichment. A failed read must
                // not replace the established list with an error.
                developer.log(
                  'Failed to attach project agent sidecars',
                  name: 'projectsOverviewProvider',
                  error: error,
                  stackTrace: stackTrace,
                );
                return _restoreCachedProjectAgentSidecars(
                  snapshot,
                  sidecarCache,
                );
              }
            },
          );
    });

/// Reloads the overview when an inference profile is renamed, added or
/// deleted — locally or by sync — while the list shows profile names.
///
/// Profile edits emit no project or agent notification, so without this a
/// renamed profile kept its old name and a deleted one never turned into the
/// missing-profile warning. The first emission is the baseline; only a change
/// in the id → name map reloads, so edits to a profile's model slots do not.
void _reloadOnProfileNameChanges(Ref ref, AiConfigRepository repository) {
  Map<String, String>? baseline;
  final subscription = repository.watchProfiles().listen(
    (profiles) {
      final names = {for (final profile in profiles) profile.id: profile.name};
      final previous = baseline;
      baseline = names;
      if (previous != null &&
          !const MapEquality<String, String>().equals(previous, names)) {
        ref.invalidateSelf();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      developer.log(
        'Failed to watch inference profiles for the Projects overview',
        name: 'projectsOverviewProvider',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
  ref.onDispose(subscription.cancel);
}

Iterable<ProjectListItemData> _overviewItems(
  ProjectsOverviewSnapshot snapshot,
) => snapshot.groups.expand((group) => group.projects);

ProjectsOverviewSnapshot _mapOverviewItems(
  ProjectsOverviewSnapshot snapshot,
  ProjectListItemData Function(ProjectListItemData item) transform,
) {
  return ProjectsOverviewSnapshot(
    groups: [
      for (final group in snapshot.groups)
        group.copyWith(
          projects: [for (final item in group.projects) transform(item)],
        ),
    ],
  );
}

void _replaceProjectAgentSidecarCache(
  Map<String, _ProjectAgentSidecar> cache,
  ProjectsOverviewSnapshot snapshot,
) {
  cache
    ..clear()
    ..addEntries(
      _overviewItems(snapshot).map(
        (item) => MapEntry(item.project.meta.id, (
          oneLiner: item.oneLiner,
          hasProjectAgent: item.hasProjectAgent,
          inferenceProfileName: item.inferenceProfileName,
          inferenceProfileMissing: item.inferenceProfileMissing,
          inferenceProfileLoaded: item.inferenceProfileLoaded,
          reportStale: item.reportStale,
        )),
      ),
    );
}

ProjectsOverviewSnapshot _restoreCachedProjectAgentSidecars(
  ProjectsOverviewSnapshot snapshot,
  Map<String, _ProjectAgentSidecar> cache,
) {
  return _mapOverviewItems(snapshot, (item) {
    final cached = cache[item.project.meta.id];
    if (cached == null) return item;
    return item.withAgentSidecar(
      oneLiner: cached.oneLiner ?? item.oneLiner,
      hasProjectAgent: cached.hasProjectAgent,
      inferenceProfileName: cached.inferenceProfileName,
      inferenceProfileMissing: cached.inferenceProfileMissing,
      // A sidecar cached while profiles were not looked up stays unloaded, so
      // its empty profile fields never render as "no inference profile".
      inferenceProfileLoaded: cached.inferenceProfileLoaded,
      reportStale: cached.reportStale,
    );
  });
}

/// Attaches each row's agent sidecar. The inference profiles are resolved only
/// when [aiConfigRepository] is given; without it every profile field stays
/// empty.
Future<ProjectsOverviewSnapshot> _attachProjectAgentSidecars(
  ProjectsOverviewSnapshot snapshot,
  AgentRepository agentRepository,
  AiConfigRepository? aiConfigRepository,
) async {
  final projectIds = [
    for (final item in _overviewItems(snapshot)) item.project.meta.id,
  ];
  if (projectIds.isEmpty) return snapshot;

  final linksByProjectId = await agentRepository.getLinksToMultiple(
    projectIds,
    type: AgentLinkTypes.agentProject,
  );
  final agentIdsByProjectId = <String, String>{};
  for (final entry in linksByProjectId.entries) {
    if (entry.value.isEmpty) continue;
    agentIdsByProjectId[entry.key] = entry.value.selectPrimary().fromId;
  }
  final agentIds = agentIdsByProjectId.values.toSet().toList(growable: false);
  if (agentIds.isEmpty) return snapshot;

  final (reportsByAgentId, statesByAgentId, profileNamesByAgentId) = await (
    agentRepository.getLatestReportsByAgentIds(
      agentIds,
      AgentReportScopes.current,
    ),
    agentRepository.getAgentStatesByAgentIds(agentIds),
    aiConfigRepository == null
        ? Future.value(const <String, String?>{})
        : _assignedProfileNamesByAgentId(
            agentIds,
            agentRepository,
            aiConfigRepository,
          ),
  ).wait;
  return _mapOverviewItems(snapshot, (item) {
    final agentId = agentIdsByProjectId[item.project.meta.id];
    final profileName = profileNamesByAgentId[agentId];
    return item.withAgentSidecar(
      oneLiner: reportsByAgentId[agentId]?.oneLiner?.trim(),
      hasProjectAgent: agentId != null,
      inferenceProfileName: profileName,
      inferenceProfileMissing:
          profileName == null && profileNamesByAgentId.containsKey(agentId),
      inferenceProfileLoaded: aiConfigRepository != null,
      reportStale: statesByAgentId[agentId]?.isReportStale ?? false,
    );
  });
}

/// Names of the inference profiles [agentIds] are explicitly assigned.
///
/// An agent without an assigned profile is absent from the result. An agent
/// whose assigned id no longer resolves to an inference profile — deleted, or
/// some other config — maps to `null`: it is assigned, but nothing can run.
/// Profile reads go through the repository's per-id cache, so a shared
/// profile is fetched once.
Future<Map<String, String?>> _assignedProfileNamesByAgentId(
  List<String> agentIds,
  AgentRepository agentRepository,
  AiConfigRepository aiConfigRepository,
) async {
  final entities = await agentRepository.getEntitiesByIds(agentIds);
  final profileIdsByAgentId = <String, String>{
    for (final entity in entities.values)
      if (entity case final AgentIdentityEntity identity)
        if (identity.config.assignedProfileId case final String profileId)
          identity.agentId: profileId,
  };
  final profileIds = profileIdsByAgentId.values.toSet().toList();
  final configs = await Future.wait(
    profileIds.map(aiConfigRepository.getConfigById),
  );
  final profileNamesById = <String, String>{
    for (final config in configs)
      if (config case final AiConfigInferenceProfile profile)
        profile.id: profile.name,
  };
  return <String, String?>{
    for (final MapEntry(key: agentId, value: profileId)
        in profileIdsByAgentId.entries)
      agentId: profileNamesById[profileId],
  };
}

/// Applies the provider-layer filtering model to the raw snapshot.
///
/// Stale-while-revalidate: while the overview reloads — every relevant agent
/// update rebuilds it — the last snapshot stays on screen until the new one
/// arrives, and an error after a loaded snapshot keeps that snapshot. Only a
/// first load with nothing to show yet is loading or an error. This is
/// deliberately not `whenData`, which turns a reload into a bare loading state
/// and drops the previous value, so the list would blink out on every update.
final visibleProjectGroupsProvider =
    Provider.autoDispose<AsyncValue<List<ProjectCategoryGroup>>>((ref) {
      final overviewAsync = ref.watch(projectsOverviewProvider);
      final filter = ref.watch(projectsFilterControllerProvider);

      return switch (overviewAsync) {
        AsyncValue(:final value?) => AsyncData(
          applyProjectsFilter(value, filter),
        ),
        AsyncError(:final error, :final stackTrace) => AsyncError(
          error,
          stackTrace,
        ),
        _ => const AsyncLoading(),
      };
    });
