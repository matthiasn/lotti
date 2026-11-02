import 'dart:convert';

import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/related_task_finder.dart';

/// What the task agent's tools for other tasks read, for one wake.
///
/// The wake's `## Linked Tasks` section lists every linked task the budget
/// admits with its agent's one-liner ([linkedIds]). `find_related_tasks`
/// searches by meaning, on the device, for the tasks a note of the current
/// task might be talking about, and answers with their id, title, status and
/// one-liner. Either way the model can then read one task deeper:
/// `get_task_tldr` for its agent's TL;DR, `get_task_report` for the whole
/// latest report.
///
/// Nothing beyond the one-liners reaches the conversation until the model
/// asks, and only what it asks for.
///
/// Only a task this wake has shown can be read in detail ([canRead]): one
/// the Linked Tasks section lists, or one a search returned. The model
/// cannot inspect a task it guessed the id of. A search sees only the
/// categories the agent may work in and never a private task: what it
/// returns is sent to the agent's inference provider.
class RelatedTaskLookup {
  /// The finder is null where search by meaning cannot run on this device:
  /// then only the linked tasks can be read, and [canSearch] is false.
  RelatedTaskLookup({
    required this._finder,
    required this._journalDb,
    required this._agentRepository,
    required this._allowedCategoryIds,
    Set<String> linkedIds = const {},
  }) : _linkedIds = Set.unmodifiable(linkedIds);

  final RelatedTaskFinder? _finder;
  final JournalDb _journalDb;
  final AgentRepository _agentRepository;
  final Set<String> _allowedCategoryIds;
  final Set<String> _linkedIds;

  /// The most tasks one search answers with.
  static const maxResults = 5;

  /// The longest query a search accepts, in characters.
  static const maxQueryLength = 300;

  final Set<String> _foundIds = {};

  /// Whether [find] can search: false where search by meaning is
  /// unavailable.
  bool get canSearch => _finder != null;

  /// The tasks the wake's Linked Tasks section lists.
  Set<String> get linkedIds => _linkedIds;

  /// Every task id a search of this wake has returned.
  Set<String> get foundIds => Set.unmodifiable(_foundIds);

  /// Whether [taskId] may be read in detail: it is listed under Linked Tasks
  /// or a search of this wake returned it.
  bool canRead(String taskId) =>
      _linkedIds.contains(taskId) || _foundIds.contains(taskId);

  /// Searches for tasks related to [query], for task [taskId]; answers with
  /// a JSON object listing them, nearest first.
  ///
  /// The task itself and every task already linked to it are left out: the
  /// first is not a relationship, and the second is in the Linked Tasks
  /// section already.
  ///
  /// Only for a lookup that [canSearch].
  Future<String> find(String taskId, String query) async {
    final trimmed = query.trim();
    final bounded = trimmed.length > maxQueryLength
        ? trimmed.substring(0, maxQueryLength)
        : trimmed;
    final finder = _finder;
    if (finder == null) {
      throw StateError('find called on a lookup that cannot search');
    }
    final search = _allowedCategoryIds.isEmpty
        ? null
        : await finder.find(
            taskId,
            [bounded],
            categoryIds: _allowedCategoryIds,
          );
    final found = search?.matches ?? const <RelatedTaskMatch>[];
    // The finder remembers only searches that ran: with one query, an empty
    // map means the model was missing, the query could not be embedded or
    // the search threw — which says nothing about the journal.
    final searchRan = search == null || search.searches.isNotEmpty;
    final tasks = [
      for (final match in found)
        if (match.task.meta.private != true) match.task,
    ].take(maxResults).toList();
    final reports = tasks.isEmpty
        ? const <String, AgentReportEntity>{}
        : await _agentRepository.getUsableTaskReportsForTaskIds([
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
        'note': searchRan
            ? 'No related task is close enough to this query. Do not '
                  'propose a link without one.'
            : 'Search by meaning could not run on this device right now, so '
                  'this says nothing about other tasks. Do not propose a '
                  'link without a search result.',
    });
  }

  /// Task [taskId]'s agent TL;DR, as a JSON object with its title, status
  /// and one-liner. Null when the task is gone.
  ///
  /// The caller checks [canRead] first.
  Future<String?> tldr(String taskId) => _read(
    taskId,
    (report) => {
      'oneLiner': ?_nonEmpty(report?.oneLiner),
      'tldr': ?_nonEmpty(report?.tldr),
    },
  );

  /// Task [taskId]'s whole latest agent report, as a JSON object with its
  /// title, status and one-liner. Null when the task is gone.
  ///
  /// The caller checks [canRead] first.
  Future<String?> report(String taskId) => _read(
    taskId,
    (report) => {
      'oneLiner': ?_nonEmpty(report?.oneLiner),
      'report': ?_nonEmpty(report?.content),
    },
  );

  Future<String?> _read(
    String taskId,
    Map<String, Object> Function(AgentReportEntity? report) fields,
  ) async {
    final task = await _journalDb.journalEntityById(taskId);
    if (task is! Task || task.meta.deletedAt != null) return null;
    // The same report the Linked Tasks row's one-liner came from.
    final reports = await _agentRepository.getUsableTaskReportsForTaskIds([
      taskId,
    ]);
    final report = reports[taskId];
    return jsonEncode({
      ..._identity(task),
      ...fields(report),
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
