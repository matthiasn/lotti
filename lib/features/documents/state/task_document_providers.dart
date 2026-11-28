import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/service/task_document_agent_source.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';

/// Whether task documents are switched on (`enable_task_documents`): the
/// task's Documents section, "Write a document", and the document tools of
/// the task agent and the task's chat. False until the flag is read, so
/// nothing of the feature shows before the user's choice is known.
final Provider<bool> taskDocumentsEnabledProvider = Provider.autoDispose<bool>(
  (ref) =>
      ref.watch(configFlagProvider(enableTaskDocumentsFlag)).value ?? false,
  name: 'taskDocumentsEnabledProvider',
);

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

/// Whether document `documentId` is known to be gone from task `taskId` —
/// deleted, or never one of its documents — as opposed to not read yet.
///
/// [taskDocumentProvider] is null in both cases: the task's links and each
/// linked entry load one after the other. A page that took null for
/// "deleted" would say so on every cold open, and would close a review the
/// route had just asked for. False while anything that could still produce
/// the document is loading.
final ProviderFamily<bool, TaskDocumentKey> taskDocumentGoneProvider = Provider
    .autoDispose
    .family<bool, TaskDocumentKey>((ref, key) {
      if (ref.watch(taskDocumentProvider(key)) != null) return false;
      final links = ref
          .watch(linkedEntriesControllerProvider(key.taskId))
          .value;
      if (links == null) return false;
      if (!links.any((link) => link.toId == key.documentId)) return true;
      return ref.watch(entryControllerProvider(key.documentId)).hasValue;
    }, name: 'taskDocumentGoneProvider');

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
