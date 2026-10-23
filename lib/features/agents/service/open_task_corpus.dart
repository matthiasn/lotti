import 'package:lotti/classes/day_plan.dart' show localDay;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/utils/day_agent_capture_helpers.dart';

/// The bounded open-task corpus two agents embed in a prompt: the day agent's
/// capture wake (`DayAgentCorpusService`) and the front agent's routing index.
///
/// One ordering, written once: tasks due on or before [day] first — overdue
/// work is what a user most often means — then the open tasks the day-agent
/// corpus query returns, closed tasks skipped, the allow-list applied, each
/// task once, at most [limit]. Both callers shape their own rows from the
/// result; neither re-derives the order, so a corpus built here for either
/// agent is byte-stable across the two.
Future<List<Task>> readOpenTaskCorpus({
  required JournalDb journalDb,
  required Set<String> allowedCategoryIds,
  required DateTime day,
  required int limit,
}) async {
  final dayStart = localDay(day);
  final openTasks = await journalDb.getOpenTasksForDayAgentCorpus(
    categoryIds: allowedCategoryIds,
    limit: limit,
  );
  final overdueAndToday = await journalDb.getTasksDueOnOrBefore(dayStart);

  final byId = <String, Task>{};
  for (final task in [...overdueAndToday, ...openTasks]) {
    if (isClosedTask(task)) continue;
    if (!categoryAllowed(task.meta.categoryId, allowedCategoryIds)) continue;
    byId.putIfAbsent(task.id, () => task);
    if (byId.length >= limit) break;
  }
  return byId.values.toList(growable: false);
}

/// One full-text hit on an open task: the task and its rank among every FTS
/// match for the phrase, counting the non-task and closed hits it was
/// ranked behind, so a caller scoring by rank sees the index's own order.
typedef OpenTaskPhraseMatch = ({int rank, Task task});

/// Open tasks whose text matches [phrase], in the FTS index's order.
///
/// Closed tasks and non-task entries are skipped but still occupy a rank;
/// [categoryFilter] of `null` or empty is unrestricted. At most [limit]
/// matches.
Future<List<OpenTaskPhraseMatch>> matchOpenTasksByPhrase({
  required Fts5Db fts5Db,
  required JournalDb journalDb,
  required String phrase,
  required Set<String>? categoryFilter,
  required int limit,
}) async {
  final ids = await fts5Db.watchFullTextMatches(phrase).first;
  if (ids.isEmpty) return const <OpenTaskPhraseMatch>[];

  final entities = await journalDb.getJournalEntitiesForIdsUnordered(
    ids.toSet(),
  );
  final taskById = {
    for (final entity in entities)
      if (entity is Task && !isClosedTask(entity)) entity.id: entity,
  };

  final matches = <OpenTaskPhraseMatch>[];
  for (var rank = 0; rank < ids.length; rank++) {
    final task = taskById[ids[rank]];
    if (task == null) continue;
    if (!categoryAllowed(task.meta.categoryId, categoryFilter)) continue;
    matches.add((rank: rank, task: task));
    if (matches.length >= limit) break;
  }
  return matches;
}
