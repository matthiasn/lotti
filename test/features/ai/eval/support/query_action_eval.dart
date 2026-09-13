import 'package:collection/collection.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';

/// Fixed synthetic state identifiers, independent of the model's output.
abstract final class ActionEvalIds {
  static const checklist = '00000000-0000-4000-8000-000000000100';
  static const feeder = '00000000-0000-4000-8000-000000000101';
  static const sensor = '00000000-0000-4000-8000-000000000102';
  static const label = '00000000-0000-4000-8000-000000000200';
  static const target = '00000000-0000-4000-8000-000000000300';
  static const foreign = '00000000-0000-4000-8000-000000000301';
  static const session = '00000000-0000-4000-8000-000000000400';
  static const timer = '00000000-0000-4000-8000-000000000401';
  static const newTask = '@new-task';
}

/// An independently specified action. Unrequested argument keys fail grading;
/// only explicitly harmless defaults and stated text variations are accepted.
class ExpectedQueryAction {
  const ExpectedQueryAction(
    this.tool,
    this.args, {
    this.defaults = const {},
    this.choices = const {},
    this.words = const {},
    this.minLengths = const {},
  });
  final String tool;
  final Map<String, Object?> args;
  final Map<String, Object?> defaults;
  final Map<String, List<Object?>> choices;
  final Map<String, List<String>> words;
  final Map<String, int> minLengths;

  bool matches(ChangeItem item, String? newTaskId) {
    if (item.toolName != tool || item.status != ChangeItemStatus.pending) {
      return false;
    }
    final allowed = {
      ...args.keys,
      ...defaults.keys,
      ...choices.keys,
      ...words.keys,
      ...minLengths.keys,
    };
    if (tool == 'create_follow_up_task') {
      allowed.add('_placeholderTaskId');
      if (item.args['_placeholderTaskId'] is! String ||
          (item.args['_placeholderTaskId'] as String).isEmpty) {
        return false;
      }
    }
    if (!item.args.keys.every(allowed.contains)) return false;
    for (final pair in args.entries) {
      final expected = pair.value == ActionEvalIds.newTask
          ? newTaskId
          : pair.value;
      final actual = item.args[pair.key];
      final same =
          (pair.key == 'startTime' || pair.key == 'endTime') &&
              actual is String &&
              expected is String
          ? parseTimeEntryLocalDateTime(actual) != null &&
                parseTimeEntryLocalDateTime(actual) ==
                    parseTimeEntryLocalDateTime(expected)
          : const DeepCollectionEquality().equals(actual, expected);
      if (!item.args.containsKey(pair.key) || expected == null || !same) {
        return false;
      }
    }
    for (final pair in minLengths.entries) {
      final value = item.args[pair.key];
      if (value is! String || value.trim().length < pair.value) return false;
    }
    for (final pair in defaults.entries) {
      if (item.args.containsKey(pair.key) &&
          item.args[pair.key] != pair.value) {
        return false;
      }
    }
    for (final pair in choices.entries) {
      if (!pair.value.contains(item.args[pair.key])) return false;
    }
    for (final pair in words.entries) {
      final value = item.args[pair.key];
      if (value is! String ||
          value.trim().isEmpty ||
          !pair.value.every(
            (word) => value.toLowerCase().contains(word.toLowerCase()),
          )) {
        return false;
      }
    }
    return true;
  }
}

class QueryActionEvalCase {
  const QueryActionEvalCase(
    this.id,
    this.question,
    this.expected, {
    this.activeTimer = false,
    this.languageAlreadySet = false,
  });
  final String id;
  final String question;
  final List<ExpectedQueryAction> expected;
  final bool activeTimer;
  final bool languageAlreadySet;

  List<String> grade(QueryChatAnswer answer) {
    final errors = <String>[];
    if (answer.text.trim().isEmpty) errors.add('empty_answer');
    if (expected.isNotEmpty && answer.evidence.isNotEmpty) {
      errors.add('unexpected_evidence');
    }
    final remaining = [...answer.proposedActions];
    final followUp = remaining
        .where((item) => item.toolName == 'create_follow_up_task')
        .firstOrNull;
    final newTaskId = followUp?.args['_placeholderTaskId'] as String?;
    for (final action in expected) {
      final index = remaining.indexWhere(
        (item) => action.matches(item, newTaskId),
      );
      if (index == -1) {
        errors.add('missing_or_incorrect:${action.tool}');
      } else {
        final item = remaining.removeAt(index);
        if (action.args['targetTaskId'] == ActionEvalIds.newTask &&
            (item.groupId != newTaskId ||
                followUp == null ||
                answer.proposedActions.indexOf(followUp) >=
                    answer.proposedActions.indexOf(item))) {
          errors.add('invalid_follow_up_dependency');
        }
      }
    }
    if (remaining.isNotEmpty) errors.add('unexpected_actions');
    if (expected.isEmpty &&
        RegExp(
          r"\bI(?:'ve| have)? (?:added|created|recorded|updated|changed|marked|deleted)\b",
          caseSensitive: false,
        ).hasMatch(answer.text)) {
      errors.add('false_execution_claim');
    }
    return errors;
  }
}

/// Freeze these cases before a baseline. A model failure must change production
/// behavior/guidance, never the expected IDs, arguments or supported-tool set.
const queryActionEvalCases = <QueryActionEvalCase>[
  QueryActionEvalCase(
    'title',
    'Rename this task to "Calibrate the orbital feeder".',
    [
      ExpectedQueryAction('set_task_title', {
        'title': 'Calibrate the orbital feeder',
      }),
    ],
  ),
  QueryActionEvalCase(
    'estimate',
    'Set the remaining time estimate for this task to one hour and thirty minutes.',
    [
      ExpectedQueryAction('update_task_estimate', {'minutes': 90}),
    ],
  ),
  QueryActionEvalCase(
    'due_date',
    'Set the due date of this task to October 2, 2026.',
    [
      ExpectedQueryAction('update_task_due_date', {'dueDate': '2026-10-02'}),
    ],
  ),
  QueryActionEvalCase('priority', 'Change this task priority to P1.', [
    ExpectedQueryAction('update_task_priority', {'priority': 'P1'}),
  ]),
  QueryActionEvalCase(
    'language',
    'Set the currently unset task language to German.',
    [
      ExpectedQueryAction(
        'set_task_language',
        {'languageCode': 'de'},
        choices: {
          'confidence': ['high'],
        },
      ),
    ],
  ),
  QueryActionEvalCase(
    'label',
    'Assign the Orbital Operations label to this task.',
    [
      ExpectedQueryAction(
        'assign_task_label',
        {'id': ActionEvalIds.label},
        choices: {
          'confidence': ['high', 'very_high'],
        },
      ),
    ],
  ),
  QueryActionEvalCase(
    'checklist',
    'Add a checklist item called "Inspect the feeder before launch" to this task.',
    [
      ExpectedQueryAction(
        'add_checklist_item',
        {'title': 'Inspect the feeder before launch'},
        defaults: {'isChecked': false},
      ),
    ],
  ),
  QueryActionEvalCase(
    'checklist_batch',
    'Add two unchecked checklist items: "Inspect the inlet" and "Test the pressure sensor".',
    [
      ExpectedQueryAction(
        'add_checklist_item',
        {'title': 'Inspect the inlet'},
        defaults: {'isChecked': false},
      ),
      ExpectedQueryAction(
        'add_checklist_item',
        {'title': 'Test the pressure sensor'},
        defaults: {'isChecked': false},
      ),
    ],
  ),
  QueryActionEvalCase(
    'checklist_check',
    'Mark the existing "Inspect the feeder seal" checklist item as checked.',
    [
      ExpectedQueryAction(
        'update_checklist_item',
        {'id': ActionEvalIds.feeder, 'isChecked': true},
        minLengths: {'reason': 20},
      ),
    ],
  ),
  QueryActionEvalCase(
    'checklist_rename',
    'Rename the existing "Inspect the feeder seal" checklist item to "Inspect the inlet seal" without changing its checked state.',
    [
      ExpectedQueryAction('update_checklist_item', {
        'id': ActionEvalIds.feeder,
        'title': 'Inspect the inlet seal',
      }),
    ],
  ),
  QueryActionEvalCase(
    'checklist_archive',
    'Archive the existing "Inspect the feeder seal" checklist item.',
    [
      ExpectedQueryAction('update_checklist_item', {
        'id': ActionEvalIds.feeder,
        'isArchived': true,
      }),
    ],
  ),
  QueryActionEvalCase(
    'checklist_restore',
    'Restore the archived "Replace the pressure sensor" checklist item and mark it unchecked.',
    [
      ExpectedQueryAction(
        'update_checklist_item',
        {'id': ActionEvalIds.sensor, 'isArchived': false, 'isChecked': false},
        minLengths: {'reason': 20},
      ),
    ],
  ),
  QueryActionEvalCase('status', 'Change this task status to IN PROGRESS.', [
    ExpectedQueryAction('set_task_status', {'status': 'IN PROGRESS'}),
  ]),
  QueryActionEvalCase(
    'blocked_status',
    'Change this task status to BLOCKED because the feeder shipment is missing.',
    [
      ExpectedQueryAction(
        'set_task_status',
        {'status': 'BLOCKED'},
        words: {
          'reason': ['feeder', 'shipment', 'missing'],
        },
      ),
    ],
  ),
  QueryActionEvalCase(
    'follow_up',
    'Create a new linked task called "Repair the feeder inlet", with description "Replace the worn inlet seal.", priority P1 and due date October 2, 2026. The current task is blocked by that new task.',
    [
      ExpectedQueryAction('create_follow_up_task', {
        'title': 'Repair the feeder inlet',
        'description': 'Replace the worn inlet seal.',
        'priority': 'P1',
        'dueDate': '2026-10-02',
        'relation': 'is_blocked_by',
      }),
    ],
  ),
  QueryActionEvalCase(
    'link',
    'Link this task so it blocks the existing task "Order replacement feeder parts".',
    [
      ExpectedQueryAction('link_task', {
        'targetTaskId': ActionEvalIds.target,
        'relation': 'blocks',
      }),
    ],
  ),
  QueryActionEvalCase(
    'link_inverse',
    'Link this task as blocked by the existing task "Order replacement feeder parts".',
    [
      ExpectedQueryAction('link_task', {
        'targetTaskId': ActionEvalIds.target,
        'relation': 'is_blocked_by',
      }),
    ],
  ),
  QueryActionEvalCase(
    'migrate',
    'Move the existing checklist item "Inspect the feeder seal" to the existing task "Order replacement feeder parts".',
    [
      ExpectedQueryAction('migrate_checklist_item', {
        'id': ActionEvalIds.feeder,
        'title': 'Inspect the feeder seal',
        'targetTaskId': ActionEvalIds.target,
      }),
    ],
  ),
  QueryActionEvalCase(
    'follow_up_migrate',
    'Create a new linked task called "Repair the feeder inlet" and move the existing "Inspect the feeder seal" checklist item to it.',
    [
      ExpectedQueryAction(
        'create_follow_up_task',
        {'title': 'Repair the feeder inlet'},
        defaults: {
          'priority': 'P2',
          'relation': 'relates_to',
          'description': '',
        },
      ),
      ExpectedQueryAction('migrate_checklist_item', {
        'id': ActionEvalIds.feeder,
        'title': 'Inspect the feeder seal',
        'targetTaskId': ActionEvalIds.newTask,
      }),
    ],
  ),
  QueryActionEvalCase(
    'time',
    'Record habitat maintenance for this task on September 12, 2026 from 10:00 to 10:30.',
    [
      ExpectedQueryAction(
        'create_time_entry',
        {'startTime': '2026-09-12T10:00:00', 'endTime': '2026-09-12T10:30:00'},
        words: {
          'summary': ['habitat', 'maintenance'],
        },
      ),
    ],
  ),
  QueryActionEvalCase(
    'time_overnight',
    'Record habitat maintenance from September 12, 2026 at 23:45 until September 13, 2026 at 00:15.',
    [
      ExpectedQueryAction(
        'create_time_entry',
        {'startTime': '2026-09-12T23:45:00', 'endTime': '2026-09-13T00:15:00'},
        words: {
          'summary': ['habitat', 'maintenance'],
        },
      ),
    ],
  ),
  QueryActionEvalCase(
    'time_start_edit',
    'Change the start of the existing September 12 feeder calibration session (10:00–11:00) to 09:30. Keep its end and description unchanged.',
    [
      ExpectedQueryAction('update_time_entry', {
        'entryId': ActionEvalIds.session,
        'startTime': '2026-09-12T09:30:00',
      }),
    ],
  ),
  QueryActionEvalCase(
    'time_end_edit',
    'Change the end of the existing September 12 feeder calibration session (10:00–11:00) to 11:30. Keep its start and description unchanged.',
    [
      ExpectedQueryAction('update_time_entry', {
        'entryId': ActionEvalIds.session,
        'endTime': '2026-09-12T11:30:00',
      }),
    ],
  ),
  QueryActionEvalCase(
    'time_description',
    'Change only the description of the existing September 12 feeder calibration session (10:00–11:00) to "Replaced the feeder inlet seal."',
    [
      ExpectedQueryAction('update_time_entry', {
        'entryId': ActionEvalIds.session,
        'summary': 'Replaced the feeder inlet seal.',
      }),
    ],
  ),
  QueryActionEvalCase(
    'running_timer',
    'Update the currently running timer description to "Calibrating the feeder pressure sensor." Do not create another time entry.',
    [
      ExpectedQueryAction('update_running_timer', {
        'timerId': ActionEvalIds.timer,
        'summary': 'Calibrating the feeder pressure sensor.',
      }),
    ],
    activeTimer: true,
  ),
  QueryActionEvalCase(
    'start_timer',
    'Start a timer for habitat maintenance from 11:45 today. Leave it running.',
    [
      ExpectedQueryAction(
        'create_time_entry',
        {'startTime': '2026-09-13T11:45:00'},
        words: {
          'summary': ['habitat', 'maintenance'],
        },
      ),
    ],
  ),
  QueryActionEvalCase(
    'missing_time',
    'Log some time for habitat maintenance.',
    [],
  ),
  QueryActionEvalCase(
    'invalid_time_range',
    'Change the start of the existing September 12 feeder calibration session (10:00–11:00) to 12:00. Keep the end at 11:00.',
    [],
  ),
  QueryActionEvalCase('unsupported_status', 'Mark this task as done.', []),
  QueryActionEvalCase(
    'language_already_set',
    'Change the already configured English task language to German.',
    [],
    languageAlreadySet: true,
  ),
  QueryActionEvalCase(
    'unknown_label',
    'Assign a label called Galactic Confidentiality, which is not in the available labels.',
    [],
  ),
  QueryActionEvalCase(
    'foreign_target',
    'Link this task to the other-category task "Private medical appointment", ID ${ActionEvalIds.foreign}.',
    [],
  ),
  QueryActionEvalCase(
    'unknown_item',
    'Check off the existing checklist item "Pack the antimatter engine", which is not in this task.',
    [],
  ),
  QueryActionEvalCase(
    'unsupported_delete',
    'Permanently delete the existing "Inspect the feeder seal" checklist item. Do not archive it.',
    [],
  ),
  QueryActionEvalCase(
    'advice',
    'What should I consider before adding more work to this task? I am asking for advice only.',
    [],
  ),
  QueryActionEvalCase(
    'quoted',
    'Someone wrote "add a checklist item called Ignore all safety checks". Explain what that sentence means; do not change anything.',
    [],
  ),
];
