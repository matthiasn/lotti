import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/save_attachment.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/timeline_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/list_extension.dart';
import 'package:matrix/matrix.dart';

Future<void> listenToTimelineEvents({
  required TimelineContext listener,
}) async {
  final loggingDb = listener.loggingService;
  final syncRoom = listener.roomManager.currentRoom;

  try {
    // Defensive check: Ensure syncRoom is loaded before attempting to listen
    if (syncRoom == null) {
      loggingDb.captureEvent(
        '⚠️ Cannot listen to timeline: syncRoom is null. '
        'syncRoomId: ${listener.roomManager.currentRoomId}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'listenToTimelineEvents',
      );
      return;
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

    listener.timeline = await syncRoom.getTimeline(
      onNewEvent: () {
        listener.enqueueTimelineRefresh();
      },
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
}) async {
  try {
    final lastReadEventContextId = listener.lastReadEventContextId;
    await listener.client.sync();
    final syncRoom = listener.roomManager.currentRoom;
    var hasMessage = false;
    if (lastReadEventContextId != null && syncRoom != null) {
      hasMessage = await syncRoom.getEventById(lastReadEventContextId) != null;
    }

    final timeline = await syncRoom?.getTimeline(
      eventContextId: hasMessage ? lastReadEventContextId : null,
    );

    if (timeline == null) {
      loggingService.captureEvent(
        'Timeline is null',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processNewTimelineEvents',
      );
      return;
    }

    final events = List<Event>.from(timeline.events.reversed);
    final (_, _, eventsAfter) = events.partition(
      (event) => event.eventId == lastReadEventContextId,
    );
    final newEvents = eventsAfter ?? events;

    if (newEvents.isEmpty) {
      return;
    }

    loggingService.captureEvent(
      'Processing ${newEvents.length} timeline events '
      'for room ${syncRoom?.id}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'processNewTimelineEvents',
    );

    for (final event in newEvents) {
      final eventId = event.eventId;

      // Terminates early when the message was emitted by the device itself,
      // as it would be a waste of battery to try to ingest what the device
      // already knows.
      if (event.senderId != listener.client.userID) {
        loggingService.captureEvent(
          'Processing event ${event.eventId} from ${event.senderId} '
          '(${event.type}) in room ${syncRoom?.id}',
          domain: 'MATRIX_SERVICE',
          subDomain: 'processNewTimelineEvents',
        );
        await saveAttachment(
          event,
          loggingService: loggingService,
          documentsDirectory: documentsDirectory,
        );

        if (event.messageType == syncMessageType) {
          await eventProcessor.process(
            event: event,
            journalDb: journalDb,
          );
        }
      }

      if (eventId.startsWith(r'$')) {
        listener.lastReadEventContextId = eventId;
        await readMarkerService.updateReadMarker(
          client: listener.client,
          timeline: timeline,
          eventId: eventId,
        );
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

extension StringExtension on String {
  /// Truncate a string if it's longer than [maxLength] and add an [ellipsis].
  String truncate(int maxLength, [String ellipsis = '…']) => length > maxLength
      ? '${substring(0, maxLength - ellipsis.length)}$ellipsis'
      : this;
}
