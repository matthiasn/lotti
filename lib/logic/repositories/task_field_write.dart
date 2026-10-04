import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';

/// What became of a tool's write of one task field ([writeTaskField]).
sealed class TaskFieldWrite {
  const TaskFieldWrite();
}

/// The field was set; [task] is the task as stored afterwards.
class TaskFieldWritten extends TaskFieldWrite {
  const TaskFieldWritten(this.task);

  final Task task;
}

/// Nothing was written: the stored field no longer holds the value the tool
/// decided against — sync or the user set it since — and the newer value
/// stands. [task] is the task as stored.
class TaskFieldMoved extends TaskFieldWrite {
  const TaskFieldMoved(this.task);

  final Task task;
}

/// The task does not exist, or the write failed.
class TaskFieldWriteFailed extends TaskFieldWrite {
  const TaskFieldWriteFailed();
}

/// Sets one field of [task] — the copy a tool call decided against — on the
/// task as stored: [set] is applied to the stored data only while [field]
/// still reads the same value there as on [task], inside the write.
///
/// A tool validates its change against the task its call began with, and
/// the write lands after further awaits. Comparing again on the stored row,
/// in the same transaction as the write, keeps the tool from setting a
/// field over a value it never saw (`specs/tla/TaskFieldWrites.tla`,
/// NoBlindAgentWrite); building on the stored row keeps every field the
/// tool does not set as stored (NoLostFieldEdit). The change effects [task]
/// records — the dispatcher's key for this change among them (ADR 0098) —
/// are written in the same version as the value.
Future<TaskFieldWrite> writeTaskField({
  required JournalRepository journalRepository,
  required Task task,
  required Object? Function(TaskData data) field,
  required TaskData Function(TaskData stored) set,
}) async {
  var moved = false;
  final stored = await journalRepository.updateTask(task.id, (stored) {
    moved = field(stored) != field(task.data);
    return moved ? stored : set(stored).withEffectsOf(task.data);
  });
  if (stored == null) return const TaskFieldWriteFailed();
  return moved ? TaskFieldMoved(stored) : TaskFieldWritten(stored);
}
