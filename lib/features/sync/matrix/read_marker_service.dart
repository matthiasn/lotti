import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

class SyncReadMarkerService {
  /// Persists and publishes Matrix read markers after successful processing.
  ///
  /// Prefers the room-level API (`Room.setReadMarker`) and only falls back to
  /// the timeline-level API when a snapshot is available. Updates are gated by
  /// `client.isLogged()` to avoid failures while the SDK is disconnected.
  SyncReadMarkerService({
    required SettingsDb settingsDb,
    required LoggingService loggingService,
  })  : _settingsDb = settingsDb,
        _loggingService = loggingService;

  final SettingsDb _settingsDb;
  final LoggingService _loggingService;

  /// Updates the read marker to [eventId] for the provided [room].
  ///
  /// - [client]: Matrix client used to check login state.
  /// - [room]: Target room for the read marker.
  /// - [eventId]: The event ID to advance the read marker to.
  /// - [timeline]: Optional timeline snapshot; used as a compatibility fallback
  ///   when the room-level update fails.
  Future<void> updateReadMarker({
    required Client client,
    required Room room,
    required String eventId,
    Timeline? timeline,
  }) async {
    await setLastReadMatrixEventId(
      eventId,
      _settingsDb,
    );

    if (client.isLogged()) {
      try {
        // Guard: Avoid regressing a remote marker if the server already has
        // a newer fullyRead. When a timeline is provided and both ids are
        // visible, only advance if `eventId` is strictly newer.
        final remoteId = room.fullyRead;
        if (remoteId != eventId) {
          var shouldSend = true;
          final tl = timeline;
          if (tl != null) {
            try {
              final events = tl.events;
              Event? a;
              Event? b;
              for (final e in events) {
                if (e.eventId == eventId) a = e;
                if (e.eventId == remoteId) b = e;
                if (a != null && b != null) break;
              }
              if (a != null && b != null) {
                final newer = TimelineEventOrdering.isNewer(
                  candidateTimestamp: a.originServerTs.millisecondsSinceEpoch,
                  candidateEventId: a.eventId,
                  latestTimestamp: b.originServerTs.millisecondsSinceEpoch,
                  latestEventId: b.eventId,
                );
                if (!newer) {
                  shouldSend = false;
                  _loggingService.captureEvent(
                    'marker.remote.skip id=$eventId (remoteAhead=$remoteId)',
                    domain: 'MATRIX_SERVICE',
                    subDomain: 'setReadMarker.guard',
                  );
                }
              }
            } catch (_) {
              // If comparison fails, fall through to default behaviour.
            }
          } else {
            // Without a timeline we can't compare reliably. Be conservative
            // and skip to avoid downgrading a newer remote marker.
            shouldSend = false;
            _loggingService.captureEvent(
              'marker.remote.skip(noTimeline) id=$eventId (remote=$remoteId)',
              domain: 'MATRIX_SERVICE',
              subDomain: 'setReadMarker.guard',
            );
          }
          if (!shouldSend) return;
        }

        // Prefer room-level API to avoid coupling to a snapshot timeline.
        await room.setReadMarker(eventId);
        _loggingService.captureEvent(
          'marker.remote room=${room.id} id=$eventId',
          domain: 'MATRIX_SERVICE',
          subDomain: 'setReadMarker',
        );
      } catch (error, stackTrace) {
        // Fallback to timeline-level API for compatibility if provided.
        if (timeline != null) {
          try {
            await timeline.setReadMarker(eventId: eventId);
            _loggingService.captureEvent(
              'marker.remote.timeline room=${room.id} id=$eventId',
              domain: 'MATRIX_SERVICE',
              subDomain: 'setReadMarker.timeline',
            );
            return;
          } catch (_) {
            // Fall through to log the original error below.
          }
        }
        _loggingService.captureException(
          error,
          domain: 'MATRIX_SERVICE',
          subDomain: 'setReadMarker ${client.deviceName}',
          stackTrace: stackTrace,
        );
      }
    }
  }
}
