import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/save_attachment.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/timeline_context.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

const _maxTimelineProcessingRetries = 5;
const _readMarkerFollowUpDelay = Duration(milliseconds: 150);
// Perform a few consecutive drains in a single pass to avoid staying
// one message behind due to async timeline updates.
const _maxDrainPasses = 3;

// Escalating live snapshot limits to widen the window when we suspect the
// newest event fell just outside the current view or the SDK applied updates
// slightly after our first fetch.
const List<int> _timelineLimits = <int>[100, 300, 500, 1000];

// Short intra-pass delays to give the SDK a moment to apply timeline updates
// after sync completes, before we re-fetch the live snapshot.
const List<Duration> _staleTailRetryDelays = <Duration>[
  Duration(milliseconds: 60),
  Duration(milliseconds: 120),
];

class _IndexedEvent {
  const _IndexedEvent({
    required this.index,
    required this.event,
  });

  final int index;
  final Event event;
}

Future<void> listenToTimelineEvents({
  required TimelineContext listener,
}) async {
  final loggingDb = listener.loggingService;
  var syncRoom = listener.roomManager.currentRoom;

  try {
    // Defensive check: Ensure syncRoom is loaded before attempting to listen
    if (syncRoom == null) {
      final syncRoomId = listener.roomManager.currentRoomId;
      if (syncRoomId != null) {
        loggingDb.captureEvent(
          '⚠️ Sync room $syncRoomId not yet available – retrying hydrate.',
          domain: 'MATRIX_SERVICE',
          subDomain: 'listenToTimelineEvents.retryHydrate',
        );
        await listener.roomManager.hydrateRoomSnapshot(
          client: listener.client,
        );
        syncRoom = listener.roomManager.currentRoom;
      }

      if (syncRoom == null) {
        loggingDb.captureEvent(
          '⚠️ Cannot listen to timeline: syncRoom is null. '
          'syncRoomId: $syncRoomId',
          domain: 'MATRIX_SERVICE',
          subDomain: 'listenToTimelineEvents',
        );
        return;
      }
    }

    loggingDb.captureEvent(
      'Attempting to listen - syncRoom: ${syncRoom.id}, '
      'syncRoomId: ${listener.roomManager.currentRoomId}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'listenToTimelineEvents',
    );

    final previousTimeline = listener.timeline;

    if (previousTimeline != null) {
      previousTimeline.cancelSubscriptions();
    }

    void scheduleRefresh() => listener.enqueueTimelineRefresh();

    listener.timeline = await syncRoom.getTimeline(
      onNewEvent: () {
        Future<void>.microtask(scheduleRefresh);
      },
      onInsert: (_) => scheduleRefresh(),
      onChange: (_) => scheduleRefresh(),
      onRemove: (_) => scheduleRefresh(),
      onUpdate: scheduleRefresh,
    );

    unawaited(
      Future<void>.delayed(const Duration(seconds: 1))
          .then((value) => listener.enqueueTimelineRefresh()),
    );

    final timeline = listener.timeline;

    if (timeline == null) {
      loggingDb.captureEvent(
        'Timeline is null',
        domain: 'MATRIX_SERVICE',
        subDomain: 'listenToTimelineEvents',
      );
      return;
    }
  } catch (e, stackTrace) {
    debugPrint('$e');
    loggingDb.captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'listenToTimelineEvents',
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<void> processNewTimelineEvents({
  required TimelineContext listener,
  required JournalDb journalDb,
  required LoggingService loggingService,
  required SyncReadMarkerService readMarkerService,
  required SyncEventProcessor eventProcessor,
  required Directory documentsDirectory,
  Map<String, int>? failureCounts,
}) async {
  try {
    if (!listener.client.isLogged()) {
      loggingService.captureEvent(
        'Skipping timeline processing: client not logged in.',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processNewTimelineEvents.unauthenticated',
      );
      return;
    }
    // Drain timeline in small batches to avoid being one message behind.
    for (var pass = 0; pass < _maxDrainPasses; pass++) {
      // Pull fresh events from homeserver before each pass.
      await listener.client.sync();

      final syncRoom = listener.roomManager.currentRoom;
      final roomId = listener.roomManager.currentRoomId ??
          listener.roomManager.currentRoom?.id ??
          'unknown';

      // Prefer the already-attached live timeline first to avoid snapshot lag.
      var timeline = listener.timeline;
      var sortedEvents = const <_IndexedEvent>[];
      var newEvents = const <Event>[];
      var usedLimit = 0;

      final lastReadEventContextId = listener.lastReadEventContextId;

      Future<void> computeFromTimeline(Timeline tl, {String source = 'live'}) async {
        final events = tl.events;
        sortedEvents = <_IndexedEvent>[
          for (var i = 0; i < events.length; i++)
            _IndexedEvent(index: i, event: events[i]),
        ]
          ..sort((a, b) {
            final timestampComparison =
                TimelineEventOrdering.timestamp(a.event)
                    .compareTo(TimelineEventOrdering.timestamp(b.event));
            if (timestampComparison != 0) {
              return timestampComparison;
            }
            return b.index.compareTo(a.index);
          });
        final newestId =
            sortedEvents.isNotEmpty ? sortedEvents.last.event.eventId : null;
        loggingService.captureEvent(
          'Timeline drain start (pass ${pass + 1}) - room: $roomId, '
          'lastRead: ${lastReadEventContextId ?? 'null'}, '
          'newest: ${newestId ?? 'null'}, '
          'events: ${sortedEvents.length}, source: $source${usedLimit > 0 ? ', limit: $usedLimit' : ''}',
          domain: 'MATRIX_SERVICE',
          subDomain: 'timeline.debug',
        );

        final lastReadPosition = lastReadEventContextId == null
            ? -1
            : sortedEvents.indexWhere(
                (indexed) =>
                    indexed.event.eventId == lastReadEventContextId,
              );

        final candidateEvents = <Event>[];
        for (var i = 0; i < sortedEvents.length; i++) {
          final event = sortedEvents[i].event;
          final eventId = event.eventId;
          if (lastReadEventContextId != null) {
            if (lastReadPosition >= 0) {
              if (i <= lastReadPosition) {
                continue;
              }
            } else if (eventId == lastReadEventContextId) {
              continue;
            }
          }
          candidateEvents.add(event);
        }
        newEvents = candidateEvents;

        // If empty and we're at the tail, do tiny intra-pass waits to allow the
        // SDK to apply the newest event into the live list.
        final atTail = lastReadEventContextId != null &&
            lastReadPosition >= 0 &&
            lastReadPosition == sortedEvents.length - 1;
        if (newEvents.isEmpty && atTail) {
          for (final delay in _staleTailRetryDelays) {
            loggingService.captureEvent(
              'Empty snapshot at tail; retrying after ${delay.inMilliseconds}ms '
              '(pass ${pass + 1}, source: $source${usedLimit > 0 ? ', limit: $usedLimit' : ''})',
              domain: 'MATRIX_SERVICE',
              subDomain: 'timeline.debug',
            );
            await Future<void>.delayed(delay);
            // Re-evaluate from the same live timeline instance.
            final evs = tl.events;
            final retrySorted = <_IndexedEvent>[
              for (var i = 0; i < evs.length; i++)
                _IndexedEvent(index: i, event: evs[i]),
            ]
              ..sort((a, b) {
                final timestampComparison =
                    TimelineEventOrdering.timestamp(a.event)
                        .compareTo(TimelineEventOrdering.timestamp(b.event));
                if (timestampComparison != 0) {
                  return timestampComparison;
                }
                return b.index.compareTo(a.index);
              });
            final recalculated = <Event>[];
            for (var i = 0; i < retrySorted.length; i++) {
              final event = retrySorted[i].event;
              final eventId = event.eventId;
              if (lastReadPosition >= 0) {
                if (i <= lastReadPosition) {
                  continue;
                }
              } else if (eventId == lastReadEventContextId) {
                continue;
              }
              recalculated.add(event);
            }
            if (recalculated.isNotEmpty) {
              sortedEvents = retrySorted;
              newEvents = recalculated;
              break;
            }
          }
        }
      } // end computeFromTimeline

      // 1) Try the live timeline first, if present.
      if (timeline != null) {
        await computeFromTimeline(timeline);
      }

      // 2) If still empty, fall back to fetching wider snapshots.
      if (newEvents.isEmpty) {
        for (final limit in _timelineLimits) {
          usedLimit = limit;
          timeline = await syncRoom?.getTimeline(limit: limit);
          if (timeline == null) {
            loggingService.captureEvent(
              'Timeline is null',
              domain: 'MATRIX_SERVICE',
              subDomain: 'processNewTimelineEvents',
            );
            return;
          }
          await computeFromTimeline(timeline, source: 'snapshot');
          if (newEvents.isNotEmpty) {
            break;
          }
        }
      }

      if (newEvents.isEmpty) {
        // After escalating limits and intra-pass retries, still nothing.
        if (pass < _maxDrainPasses - 1) {
          loggingService.captureEvent(
            'No new events in pass ${pass + 1}; continuing drain (limits tried: $usedLimit).',
            domain: 'MATRIX_SERVICE',
            subDomain: 'timeline.debug',
          );
          continue;
        }
        // On the final pass, schedule a short follow-up regardless to cover
        // single-message gaps that land just after the snapshot.
        loggingService.captureEvent(
          'Timeline follow-up scheduled (empty snapshot) - room: $roomId',
          domain: 'MATRIX_SERVICE',
          subDomain: 'timeline.debug',
        );
        unawaited(
          Future<void>.delayed(_readMarkerFollowUpDelay).then((_) {
            listener.enqueueTimelineRefresh();
          }),
        );
        break;
      }

      loggingService.captureEvent(
        'Processing ${newEvents.length} timeline events '
        'for room ${syncRoom?.id}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processNewTimelineEvents',
      );

      // Phase 1: prefetch attachments for all new remote events so any
      // subsequent processors can assume referenced files are present even if
      // the file-bearing event appears later in the timeline.
      for (final event in newEvents) {
        final isRemoteEvent = event.senderId != listener.client.userID;
        if (isRemoteEvent && event.attachmentMimetype.isNotEmpty) {
          await saveAttachment(
            event,
            loggingService: loggingService,
            documentsDirectory: documentsDirectory,
          );
        }
      }

      // Phase 2: process events and decide the farthest read marker.
      String? latestAdvancingEventId;
      num? latestAdvancingTimestamp;

      var hadRetriableFailure = false;
      for (final event in newEvents) {
        final eventId = event.eventId;
        var shouldAdvanceReadMarker = true;
        final isRemoteEvent = event.senderId != listener.client.userID;

        // Skip re-ingesting events emitted by this device.
        if (isRemoteEvent) {
          try {
            loggingService.captureEvent(
              'Processing event ${event.eventId} from ${event.senderId} '
              '(${event.type}) in room ${syncRoom?.id}',
              domain: 'MATRIX_SERVICE',
              subDomain: 'processNewTimelineEvents',
            );

            if (event.messageType == syncMessageType) {
              await eventProcessor.process(
                event: event,
                journalDb: journalDb,
              );
            }

            failureCounts?.remove(eventId);
          } on FileSystemException catch (error, stackTrace) {
            final advance = _recordProcessingFailure(
              eventId: eventId,
              loggingService: loggingService,
              failureCounts: failureCounts,
              error: error,
              stackTrace: stackTrace,
              subDomain: 'processNewTimelineEvents.missingAttachment',
              skipReason: 'missing attachment',
            );
            shouldAdvanceReadMarker = advance;
            if (!advance) {
              hadRetriableFailure = true;
            }
          } on Object catch (error, stackTrace) {
            final advance = _recordProcessingFailure(
              eventId: eventId,
              loggingService: loggingService,
              failureCounts: failureCounts,
              error: error,
              stackTrace: stackTrace,
              subDomain: 'processNewTimelineEvents.handler',
              skipReason: 'handler error',
            );
            shouldAdvanceReadMarker = advance;
            if (!advance) {
              hadRetriableFailure = true;
            }
          }
        }

        if (shouldAdvanceReadMarker && eventId.startsWith(r'$')) {
          final eventTimestamp = TimelineEventOrdering.timestamp(event);
          if (TimelineEventOrdering.isNewer(
            candidateTimestamp: eventTimestamp,
            candidateEventId: eventId,
            latestTimestamp: latestAdvancingTimestamp,
            latestEventId: latestAdvancingEventId,
          )) {
            latestAdvancingEventId = eventId;
            latestAdvancingTimestamp = eventTimestamp;
          }
        }
      }

      if (latestAdvancingEventId != null) {
        loggingService.captureEvent(
          'Advancing read marker to $latestAdvancingEventId',
          domain: 'MATRIX_SERVICE',
          subDomain: 'processNewTimelineEvents',
        );
        // Advance in-memory marker before persisting, so any observers read the
        // most recent value immediately.
        listener.lastReadEventContextId = latestAdvancingEventId;
        await readMarkerService.updateReadMarker(
          client: listener.client,
          room: syncRoom!,
          eventId: latestAdvancingEventId,
          timeline: timeline,
        );
        // Continue to the next pass to catch any events that landed mid-loop.
        // We also keep the small delayed refresh as a safety net.
        loggingService.captureEvent(
          'Timeline drain end (pass ${pass + 1}) - room: $roomId, '
          'processed: ${newEvents.length}, advancedTo: $latestAdvancingEventId, '
          'followUp: true',
          domain: 'MATRIX_SERVICE',
          subDomain: 'timeline.debug',
        );
        unawaited(
          Future<void>.delayed(_readMarkerFollowUpDelay).then((_) {
            listener.enqueueTimelineRefresh();
          }),
        );
      } else {
        // No advancement in this pass; if we observed a retriable failure
        // (e.g., attachment not yet available), schedule a short follow-up
        // refresh so we don't rely on a future inbound event to retry.
        if (hadRetriableFailure) {
          loggingService
            ..captureEvent(
              'Timeline follow-up scheduled (retriable failure) - room: $roomId',
              domain: 'MATRIX_SERVICE',
              subDomain: 'timeline.debug',
            )
            ..captureEvent(
              'Timeline drain end (pass ${pass + 1}) - room: $roomId, '
              'processed: ${newEvents.length}, advancedTo: null, followUp: true',
              domain: 'MATRIX_SERVICE',
              subDomain: 'timeline.debug',
            );
          unawaited(
            Future<void>.delayed(_readMarkerFollowUpDelay).then((_) {
              listener.enqueueTimelineRefresh();
            }),
          );
        }
        if (!hadRetriableFailure) {
          loggingService.captureEvent(
            'Timeline drain end (pass ${pass + 1}) - room: $roomId, '
            'processed: ${newEvents.length}, advancedTo: null, followUp: false',
            domain: 'MATRIX_SERVICE',
            subDomain: 'timeline.debug',
          );
        }
        break;
      }
    }
  } catch (e, stackTrace) {
    loggingService.captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'processNewTimelineEvents ${listener.client.deviceName}',
      stackTrace: stackTrace,
    );
  }
}

/// Incrementally process a set of newly arrived events for the active room.
///
/// Returns the latest event ID that should advance the read marker, or null if
/// no advancement is warranted.
Future<String?> processTimelineEventsIncremental({
  required TimelineContext listener,
  required List<Event> events,
  required JournalDb journalDb,
  required LoggingService loggingService,
  required SyncReadMarkerService readMarkerService,
  required SyncEventProcessor eventProcessor,
  required Directory documentsDirectory,
  Map<String, int>? failureCounts,
}) async {
  try {
    if (!listener.client.isLogged()) {
      return null;
    }

    final syncRoom = listener.roomManager.currentRoom;
    final roomId =
        listener.roomManager.currentRoomId ?? syncRoom?.id ?? 'unknown';

    if (events.isEmpty || syncRoom == null) {
      return null;
    }

    // Phase 1: prefetch attachments for remote events to avoid ordering hazards.
    for (final event in events) {
      final isRemoteEvent = event.senderId != listener.client.userID;
      if (isRemoteEvent && event.attachmentMimetype.isNotEmpty) {
        await saveAttachment(
          event,
          loggingService: loggingService,
          documentsDirectory: documentsDirectory,
        );
      }
    }

    // Phase 2: process events and compute latest advancing marker.
    String? latestAdvancingEventId;
    num? latestAdvancingTimestamp;
    for (final event in events) {
      final eventId = event.eventId;
      var shouldAdvanceReadMarker = true;
      final isRemoteEvent = event.senderId != listener.client.userID;

      if (isRemoteEvent) {
        try {
          loggingService.captureEvent(
            'Processing event ${event.eventId} from ${event.senderId} '
            '(${event.type}) in room $roomId',
            domain: 'MATRIX_SERVICE',
            subDomain: 'processTimelineEventsIncremental',
          );

          if (event.messageType == syncMessageType) {
            await eventProcessor.process(
              event: event,
              journalDb: journalDb,
            );
          }

          failureCounts?.remove(eventId);
        } on FileSystemException catch (error, stackTrace) {
          final advance = _recordProcessingFailure(
            eventId: eventId,
            loggingService: loggingService,
            failureCounts: failureCounts,
            error: error,
            stackTrace: stackTrace,
            subDomain: 'processTimelineEventsIncremental.missingAttachment',
            skipReason: 'missing attachment',
          );
          shouldAdvanceReadMarker = advance;
        } on Object catch (error, stackTrace) {
          final advance = _recordProcessingFailure(
            eventId: eventId,
            loggingService: loggingService,
            failureCounts: failureCounts,
            error: error,
            stackTrace: stackTrace,
            subDomain: 'processTimelineEventsIncremental.handler',
            skipReason: 'handler error',
          );
          shouldAdvanceReadMarker = advance;
        }
      }

      if (shouldAdvanceReadMarker && eventId.startsWith(r'$')) {
        final eventTimestamp = TimelineEventOrdering.timestamp(event);
        if (TimelineEventOrdering.isNewer(
          candidateTimestamp: eventTimestamp,
          candidateEventId: eventId,
          latestTimestamp: latestAdvancingTimestamp,
          latestEventId: latestAdvancingEventId,
        )) {
          latestAdvancingEventId = eventId;
          latestAdvancingTimestamp = eventTimestamp;
        }
      }
    }

    return latestAdvancingEventId;
  } catch (e, stackTrace) {
    loggingService.captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain:
          'processTimelineEventsIncremental ${listener.client.deviceName}',
      stackTrace: stackTrace,
    );
    return null;
  }
}

bool _recordProcessingFailure({
  required String eventId,
  required LoggingService loggingService,
  required Map<String, int>? failureCounts,
  required Object error,
  required StackTrace stackTrace,
  required String subDomain,
  required String skipReason,
}) {
  loggingService.captureException(
    error,
    domain: 'MATRIX_SERVICE',
    subDomain: subDomain,
    stackTrace: stackTrace,
  );

  if (failureCounts == null || eventId.isEmpty) {
    return false;
  }

  final attempts = (failureCounts[eventId] ?? 0) + 1;
  failureCounts[eventId] = attempts;

  if (attempts < _maxTimelineProcessingRetries) {
    return false;
  }

  loggingService.captureEvent(
    'Skipping event $eventId after $attempts failed attempts ($skipReason)',
    domain: 'MATRIX_SERVICE',
    subDomain: 'processNewTimelineEvents.skip',
  );
  failureCounts.remove(eventId);
  return true;
}

extension StringExtension on String {
  /// Truncate a string if it's longer than [maxLength] and add an [ellipsis].
  String truncate(int maxLength, [String ellipsis = '…']) => length > maxLength
      ? '${substring(0, maxLength - ellipsis.length)}$ellipsis'
      : this;
}
