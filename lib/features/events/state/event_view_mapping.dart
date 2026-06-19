import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';

String? _trimmedNote(JournalEntity entity) {
  final text = entity.entryText?.plainText.trim();
  return (text == null || text.isEmpty) ? null : text;
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
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
      text: _trimmedNote(image),
      photos: [EventPhoto(imageProviderFor(image))],
    ),
    final JournalAudio audio => EventTimelineEntry(
      timeLabel: timeLabel,
      kind: EventTimelineKind.audio,
      durationLabel: _formatDuration(
        audio.data.dateTo.difference(audio.data.dateFrom),
      ),
      text: _trimmedNote(audio),
    ),
    final JournalEntry entry => EventTimelineEntry(
      timeLabel: timeLabel,
      kind: EventTimelineKind.note,
      text: _trimmedNote(entry),
    ),
    _ => null,
  };
}

/// Maps a linked [Task] to the compact [EventTaskRef] shown in the event's
/// "Tasks" section, or `null` for non-task entries. [dueLabel] is the
/// already-formatted due date, when present.
EventTaskRef? eventTaskRefFor(JournalEntity entity, {String? dueLabel}) {
  if (entity is! Task) return null;
  return EventTaskRef(
    title: entity.data.title,
    done: entity.data.status is TaskDone,
    dueLabel: dueLabel,
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
