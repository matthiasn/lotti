import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/service/open_task_corpus.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/utils/day_agent_capture_helpers.dart';

/// What the front agent may see (the owner's decision 4: narrow by default).
///
/// [categoryIds] is the allow-list every category-scoped kind — tasks,
/// projects, people — filters through; empty means unrestricted, the
/// `categoryAllowed` convention. Goals carry no category and are the user's
/// own, so they are listed whenever [includeGoals]; people are listed only
/// when [includePeople], a separate opt-in.
class FrontRoutingScope {
  const FrontRoutingScope({
    this.categoryIds = const {},
    this.includeGoals = true,
    this.includePeople = false,
  });

  final Set<String> categoryIds;
  final bool includeGoals;
  final bool includePeople;
}

/// Builds the routing index from existing reads — no model call, no raw
/// entries: titles, statuses, due dates and the owner agents' one-liners
/// and TL;DRs.
class FrontRoutingIndexBuilder {
  const FrontRoutingIndexBuilder({
    required this.journalDb,
    required this.agentRepository,
    this.fts5Db,
  });

  final JournalDb journalDb;
  final AgentRepository agentRepository;

  /// Null when no full-text index is wired; `match_to_corpus` is then
  /// unavailable for the turn.
  final Fts5Db? fts5Db;

  Future<FrontRoutingIndex> build({
    required FrontRoutingScope scope,
    required DateTime now,
  }) async {
    final tasks = await _tasks(scope, now);
    final projects = await _projects(scope);
    final goals = scope.includeGoals ? await _goals() : const <FrontIndexRow>[];
    final people = scope.includePeople
        ? await _people(scope)
        : const <FrontIndexRow>[];
    return FrontRoutingIndex(
      tasks: tasks,
      tasksTruncated: tasks.length >= frontIndexMaxTasks,
      projects: projects.take(frontIndexMaxProjects).toList(),
      omittedProjects: _omitted(projects.length, frontIndexMaxProjects),
      goals: goals.take(frontIndexMaxGoals).toList(),
      omittedGoals: _omitted(goals.length, frontIndexMaxGoals),
      people: people.take(frontIndexMaxPeople).toList(),
      omittedPeople: _omitted(people.length, frontIndexMaxPeople),
    );
  }

  /// A matcher over the open tasks inside [scope]: the phrase in, the index
  /// rows the turn may now route to out. Null when no full-text index is
  /// wired.
  Future<List<FrontIndexRow>> Function(String phrase)? corpusMatcher(
    FrontRoutingScope scope,
  ) {
    final fts = fts5Db;
    if (fts == null) return null;
    return (phrase) async {
      final matches = await matchOpenTasksByPhrase(
        fts5Db: fts,
        journalDb: journalDb,
        phrase: phrase,
        categoryFilter: scope.categoryIds,
        limit: frontCorpusMatchLimit,
      );
      final reports = await agentRepository.getLatestTaskReportsForTaskIds([
        for (final match in matches) match.task.id,
      ]);
      return [
        for (final match in matches)
          _taskRow(match.task, reports[match.task.id]),
      ];
    };
  }

  static int _omitted(int total, int cap) => total > cap ? total - cap : 0;

  Future<List<FrontIndexRow>> _tasks(
    FrontRoutingScope scope,
    DateTime now,
  ) async {
    final tasks = await readOpenTaskCorpus(
      journalDb: journalDb,
      allowedCategoryIds: scope.categoryIds,
      day: now,
      limit: frontIndexMaxTasks,
    );
    final reports = await agentRepository.getLatestTaskReportsForTaskIds([
      for (final task in tasks) task.id,
    ]);
    return [for (final task in tasks) _taskRow(task, reports[task.id])];
  }

  static FrontIndexRow _taskRow(Task task, AgentReportEntity? report) =>
      FrontIndexRow(
        kind: FrontDestinationKind.task,
        id: task.id,
        title: task.data.title,
        status: task.data.status.toDbString,
        categoryId: task.meta.categoryId,
        due: task.data.due,
        oneLiner: report?.oneLiner,
        tldr: report?.tldr,
      );

  /// Visible projects in the allow-list, most recently updated first, with
  /// the primary project agent's report where one exists.
  Future<List<FrontIndexRow>> _projects(FrontRoutingScope scope) async {
    final projects =
        (await journalDb.getVisibleProjects())
            .where((p) => categoryAllowed(p.meta.categoryId, scope.categoryIds))
            .toList()
          ..sort((a, b) => b.meta.updatedAt.compareTo(a.meta.updatedAt));
    final linksByProjectId = await agentRepository.getLinksToMultiple(
      [for (final project in projects) project.id],
      type: AgentLinkTypes.agentProject,
    );
    final agentIdByProjectId = <String, String>{
      for (final entry in linksByProjectId.entries)
        if (entry.value.isNotEmpty)
          entry.key: entry.value.selectPrimary().fromId,
    };
    final reports = await agentRepository.getLatestReportsByAgentIds(
      agentIdByProjectId.values.toSet().toList(),
      AgentReportScopes.current,
    );
    return [
      for (final project in projects)
        FrontIndexRow(
          kind: FrontDestinationKind.project,
          id: project.id,
          title: project.data.title,
          categoryId: project.meta.categoryId,
          oneLiner: reports[agentIdByProjectId[project.id]]?.oneLiner,
          tldr: reports[agentIdByProjectId[project.id]]?.tldr,
        ),
    ];
  }

  /// Active goal agents, their statement from the spec head, most recently
  /// updated first.
  Future<List<FrontIndexRow>> _goals() async {
    final identities =
        (await agentRepository.getAgentIdentitiesByLifecycle(
            AgentLifecycle.active,
          )).where((identity) => identity.kind == AgentKinds.goalAgent).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (identities.isEmpty) return const [];
    final agentIds = [for (final identity in identities) identity.agentId];
    final heads = await agentRepository.getEntitiesByIds({
      for (final agentId in agentIds) goalSpecHeadId(agentId),
    });
    final versionIdByAgentId = <String, String>{
      for (final entity in heads.values)
        if (entity is GoalSpecHeadEntity && entity.deletedAt == null)
          entity.agentId: entity.versionId,
    };
    final versions = await agentRepository.getEntitiesByIds(
      versionIdByAgentId.values.toSet(),
    );
    final reports = await agentRepository.getLatestReportsByAgentIds(
      agentIds,
      AgentReportScopes.current,
    );
    return [
      for (final identity in identities)
        if (versions[versionIdByAgentId[identity.agentId]]
            case final GoalSpecVersionEntity version)
          FrontIndexRow(
            kind: FrontDestinationKind.goal,
            id: identity.agentId,
            title: version.statement,
            oneLiner: reports[identity.agentId]?.oneLiner,
            tldr: reports[identity.agentId]?.tldr,
          ),
    ];
  }

  /// Tracked people in the allow-list, most recently updated first. Names
  /// only: a person's one-liner is the relationship agent's, and reading it
  /// is not part of this opt-in.
  Future<List<FrontIndexRow>> _people(FrontRoutingScope scope) async {
    final people =
        (await journalDb.getRelationships())
            .where((p) => categoryAllowed(p.meta.categoryId, scope.categoryIds))
            .toList()
          ..sort((a, b) => b.meta.updatedAt.compareTo(a.meta.updatedAt));
    return [
      for (final person in people)
        FrontIndexRow(
          kind: FrontDestinationKind.person,
          id: person.id,
          title: person.data.title,
          categoryId: person.meta.categoryId,
        ),
    ];
  }
}
