import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/save_attachment.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/timeline_config.dart';
import 'package:lotti/features/sync/matrix/timeline_context.dart';
import 'package:lotti/features/sync/matrix/timeline_metrics.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

const _maxTimelineProcessingRetries = 5;

class _IndexedEvent {
  const _IndexedEvent({
    required this.index,
    required this.event,
  });

  final int index;
  final Event event;
}

class _IngestOutcome {
  const _IngestOutcome({
    required this.latestAdvancingEventId,
    required this.hadRetriableFailure,
  });

  final String? latestAdvancingEventId;
  final bool hadRetriableFailure;
}

List<_IndexedEvent> _buildSortedIndexedEvents(Timeline tl) {
  final events = tl.events;
  return <_IndexedEvent>[
    for (var i = 0; i < events.length; i++)
      _IndexedEvent(index: i, event: events[i]),
  ]..sort((a, b) {
      final t = TimelineEventOrdering.timestamp(a.event)
          .compareTo(TimelineEventOrdering.timestamp(b.event));
      if (t != 0) return t;
      // For ties, prefer higher original indices to preserve SDK ordering.
      return b.index.compareTo(a.index);
    });
}

int _findLastReadPosition(
  List<_IndexedEvent> sortedEvents,
  String? lastReadEventContextId,
) {
  if (lastReadEventContextId == null) return -1;
  for (var i = sortedEvents.length - 1; i >= 0; i--) {
    if (sortedEvents[i].event.eventId == lastReadEventContextId) {
      return i;
    }
  }
  return -1;
}

List<Event> _collectNewEvents(
  List<_IndexedEvent> sortedEvents,
  int lastReadPosition,
  String? lastReadEventContextId,
) {
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
  return candidateEvents;
}

class TimelineDrainer {
  TimelineDrainer({
    required this.listener,
    required this.journalDb,
    required this.loggingService,
    required this.readMarkerService,
    required this.eventProcessor,
    required this.documentsDirectory,
    required this.failureCounts,
    required this.config,
    required this.metrics,
  });

  final TimelineContext listener;
  final JournalDb journalDb;
  final LoggingService loggingService;
  final SyncReadMarkerService readMarkerService;
  final SyncEventProcessor eventProcessor;
  final Directory documentsDirectory;
  final Map<String, int>? failureCounts;
  final TimelineConfig config;
  final TimelineMetrics? metrics;

  Future<List<Event>> computeFromTimeline({
    required Timeline tl,
    required String source,
    required int pass,
    required String roomId,
    required int usedLimit,
    required String? lastReadEventContextId,
  }) async {
    final sortedEvents = _buildSortedIndexedEvents(tl);
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

    final lastReadPosition =
        _findLastReadPosition(sortedEvents, lastReadEventContextId);
    var newEvents = _collectNewEvents(
      sortedEvents,
      lastReadPosition,
      lastReadEventContextId,
    );

    // If empty and we're at the tail, do tiny intra-pass waits to allow the
    // SDK to apply the newest event into the live list.
    final atTail = lastReadEventContextId != null &&
        lastReadPosition >= 0 &&
        lastReadPosition == sortedEvents.length - 1;
    if (newEvents.isEmpty && atTail) {
      for (final delay in config.retryDelays) {
        if (config.collectMetrics) metrics?.retryAttempts++;
        loggingService.captureEvent(
          'Empty snapshot at tail; retrying after ${delay.inMilliseconds}ms '
          '(pass ${pass + 1}, source: $source${usedLimit > 0 ? ', limit: $usedLimit' : ''})',
          domain: 'MATRIX_SERVICE',
          subDomain: 'timeline.debug',
        );
        await Future<void>.delayed(delay);
        // Re-evaluate from the same live timeline instance.
        final evsIndexed = _buildSortedIndexedEvents(tl);
        final recalculated = <Event>[];
        for (var i = 0; i < evsIndexed.length; i++) {
          final event = evsIndexed[i].event;
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
          newEvents = recalculated;
          break;
        }
      }
    }

    return newEvents;
  }

  Future<void> drain() async {
    for (var pass = 0; pass < config.maxDrainPasses; pass++) {
      if (config.collectMetrics) metrics?.drainPasses++;
      await listener.client.sync();

      final syncRoom = listener.roomManager.currentRoom;
      final roomId = listener.roomManager.currentRoomId ??
          listener.roomManager.currentRoom?.id ??
          'unknown';

      var timeline = listener.timeline;
      var newEvents = const <Event>[];
      var usedLimit = 0;

      final lastReadEventContextId = listener.lastReadEventContextId;

      if (timeline != null) {
        newEvents = await computeFromTimeline(
          tl: timeline,
          source: 'live',
          pass: pass,
          roomId: roomId,
          usedLimit: usedLimit,
          lastReadEventContextId: lastReadEventContextId,
        );
      }

      if (newEvents.isEmpty) {
        for (final limit in config.timelineLimits) {
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
          newEvents = await computeFromTimeline(
            tl: timeline,
            source: 'snapshot',
            pass: pass,
            roomId: roomId,
            usedLimit: usedLimit,
            lastReadEventContextId: lastReadEventContextId,
          );
          if (newEvents.isNotEmpty) {
            break;
          }
        }
      }

      if (newEvents.isEmpty) {
        if (pass < config.maxDrainPasses - 1) {
          loggingService.captureEvent(
            'No new events in pass ${pass + 1}; continuing drain (limits tried: $usedLimit).',
            domain: 'MATRIX_SERVICE',
            subDomain: 'timeline.debug',
          );
          continue;
        }
        loggingService.captureEvent(
          'Timeline follow-up scheduled (empty snapshot) - room: $roomId',
          domain: 'MATRIX_SERVICE',
          subDomain: 'timeline.debug',
        );
        unawaited(
          Future<void>.delayed(config.readMarkerFollowUpDelay).then((_) {
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

      final outcome = await _ingestAndComputeLatest(
        events: newEvents,
        listener: listener,
        journalDb: journalDb,
        loggingService: loggingService,
        eventProcessor: eventProcessor,
        documentsDirectory: documentsDirectory,
        failureCounts: failureCounts,
        subDomainPrefix: 'processNewTimelineEvents',
        roomId: syncRoom?.id ?? roomId,
      );
      if (config.collectMetrics) metrics?.eventsProcessed += newEvents.length;

      final latestAdvancingEventId = outcome.latestAdvancingEventId;
      final hadRetriableFailure = outcome.hadRetriableFailure;
      if (latestAdvancingEventId != null) {
        loggingService.captureEvent(
          'Advancing read marker to $latestAdvancingEventId',
          domain: 'MATRIX_SERVICE',
          subDomain: 'processNewTimelineEvents',
        );
        listener.lastReadEventContextId = latestAdvancingEventId;
        await readMarkerService.updateReadMarker(
          client: listener.client,
          room: syncRoom!,
          eventId: latestAdvancingEventId,
          timeline: timeline,
        );
        loggingService.captureEvent(
          'Timeline drain end (pass ${pass + 1}) - room: $roomId, '
          'processed: ${newEvents.length}, advancedTo: $latestAdvancingEventId, '
          'followUp: true',
          domain: 'MATRIX_SERVICE',
          subDomain: 'timeline.debug',
        );
        unawaited(
          Future<void>.delayed(config.readMarkerFollowUpDelay).then((_) {
            listener.enqueueTimelineRefresh();
          }),
        );
      } else {
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
            Future<void>.delayed(config.readMarkerFollowUpDelay).then((_) {
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
  }
}

Future<_IngestOutcome> _ingestAndComputeLatest({
  required List<Event> events,
  required TimelineContext listener,
  required JournalDb journalDb,
  required LoggingService loggingService,
  required SyncEventProcessor eventProcessor,
  required Directory documentsDirectory,
  required String subDomainPrefix,
  required String roomId,
  Map<String, int>? failureCounts,
}) async {
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
  var hadRetriableFailure = false;

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
          subDomain: subDomainPrefix,
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
          subDomain: '$subDomainPrefix.missingAttachment',
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
          subDomain: '$subDomainPrefix.handler',
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

  return _IngestOutcome(
    latestAdvancingEventId: latestAdvancingEventId,
    hadRetriableFailure: hadRetriableFailure,
  );
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
  TimelineConfig config = TimelineConfig.production,
  TimelineMetrics? metrics,
}) async {
  final sw = Stopwatch()..start();
  try {
    if (!listener.client.isLogged()) {
      loggingService.captureEvent(
        'Skipping timeline processing: client not logged in.',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processNewTimelineEvents.unauthenticated',
      );
      return;
    }
    final drainer = TimelineDrainer(
      listener: listener,
      journalDb: journalDb,
      loggingService: loggingService,
      readMarkerService: readMarkerService,
      eventProcessor: eventProcessor,
      documentsDirectory: documentsDirectory,
      failureCounts: failureCounts,
      config: config,
      metrics: metrics,
    );
    await drainer.drain();
  } catch (e, stackTrace) {
    loggingService.captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'processNewTimelineEvents ${listener.client.deviceName}',
      stackTrace: stackTrace,
    );
  } finally {
    if (config.collectMetrics) metrics?.addProcessingTime(sw.elapsed);
    // Optional metrics threshold logging to flag anomalous drains without
    // impacting success paths.
    if (config.collectMetrics && (metrics?.drainPasses ?? 0) > 2) {
      loggingService.captureEvent(
        'Excessive drain passes: ${metrics?.drainPasses}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'timeline.metrics',
      );
    }
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
  TimelineConfig config = TimelineConfig.production,
  TimelineMetrics? metrics,
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

    final outcome = await _ingestAndComputeLatest(
      events: events,
      listener: listener,
      journalDb: journalDb,
      loggingService: loggingService,
      eventProcessor: eventProcessor,
      documentsDirectory: documentsDirectory,
      failureCounts: failureCounts,
      subDomainPrefix: 'processTimelineEventsIncremental',
      roomId: roomId,
    );

    return outcome.latestAdvancingEventId;
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
