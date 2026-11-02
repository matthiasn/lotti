import 'dart:convert';

import 'package:lotti/classes/ai_input.dart';
import 'package:lotti/features/agents/util/text_utils.dart';

/// One linked task on its way into the wake's `## Linked Tasks` section: the
/// typed context the directory ranks by, and the JSON row it renders.
typedef LinkedTaskRow = ({AiLinkedTaskContext task, Map<String, dynamic> row});

/// The `## Linked Tasks` section of a task agent's wake, held to a budget.
///
/// Every linked task the budget admits is listed with its metadata and its
/// agent's one-liner — never the TL;DR or the report, which the agent reads
/// on demand with `get_task_tldr` and `get_task_report`. [taskIds] is what
/// those tools may read for this wake, besides what `find_related_tasks`
/// returns: a task the section does not show cannot be drilled into.
///
/// A task can link to many others, and every row is paid for on every wake,
/// so the section is bounded however many there are: at most [maxRows] rows
/// and [charBudget] characters, with titles and one-liners clipped. When not
/// all fit, open tasks are chosen before closed ones and newer before older,
/// and the section says how many it left out. Chosen rows keep the order
/// they arrived in, so a task linked later does not reshuffle the section.
class LinkedTaskDirectory {
  const LinkedTaskDirectory._({
    required this.json,
    required this.taskIds,
    required this.omittedCount,
  });

  /// Lays out [linkedFrom] (tasks whose link points at the current task) and
  /// [linkedTo] (tasks it links out to) within the budget.
  factory LinkedTaskDirectory.build({
    required List<LinkedTaskRow> linkedFrom,
    required List<LinkedTaskRow> linkedTo,
  }) {
    if (linkedFrom.isEmpty && linkedTo.isEmpty) return empty;

    final candidates = [
      for (final entry in linkedFrom) (fromSide: true, entry: entry),
      for (final entry in linkedTo) (fromSide: false, entry: entry),
    ];
    final ranked = [for (var i = 0; i < candidates.length; i++) i]
      ..sort(
        (a, b) => _rank(candidates[a].entry.task, candidates[b].entry.task),
      );

    // The fixed frame — braces, both keys, an `omitted` entry at its longest
    // — is reserved up front, so whatever is admitted always fits.
    var used = _frameReserve;
    final admitted = <int, Map<String, dynamic>>{};
    for (final index in ranked) {
      if (admitted.length >= maxRows) break;
      final row = _clipped(candidates[index].entry.row);
      final cost = jsonEncode(row).length + _rowOverhead;
      // A row too large for what is left is skipped, not a stop: a smaller
      // row further down may still fit.
      if (used + cost > charBudget) continue;
      used += cost;
      admitted[index] = row;
    }

    List<Map<String, dynamic>> side({required bool fromSide}) => [
      for (var i = 0; i < candidates.length; i++)
        if (candidates[i].fromSide == fromSide) ?admitted[i],
    ];
    final omitted = candidates.length - admitted.length;

    return LinkedTaskDirectory._(
      json: _render(
        from: side(fromSide: true),
        to: side(fromSide: false),
        omitted: omitted,
      ),
      taskIds: {
        for (final row in admitted.values)
          if (row['id'] case final String id when id.isNotEmpty) id,
      },
      omittedCount: omitted,
    );
  }

  /// No linked tasks: no section, and nothing to read.
  static const empty = LinkedTaskDirectory._(
    json: '{}',
    taskIds: {},
    omittedCount: 0,
  );

  /// The most rows the section lists.
  static const maxRows = 30;

  /// The longest the section's JSON may be, in characters — about 3,000
  /// tokens.
  static const charBudget = 12000;

  /// The longest title a row carries, in characters.
  static const maxTitleChars = 160;

  /// The longest one-liner a row carries, in characters.
  static const maxOneLinerChars = 240;

  /// The row key holding a linked task's agent one-liner.
  static const oneLinerKey = 'latestTaskAgentReportOneLiner';

  /// The section's JSON: `linked_from` and `linked_to` arrays, one row per
  /// line, and an `omitted` entry when the budget left tasks out. `{}` when
  /// there are no linked tasks.
  final String json;

  /// The ids of the tasks the section lists — what the drill-down tools may
  /// read for this wake.
  final Set<String> taskIds;

  /// How many linked rows the budget left out.
  final int omittedCount;

  /// Characters per row beyond its JSON: indentation, comma, newline.
  static const _rowOverhead = 6;

  static const _closedStatuses = {'DONE', 'REJECTED'};

  /// The frame at its longest: empty arrays grow by four characters each
  /// once they hold a row, and the `omitted` count has at most six digits.
  static final int _frameReserve =
      _render(from: const [], to: const [], omitted: 999999).length + 4;

  static String omittedNote(int count) =>
      '$count more linked ${count == 1 ? 'task is' : 'tasks are'} not listed, '
      'to keep this context small: closed and older ones are left out first. '
      'Their ids are not available in this wake.';

  /// Open before closed, then newest first; the id breaks ties so the choice
  /// is the same on every wake.
  static int _rank(AiLinkedTaskContext a, AiLinkedTaskContext b) {
    final aClosed = _closedStatuses.contains(a.status);
    final bClosed = _closedStatuses.contains(b.status);
    if (aClosed != bClosed) return aClosed ? 1 : -1;
    final byCreated = b.createdAt.compareTo(a.createdAt);
    return byCreated != 0 ? byCreated : b.id.compareTo(a.id);
  }

  static Map<String, dynamic> _clipped(Map<String, dynamic> row) => {
    for (final MapEntry(:key, :value) in row.entries)
      key: switch ((key, value)) {
        ('title', final String title) => truncateAgentText(
          title,
          maxTitleChars,
        ),
        (oneLinerKey, final String oneLiner) => truncateAgentText(
          oneLiner,
          maxOneLinerChars,
        ),
        _ => value,
      },
  };

  static String _render({
    required List<Map<String, dynamic>> from,
    required List<Map<String, dynamic>> to,
    required int omitted,
  }) {
    String array(List<Map<String, dynamic>> rows) => rows.isEmpty
        ? '[]'
        : '[\n${rows.map((row) => '    ${jsonEncode(row)}').join(',\n')}\n  ]';
    final buffer = StringBuffer()
      ..write('{\n  "linked_from": ')
      ..write(array(from))
      ..write(',\n  "linked_to": ')
      ..write(array(to));
    if (omitted > 0) {
      buffer
        ..write(',\n  "omitted": ')
        ..write(
          jsonEncode({'count': omitted, 'note': omittedNote(omitted)}),
        );
    }
    buffer.write('\n}');
    return buffer.toString();
  }
}
