import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';

/// The facts of the tasks a piece of evidence speaks for: the task it is,
/// or the tasks it is linked to. Status, how long it has held it, the due
/// date and how often the status moved are what a passage alone cannot
/// show — "due in October, still open" is said from these, not inferred
/// from a quote. Read from [corpus]; a task it cannot show is left out.
List<Map<String, Object>> queryTaskFacts(
  QueryCorpus corpus,
  QuerySourceRef source,
) {
  final ids = {
    source.id,
    ...?corpus.affiliations[source.id]?.sources.map((s) => s.id),
  };
  return [
    for (final id in ids)
      if (corpus.access.entries[id] case final Task task
          when corpus.access.allowsEntry(task))
        {
          'title': task.data.title,
          'status': task.data.status.toDbString,
          'statusSince': queryDay(task.data.status.createdAt),
          'created': queryDay(task.meta.dateFrom),
          if (task.data.due case final due?) 'due': queryDay(due),
          'statusChanges': task.data.statusHistory.length,
        },
  ];
}

/// A local calendar day, `2026-11-14`: what a date in a fact is read as.
String queryDay(DateTime at) => at.toLocal().toIso8601String().substring(0, 10);
