import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/lotti_logger.dart';
import 'package:lotti/utils/list_extension.dart';
import 'package:matrix/matrix.dart';

Future<void> listenToTimelineEvents({
  required MatrixService service,
}) async {
  final logger = getIt<LottiLogger>();

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

    unawaited(
      Future<void>.delayed(const Duration(seconds: 1))
          .then((value) => service.clientRunner.enqueueRequest(null)),
    );

    final timeline = service.timeline;

    if (timeline == null) {
      logger.event(
        'Timeline is null',
        domain: 'MATRIX_SERVICE',
        subDomain: 'listenToTimelineEvents',
      );
      return;
    }
  } catch (e, stackTrace) {
    debugPrint('$e');
    logger.exception(
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
  LottiLogger? overriddenLoggingService,
  SettingsDb? overriddenSettingsDb,
}) async {
  final logger = overriddenLoggingService ?? getIt<LottiLogger>();

  try {
    final lastReadEventContextId = service.lastReadEventContextId;

    await service.client.sync();
    final hasMessage = await service.syncRoom
            ?.getEventById(lastReadEventContextId.toString()) !=
        null;

    final timeline = await service.syncRoom?.getTimeline(
      eventContextId: hasMessage ? lastReadEventContextId : null,
    );

    if (timeline == null) {
      logger.event(
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

      // Terminates early when the message was emitted by the device itself,
      // as it would be a waste of battery to try to ingest what the device
      // already knows.
      if (event.senderId != service.client.userID) {
        if (event.messageType == syncMessageType) {
          await processMatrixMessage(
            event: event,
            service: service,
            overriddenJournalDb: overriddenJournalDb,
          );
        }

        await saveAttachment(event);
      }

      try {
        if (eventId.startsWith(r'$')) {
          service.lastReadEventContextId = eventId;
          await setLastReadMatrixEventId(eventId, overriddenSettingsDb);
          final loginState = service.client.onLoginStateChanged.value;
          if (loginState == LoginState.loggedIn) {
            await timeline.setReadMarker(eventId: eventId);
          }
        }
      } catch (e, stackTrace) {
        logger.exception(
          e,
          domain: 'MATRIX_SERVICE',
          subDomain: 'setReadMarker ${service.client.deviceName}',
          stackTrace: stackTrace,
        );
      }
    }
  } catch (e, stackTrace) {
    logger.exception(
      e,
      domain: 'MATRIX_SERVICE',
      subDomain: 'listenToTimelineEvents ${service.client.deviceName}',
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
