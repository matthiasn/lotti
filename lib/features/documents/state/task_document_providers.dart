import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/service/task_document_agent_source.dart';
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

/// The documents feature's `TaskDocumentSource` for the task agent; the
/// composition root wires it into `taskDocumentSourceProvider`.
final taskDocumentAgentSourceProvider = Provider<TaskDocumentAgentSource>(
  (ref) => TaskDocumentAgentSource(ref.watch(taskDocumentRepositoryProvider)),
  name: 'taskDocumentAgentSourceProvider',
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

/// Which document of which task: the family key of the providers that follow
/// one document.
typedef TaskDocumentKey = ({String taskId, String documentId});

/// Document `documentId` of task `taskId` as stored now — live, like
/// [taskDocumentsProvider] — or null once it is deleted.
final ProviderFamily<TaskDocumentEntry?, TaskDocumentKey> taskDocumentProvider =
    Provider.autoDispose.family<TaskDocumentEntry?, TaskDocumentKey>(
      (ref, key) => ref
          .watch(taskDocumentsProvider(key.taskId))
          .where((document) => document.id == key.documentId)
          .firstOrNull,
      name: 'taskDocumentProvider',
    );

/// The version a document shows, or null before its first one. Read again
/// only when the document moves to another version — a rename alone reads
/// nothing — and, being a future, keeps the version it had while the next
/// one loads, so the text on screen is replaced in place, never blanked.
final FutureProviderFamily<TaskDocumentVersionEntry?, TaskDocumentKey>
taskDocumentCurrentVersionProvider = FutureProvider.autoDispose
    .family<TaskDocumentVersionEntry?, TaskDocumentKey>((ref, key) async {
      ref.watch(
        taskDocumentProvider(key).select((document) => document?.data.current),
      );
      final document = ref.read(taskDocumentProvider(key));
      if (document == null) return null;
      return ref.read(taskDocumentRepositoryProvider).currentVersion(document);
    }, name: 'taskDocumentCurrentVersionProvider');

/// Every version of a document, newest first, read again whenever the
/// document moves to another version.
final FutureProviderFamily<List<TaskDocumentVersionEntry>, TaskDocumentKey>
taskDocumentVersionsProvider = FutureProvider.autoDispose
    .family<List<TaskDocumentVersionEntry>, TaskDocumentKey>((ref, key) {
      ref.watch(
        taskDocumentProvider(key).select((document) => document?.data.current),
      );
      return ref.read(taskDocumentRepositoryProvider).versions(key.documentId);
    }, name: 'taskDocumentVersionsProvider');
