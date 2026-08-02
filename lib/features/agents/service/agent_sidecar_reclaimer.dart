import 'dart:io';

import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// Deletes the outbox's JSON sidecars for agent rows that are gone.
///
/// Every synced agent entity and link is also written to disk as
/// `/agent_entities/<id>.json` or `/agent_links/<id>.json` so the sync
/// pipeline can serve it later. Nothing has ever removed those files — not a
/// tombstone, not `hardDeleteAgent`, not retention — so a destroyed agent's
/// content stayed readable in the documents directory indefinitely, and disk
/// use tracked every row ever synced rather than the rows still held.
///
/// **What a peer asking for a reclaimed payload gets: a terminal "deleted"
/// response.** `BackfillResponseHandler._processAgentBackfillEntry` sends one
/// when the payload cannot be loaded, so the requester stops asking rather
/// than retrying against silence. No sync contract changes, because both
/// callers below only reclaim rows that are intentionally gone: a destroyed
/// agent's lifecycle syncs to every device, and retention prunes by a rule
/// every device applies to the same rows.
///
/// That propagation is asynchronous, though. `hardDeleteAgent` is local, so a
/// peer can still hold — or ask for — the old payload until the lifecycle
/// update reaches it, and the deleted response is what makes that case
/// terminate cleanly rather than something the reclaim prevents.
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

  /// Deletes the sidecars for the given entity and link ids. Returns how many
  /// files were removed.
  ///
  /// Best-effort by construction: a file that is already absent is the normal
  /// case (it may never have synced), and an unreadable one must not abort the
  /// caller, which has already committed its database work.
  /// Deletes one sidecar file, returning whether it existed.
  ///
  /// A seam so a test can force a deletion failure on every platform: the
  /// real failure modes (permissions, a busy file) are OS-specific, and the
  /// suite runs on a Windows shard where a POSIX `chmod` means nothing.
  @visibleForTesting
  bool Function(File file) deleteSidecar = _deleteSidecar;

  static bool _deleteSidecar(File file) {
    if (!file.existsSync()) return false;
    file.deleteSync();
    return true;
  }

  /// Files handled before yielding the isolate.
  ///
  /// A full sweep can reach ten thousand ids, and the deletes are synchronous
  /// — the fastest way to do the work, but ten thousand of them in one go
  /// monopolises the isolate and shows up as a startup freeze. Yielding keeps
  /// the total work identical while leaving the frame loop room to run.
  static const _yieldEvery = 200;

  Future<int> reclaim({
    Iterable<String> entityIds = const [],
    Iterable<String> linkIds = const [],
  }) async {
    final root = documentsDirectory;
    if (root == null) return 0;

    var removed = 0;
    var handled = 0;
    for (final (ids, toPath) in [
      (entityIds, relativeAgentEntityPath),
      (linkIds, relativeAgentLinkPath),
    ]) {
      for (final id in ids) {
        if (++handled % _yieldEvery == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        try {
          // Ids reach this method from sync payloads, so they are untrusted
          // input. A traversal segment would otherwise resolve to
          // '<docs>/agent_entities/../settings.json' and delete an unrelated
          // file outside the sidecar directory entirely.
          final relativePath = toPath(id);
          if (!isReclaimable(root: root, id: id, toPath: toPath)) {
            domainLogger.error(
              LogDomain.agentRuntime,
              ArgumentError.value(id, 'id', 'not a sidecar id'),
              message:
                  'refusing to reclaim a sidecar for a traversing id '
                  '${DomainLogger.sanitizeId(id)}',
            );
            continue;
          }
          // The relative paths carry a leading '/', which would otherwise make
          // this an absolute path and escape the documents directory.
          final file = File('${root.path}$relativePath');
          if (deleteSidecar(file)) removed++;
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

  /// Whether the resolved sidecar path stays inside its own directory.
  ///
  /// Checked by resolving the path rather than by rejecting characters: real
  /// ids contain colons (`day_status:<dayId>:<uuid>`), so a character
  /// blacklist refuses production rows and silently reclaims nothing. What
  /// matters is only where the path lands.
  ///
  /// Ids arrive from peers over sync, and the cost of being wrong is deleting
  /// a file no database write accounted for.
  @visibleForTesting
  static bool isReclaimable({
    required Directory root,
    required String id,
    required String Function(String id) toPath,
  }) {
    // An id is a leaf name, never a path. Rejecting separators and '..' is
    // what stops `../agent_entities/victim` — which normalises back *into*
    // this directory and would delete a different row's sidecar, passing a
    // containment check that only compares the parent directory.
    const backslash = r'\';
    if (id.isEmpty ||
        id.contains('/') ||
        id.contains(backslash) ||
        id.contains('..')) {
      return false;
    }
    return _isContained(root: root, relativePath: toPath(id), toPath: toPath);
  }

  static bool _isContained({
    required Directory root,
    required String relativePath,
    required String Function(String id) toPath,
  }) {
    // `p.join` DISCARDS everything before an absolute segment, and these
    // relative paths carry a leading '/', so joining them would drop the root
    // and compare two paths that both escaped it — a check that passes
    // without checking anything. Concatenate exactly as the delete does.
    String under(String relative) => p.normalize(
      '${root.path}${relative.startsWith('/') ? '' : '/'}$relative',
    );

    final directory = p.dirname(under(toPath('probe')));
    final resolved = under(relativePath);
    return p.equals(p.dirname(resolved), directory) &&
        p.isWithin(root.path, resolved);
  }
}
