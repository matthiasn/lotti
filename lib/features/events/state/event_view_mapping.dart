import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';

String? _trimmedNote(JournalEntity entity) {
  final text = entity.entryText?.plainText.trim();
  return (text == null || text.isEmpty) ? null : text;
}

String _formatDuration(Duration duration) {
  // A reversed audio range (dateTo before dateFrom) would otherwise format as a
  // misleading negative `m:ss`; clamp to zero.
  final safe = duration.isNegative ? Duration.zero : duration;
  final minutes = safe.inMinutes;
  final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Maps a resolved linked entry to a timeline entry, or `null` when the entry
/// isn't a timeline kind (tasks and AI responses are surfaced elsewhere). The
/// [imageProviderFor] callback resolves an image entry to a displayable
/// [ImageProvider] (it needs the documents directory, which lives outside pure
/// code), and [timeLabel] is the already-formatted timestamp.
EventTimelineEntry? eventTimelineEntryFor(
  JournalEntity entity, {
  required String timeLabel,
  required ImageProvider Function(JournalImage image) imageProviderFor,
}) {
  return switch (entity) {
    final JournalImage image => EventTimelineEntry(
      timeLabel: timeLabel,
      kind: EventTimelineKind.photo,
      entryId: image.meta.id,
      text: _trimmedNote(image),
      photos: [EventPhoto(imageProviderFor(image))],
    ),
    final JournalAudio audio => EventTimelineEntry(
      timeLabel: timeLabel,
      kind: EventTimelineKind.audio,
      entryId: audio.meta.id,
      durationLabel: _formatDuration(
        audio.data.dateTo.difference(audio.data.dateFrom),
      ),
      text: _trimmedNote(audio),
    ),
    final JournalEntry entry => _journalEntryBeat(entry, timeLabel),
    _ => null,
  };
}

/// A plain note becomes a [EventTimelineKind.note]; one whose `dateTo` is after
/// its `dateFrom` (a time recording) becomes a [EventTimelineKind.timeRecording]
/// carrying its end time and elapsed duration, so it reads as a span rather than
/// a point-in-time observation.
EventTimelineEntry _journalEntryBeat(JournalEntry entry, String timeLabel) {
  final span = entry.meta.dateTo.difference(entry.meta.dateFrom);
  if (isTimeRecordingSpan(span)) {
    return EventTimelineEntry(
      timeLabel: timeLabel,
      kind: EventTimelineKind.timeRecording,
      entryId: entry.meta.id,
      endTimeLabel: DateFormat('HH:mm').format(entry.meta.dateTo.toLocal()),
      durationLabel: formatRangeDuration(span),
      text: _trimmedNote(entry),
    );
  }
  return EventTimelineEntry(
    timeLabel: timeLabel,
    kind: EventTimelineKind.note,
    entryId: entry.meta.id,
    text: _trimmedNote(entry),
  );
}

/// Maps a linked [Task] to the compact [EventTaskRef] shown in the event's
/// "Tasks" section, or `null` for non-task entries. [dueLabel] is the
/// already-formatted due date, when present.
EventTaskRef? eventTaskRefFor(JournalEntity entity, {String? dueLabel}) {
  if (entity is! Task) return null;
  return EventTaskRef(
    id: entity.meta.id,
    title: entity.data.title,
    done: entity.data.status is TaskDone,
    dueLabel: dueLabel,
  );
}

/// Builds the full [EventDetailData] for the detail page from a resolved event
/// and its outgoing linked entries. Pure: the documents-directory-dependent
/// image resolution is injected via [imageProviderFor].
///
/// - **Cover**: the linked image whose id matches the event's `coverArtId`,
///   else the first linked photo, else none.
/// - **Timeline**: linked photos/notes/audio, oldest first.
/// - **Tasks**: linked tasks.
/// - **Summary**: the latest linked AI response, falling back to the event's
///   own note.
EventDetailData eventDetailDataFromEntities({
  required JournalEvent event,
  required List<JournalEntity> linked,
  required DateTime now,
  required Color categoryColor,
  required String fallbackTitle,
  required ImageProvider Function(JournalImage image) imageProviderFor,
  String? categoryName,
}) {
  final images = linked.whereType<JournalImage>().toList();
  JournalImage? cover;
  for (final image in images) {
    if (image.meta.id == event.data.coverArtId) {
      cover = image;
      break;
    }
  }
  // Match the overview card (events_controller.loadResolvedEvents): the newest
  // linked photo, picked explicitly rather than relying on the caller's link
  // ordering, so the card and the detail never disagree about an event's cover.
  cover ??= images.isEmpty
      ? null
      : images.reduce(
          (a, b) => a.meta.dateFrom.isAfter(b.meta.dateFrom) ? a : b,
        );

  final card = eventCardDataFromEvent(
    event,
    dateLabel: eventDateLabel(event.meta.dateFrom, now),
    categoryColor: categoryColor,
    categoryName: categoryName,
    fallbackTitle: fallbackTitle,
    coverImage: cover == null ? null : imageProviderFor(cover),
  );

  // Sort the linked entries once; the timeline, photo gallery and AI summary
  // all read from this single ordering (oldest first).
  final sorted = [...linked]
    ..sort((a, b) => a.meta.dateFrom.compareTo(b.meta.dateFrom));

  final timeline = <EventTimelineEntry>[];
  for (final entity in sorted) {
    final timelineEntry = eventTimelineEntryFor(
      entity,
      timeLabel: DateFormat('HH:mm').format(entity.meta.dateFrom.toLocal()),
      imageProviderFor: imageProviderFor,
    );
    if (timelineEntry != null) timeline.add(timelineEntry);
  }

  final tasks = <EventTaskRef>[];
  for (final entity in linked) {
    final due = entity is Task ? entity.data.due : null;
    final task = eventTaskRefFor(
      entity,
      dueLabel: due == null ? null : DateFormat('d MMM').format(due),
    );
    if (task != null) tasks.add(task);
  }

  // All linked photos, oldest first, for the gallery grid.
  final photos = [
    for (final image in sorted.whereType<JournalImage>())
      EventPhoto(imageProviderFor(image)),
  ];

  final note = event.entryText?.plainText.trim();
  // `sorted` is oldest-first, so the last AI response is the newest regardless
  // of the order the linked entries arrived in.
  final aiResponses = sorted.whereType<AiResponseEntry>();
  final summary = aiResponses.isNotEmpty
      ? aiResponses.last.data.response.trim()
      : (note != null && note.isNotEmpty ? note : null);

  return EventDetailData(
    card: card,
    whenLabel: DateFormat(
      'EEE, d MMM yyyy · HH:mm',
    ).format(event.meta.dateFrom),
    summary: summary,
    timeline: timeline,
    tasks: tasks,
    photos: photos,
  );
}

/// A glanceable, locale-formatted date for an event card: `12 May` when the
/// event falls in the current year, otherwise `MMM yyyy` (e.g. `Aug 2025`).
/// Absolute (not relative) so it needs no plural localization while staying
/// correct in every locale via [DateFormat].
String eventDateLabel(DateTime date, DateTime now, {String? locale}) {
  if (date.year == now.year) {
    return DateFormat('d MMM', locale).format(date);
  }
  return DateFormat('MMM yyyy', locale).format(date);
}

/// Maps a resolved [JournalEvent] to the presentational [EventCardData] the
/// overview/detail surfaces render. Derived/linked data (cover image, category
/// styling, date label) is injected so this stays pure and testable; the note
/// text doubles as a one-line summary when present.
EventCardData eventCardDataFromEvent(
  JournalEvent event, {
  required String dateLabel,
  required Color categoryColor,
  required String fallbackTitle,
  String? categoryName,
  ImageProvider? coverImage,
  int photoCount = 0,
  int taskCount = 0,
}) {
  final title = event.data.title.trim();
  final note = event.entryText?.plainText.trim();
  return EventCardData(
    id: event.meta.id,
    title: title.isEmpty ? fallbackTitle : title,
    dateLabel: dateLabel,
    sortDate: event.meta.dateFrom,
    status: event.data.status,
    stars: event.data.stars,
    categoryName: categoryName,
    categoryColor: categoryColor,
    coverImage: coverImage,
    coverCropX: event.data.coverArtCropX,
    summary: (note != null && note.isNotEmpty) ? note : null,
    photoCount: photoCount,
    taskCount: taskCount,
  );
}

/// Pure logic that turns a flat list of resolved [EventCardData] into the
/// overview's time-ordered sections: a featured **Upcoming** section (events
/// still ahead of [now]) followed by past events grouped by calendar year,
/// newest year first and newest event first within a year.
///
/// Label text is injected so this stays locale-agnostic and trivially testable:
/// [upcomingTitle] for the featured section and [yearTitle] for each year
/// bucket (the provider can render the current year as "Earlier in {year}").
///
/// An event counts as upcoming when its [EventCardData.sortDate] is after [now],
/// or — when it has no date — when its status is upcoming
/// ([EventCardData.isUpcoming]). Undated, non-upcoming events fall into a final
/// "undated" bucket whose title is built with [yearTitle]`(null-year)` via
/// [undatedTitle].
List<EventSection> groupEventsIntoSections(
  List<EventCardData> cards, {
  required DateTime now,
  required String upcomingTitle,
  required String Function(int year) yearTitle,
  String? undatedTitle,
}) {
  final upcoming = <EventCardData>[];
  final byYear = <int, List<EventCardData>>{};
  final undated = <EventCardData>[];

  for (final card in cards) {
    final date = card.sortDate;
    if (date != null && date.isAfter(now)) {
      upcoming.add(card);
    } else if (date != null) {
      byYear.putIfAbsent(date.year, () => <EventCardData>[]).add(card);
    } else if (card.isUpcoming) {
      upcoming.add(card);
    } else {
      undated.add(card);
    }
  }

  // Soonest-first for upcoming; an undated upcoming sorts last.
  upcoming.sort((a, b) {
    final ad = a.sortDate;
    final bd = b.sortDate;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  });

  final sections = <EventSection>[];
  if (upcoming.isNotEmpty) {
    sections.add(
      EventSection(title: upcomingTitle, featured: true, events: upcoming),
    );
  }

  final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
  for (final year in years) {
    final events = byYear[year]!
      ..sort((a, b) => b.sortDate!.compareTo(a.sortDate!));
    sections.add(EventSection(title: yearTitle(year), events: events));
  }

  if (undated.isNotEmpty && undatedTitle != null) {
    sections.add(EventSection(title: undatedTitle, events: undated));
  }

  return sections;
}
