import 'dart:io';

import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/file_utils.dart';

/// Deletes the outbox's JSON sidecars for agent rows that are gone.
///
/// Every synced agent entity and link is also written to disk as
/// `/agent_entities/<id>.json` or `/agent_links/<id>.json` so the sync
/// pipeline can serve it later. Nothing has ever removed those files — not a
/// tombstone, not `hardDeleteAgent`, not retention — so a destroyed agent's
/// content stayed readable in the documents directory indefinitely, and disk
/// use tracked every row ever synced rather than the rows still held.
///
/// **What a peer asking for a reclaimed payload gets: nothing, and that is
/// correct.** `BackfillResponseHandler._processBackfillEntry` already returns
/// "skipped" when it cannot produce a payload, so a request for a reclaimed
/// file is answered by silence and the requester's own backoff. No sync
/// contract changes, because both callers below only reclaim rows that are
/// intentionally gone *everywhere*: a destroyed agent's lifecycle syncs to
/// every device, and retention prunes by a rule every device applies to the
/// same rows. Asking for one is asking for something no peer still has.
class AgentSidecarReclaimer {
  AgentSidecarReclaimer({
    required this.documentsDirectory,
    required this.domainLogger,
  });

  /// Root the relative sidecar paths hang off. Null disables reclamation —
  /// the directory is unavailable in tests and headless contexts, and a
  /// missing file is never worth failing a delete or a sweep over.
  final Directory? documentsDirectory;

  final DomainLogger domainLogger;

  /// Deletes the sidecars for [entityIds] and [linkIds]. Returns how many
  /// files were removed.
  ///
  /// Best-effort by construction: a file that is already absent is the normal
  /// case (it may never have synced), and an unreadable one must not abort the
  /// caller, which has already committed its database work.
  int reclaim({
    Iterable<String> entityIds = const [],
    Iterable<String> linkIds = const [],
  }) {
    final root = documentsDirectory;
    if (root == null) return 0;

    var removed = 0;
    for (final (ids, toPath) in [
      (entityIds, relativeAgentEntityPath),
      (linkIds, relativeAgentLinkPath),
    ]) {
      for (final id in ids) {
        try {
          // The relative paths carry a leading '/', which would otherwise make
          // this an absolute path and escape the documents directory.
          final file = File(
            '${root.path}${toPath(id)}',
          );
          if (file.existsSync()) {
            file.deleteSync();
            removed++;
          }
        } catch (e, s) {
          domainLogger.error(
            LogDomain.agentRuntime,
            e,
            message:
                'failed to reclaim sidecar for '
                '${DomainLogger.sanitizeId(id)}',
            stackTrace: s,
          );
        }
      }
    }
    return removed;
  }
}
