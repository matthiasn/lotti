import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:meta/meta.dart';

/// The task agent's drafts of the document the key names still
/// waiting for the user, newest first — null until the task's proposals
/// have loaded, so "none" is never confused with "not read yet".
///
/// Read with `.value`, so a reload keeps the list it had (stay while
/// reload). Drafts proposed in task chat belong to the chat and are not
/// listed here.
final ProviderFamily<List<PendingSuggestion>?, TaskDocumentKey>
pendingDocumentProposalsProvider = Provider.autoDispose
    .family<List<PendingSuggestion>?, TaskDocumentKey>((ref, key) {
      final list = ref.watch(unifiedSuggestionListProvider(key.taskId)).value;
      if (list == null) return null;
      return [
        for (final suggestion in list.open)
          if (suggestion.item.toolName ==
                  TaskAgentToolNames.proposeDocumentVersion &&
              suggestion.item.args['documentId'] == key.documentId)
            suggestion,
      ];
    }, name: 'pendingDocumentProposalsProvider');

/// Which draft of which document a review is of: the change item, by its
/// set and its place in it.
typedef DocumentReviewKey = ({
  String taskId,
  String documentId,
  String changeSetId,
  int itemIndex,
});

extension on DocumentReviewKey {
  TaskDocumentKey get document => (taskId: taskId, documentId: documentId);

  bool names(PendingSuggestion suggestion) =>
      suggestion.changeSet.id == changeSetId &&
      suggestion.itemIndex == itemIndex;
}

/// What a review holds while it is open: the draft, the version it was
/// drafted against, and the rows aligning the two.
@immutable
class DocumentReviewSnapshot {
  const DocumentReviewSnapshot({
    required this.proposal,
    required this.baseVersion,
    required this.pairs,
    required this.stats,
  });

  final PendingSuggestion proposal;

  /// The version the draft was written over; null when the document had no
  /// text yet, and then every proposed block is an addition.
  final TaskDocumentVersionEntry? baseVersion;
  final List<MarkdownBlockPair> pairs;
  final MarkdownBlockDiffStats stats;

  ChangeItem get item => proposal.item;

  String get proposedMarkdown => item.args['markdown'] as String? ?? '';

  /// The agent's line on what the draft changes; null when it gave none.
  String? get changeSummary => switch (item.args['changeSummary']) {
    final String summary when summary.trim().isNotEmpty => summary.trim(),
    _ => null,
  };

  /// The version id the draft names as its base; null for a document that
  /// had no text.
  String? get baseVersionId => item.args['baseVersionId'] as String?;
}

/// The draft a review is of, by its fingerprint, which a reload of the
/// task's proposals leaves alone: what the review snapshot watches, so it is
/// built again only when the draft stops waiting, never because something
/// else changed. Null while the proposals load.
final ProviderFamily<_DraftState?, DocumentReviewKey> _draftStateProvider =
    Provider.autoDispose.family<_DraftState?, DocumentReviewKey>((ref, key) {
      final drafts = ref.watch(pendingDocumentProposalsProvider(key.document));
      if (drafts == null) return null;
      final draft = drafts.where(key.names).firstOrNull;
      return draft == null
          ? const _DraftGone()
          : _DraftWaiting(ChangeItem.fingerprint(draft.item));
    });

@immutable
sealed class _DraftState {
  const _DraftState();
}

class _DraftWaiting extends _DraftState {
  const _DraftWaiting(this.fingerprint);

  final String fingerprint;

  @override
  bool operator ==(Object other) =>
      other is _DraftWaiting && other.fingerprint == fingerprint;

  @override
  int get hashCode => fingerprint.hashCode;
}

class _DraftGone extends _DraftState {
  const _DraftGone();

  @override
  bool operator ==(Object other) => other is _DraftGone;

  @override
  int get hashCode => 0;
}

/// The rows a review shows, pinned (ADR 0166, direction B).
///
/// Built once for the draft the key names — the version it was drafted
/// against read once, the blocks aligned once — and built again only when
/// that draft stops waiting. A sync, a version landing, an agent wake or a
/// newer draft never swaps the rows under the reader; [documentReviewProvider]
/// says what changed around them instead.
///
/// Null while the task's proposals load, and once the draft is no longer
/// waiting: confirmed or dismissed here or on another device, or withdrawn.
final FutureProviderFamily<DocumentReviewSnapshot?, DocumentReviewKey>
documentReviewSnapshotProvider = FutureProvider.autoDispose
    .family<DocumentReviewSnapshot?, DocumentReviewKey>((ref, key) async {
      if (ref.watch(_draftStateProvider(key)) is! _DraftWaiting) return null;
      final draft = ref
          .read(pendingDocumentProposalsProvider(key.document))!
          .firstWhere(key.names);
      final baseId = draft.item.args['baseVersionId'];
      final base = baseId is String
          ? await ref.read(taskDocumentRepositoryProvider).version(baseId)
          : null;
      final markdown = draft.item.args['markdown'];
      final pairs = alignMarkdownBlocks(
        splitMarkdownBlocks(base?.data.markdown ?? ''),
        splitMarkdownBlocks(markdown is String ? markdown : ''),
      );
      return DocumentReviewSnapshot(
        proposal: draft,
        baseVersion: base,
        pairs: pairs,
        stats: MarkdownBlockDiffStats.of(pairs),
      );
    }, name: 'documentReviewSnapshotProvider');

/// An open review: its pinned rows, and what moved around them.
@immutable
class DocumentReview {
  const DocumentReview({
    required this.snapshot,
    required this.isStale,
    required this.newerProposalAvailable,
  });

  final DocumentReviewSnapshot snapshot;

  /// The document no longer shows the version the draft was written over —
  /// an edit, a restore or another draft landed since. Confirming would be
  /// refused (ADR 0166), so the review offers a fresh draft instead.
  final bool isStale;

  /// The agent proposed a later draft of the same document while this one
  /// was open; the rows stay, and the review says so.
  final bool newerProposalAvailable;
}

/// The review [DocumentReviewKey] names, as the view shows it: the pinned
/// snapshot, with whether it went stale and whether a newer draft waits —
/// both live, neither touching the rows. Null on the first load, and once
/// the draft is no longer waiting, when the review closes onto the
/// document. Reads the snapshot with `.value`, so a rebuild keeps the rows
/// it shows.
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
      final drafts =
          ref.watch(pendingDocumentProposalsProvider(key.document)) ??
          const <PendingSuggestion>[];
      final opened = snapshot.proposal.changeSet.createdAt;
      return DocumentReview(
        snapshot: snapshot,
        isStale: current != snapshot.baseVersionId,
        newerProposalAvailable: drafts.any(
          (draft) =>
              !key.names(draft) && draft.changeSet.createdAt.isAfter(opened),
        ),
      );
    }, name: 'documentReviewProvider');
