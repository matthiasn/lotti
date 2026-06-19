import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/state/event_view_mapping.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_detail_view.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/image_utils.dart';

/// Route-level page for a single event's detail view.
///
/// Resolves the [JournalEvent] and its outgoing linked entries, maps them into
/// an [EventDetailData] (cover, timeline, tasks, summary) and renders the
/// [EventDetailView]. Editing and adding to the timeline reuse the existing
/// entry-detail surface; AI summary regeneration is a follow-up.
class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(entryControllerProvider(id: eventId)).value?.entry;

    if (entry is! JournalEvent) {
      return Scaffold(
        backgroundColor: dsPageSurface(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final linked = ref.watch(resolvedOutgoingLinkedEntriesProvider(eventId));
    final cache = getIt<EntitiesCacheService>();
    final category = cache.getCategoryById(entry.meta.categoryId);
    final documentsDirectory = getIt<Directory>().path;

    ImageProvider imageFor(JournalImage image) => FileImage(
      File(getFullImagePath(image, documentsDirectory: documentsDirectory)),
    );

    // Cover: the image matching coverArtId, else the first linked photo.
    final images = linked.whereType<JournalImage>().toList();
    JournalImage? cover;
    for (final image in images) {
      if (image.meta.id == entry.data.coverArtId) {
        cover = image;
        break;
      }
    }
    cover ??= images.isEmpty ? null : images.first;

    final card = eventCardDataFromEvent(
      entry,
      dateLabel: eventDateLabel(entry.meta.dateFrom, DateTime.now()),
      categoryColor: colorFromCssHex(category?.color),
      categoryName: category?.name,
      fallbackTitle: context.messages.entryTypeLabelJournalEvent,
      coverImage: cover == null ? null : imageFor(cover),
    );

    final timeline = <EventTimelineEntry>[];
    final sortedLinked = [...linked]
      ..sort((a, b) => a.meta.dateFrom.compareTo(b.meta.dateFrom));
    for (final linkedEntry in sortedLinked) {
      final timelineEntry = eventTimelineEntryFor(
        linkedEntry,
        timeLabel: DateFormat('HH:mm').format(linkedEntry.meta.dateFrom),
        imageProviderFor: imageFor,
      );
      if (timelineEntry != null) timeline.add(timelineEntry);
    }

    final tasks = <EventTaskRef>[];
    for (final linkedEntry in linked) {
      final due = linkedEntry is Task ? linkedEntry.data.due : null;
      final task = eventTaskRefFor(
        linkedEntry,
        dueLabel: due == null ? null : DateFormat('d MMM').format(due),
      );
      if (task != null) tasks.add(task);
    }

    final note = entry.entryText?.plainText.trim();
    final aiResponses = linked.whereType<AiResponseEntry>().toList();
    final summary = aiResponses.isNotEmpty
        ? aiResponses.last.data.response.trim()
        : (note != null && note.isNotEmpty ? note : null);

    final data = EventDetailData(
      card: card,
      whenLabel: DateFormat('EEE, d MMM yyyy · HH:mm').format(
        entry.meta.dateFrom,
      ),
      summary: summary,
      timeline: timeline,
      tasks: tasks,
    );

    return EventDetailView(
      data: data,
      onBack: () => Navigator.of(context).maybePop(),
      onEdit: () => beamToNamed('/journal/${entry.meta.id}'),
      onAddToTimeline: () => beamToNamed('/journal/${entry.meta.id}'),
      onAddTask: () => beamToNamed('/journal/${entry.meta.id}'),
    );
  }
}
