import 'dart:convert';

import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/link_suggestions/related_task_finder.dart';

/// What the task agent's related-task tools read, for one wake.
///
/// `find_related_tasks` searches by meaning, on the device, for the tasks a
/// note of the current task might be talking about, and answers with their
/// id, title, status and one-liner. `get_related_task_details` then reads
/// one of them: its agent's TL;DR, and on request the whole report.
///
/// Nothing reaches the conversation until the model asks, and only what it
/// asks for: a wake whose notes mention no other work never searches.
///
/// Only a task this wake's searches returned can be read in detail
/// ([foundIds]), so the model cannot inspect a task it guessed the id of. A
/// search sees only the categories the agent may work in and never a private
/// task: what it returns is sent to the agent's inference provider.
class RelatedTaskLookup {
  RelatedTaskLookup({
    required this._finder,
    required this._journalDb,
    required this._agentRepository,
    required this._allowedCategoryIds,
  });

  final RelatedTaskFinder _finder;
  final JournalDb _journalDb;
  final AgentRepository _agentRepository;
  final Set<String> _allowedCategoryIds;

  /// The most tasks one search answers with.
  static const maxResults = 5;

  /// The longest query a search accepts, in characters.
  static const maxQueryLength = 300;

  final Set<String> _foundIds = {};

  /// Every task id a search of this wake has returned — the only ids
  /// [details] reads.
  Set<String> get foundIds => Set.unmodifiable(_foundIds);

  /// Searches for tasks related to [query], for task [taskId]; answers with
  /// a JSON object listing them, nearest first.
  ///
  /// The task itself and every task already linked to it are left out: the
  /// first is not a relationship, and the second is in the Linked Tasks
  /// section already.
  Future<String> find(String taskId, String query) async {
    final trimmed = query.trim();
    final bounded = trimmed.length > maxQueryLength
        ? trimmed.substring(0, maxQueryLength)
        : trimmed;
    final found = _allowedCategoryIds.isEmpty
        ? const <RelatedTaskMatch>[]
        : (await _finder.find(
            taskId,
            [bounded],
            categoryIds: _allowedCategoryIds,
          )).matches;
    final tasks = [
      for (final match in found)
        if (match.task.meta.private != true) match.task,
    ].take(maxResults).toList();
    final reports = tasks.isEmpty
        ? const <String, AgentReportEntity>{}
        : await _agentRepository.getLatestTaskReportsForTaskIds([
            for (final task in tasks) task.meta.id,
          ]);
    _foundIds.addAll(tasks.map((task) => task.meta.id));

    return jsonEncode({
      'query': bounded,
      'tasks': [
        for (final task in tasks)
          {
            ..._identity(task),
            'oneLiner': ?_nonEmpty(reports[task.meta.id]?.oneLiner),
          },
      ],
      if (tasks.isEmpty)
        'note':
            'No related task is close enough to this query. Do not propose '
            'a link without one.',
    });
  }

  /// The details of task [taskId] as a JSON object: its title, status,
  /// one-liner and TL;DR, and with [fullReport] the whole latest report of
  /// its agent. Null when the task is gone.
  ///
  /// The caller checks [foundIds] first.
  Future<String?> details(String taskId, {bool fullReport = false}) async {
    final task = await _journalDb.journalEntityById(taskId);
    if (task is! Task || task.meta.deletedAt != null) return null;
    final reports = await _agentRepository.getLatestTaskReportsForTaskIds([
      taskId,
    ]);
    final report = reports[taskId];
    return jsonEncode({
      ..._identity(task),
      'oneLiner': ?_nonEmpty(report?.oneLiner),
      'tldr': ?_nonEmpty(report?.tldr),
      if (fullReport) 'report': ?_nonEmpty(report?.content),
      if (report == null)
        'note':
            'This task has no agent report yet; its title is all there is '
            'to go on.',
    });
  }

  static Map<String, Object> _identity(Task task) => {
    'id': task.meta.id,
    'title': task.data.title,
    'status': task.data.status.toDbString,
  };

  static String? _nonEmpty(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
