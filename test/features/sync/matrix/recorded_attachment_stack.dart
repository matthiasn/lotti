import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/sync_attachment_fetcher.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_fetcher.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

/// The attachment stack as production wires it, over the SDK events a test
/// records: its index holds their descriptors, and its fetcher — the real
/// `MatrixAttachmentFetcher` — downloads and purges through the recorded
/// events themselves, so a test's `downloadAndDecryptAttachment` stubs and
/// `room.client.database` purge chains keep working on the mock it built.
///
/// Stands in for the client lookup (`SyncDescriptorFetcher`) that production
/// resolves a descriptor's event with: a recorded event is found by its id; a
/// mock that stubs no id is found as long as it is the only such one; and an
/// event the test never recorded — one production recovered into the index
/// itself — goes to `fallback`, the room mocks the test built for recovery.
class RecordedAttachmentStack implements SyncDescriptorFetcher {
  RecordedAttachmentStack({
    DomainLogger? logging,
    bool verboseLogging = true,
    this._fallback,
  }) : index = AttachmentIndex(
         logging: logging,
         verboseLogging: verboseLogging,
       ) {
    fetcher = MatrixAttachmentFetcher(events: this);
  }

  final SyncDescriptorFetcher? _fallback;
  final AttachmentIndex index;
  late final MatrixAttachmentFetcher fetcher;
  final Map<String, Event> _byEventId = <String, Event>{};
  final List<Event> _withoutId = <Event>[];

  /// Records [event] into the index and remembers it for downloads. Returns
  /// what `AttachmentIndex.record` returns.
  bool record(Event event) {
    final id = _safeEventId(event);
    if (id.isEmpty) {
      _withoutId.add(event);
    } else {
      _byEventId[id] = event;
    }
    return index.record(event);
  }

  Future<void> dispose() => index.dispose();

  @override
  Future<SyncDescriptorLookup> fetch({
    required String roomId,
    required String eventId,
  }) async {
    if (eventId.isEmpty) {
      return SyncDescriptorLookup(
        descriptor: _withoutId.length == 1 ? _withoutId.single : null,
        source: 'recorded',
      );
    }
    final recorded = _byEventId[eventId];
    if (recorded != null) {
      return SyncDescriptorLookup(descriptor: recorded, source: 'recorded');
    }
    final fallback = _fallback;
    if (fallback != null) {
      return fallback.fetch(roomId: roomId, eventId: eventId);
    }
    return SyncDescriptorLookup.none;
  }

  static String _safeEventId(Event event) {
    try {
      return event.eventId;
    } catch (_) {
      return '';
    }
  }
}
