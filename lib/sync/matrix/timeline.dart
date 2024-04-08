import 'package:flutter/foundation.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/consts.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/matrix/process_message.dart';
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
        service.clientRunner.enqueueRequest(null);
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
}) async {
  final loggingDb = getIt<LoggingDb>();

  try {
    final lastReadEventContextId = service.lastReadEventContextId;
    if (lastReadEventContextId != null) {
      debugPrint('>> lastReadEventContextId $lastReadEventContextId');
      final timelineChunk =
          await service.syncRoom?.getEventContext(lastReadEventContextId);
      final events = timelineChunk?.events;
      debugPrint('>> getEventContext ${events?.length} $events');
      debugPrint(
        '>> getEventContext prevBatch ${timelineChunk?.prevBatch} nextBatch ${timelineChunk?.nextBatch}',
      );
    }

    final timeline = await service.syncRoom?.getTimeline(
      eventContextId: service.lastReadEventContextId,
    );

    final events = timeline?.events;

    if (timeline == null || events == null) {
      loggingDb.captureEvent(
        'Timeline is null',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processNewTimelineEvents',
      );
      return;
    }

    for (final event in List<Event>.from(events).reversed) {
      final eventId = event.eventId;
      final body = event.plaintextBody;
      debugPrint(
        '${event.eventId} ${event.messageType} ${body.truncate(50)}',
      );

      if (event.messageType == syncMessageType) {
        await processMatrixMessage(event.text);
      }

      try {
        await timeline.setReadMarker(eventId: eventId);
        await service.syncRoom?.setReadMarker(eventId);
        await service.client.sync(fullState: true);
        service.lastReadEventContextId = eventId;
      } catch (e) {
        debugPrint('$e');
      }
    }

    await service.client.sync();

    debugPrint('>>> processNewTimelineEvents count ${events.length}');
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

extension StringExtension on String {
  /// Truncate a string if it's longer than [maxLength] and add an [ellipsis].
  String truncate(int maxLength, [String ellipsis = '…']) => length > maxLength
      ? '${substring(0, maxLength - ellipsis.length)}$ellipsis'
      : this;
}
