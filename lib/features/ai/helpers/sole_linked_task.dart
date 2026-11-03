import 'package:lotti/classes/journal_entities.dart';

/// The one task among [linkedEntities] — everything an entry links to and
/// everything that links to it — or null when there is none, or more than one.
///
/// This is the fallback for an AI run started on an entry without saying
/// which task it is for (the entry opened from the logbook rather than from
/// inside a task). An entry can belong to several tasks, a task and its
/// follow-up being the usual pair, and then no link says which one is meant:
/// taking the first would write a coding prompt or cover art into whichever
/// task the database happened to return first. With more than one candidate
/// the run gets no task, so a skill that needs one is not offered there; from
/// inside either task the task is known and passed along explicitly.
Task? soleLinkedTask(Iterable<JournalEntity> linkedEntities) {
  final tasks = {
    for (final task in linkedEntities.whereType<Task>()) task.id: task,
  };
  return tasks.length == 1 ? tasks.values.single : null;
}
