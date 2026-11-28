import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/task_document_source.dart';

/// Where the task agent reads a task's documents, and where a version it
/// drafts is written. Null until the composition root
/// wires the documents feature's implementation; agents do not depend on it,
/// and without it the agent is never offered the document tools.
final taskDocumentSourceProvider = Provider<TaskDocumentSource?>(
  (ref) => null,
  name: 'taskDocumentSourceProvider',
);
