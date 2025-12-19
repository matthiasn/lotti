import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Lightweight, in-memory index mapping relativePath -> latest attachment event.
///
/// Used by the apply phase to locate download descriptors for JSON files based
/// on the path referenced in the text message. Populated passively by the
/// stream consumer; never triggers rescans.
class AttachmentIndex {
  AttachmentIndex({LoggingService? logging}) : _logging = logging;

  final LoggingService? _logging;

  final Map<String, Event> _byPath = <String, Event>{};

  /// Records an attachment event keyed by its relativePath. Later events
  /// overwrite earlier ones for the same path.
  ///
  /// Returns true when the index changes (new event or updated eventId).
  bool record(Event e) {
    try {
      final mimetype = e.attachmentMimetype;
      final rp = e.content['relativePath'];
      if (rp is String && rp.isNotEmpty) {
        final key = rp.startsWith('/') ? rp : '/$rp';
        final noSlash = rp.startsWith('/') ? rp.substring(1) : rp;
        final existing = _byPath[key] ?? _byPath[noSlash];
        if (existing != null && existing.eventId == e.eventId) {
          return false;
        }
        _byPath[key] = e;
        // For robustness, also record a variant without the leading slash in
        // case callers use that form.
        _byPath[noSlash] = e;
        _logging?.captureEvent(
          'attachmentIndex.record path=$key mime=$mimetype id=${e.eventId}',
          domain: syncLoggingDomain,
          subDomain: 'attachmentIndex.record',
        );
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

  /// Returns the last-seen attachment event for [relativePath], or null.
  Event? find(String relativePath) {
    final key1 = relativePath;
    final key2 = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : '/$relativePath';
    final hit = _byPath[key1] ?? _byPath[key2];
    _logging?.captureEvent(
      hit == null
          ? 'attachmentIndex.miss path=$relativePath alt=$key2'
          : 'attachmentIndex.hit path=$relativePath id=${hit.eventId}',
      domain: syncLoggingDomain,
      subDomain: 'attachmentIndex.find',
    );
    return hit;
  }
}
