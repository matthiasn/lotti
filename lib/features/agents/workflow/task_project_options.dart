import 'dart:convert';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/repositories/project_repository.dart';

/// One project the task agent may propose for its task.
///
/// The read side of `get_category_projects` and the validation side of
/// `set_task_project` share this list, so the agent can only propose a project
/// it was able to read.
class TaskProjectOption {
  const TaskProjectOption({
    required this.id,
    required this.title,
    required this.status,
    required this.isCurrent,
    this.oneLiner,
    this.tldr,
  });

  final String id;
  final String title;

  /// The project's status as its database string (`OPEN`, `ACTIVE`, …).
  final String status;

  /// The one-liner of the project agent's latest report, when there is one.
  final String? oneLiner;

  /// The TLDR of the project agent's latest report, when there is one.
  final String? tldr;

  /// Whether the task already belongs to this project.
  final bool isCurrent;

  /// The entry `get_category_projects` reports for this project.
  Map<String, Object?> toToolJson() => {
    'id': id,
    'title': title,
    'status': status,
    'oneLiner': oneLiner,
    'tldr': tldr,
    'isCurrentProject': isCurrent,
  };
}

/// The projects of [taskId]'s category, sorted by title, each with the
/// one-liner and TLDR of its project agent's latest report.
///
/// Empty when the task cannot be read or has no category. Read from the local
/// database only; the privacy filter of [ProjectRepository] applies, so a
/// project hidden from the user is hidden from the agent too.
Future<List<TaskProjectOption>> loadTaskProjectOptions({
  required String taskId,
  required JournalDb journalDb,
  required ProjectRepository projectRepository,
  required AgentRepository agentRepository,
}) async {
  final task = await journalDb.journalEntityById(taskId);
  final categoryId = task is Task ? task.meta.categoryId : null;
  if (categoryId == null || categoryId.isEmpty) return const [];

  final (projects, current) = await (
    projectRepository.getProjectsForCategory(categoryId),
    projectRepository.getProjectForTask(taskId),
  ).wait;
  final reports = await Future.wait(
    projects.map(
      (project) =>
          agentRepository.getLatestProjectReportForProjectId(project.id),
    ),
  );

  return [
    for (final (index, project) in projects.indexed)
      TaskProjectOption(
        id: project.meta.id,
        title: project.data.title,
        status: project.data.status.toDbString,
        oneLiner: _nonEmpty(reports[index]?.oneLiner),
        tldr: _nonEmpty(reports[index]?.tldr),
        isCurrent: project.meta.id == current?.meta.id,
      ),
  ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
}

/// The option [reference] names: its id, or else its title compared without
/// case or surrounding whitespace. `null` when nothing matches, or when the
/// title is shared by more than one project and so names none of them.
TaskProjectOption? matchTaskProjectOption(
  List<TaskProjectOption> options,
  String reference,
) {
  final trimmed = reference.trim();
  for (final option in options) {
    if (option.id == trimmed) return option;
  }
  final wanted = trimmed.toLowerCase();
  final byTitle = options
      .where((option) => option.title.trim().toLowerCase() == wanted)
      .toList();
  return byTitle.length == 1 ? byTitle.single : null;
}

/// The `get_category_projects` response for [options].
String renderTaskProjectOptions(List<TaskProjectOption> options) {
  if (options.isEmpty) {
    return "No projects exist in this task's category. Do not call "
        'set_task_project.';
  }
  return const JsonEncoder.withIndent('  ').convert({
    'projects': [for (final option in options) option.toToolJson()],
  });
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
