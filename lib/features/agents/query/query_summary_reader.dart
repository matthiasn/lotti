import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';

/// A published report authorized through its owning task or project.
/// Summary text is kept distinct from original-entry evidence.
class QuerySummary {
  const QuerySummary({
    required this.owner,
    required this.title,
    required this.report,
    this.status,
  });

  final QuerySourceRef owner;
  final String title;
  final String? status;
  final AgentReportEntity report;

  /// The initial retrieval round gets the TL;DR, never the action-focused
  /// one-liner or the full report body. Missing TL;DRs stay explicitly missing.
  Map<String, Object?> get orientation => {
    'ownerId': owner.id,
    'taskId': owner.id,
    'reportId': report.id,
    'title': title,
    if (status != null) 'status': status,
    'tldr': report.tldr?.trim() ?? '',
  };

  Map<String, Object?> get fullSummary => {
    ...orientation,
    'content': report.content,
  };
}

/// One bounded discovery result. Counts describe summaries, not inspected
/// original sources; hitting a bound never implies exhaustive coverage.
class QuerySummaryCatalog {
  QuerySummaryCatalog({
    required this.scope,
    required this.categoryId,
    required Iterable<QuerySummary> tasks,
    required this.incomplete,
    this.project,
  }) : tasks = List.unmodifiable(tasks);

  final QueryScope scope;
  final String? categoryId;
  final List<QuerySummary> tasks;
  final QuerySummary? project;
  final bool incomplete;
}

/// Reads the existing maintained report layers without crawling task entries,
/// generating replacement summaries, or reconstructing source dependencies.
/// Every report inherits its owner's live visibility and category boundary.
class QuerySummaryReader {
  const QuerySummaryReader({
    required this.journal,
    required this.access,
    required this.repository,
    this.maxTasks = 200,
  }) : assert(maxTasks > 0, 'A summary discovery budget must be positive');

  final JournalDb journal;
  final QuerySourceAccess access;
  final AgentRepository repository;
  final int maxTasks;

  Future<QuerySummaryCatalog> discover(
    QueryScope scope, {
    bool homeOnly = false,
  }) async {
    final initial = await access.load([scope.id]);
    final home = initial.entries[scope.id];
    final categoryId = scope.kind == QueryScopeKind.category
        ? scope.id
        : home?.meta.categoryId;
    _requireScope(scope, categoryId, initial);

    final taskIds = <String>{if (home is Task) home.meta.id};
    String? projectId;
    if (scope.kind == QueryScopeKind.project) {
      projectId = scope.id;
      taskIds.addAll(await journal.getTaskIdsForProjects({scope.id}));
    } else if (home is Task) {
      projectId = (await journal.getProjectIdMapForTasks({scope.id}))[scope.id];
      final links = await journal.linksForEntryIdsBidirectional({scope.id});
      for (final link in links) {
        if (link.hidden == true || link.deletedAt != null) continue;
        taskIds
          ..add(link.fromId)
          ..add(link.toId);
      }
    }

    final homeTaskIds = Set<String>.of(taskIds);
    var incomplete = false;
    if (categoryId != null && (!homeOnly || home == null)) {
      // No status filter: completed tasks retain the knowledge sought by
      // retrospective questions. Scope/privacy filters precede the SQL limit.
      final candidates = await journal.getJournalEntities(
        types: const ['Task'],
        starredStatuses: const [false, true],
        privateStatuses: initial.showPrivate
            ? const [false, true]
            : const [false],
        flaggedStatuses: const [0, 1, 2, 3],
        ids: null,
        categoryIds: {categoryId},
        limit: maxTasks + 1,
      );
      incomplete = candidates.length > maxTasks;
      taskIds.addAll(candidates.map((entry) => entry.meta.id));
    }
    final owners = await access.load([
      scope.id,
      ...taskIds,
      ?projectId,
    ]);
    _requireScope(scope, categoryId, owners);
    final tasks =
        taskIds
            .map((id) => owners.entries[id])
            .whereType<Task>()
            .where(
              (task) =>
                  owners.allowsEntry(task) &&
                  task.meta.categoryId == categoryId,
            )
            .toList()
          ..sort((a, b) {
            int priority(Task task) => task.meta.id == scope.id
                ? 0
                : homeTaskIds.contains(task.meta.id)
                ? 1
                : 2;
            final byScope = priority(a).compareTo(priority(b));
            return byScope == 0 ? a.meta.id.compareTo(b.meta.id) : byScope;
          });
    incomplete = incomplete || tasks.length > maxTasks;
    final boundedTasks = tasks.take(maxTasks).toList();
    final reports = boundedTasks.isEmpty
        ? const <String, AgentReportEntity>{}
        : await repository.getLatestTaskReportsForTaskIds(
            boundedTasks.map((task) => task.meta.id).toList(),
          );
    final project = owners.entries[projectId];
    final projectReport =
        project is ProjectEntry &&
            owners.allowsEntry(project) &&
            project.meta.categoryId == categoryId
        ? await repository.getLatestProjectReportForProjectId(project.meta.id)
        : null;

    // Reads can yield across privacy changes. Recheck after report lookup,
    // before handing any text to the caller.
    final live = await access.load([
      scope.id,
      ...boundedTasks.map((task) => task.meta.id),
      ?projectId,
    ]);
    _requireScope(scope, categoryId, live);
    QuerySummary? summary(String id, AgentReportEntity? report) {
      final owner = live.entries[id];
      if (report == null ||
          report.deletedAt != null ||
          owner == null ||
          !live.allowsEntry(owner) ||
          owner.meta.categoryId != categoryId) {
        return null;
      }
      return QuerySummary(
        owner: live.reference(owner),
        title: switch (owner) {
          Task(:final data) => data.title,
          ProjectEntry(:final data) => data.title,
          _ => throw const QueryScopeUnavailable(),
        },
        status: owner is Task ? owner.data.status.toDbString : null,
        report: report,
      );
    }

    final summaries = <QuerySummary>[];
    for (final task in boundedTasks) {
      final item = summary(task.meta.id, reports[task.meta.id]);
      if (item == null) {
        incomplete = true;
      } else {
        summaries.add(item);
      }
    }
    return QuerySummaryCatalog(
      scope: scope,
      categoryId: categoryId,
      tasks: summaries,
      project: projectId == null ? null : summary(projectId, projectReport),
      incomplete: incomplete,
    );
  }

  /// Full bodies are available only for task IDs from this discovery result.
  /// Unknown/model-invented IDs never trigger another lookup or a raw crawl.
  /// The same published revision supplies both layers within this operation.
  Future<List<QuerySummary>> fullSummaries(
    QuerySummaryCatalog catalog,
    Iterable<String> taskIds,
  ) async {
    final requested = taskIds.toSet();
    final selected = catalog.tasks
        .where((summary) => requested.contains(summary.owner.id))
        .toList();
    if (selected.length != requested.length) {
      throw const FormatException('Unknown summary task');
    }
    await authorize(catalog, selected);
    return selected;
  }

  /// Rechecks owner-level permissions before an inference or publication.
  /// Reports are maintained artifacts; underlying entry dependencies are not
  /// reconstructed or fetched by query chat.
  Future<void> authorize(
    QuerySummaryCatalog catalog,
    Iterable<QuerySummary> selected,
  ) async {
    final current = await access.load([
      catalog.scope.id,
      ...selected.map((summary) => summary.owner.id),
    ]);
    _requireScope(catalog.scope, catalog.categoryId, current);
    for (final summary in selected) {
      final owner = current.entries[summary.owner.id];
      if (owner == null ||
          !current.allowsEntry(owner) ||
          owner.meta.categoryId != catalog.categoryId) {
        throw const QueryScopeUnavailable();
      }
    }
  }

  static void _requireScope(
    QueryScope scope,
    String? categoryId,
    QueryAccessSnapshot access,
  ) {
    final home = access.entries[scope.id];
    if (!access.allowsCategory(categoryId) ||
        (scope.kind != QueryScopeKind.category &&
            (home == null ||
                !access.allowsEntry(home) ||
                home.meta.categoryId != categoryId))) {
      throw const QueryScopeUnavailable();
    }
  }
}
