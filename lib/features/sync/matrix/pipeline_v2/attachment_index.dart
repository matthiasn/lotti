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
  void record(Event e) {
    try {
      final mimetype = e.attachmentMimetype;
      if (mimetype.isEmpty) return;
      final rp = e.content['relativePath'];
      if (rp is String && rp.isNotEmpty) {
        _byPath[rp] = e;
      }
    } catch (err) {
      _logging?.captureEvent(
        'attachmentIndex.record failed: $err',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'attachmentIndex',
      );
    }
  }

  /// Returns the last-seen attachment event for [relativePath], or null.
  Event? find(String relativePath) => _byPath[relativePath];
}
