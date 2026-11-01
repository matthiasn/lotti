import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/util/project_suggestion_matcher.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/project_lookup_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';

/// The project the app proposes for a task that has none.
@immutable
class TaskProjectSuggestion {
  const TaskProjectSuggestion({
    required this.projectId,
    required this.projectTitle,
  });

  final String projectId;
  final String projectTitle;

  @override
  bool operator ==(Object other) =>
      other is TaskProjectSuggestion &&
      other.projectId == projectId &&
      other.projectTitle == projectTitle;

  @override
  int get hashCode => Object.hash(projectId, projectTitle);
}

/// How many of a project's task titles feed its vocabulary. Enough to learn
/// the words the user files under it; bounded so a project with years of
/// history costs no more to index than a busy one.
const maxHistoryTitlesPerProject = 200;

/// Whether [project] may be suggested at all: one whose work is over —
/// completed or archived — is not where new work belongs.
bool isSuggestibleProject(ProjectEntry project) =>
    switch (project.data.status) {
      ProjectCompleted() || ProjectArchived() => false,
      _ => true,
    };

/// The key one category's suggestion index is built for. Privacy is part of
/// it because a task can only join a project of its own privacy — the
/// repository rejects any other link, so the picker never offers one and
/// neither may a suggestion.
typedef ProjectSuggestionScope = ({String categoryId, bool private});

/// A ready-to-query matcher over one scope's suggestible projects, with the
/// titles the suggestion displays.
@immutable
class ProjectSuggestionIndex {
  const ProjectSuggestionIndex({required this.matcher, required this.titles});

  final ProjectSuggestionMatcher matcher;
  final Map<String, String> titles;
}

/// Builds the [ProjectSuggestionIndex] for a category and privacy.
///
/// The projects come from [projectsForCategoryProvider], which refreshes on
/// every project notification — linking a task included — so the index
/// learns a newly filed task's words without a restart. Each project's task
/// titles are read once here, not on every keystroke: re-ranking a task only
/// tokenises the task.
final FutureProviderFamily<ProjectSuggestionIndex, ProjectSuggestionScope>
projectSuggestionIndexProvider = FutureProvider.autoDispose
    .family<ProjectSuggestionIndex, ProjectSuggestionScope>(
      buildProjectSuggestionIndex,
      name: 'projectSuggestionIndexProvider',
    );

@visibleForTesting
Future<ProjectSuggestionIndex> buildProjectSuggestionIndex(
  Ref ref,
  ProjectSuggestionScope scope,
) async {
  final repository = ref.watch(projectRepositoryProvider);
  final projects = await ref.watch(
    projectsForCategoryProvider(scope.categoryId).future,
  );
  final suggestible = [
    for (final project in projects)
      if (isSuggestibleProject(project) &&
          (project.meta.private ?? false) == scope.private)
        project,
  ];
  // One title-only query for every project, capped per project in SQL: the
  // cost of opening an unassigned task stays bounded however long the
  // projects' histories grow.
  final histories = suggestible.isEmpty
      ? const <String, List<String>>{}
      : await repository.getRecentTaskTitlesForProjects(
          {for (final project in suggestible) project.meta.id},
          limitPerProject: maxHistoryTitlesPerProject,
        );

  final candidates = [
    for (final project in suggestible)
      ProjectMatchCandidate(
        projectId: project.meta.id,
        title: project.data.title,
        description: project.entryText?.plainText ?? '',
        taskTitles: histories[project.meta.id] ?? const [],
      ),
  ];
  return ProjectSuggestionIndex(
    matcher: ProjectSuggestionMatcher(candidates),
    titles: {
      for (final project in suggestible) project.meta.id: project.data.title,
    },
  );
}

/// SettingsDb key prefix for the projects a task's suggestion was dismissed
/// for; the task id follows it.
const taskProjectSuggestionDismissedKeyPrefix =
    'TASK_PROJECT_SUGGESTION_DISMISSED_';

String taskProjectSuggestionDismissedKey(String taskId) =>
    '$taskProjectSuggestionDismissedKeyPrefix$taskId';

/// The projects the user has said a task does not belong to.
///
/// Remembered per task on this device, so a dismissed suggestion stays gone
/// across restarts — the same project is never proposed for the same task
/// twice. An unreadable or corrupt record reads as "nothing dismissed": the
/// worst case is one suggestion shown again, never a crash.
class TaskProjectSuggestionDismissals extends AsyncNotifier<Set<String>> {
  TaskProjectSuggestionDismissals(this.taskId);

  final String taskId;

  @override
  Future<Set<String>> build() async {
    // Taken before the read: a load that fails after the provider is gone
    // must still be able to say so.
    final logger = ref.read(domainLoggerProvider);
    final String? raw;
    try {
      raw = await ref
          .read(settingsDbProvider)
          .itemByKey(taskProjectSuggestionDismissedKey(taskId));
    } catch (error, stackTrace) {
      _report(logger, 'load', error, stackTrace);
      return const {};
    }
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return {...decoded.whereType<String>()};
    } on FormatException {
      // A corrupt record is not worth surfacing; nothing counts as dismissed.
    }
    return const {};
  }

  /// Records that the task does not belong in [projectId]. The suggestion
  /// disappears at once; the write follows, and a failed write is logged —
  /// the dismissal still holds for this session.
  ///
  /// Everything the write needs is taken from [ref] before the first await,
  /// so the dismissal is persisted even when the page that asked for it
  /// closes — and the provider with it — while the write is under way.
  Future<void> dismiss(String projectId) async {
    final settingsDb = ref.read(settingsDbProvider);
    final logger = ref.read(domainLoggerProvider);
    final current = state.value ?? await future;
    if (current.contains(projectId)) return;
    final updated = {...current, projectId};
    if (ref.mounted) state = AsyncData(updated);
    try {
      await settingsDb.saveSettingsItem(
        taskProjectSuggestionDismissedKey(taskId),
        jsonEncode(updated.toList()..sort()),
      );
    } catch (error, stackTrace) {
      _report(logger, 'persist', error, stackTrace);
    }
  }

  void _report(
    DomainLogger logger,
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    logger.error(
      LogDomain.settings,
      error,
      stackTrace: stackTrace,
      subDomain: 'taskProjectSuggestionDismissals.$operation',
    );
  }
}

final AsyncNotifierProviderFamily<
  TaskProjectSuggestionDismissals,
  Set<String>,
  String
>
taskProjectSuggestionDismissalsProvider = AsyncNotifierProvider.autoDispose
    .family<TaskProjectSuggestionDismissals, Set<String>, String>(
      TaskProjectSuggestionDismissals.new,
      name: 'taskProjectSuggestionDismissalsProvider',
    );

/// The parts of a task the suggestion depends on. A record of plain values,
/// so selecting it from the entry controller only re-ranks when one of them
/// changes — not on every focus or toolbar flip of the editor.
typedef _TaskMatchFacts = ({
  bool isTask,
  String? categoryId,
  bool private,
  String title,
  String body,
  String labelIds,
});

_TaskMatchFacts _factsOf(AsyncValue<EntryState?> state) {
  final entry = state.value?.entry;
  if (entry is! Task) {
    return (
      isTask: false,
      categoryId: null,
      private: false,
      title: '',
      body: '',
      labelIds: '',
    );
  }
  return (
    isTask: true,
    categoryId: entry.meta.categoryId,
    private: entry.meta.private ?? false,
    title: entry.data.title,
    body: entry.entryText?.plainText ?? '',
    labelIds: (entry.meta.labelIds ?? const <String>[]).join('\u0000'),
  );
}

/// The project to propose for a task that has none, or null.
///
/// Re-evaluated whenever the task's title, body, labels, category or privacy
/// change — so a new task gets its suggestion the moment it is named — and
/// whenever its project link changes, which is what makes an accepted
/// suggestion disappear. Null when the task already has a project, has no
/// category (projects live inside one), no project clearly fits, or the
/// best fit is one the user dismissed for this task. A dismissed best fit
/// does not hand over to the runner-up: "not that one" is not "show me
/// another", and a new title is what earns a new suggestion.
///
/// Everything runs locally: the task's own text against projects already in
/// the database, nothing leaves the device.
final FutureProviderFamily<TaskProjectSuggestion?, String>
taskProjectSuggestionProvider = FutureProvider.autoDispose
    .family<TaskProjectSuggestion?, String>(
      taskProjectSuggestion,
      name: 'taskProjectSuggestionProvider',
    );

@visibleForTesting
Future<TaskProjectSuggestion?> taskProjectSuggestion(
  Ref ref,
  String taskId,
) async {
  final facts = ref.watch(
    entryControllerProvider(taskId).select(_factsOf),
  );
  final categoryId = facts.categoryId;
  if (!facts.isTask || categoryId == null || categoryId.isEmpty) return null;

  // Every dependency is subscribed before the first await, so an
  // invalidation during the loads below still reaches this provider.
  final projectFuture = ref.watch(projectForTaskProvider(taskId).future);
  final indexFuture = ref.watch(
    projectSuggestionIndexProvider((
      categoryId: categoryId,
      private: facts.private,
    )).future,
  );
  final dismissedFuture = ref.watch(
    taskProjectSuggestionDismissalsProvider(taskId).future,
  );
  final cache = ref.watch(entitiesCacheServiceProvider);

  if (await projectFuture != null) return null;
  final index = await indexFuture;
  if (index.matcher.isEmpty) return null;

  final labels = <String>[];
  if (facts.labelIds.isNotEmpty) {
    final showPrivate = cache?.showPrivateEntries ?? false;
    for (final id in facts.labelIds.split('\u0000')) {
      final label = cache?.getLabelById(id);
      if (label == null) continue;
      if (!showPrivate && (label.private ?? false)) continue;
      labels.add(label.name);
    }
  }

  final best = index.matcher.suggest(
    ProjectMatchTask(title: facts.title, body: facts.body, labels: labels),
  );
  if (best == null) return null;
  final dismissed = await dismissedFuture;
  if (dismissed.contains(best.projectId)) return null;
  final title = index.titles[best.projectId];
  if (title == null) return null;
  // [projectForTaskProvider] hides a project the private gate hides, so a
  // task filed under one reads as unassigned there. Accepting would move it
  // out of a project the user cannot currently see; the unfiltered link
  // decides. Read last, so only a task about to get a suggestion pays for it.
  final linked = await ref
      .read(projectRepositoryProvider)
      .getLinkedProjectForTask(taskId);
  if (linked != null) return null;
  return TaskProjectSuggestion(projectId: best.projectId, projectTitle: title);
}
