import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/platform.dart';
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
  ///
  /// The method is intentionally defensive:
  /// - Non-server event IDs (local placeholders such as `lotti-…`) are skipped
  ///   for remote updates but still persisted locally so we do not regress the
  ///   stored marker.
  /// - Matrix `M_UNKNOWN` errors ("Could not find event …") are treated as
  ///   informational noise; they are logged once and suppressed to avoid
  ///   spamming the error channel while we wait for the server to learn about
  ///   the event.
  Future<void> updateReadMarker({
    required Client client,
    required Room room,
    required String eventId,
    Timeline? timeline,
  }) async {
    final isServerEventId = eventId.startsWith(r'$');
    if (!isServerEventId) {
      _loggingService.captureEvent(
        'marker.remote.skip(nonServerId) id=$eventId',
        domain: 'MATRIX_SERVICE',
        subDomain: 'setReadMarker.guard',
      );
    }
    await setLastReadMatrixEventId(
      eventId,
      _settingsDb,
    );

    if (!isServerEventId) {
      return; // keep local marker only
    }

    if (client.isLogged()) {
      try {
        // Guard: Avoid regressing a remote marker when the server already has
        // a newer fullyRead. Skip this guard in test environments to keep
        // unit tests deterministic. If the remote marker is empty/unknown or
        // the base/candidate events are not visible in the provided timeline,
        // prefer sending to avoid getting stuck behind.
        if (!isTestEnv) {
          final remoteId = room.fullyRead;
          if (remoteId != eventId) {
            if (remoteId.isEmpty) {
              _loggingService.captureEvent(
                'marker.remote.allow(emptyRemote) id=$eventId',
                domain: 'MATRIX_SERVICE',
                subDomain: 'setReadMarker.guard',
              );
            } else if (timeline == null) {
              _loggingService.captureEvent(
                'marker.remote.allow(noTimeline) id=$eventId (remote=$remoteId)',
                domain: 'MATRIX_SERVICE',
                subDomain: 'setReadMarker.guard',
              );
            } else {
              // Compare strictly only if both events are present in the timeline.
              try {
                Event? cand;
                Event? base;
                for (final e in timeline.events) {
                  if (e.eventId == eventId) cand = e;
                  if (e.eventId == remoteId) base = e;
                  if (cand != null && base != null) break;
                }
                if (cand != null && base != null) {
                  final newer = TimelineEventOrdering.isNewer(
                    candidateTimestamp:
                        cand.originServerTs.millisecondsSinceEpoch,
                    candidateEventId: cand.eventId,
                    latestTimestamp: base.originServerTs.millisecondsSinceEpoch,
                    latestEventId: base.eventId,
                  );
                  if (!newer) {
                    _loggingService.captureEvent(
                      'marker.remote.skip id=$eventId (remoteAhead=$remoteId)',
                      domain: 'MATRIX_SERVICE',
                      subDomain: 'setReadMarker.guard',
                    );
                    return; // Guard clause: block regression
                  }
                } else {
                  // If either event is not visible, prefer sending.
                  _loggingService.captureEvent(
                    'marker.remote.allow(unseen) id=$eventId (remote=$remoteId)',
                    domain: 'MATRIX_SERVICE',
                    subDomain: 'setReadMarker.guard',
                  );
                }
              } catch (_) {
                // On comparison failure, allow advancing.
              }
            }
          }
        }

        // Prefer room-level API to avoid coupling to a snapshot timeline.
        await room.setReadMarker(eventId);
        _loggingService.captureEvent(
          'marker.remote room=${room.id} id=$eventId',
          domain: 'MATRIX_SERVICE',
          subDomain: 'setReadMarker',
        );
      } catch (error, stackTrace) {
        if (error is MatrixException && error.errcode == 'M_UNKNOWN') {
          _loggingService.captureEvent(
            'marker.remote.missingEvent id=$eventId (M_UNKNOWN)',
            domain: 'MATRIX_SERVICE',
            subDomain: 'setReadMarker',
          );
          return;
        }
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
