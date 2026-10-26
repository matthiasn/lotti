import 'package:lotti/features/sync/matrix/pipeline/attachment_descriptor.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_fetcher.dart';
import 'package:lotti/features/sync/matrix/sync_event_trust.dart';
import 'package:lotti/services/domain_logging.dart';

/// Recovers the descriptor an inbound payload names, by event id, as a plain
/// [AttachmentDescriptor] the apply path can index (ADR 0142).
///
/// The apply path needs this exactly once: when a payload's descriptor is
/// missing from the in-memory index after a restart or a missed file event.
/// What comes back is already vetted — only a descriptor encrypted by a
/// trusted device may name a payload's JSON — so the apply step holds no SDK
/// event and no trust policy of its own, and the recovery can be answered by
/// whichever isolate holds the Matrix client: in-process by
/// [TrustedDescriptorRecovery], from the sync isolate over a request.
abstract interface class SyncDescriptorRecovery {
  /// The trusted descriptor [eventId] of [roomId], or null when nothing
  /// usable was found: the room is unknown here, the event is missing or
  /// still ciphertext, it names another event or room, its sender is not
  /// trusted, or it describes no attachment. Throws what the lookup throws —
  /// a timeout, a network error, a server error — so the caller classifies
  /// it.
  Future<AttachmentDescriptor?> recover({
    required String roomId,
    required String eventId,
  });
}

/// Recovers through the Matrix client this isolate holds: the SDK lookup of
/// [SyncDescriptorFetcher], then the inbound trust gate, then the plain
/// descriptor.
class TrustedDescriptorRecovery implements SyncDescriptorRecovery {
  TrustedDescriptorRecovery({
    required SyncDescriptorFetcher fetcher,
    required SyncEventTrust trust,
    DomainLogger? logging,
  }) : this._(fetcher, trust, logging);

  TrustedDescriptorRecovery._(this._fetcher, this._trust, this._logging);

  static const _subDomain = 'descriptorRecovery';

  final SyncDescriptorFetcher _fetcher;
  final SyncEventTrust _trust;
  final DomainLogger? _logging;

  @override
  Future<AttachmentDescriptor?> recover({
    required String roomId,
    required String eventId,
  }) async {
    final lookup = await _fetcher.fetch(roomId: roomId, eventId: eventId);
    final event = lookup.descriptor;
    // The server answers an id lookup with whatever it holds: bind the
    // result to the event and room that were asked for before trusting it.
    final identityMatches =
        event != null && event.eventId == eventId && event.roomId == roomId;
    final trusted =
        identityMatches &&
        await _trust.admits(event, subDomain: '$_subDomain.trust');
    final descriptor = trusted ? AttachmentDescriptor.fromEvent(event) : null;
    _logging?.log(
      LogDomain.sync,
      'descriptorRecovery.result eventId=$eventId found=${event != null} '
      'source=${lookup.source} identityMatches=$identityMatches '
      'trusted=$trusted descriptor=${descriptor != null}',
      subDomain: _subDomain,
    );
    return descriptor;
  }
}
