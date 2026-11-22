import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/classes/vector_clock.dart';

/// The instant every task document fixture is offset from.
final DateTime taskDocFixtureEpoch = DateTime.utc(2026, 3, 15, 12);

/// A ref to version [number] of a document, written [second] seconds after
/// [taskDocFixtureEpoch], with id `version-<number>` unless given.
TaskDocumentVersionRef taskDocumentRef(
  int number, {
  int second = 0,
  String? id,
}) => TaskDocumentVersionRef(
  id: id ?? 'version-$number',
  number: number,
  createdAt: taskDocFixtureEpoch.add(Duration(seconds: second)),
);

/// Task document [id] titled [title], showing [current], under [clock],
/// last edited [editedSecond] seconds after [taskDocFixtureEpoch].
TaskDocumentEntry taskDocumentEntry({
  required Map<String, int> clock,
  TaskDocumentVersionRef? current,
  String title = 'Client one-pager',
  int editedSecond = 0,
  bool deleted = false,
  String id = 'task-document',
}) {
  final edited = taskDocFixtureEpoch.add(Duration(seconds: editedSecond));
  return TaskDocumentEntry(
    meta: Metadata(
      id: id,
      createdAt: taskDocFixtureEpoch,
      updatedAt: edited,
      dateFrom: taskDocFixtureEpoch,
      dateTo: taskDocFixtureEpoch,
      vectorClock: VectorClock(clock),
      deletedAt: deleted ? edited : null,
    ),
    data: TaskDocumentData(title: title, current: current),
  );
}

/// Version [number] of document [documentId], holding [markdown].
TaskDocumentVersionEntry taskDocumentVersionEntry({
  int number = 1,
  String markdown = '# Next steps\n\nShare the rollout plan.',
  String documentId = 'task-document',
  TaskDocumentAuthor author = TaskDocumentAuthor.user,
  String? id,
}) => TaskDocumentVersionEntry(
  meta: Metadata(
    id: id ?? 'version-$number',
    createdAt: taskDocFixtureEpoch,
    updatedAt: taskDocFixtureEpoch,
    dateFrom: taskDocFixtureEpoch,
    dateTo: taskDocFixtureEpoch,
    vectorClock: const VectorClock({'a': 1}),
  ),
  data: TaskDocumentVersionData(
    documentId: documentId,
    number: number,
    markdown: markdown,
    author: author,
  ),
);
