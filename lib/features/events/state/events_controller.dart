import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/image_utils.dart';

/// A [JournalEvent] resolved with the bits the overview cards need that don't
/// live on the event itself: its category colour/name and a cover [ImageProvider]
/// (when the event has cover art). Date labels and section grouping are applied
/// in the page, where the locale/localized strings are available.
@immutable
class ResolvedEvent {
  const ResolvedEvent({
    required this.event,
    required this.categoryColor,
    this.categoryName,
    this.coverImage,
  });

  final JournalEvent event;
  final Color categoryColor;
  final String? categoryName;
  final ImageProvider? coverImage;
}

/// All events, resolved for display, re-fetched whenever an event changes.
final eventsStreamProvider = StreamProvider<List<ResolvedEvent>>((ref) {
  return notificationDrivenStream<ResolvedEvent>(
    notifications: getIt<UpdateNotifications>(),
    notificationKeys: const {eventNotification},
    fetcher: loadResolvedEvents,
  );
});

/// Loads every (non-deleted) event from the database and resolves each one's
/// category styling and cover image. Pure-ish glue: all side effects go through
/// `getIt`, so it is straightforward to test with mocked services.
Future<List<ResolvedEvent>> loadResolvedEvents() async {
  final db = getIt<JournalDb>();
  final cache = getIt<EntitiesCacheService>();
  final showPrivate = cache.showPrivateEntries;

  final entities = await db.getJournalEntities(
    types: const ['JournalEvent'],
    ids: null,
    starredStatuses: const [true, false],
    privateStatuses: showPrivate ? const [true, false] : const [false],
    flaggedStatuses: const [1, 0],
    limit: 1000,
  );
  final events = entities.whereType<JournalEvent>().toList();

  final coverIds = events
      .map((e) => e.data.coverArtId)
      .whereType<String>()
      .toSet();
  final coverImagesById = <String, JournalImage>{};
  if (coverIds.isNotEmpty) {
    final images = await db.getJournalEntitiesForIds(coverIds);
    for (final image in images.whereType<JournalImage>()) {
      coverImagesById[image.meta.id] = image;
    }
  }

  final documentsDirectory = getIt<Directory>().path;

  return events.map((event) {
    final category = cache.getCategoryById(event.meta.categoryId);
    final coverArtId = event.data.coverArtId;
    final coverImage = coverArtId != null ? coverImagesById[coverArtId] : null;
    return ResolvedEvent(
      event: event,
      categoryColor: colorFromCssHex(category?.color),
      categoryName: category?.name,
      coverImage: coverImage == null
          ? null
          : FileImage(
              File(
                getFullImagePath(
                  coverImage,
                  documentsDirectory: documentsDirectory,
                ),
              ),
            ),
    );
  }).toList();
}
