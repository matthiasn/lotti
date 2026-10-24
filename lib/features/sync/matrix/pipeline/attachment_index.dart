import 'dart:async';

import 'package:lotti/features/sync/matrix/pipeline/attachment_descriptor.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

/// An attachment event seen in the room: its media path and the plaintext
/// size it declares, when it declares one.
typedef ObservedAttachment = ({String relativePath, int? declaredSize});

/// Lightweight, in-memory index mapping both relative paths and exact Matrix
/// event ids to attachment descriptors.
///
/// Used by the apply phase to locate download descriptors for JSON files based
/// on the path referenced in the text message. Populated passively by the
/// stream consumer; never triggers rescans. It holds [AttachmentDescriptor]s,
/// not SDK events (ADR 0142, step 3): what the apply path reads needs no
/// `Room`, and fetching the bytes is `SyncAttachmentFetcher`'s job.
///
/// Emits a broadcast [pathRecorded] stream whenever the index mutates so
/// subscribers — notably `QueuePipelineCoordinator`, which resurrects
/// abandoned ledger rows on attachment arrival — can react without polling.
class AttachmentIndex {
  AttachmentIndex({this._logging, this.verboseLogging = true});

  final DomainLogger? _logging;

  /// When true, emits per-event `attachmentIndex.record`, `attachmentIndex.hit`,
  /// and `attachmentIndex.miss` lines. Production disables this; tests keep
  /// it enabled so existing per-event assertions remain valid.
  final bool verboseLogging;

  final Map<String, AttachmentDescriptor> _byPath =
      <String, AttachmentDescriptor>{};
  final Map<String, AttachmentDescriptor> _byEventId =
      <String, AttachmentDescriptor>{};

  // Per-eventId idempotency guard. Keyed by eventId so repeated observations
  // of the same Matrix event (from live scan + catch-up + backfill passes)
  // are no-ops, even when several events share one relativePath and would
  // otherwise thrash the _byPath slot back and forth between them.
  final Set<String> _seenEventIds = <String>{};

  // Broadcast path signal. Emits the canonical path (with leading slash)
  // once per actual index mutation — duplicate observations of the same
  // event are filtered out before we touch the controller, so
  // resurrection work is not triggered redundantly by replays of the
  // same attachment event.
  final StreamController<String> _pathCtl =
      StreamController<String>.broadcast();

  /// Fires with the canonical path (always prefixed with `/`) each
  /// time an attachment event is recorded for the first time.
  /// Subscribers use this to wake queue rows that were abandoned
  /// waiting for this particular attachment's JSON to land.
  Stream<String> get pathRecorded => _pathCtl.stream;

  /// [pathRecorded] with the size each recorded attachment declares
  /// ([AttachmentDescriptor.declaredSize]): what a media answer held back for
  /// another holder compares against its own copy.
  Stream<ObservedAttachment> get attachmentsObserved =>
      pathRecorded.map((path) {
        return (relativePath: path, declaredSize: find(path)?.declaredSize);
      });

  /// Releases the underlying broadcast controller. Call from the owner
  /// (`MatrixService.dispose`) so test teardown or app shutdown does
  /// not leave the stream open.
  Future<void> dispose() async {
    if (!_pathCtl.isClosed) {
      await _pathCtl.close();
    }
  }

  /// Records an attachment event keyed by its relativePath. Later events
  /// overwrite earlier ones for the same path.
  ///
  /// Returns true when the index changes (new event or updated eventId).
  bool record(Event e) {
    try {
      final descriptor = AttachmentDescriptor.fromEvent(e);
      if (descriptor == null) return false;
      final rp = descriptor.relativePath;
      final eventId = descriptor.eventId.isEmpty ? null : descriptor.eventId;
      if (eventId != null && !_seenEventIds.add(eventId)) {
        return false;
      }
      final key = rp.startsWith('/') ? rp : '/$rp';
      final noSlash = rp.startsWith('/') ? rp.substring(1) : rp;
      _byPath[key] = descriptor;
      // For robustness, also record a variant without the leading slash in
      // case callers use that form.
      _byPath[noSlash] = descriptor;
      if (eventId != null) {
        _byEventId[eventId] = descriptor;
      }
      if (verboseLogging) {
        _logging?.log(
          LogDomain.sync,
          'attachmentIndex.record path=$key mime=${descriptor.mimetype} '
          'id=${eventId ?? '?'}',
          subDomain: 'attachmentIndex.record',
        );
      }
      if (!_pathCtl.isClosed) {
        _pathCtl.add(key);
      }
      return true;
    } catch (err) {
      _logging?.log(
        LogDomain.sync,
        'attachmentIndex.record failed: $err',
        subDomain: 'attachmentIndex',
      );
    }
    return false;
  }

  /// Returns the last-seen attachment descriptor for [relativePath], or null.
  AttachmentDescriptor? find(String relativePath) {
    final key1 = relativePath;
    final key2 = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : '/$relativePath';
    final hit = _byPath[key1] ?? _byPath[key2];
    if (verboseLogging) {
      _logging?.log(
        LogDomain.sync,
        hit == null
            ? 'attachmentIndex.miss path=$relativePath alt=$key2'
            : 'attachmentIndex.hit path=$relativePath '
                  'id=${hit.eventId.isEmpty ? '?' : hit.eventId}',
        subDomain: 'attachmentIndex.find',
      );
    }
    return hit;
  }

  /// Returns the attachment descriptor with the exact Matrix [eventId].
  ///
  /// Unlike [find], this lookup preserves older generations after a newer
  /// attachment reuses the same relative path.
  AttachmentDescriptor? findByEventId(String eventId) {
    final hit = _byEventId[eventId];
    if (verboseLogging) {
      _logging?.log(
        LogDomain.sync,
        hit == null
            ? 'attachmentIndex.miss eventId=$eventId'
            : 'attachmentIndex.hit eventId=$eventId',
        subDomain: 'attachmentIndex.findByEventId',
      );
    }
    return hit;
  }
}
