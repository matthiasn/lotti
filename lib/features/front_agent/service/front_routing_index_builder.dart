import 'package:collection/collection.dart';
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
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/service/front_logged_time_reader.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/utils/day_agent_capture_helpers.dart';

/// What the front agent may see (the owner's decision 4: narrow by default).
///
/// [allowedCategoryIds] is her allow-list and [chosenCategoryIds] the
/// conversation's chips for the turn; [categoryIds], the one narrowed by the
/// other, is what every category-scoped kind — tasks, projects, people —
/// filters through. Empty means unrestricted, the `categoryAllowed`
/// convention. Goals carry no category and are the user's own, so they are
/// listed whenever [includeGoals]; people are listed only when
/// [includePeople], a separate opt-in.
class FrontRoutingScope {
  const FrontRoutingScope({
    this.allowedCategoryIds = const {},
    this.chosenCategoryIds = const {},
    this.includeGoals = true,
    this.includePeople = false,
  });

  final Set<String> allowedCategoryIds;
  final Set<String> chosenCategoryIds;
  final bool includeGoals;
  final bool includePeople;

  /// The categories the turn reads: her allow-list narrowed by the chips.
  Set<String> get categoryIds =>
      frontNarrowedCategories(allowedCategoryIds, chosenCategoryIds);
}

/// Builds the routing index from existing reads — no model call, no raw
/// entries: titles, statuses, due dates and the owner agents' one-liners
/// and TL;DRs.
class FrontRoutingIndexBuilder {
  const FrontRoutingIndexBuilder({
    required this.journalDb,
    required this.agentRepository,
    this.fts5Db,
    this.firstDayOfWeekIndex,
  });

  final JournalDb journalDb;
  final AgentRepository agentRepository;

  /// Null when no full-text index is wired; `match_to_corpus` is then
  /// unavailable for the turn.
  final Fts5Db? fts5Db;

  /// The device region's first weekday (`0 = Sunday` … `6 = Saturday`) that
  /// `this_week` starts on; Monday when null.
  final Future<int> Function()? firstDayOfWeekIndex;

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
      categories: await _categories(scope),
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

  /// The tasks [ids] name, in their order, that [scope] lets her see — open
  /// or closed, since a follow-up is often to finished work. A deleted task,
  /// a private one or one in a private category while private entries are
  /// hidden — a task need not be private itself to sit in one — and one
  /// outside the scope are left out.
  Future<List<FrontIndexRow>> conversationTasks(
    List<String> ids,
    FrontRoutingScope scope,
  ) async {
    if (ids.isEmpty) return const [];
    final hidden = await _hiddenCategoryIds();
    final byId = <String, Task>{
      for (final entity in await journalDb.getJournalEntitiesForIds(
        ids.toSet(),
      ))
        if (entity is Task &&
            entity.meta.deletedAt == null &&
            !hidden.contains(entity.meta.categoryId) &&
            categoryAllowed(entity.meta.categoryId, scope.categoryIds))
          entity.id: entity,
    };
    final reports = await agentRepository.getLatestTaskReportsForTaskIds([
      ...byId.keys,
    ]);
    return [
      for (final id in ids)
        if (byId[id] case final task?) _taskRow(task, reports[id]),
    ];
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

  /// Lists the open tasks inside [scope] in one due window of [now]'s local
  /// day — due today, overdue, or due through `daysAhead` days past today,
  /// with or without the overdue ones — soonest due first, then by title,
  /// at most [frontDueTaskLimit]. A query naming categories (one the user
  /// named) narrows the scope further, never widens it.
  ///
  /// The due-date read the Daily OS and the task list's *Due today* and
  /// *Overdue* views share, split at local midnight as they split it, so
  /// she answers a due question with what those show.
  Future<FrontDueTasks> Function(FrontDueQuery query) dueTaskLister(
    FrontRoutingScope scope, {
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    return (query) async {
      final through = switch (query.window) {
        FrontDueWindow.today || FrontDueWindow.overdue => today,
        FrontDueWindow.upcoming || FrontDueWindow.all => DateTime(
          today.year,
          today.month,
          today.day + query.daysAhead,
        ),
      };
      final (:narrowed, :within) = _narrowedBy(scope, query.categoryIds);
      // Both ends checked here, whatever bound the read applied.
      final until = DateTime(through.year, through.month, through.day + 1);
      bool inWindow(DateTime due) =>
          due.isBefore(until) &&
          switch (query.window) {
            FrontDueWindow.overdue => due.isBefore(today),
            FrontDueWindow.today ||
            FrontDueWindow.upcoming => !due.isBefore(today),
            FrontDueWindow.all => true,
          };
      final tasks =
          (await journalDb.getTasksDueOnOrBefore(through))
              .where(
                (task) =>
                    inWindow(task.data.due!) &&
                    categoryAllowed(task.meta.categoryId, within),
              )
              .toList()
            ..sort((a, b) {
              final byDue = a.data.due!.compareTo(b.data.due!);
              return byDue != 0
                  ? byDue
                  : a.data.title.toLowerCase().compareTo(
                      b.data.title.toLowerCase(),
                    );
            });
      final names = {
        for (final category in await _categories(scope))
          category.id: category.name,
      };
      return FrontDueTasks(
        window: query.window,
        today: today,
        through: through,
        rows: [
          for (final task in tasks.take(frontDueTaskLimit))
            _taskRow(task, null),
        ],
        omitted: _omitted(tasks.length, frontDueTaskLimit),
        categoryNames: names,
        narrowedTo: [
          for (final id in narrowed) ?names[id],
        ]..sort(),
      );
    };
  }

  /// Lists the tasks inside [scope] completed or rejected in one period of
  /// [now]'s local days, each with the status it closed with, oldest first,
  /// then by title, at most [frontClosedTaskLimit]. A query naming
  /// categories narrows the scope further, never widens it.
  ///
  /// When a task closed comes from its status history, never its creation
  /// date: see [_closedWithin]. The candidates are the tasks closed now
  /// whose row changed since the window began — the read Daily OS Shutdown
  /// takes its closed tasks from — so a task reopened and still open is
  /// not one, and private entries are read only while they are shown. A
  /// task in a private category while those are hidden is left out too.
  Future<FrontClosedTasks> Function(FrontTimeQuery query) closedTaskLister(
    FrontRoutingScope scope, {
    required DateTime now,
  }) {
    return (query) async {
      final range = query.period.rangeOn(
        now,
        firstDayOfWeekIndex:
            await firstDayOfWeekIndex?.call() ?? defaultFirstDayOfWeekIndex,
      );
      final start = dayStart(range.startDay);
      final end = dayStart(range.endDayExclusive);
      final (:narrowed, :within) = _narrowedBy(scope, query.categoryIds);
      final hidden = await _hiddenCategoryIds();
      final closed =
          [
            for (final task in await journalDb.getTasksClosedSince(start))
              if (!hidden.contains(task.meta.categoryId) &&
                  categoryAllowed(task.meta.categoryId, within))
                if (_closedWithin(task.data, start, end) case final status?)
                  (task: task, closed: status),
          ]..sort((a, b) {
            final byTime = a.closed.createdAt.compareTo(b.closed.createdAt);
            return byTime != 0
                ? byTime
                : a.task.data.title.toLowerCase().compareTo(
                    b.task.data.title.toLowerCase(),
                  );
          });
      final names = {
        for (final category in await _categories(scope))
          category.id: category.name,
      };
      return FrontClosedTasks(
        period: query.period,
        from: start,
        through: dayStart(range.endDayExclusive - 1),
        tasks: [
          for (final (:task, :closed) in closed.take(frontClosedTaskLimit))
            (row: _taskRow(task, null), closed: closed),
        ],
        omitted: _omitted(closed.length, frontClosedTaskLimit),
        categoryNames: names,
        narrowedTo: [for (final id in narrowed) ?names[id]]..sort(),
      );
    };
  }

  /// The status [data] closed with in `[start, end)`, or null. The status
  /// history is the record of every status the task was set to, each at
  /// the moment it was; the current status — the `statusSince` the task
  /// agent sees — is only its last entry, so it loses a close inside the
  /// window once the task is touched again. Joined with the current status
  /// (a task from before the history was kept may lack it) and in time
  /// order, the last status set before [end] is the one the window ended
  /// on, as Daily OS Shutdown reads a day: DONE or REJECTED and set inside
  /// the window, it is the close reported — a task reopened and completed
  /// again reports the latest completion, one finished and reopened inside
  /// the window none.
  static TaskStatus? _closedWithin(
    TaskData data,
    DateTime start,
    DateTime end,
  ) {
    final statuses = {
      for (final status in [...data.statusHistory, data.status])
        status.id: status,
    }.values.sortedBy((status) => status.createdAt);
    final last = statuses.lastWhereOrNull(
      (status) => status.createdAt.isBefore(end),
    );
    return (last is TaskDone || last is TaskRejected) &&
            !last!.createdAt.isBefore(start)
        ? last
        : null;
  }

  /// Sums the time logged inside [scope] in one period of [now]'s local
  /// days, per category, largest first, as [readFrontLoggedTime] reads it,
  /// and the tasks it went to. A query naming categories keeps those by
  /// name and sums every other category as one; its tasks are theirs alone.
  Future<FrontLoggedTime> Function(FrontTimeQuery query) loggedTimeSummarizer(
    FrontRoutingScope scope, {
    required DateTime now,
  }) {
    return (query) async {
      final range = query.period.rangeOn(
        now,
        firstDayOfWeekIndex:
            await firstDayOfWeekIndex?.call() ?? defaultFirstDayOfWeekIndex,
      );
      final categoryIds = scope.categoryIds;
      final named = query.categoryIds;
      final (:buckets, :names, :entries) = await readFrontLoggedTime(
        journalDb,
        range,
        categoryIds,
        namedCategoryIds: named,
      );
      final tasks = await _loggedTasks([
        for (final entry in entries)
          if (entry.row.categoryId != kInsightsOtherCategoryKey) entry,
      ], range);
      return FrontLoggedTime(
        period: query.period,
        from: dayStart(range.startDay),
        through: dayStart(range.endDayExclusive - 1),
        byCategory: [
          for (final MapEntry(key: id, value: seconds) in rankedCategoryTotals(
            dailyTotals(buckets, range),
          ))
            (
              name: switch (id) {
                null => null,
                kInsightsOtherCategoryKey => FrontLoggedTime.otherCategories,
                _ => names[id] ?? 'Unnamed',
              },
              seconds: seconds,
            ),
        ],
        named: [for (final id in named) ?names[id]]..sort(),
        tasks: tasks.take(frontLoggedTaskLimit).toList(),
        omittedTasks: _omitted(tasks.length, frontLoggedTaskLimit),
        chart: FrontLoggedTimeChart(
          range: range,
          categoryIds: categoryIds,
          namedCategoryIds: named,
        ),
      );
    };
  }

  /// The tasks [entries] are linked to, each with the time logged on them
  /// inside [range], largest first. An entry linked to several tasks counts
  /// for the one the Insights read takes its category from — the latest
  /// started of those with a category — so the task listed is the one whose
  /// category the time is summed in; only when none has a category, the
  /// latest started. Its time is clipped and merged as the chart's is. A
  /// task hidden with private entries, or deleted, is never read.
  Future<List<({FrontIndexRow row, int seconds})>> _loggedTasks(
    List<({String entryId, InsightsTimeRow row})> entries,
    InsightsRange range,
  ) async {
    final links = [
      for (final link in await journalDb.basicLinksForEntryIds({
        for (final entry in entries) entry.entryId,
      }))
        if (link.hidden != true && link.deletedAt == null) link,
    ];
    final tasksById = {
      for (final entity in await journalDb.getJournalEntitiesForIdsUnordered({
        for (final link in links) link.fromId,
      }))
        if (entity is Task) entity.id: entity,
    };
    final taskByEntry = <String, Task>{};
    for (final link in links) {
      final task = tasksById[link.fromId];
      if (task == null) continue;
      final current = taskByEntry[link.toId];
      if (current == null || _creditedBefore(task, current)) {
        taskByEntry[link.toId] = task;
      }
    }
    // Keyed by task id, the bucketing that sums categories sums tasks.
    final buckets = bucketize([
      for (final entry in entries)
        if (taskByEntry[entry.entryId] case final task?)
          InsightsTimeRow(
            dateFrom: entry.row.dateFrom,
            dateTo: entry.row.dateTo,
            categoryId: task.id,
          ),
    ], windowStartDay: range.startDay);
    return [
      for (final MapEntry(key: id, value: seconds) in rankedCategoryTotals(
        dailyTotals(buckets, range),
      ))
        (row: _taskRow(tasksById[id]!, null), seconds: seconds),
    ];
  }

  /// Whether [task] is credited with a linked entry's time before [other]:
  /// one with a category first, then the later started, then the lower id —
  /// the order `_insightsResolvedCategorySql` picks a linked task in.
  static bool _creditedBefore(Task task, Task other) {
    bool categorized(Task t) => t.meta.categoryId?.isNotEmpty ?? false;
    if (categorized(task) != categorized(other)) return categorized(task);
    final byStart = task.meta.dateFrom.compareTo(other.meta.dateFrom);
    return byStart != 0 ? byStart > 0 : task.id.compareTo(other.id) < 0;
  }

  /// The active categories her allow-list lets her see, by name, those the
  /// chips narrow the turn to marked. The privacy-gated read the task
  /// queries share, so a hidden category is never named.
  Future<List<FrontCategory>> _categories(FrontRoutingScope scope) async {
    final narrowed = scope.categoryIds;
    final chips = !const SetEquality<String>().equals(
      narrowed,
      scope.allowedCategoryIds,
    );
    return [
      for (final category in await journalDb.getAllCategories())
        if (category.active &&
            category.deletedAt == null &&
            categoryAllowed(category.id, scope.allowedCategoryIds))
          FrontCategory(
            id: category.id,
            name: category.name,
            chosen: chips && narrowed.contains(category.id),
          ),
    ];
  }

  static int _omitted(int total, int cap) => total > cap ? total - cap : 0;

  /// The categories a query naming [categoryIds] reads inside [scope]: the
  /// `narrowed` ones it may see, or the whole scope when it names none of
  /// them — a named category narrows, never widens.
  static ({Set<String> narrowed, Set<String> within}) _narrowedBy(
    FrontRoutingScope scope,
    Set<String> categoryIds,
  ) {
    final allowed = scope.categoryIds;
    final narrowed = {
      for (final id in categoryIds)
        if (categoryAllowed(id, allowed)) id,
    };
    return (narrowed: narrowed, within: narrowed.isEmpty ? allowed : narrowed);
  }

  /// The private categories while private entries are hidden: the read of
  /// the visible categories drops them, the one including private keeps
  /// them. A task need not be private itself to sit in one.
  Future<Set<String>> _hiddenCategoryIds() async {
    final visible = {
      for (final category in await journalDb.getAllCategories()) category.id,
    };
    return {
      for (final category in await journalDb.getAllCategoriesIncludingPrivate())
        if (!visible.contains(category.id)) category.id,
    };
  }

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
