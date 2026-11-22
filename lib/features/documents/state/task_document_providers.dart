import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';

/// The [TaskDocumentRepository] over the app's journal.
final taskDocumentRepositoryProvider = Provider<TaskDocumentRepository>(
  (ref) => TaskDocumentRepository(
    journalDb: ref.watch(journalDbProvider),
    persistenceLogic: ref.read(persistenceLogicProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
  ),
  name: 'taskDocumentRepositoryProvider',
);

/// The live documents linked from a task, oldest first, so a new one joins
/// the end of the section and none moves. Follows the task's links and every
/// linked entry, so a new document, a rename or a version that lands — here
/// or by sync — shows at once, without a reload.
final ProviderFamily<List<TaskDocumentEntry>, String> taskDocumentsProvider =
    Provider.autoDispose.family<List<TaskDocumentEntry>, String>(
      (ref, taskId) => liveTaskDocuments(
        ref.watch(resolvedOutgoingLinkedEntriesProvider(taskId)),
      ),
      name: 'taskDocumentsProvider',
    );
