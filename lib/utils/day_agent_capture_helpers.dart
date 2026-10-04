import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';

/// Pure helpers shared across the day-agent capture/corpus/triage
/// collaborators. Kept free of instance state so each collaborator can
/// reuse them without depending on the others.

/// Whether [categoryId] is permitted by the [allowed] set. An empty or
/// null allow-set is treated as unrestricted.
bool categoryAllowed(String? categoryId, Set<String>? allowed) {
  if (allowed == null || allowed.isEmpty) return true;
  return categoryId != null && allowed.contains(categoryId);
}

/// Trims [value] and collapses blank-only strings to `null`.
String? blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

/// Whether [task] is in a terminal (done/rejected) state.
bool isClosedTask(Task task) {
  const closedTaskStatuses = {'DONE', 'REJECTED'};
  return closedTaskStatuses.contains(task.data.status.toDbString);
}

/// End-of-day timestamp for [date], preserving its UTC/local zone so
/// callers comparing the resulting `due` against other UTC timestamps
/// (created_at, etc.) don't get a local→UTC offset surprise.
DateTime endOfDay(DateTime date) {
  return date.isUtc
      ? DateTime.utc(date.year, date.month, date.day, 23, 59, 59, 999)
      : DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}
