import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:meta/meta.dart';

/// Which version of which document a review is of: the review shows what
/// that version changed, against the version it was written over.
typedef DocumentReviewKey = ({
  String taskId,
  String documentId,
  String versionId,
});

extension on DocumentReviewKey {
  TaskDocumentKey get document => (taskId: taskId, documentId: documentId);
}

/// What a review shows: a version, the version it was written over, and the
/// rows aligning the two.
@immutable
class DocumentReviewSnapshot {
  const DocumentReviewSnapshot({
    required this.version,
    required this.baseVersion,
    required this.pairs,
    required this.stats,
  });

  /// The version under review.
  final TaskDocumentVersionEntry version;

  /// The version it was written over; null when the document had no text
  /// yet, and then every block is an addition.
  final TaskDocumentVersionEntry? baseVersion;
  final List<MarkdownBlockPair> pairs;
  final MarkdownBlockDiffStats stats;

  /// The line on what the version changes; null when it carries none.
  String? get changeSummary => switch (version.data.changeSummary) {
    final String summary when summary.trim().isNotEmpty => summary.trim(),
    _ => null,
  };
}

/// The rows a review shows (ADR 0167): the version the key names and the one
/// it was written over, each read once, the blocks aligned once. A version
/// never changes after it is written, so nothing that happens while the
/// review is open — a sync, a newer version, an agent wake — rebuilds them.
///
/// Null when the key names no version of its document.
final FutureProviderFamily<DocumentReviewSnapshot?, DocumentReviewKey>
documentReviewSnapshotProvider = FutureProvider.autoDispose
    .family<DocumentReviewSnapshot?, DocumentReviewKey>((ref, key) async {
      final repository = ref.read(taskDocumentRepositoryProvider);
      final version = await repository.version(key.versionId);
      if (version == null || version.data.documentId != key.documentId) {
        return null;
      }
      final baseId = version.data.baseVersionId;
      final base = baseId == null ? null : await repository.version(baseId);
      final pairs = alignMarkdownBlocks(
        splitMarkdownBlocks(base?.data.markdown ?? ''),
        splitMarkdownBlocks(version.data.markdown),
      );
      return DocumentReviewSnapshot(
        version: version,
        baseVersion: base,
        pairs: pairs,
        stats: MarkdownBlockDiffStats.of(pairs),
      );
    }, name: 'documentReviewSnapshotProvider');

/// An open review: its rows, and whether the document still shows the
/// version they are of.
@immutable
class DocumentReview {
  const DocumentReview({required this.snapshot, required this.isCurrent});

  final DocumentReviewSnapshot snapshot;

  /// The document shows the version under review, so going back to the one
  /// before it is on offer. False once another version landed — an edit, a
  /// restore, the agent's next one.
  final bool isCurrent;
}

/// The review [DocumentReviewKey] names, as the view shows it: the snapshot,
/// with whether its version is still the document's — live, never touching
/// the rows. Null on the first load and when the key names no version.
/// Reads the snapshot with `.value`, so a rebuild keeps the rows it shows.
final ProviderFamily<DocumentReview?, DocumentReviewKey>
documentReviewProvider = Provider.autoDispose
    .family<DocumentReview?, DocumentReviewKey>((ref, key) {
      final snapshot = ref.watch(documentReviewSnapshotProvider(key)).value;
      if (snapshot == null) return null;
      final current = ref.watch(
        taskDocumentProvider(
          key.document,
        ).select((document) => document?.data.current?.id),
      );
      return DocumentReview(
        snapshot: snapshot,
        isCurrent: current == key.versionId,
      );
    }, name: 'documentReviewProvider');

/// The version of one of task `taskId`'s documents under review, or null
/// while none is: the document page reads it to show the review instead of
/// the text, and closes it by clearing it. In memory only, like the chat's
/// open toggle — a review is never restored on the next launch.
///
/// Leaving the page while reviewing leaves it set, so coming back to the
/// document returns to the review; the panes that step aside for it read
/// [documentReviewShowingProvider], which is true only while it is on
/// screen.
final NotifierProviderFamily<DocumentReviewOpen, DocumentReviewKey?, String>
documentReviewOpenProvider =
    NotifierProvider.family<DocumentReviewOpen, DocumentReviewKey?, String>(
      DocumentReviewOpen.new,
      name: 'documentReviewOpenProvider',
    );

class DocumentReviewOpen extends Notifier<DocumentReviewKey?> {
  DocumentReviewOpen(this.taskId);

  final String taskId;

  @override
  DocumentReviewKey? build() => null;

  /// Reviews [version], in place of any review open on this task.
  void open(DocumentReviewKey version) {
    assert(version.taskId == taskId, 'a review belongs to its own task');
    state = version;
  }

  void close() => state = null;
}

/// Whether a review of one of task `taskId`'s documents is on screen in the
/// desktop detail pane: one is open ([documentReviewOpenProvider]) and the
/// pane shows that document over the task (`NavService.desktopTaskDocument`).
///
/// The task list and the day column step aside while it is true, so the two
/// columns get the width they need. Derived only — the stored pane settings
/// are never written, so the layout comes back as it was the moment the
/// review closes or the pane returns to the task.
final ProviderFamily<bool, String> documentReviewShowingProvider = Provider
    .autoDispose
    .family<bool, String>((ref, taskId) {
      // No review, nothing to follow: the pane is listened to only while
      // one is open.
      final review = ref.watch(documentReviewOpenProvider(taskId));
      if (review == null) return false;
      final shown = ref.watch(navServiceProvider).desktopTaskDocument;
      void changed() => ref.invalidateSelf();
      shown.addListener(changed);
      ref.onDispose(() => shown.removeListener(changed));
      final document = shown.value;
      return document?.taskId == taskId &&
          document?.documentId == review.documentId;
    }, name: 'documentReviewShowingProvider');
