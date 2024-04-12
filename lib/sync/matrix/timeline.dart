import 'package:flutter/foundation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/consts.dart';
import 'package:lotti/sync/matrix/last_read.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/matrix/process_message.dart';
import 'package:lotti/sync/matrix/save_attachment.dart';
import 'package:lotti/utils/list_extension.dart';
import 'package:matrix/matrix.dart';

Future<void> listenToTimelineEvents({
  required MatrixService service,
}) async {
  final loggingDb = getIt<LoggingDb>();

  try {
    final previousTimeline = service.timeline;

    if (previousTimeline != null) {
      previousTimeline.cancelSubscriptions();
    }

    service.timeline = await service.syncRoom?.getTimeline(
      onNewEvent: () {
        final clientRunner = service.clientRunner;
        if (clientRunner.queueSize < 2) {
          service.clientRunner.enqueueRequest(null);
        }
      },
    );

    final timeline = service.timeline;

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
  required MatrixService service,
  JournalDb? overriddenJournalDb,
}) async {
  final loggingDb = getIt<LoggingDb>();

  try {
    final lastReadEventContextId = service.lastReadEventContextId;
    final timeline = await service.syncRoom?.getTimeline(
      eventContextId: lastReadEventContextId,
    );

    if (timeline == null) {
      loggingDb.captureEvent(
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

    for (final event in newEvents) {
      await service.client.sync();
      final eventId = event.eventId;

      if (event.messageType == syncMessageType) {
        await processMatrixMessage(
          event,
          overriddenJournalDb: overriddenJournalDb,
        );
      }

      await saveAttachment(event);

      try {
        if (eventId.startsWith(r'$')) {
          service.lastReadEventContextId = eventId;
        }

        await timeline.setReadMarker(eventId: eventId);
        await setLastReadMatrixEventId(eventId);
      } catch (e) {
        debugPrint('$e');
      }
    }
  } catch (e, stackTrace) {
    debugPrint('$e');
    loggingDb.captureException(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'listenToTimelineEvents ${service.client.deviceName}',
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

extension StringExtension on String {
  /// Truncate a string if it's longer than [maxLength] and add an [ellipsis].
  String truncate(int maxLength, [String ellipsis = '…']) => length > maxLength
      ? '${substring(0, maxLength - ellipsis.length)}$ellipsis'
      : this;
}
