import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Lightweight, in-memory index mapping relativePath -> latest attachment event.
///
/// Used by the apply phase to locate download descriptors for JSON files based
/// on the path referenced in the text message. Populated passively by the
/// stream consumer; never triggers rescans.
class AttachmentIndex {
  AttachmentIndex({LoggingService? logging, this.verboseLogging = true})
    : _logging = logging;

  final LoggingService? _logging;

  /// When true, emits per-event `attachmentIndex.record`, `attachmentIndex.hit`,
  /// and `attachmentIndex.miss` lines. Production disables this; tests keep
  /// it enabled so existing per-event assertions remain valid.
  final bool verboseLogging;

  final Map<String, Event> _byPath = <String, Event>{};

  // Per-eventId idempotency guard. Keyed by eventId so repeated observations
  // of the same Matrix event (from live scan + catch-up + backfill passes)
  // are no-ops, even when several events share one relativePath and would
  // otherwise thrash the _byPath slot back and forth between them.
  final Set<String> _seenEventIds = <String>{};

  /// Records an attachment event keyed by its relativePath. Later events
  /// overwrite earlier ones for the same path.
  ///
  /// Returns true when the index changes (new event or updated eventId).
  bool record(Event e) {
    try {
      final mimetype = e.attachmentMimetype;
      final rp = e.content['relativePath'];
      if (rp is String && rp.isNotEmpty) {
        final eventId = _safeEventId(e);
        if (eventId != null && !_seenEventIds.add(eventId)) {
          return false;
        }
        final key = rp.startsWith('/') ? rp : '/$rp';
        final noSlash = rp.startsWith('/') ? rp.substring(1) : rp;
        _byPath[key] = e;
        // For robustness, also record a variant without the leading slash in
        // case callers use that form.
        _byPath[noSlash] = e;
        if (verboseLogging) {
          _logging?.captureEvent(
            'attachmentIndex.record path=$key mime=$mimetype id=${eventId ?? '?'}',
            domain: syncLoggingDomain,
            subDomain: 'attachmentIndex.record',
          );
        }
        return true;
      }
    } catch (err) {
      _logging?.captureEvent(
        'attachmentIndex.record failed: $err',
        domain: syncLoggingDomain,
        subDomain: 'attachmentIndex',
      );
    }
    return false;
  }

  // Safe access to [Event.eventId]. Returns null when the field is missing or
  // empty, so callers can treat the event as "not known yet" instead of
  // failing the whole record path.
  static String? _safeEventId(Event e) {
    try {
      final id = e.eventId;
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  /// Returns the last-seen attachment event for [relativePath], or null.
  Event? find(String relativePath) {
    final key1 = relativePath;
    final key2 = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : '/$relativePath';
    final hit = _byPath[key1] ?? _byPath[key2];
    if (verboseLogging) {
      _logging?.captureEvent(
        hit == null
            ? 'attachmentIndex.miss path=$relativePath alt=$key2'
            : 'attachmentIndex.hit path=$relativePath id=${hit.eventId}',
        domain: syncLoggingDomain,
        subDomain: 'attachmentIndex.find',
      );
    }
    return hit;
  }
}
