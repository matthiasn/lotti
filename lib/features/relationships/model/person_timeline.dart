/// A person's timeline as pure data: what is on it, in which section, and
/// what sits under *About* instead (ADR 0138).
///
/// Built from what the repository reads — check-ins, the entries each one
/// holds, linked tasks and the notes, voice notes, photos and meetings on
/// the person's timeline — with no I/O, so every rule here is table-tested.
library;

import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/relationships/model/relationship_calendar.dart';

/// One row on a person's timeline.
sealed class PersonTimelineItem {
  const PersonTimelineItem();

  /// The id the row is keyed by, and that opens it.
  String get id;

  /// When the row sits on the timeline.
  DateTime get at;
}

/// A logged interaction, with what it holds.
final class TimelineCheckIn extends PersonTimelineItem {
  const TimelineCheckIn(this.checkIn, {this.entries = const []});

  final CheckInEntry checkIn;

  /// The recordings, comments and photos the check-in holds.
  final List<JournalEntity> entries;

  @override
  String get id => checkIn.meta.id;

  @override
  DateTime get at => checkIn.meta.dateFrom;
}

/// A typed note about the person.
final class TimelineNote extends PersonTimelineItem {
  const TimelineNote(this.note);

  final JournalEntry note;

  /// Whether the note is pinned under *About* (it is starred).
  bool get pinned => note.meta.starred ?? false;

  @override
  String get id => note.meta.id;

  @override
  DateTime get at => note.meta.dateFrom;
}

/// A recording about the person that is not part of a check-in.
final class TimelineVoiceNote extends PersonTimelineItem {
  const TimelineVoiceNote(this.audio);

  final JournalAudio audio;

  @override
  String get id => audio.meta.id;

  @override
  DateTime get at => audio.meta.dateFrom;
}

/// The photos added on one day, as one row.
final class TimelinePhotos extends PersonTimelineItem {
  const TimelinePhotos(this.photos);

  /// Newest first; never empty.
  final List<JournalImage> photos;

  @override
  String get id => photos.first.meta.id;

  @override
  DateTime get at => photos.first.meta.dateFrom;
}

/// A task for the person.
final class TimelineTask extends PersonTimelineItem {
  const TimelineTask(this.task);

  final Task task;

  /// Done and rejected tasks are closed; everything else is still open.
  bool get open => switch (task.data.status) {
    TaskDone() || TaskRejected() => false,
    _ => true,
  };

  /// The due date, when the task has one.
  DateTime? get due => task.data.due;

  @override
  String get id => task.meta.id;

  /// An open task with a due date sits at its due date (it is ahead of the
  /// user), an open one without at when it was written, and a closed one at
  /// when it was closed — the moment its row reports.
  @override
  DateTime get at =>
      open ? due ?? task.meta.dateFrom : task.data.status.createdAt;
}

/// A meeting with the person.
final class TimelineMeeting extends PersonTimelineItem {
  const TimelineMeeting(this.event);

  final JournalEvent event;

  /// A meeting called off is shown as such, and never as upcoming.
  bool get calledOff => switch (event.data.status) {
    EventStatus.cancelled ||
    EventStatus.missed ||
    EventStatus.postponed => true,
    _ => false,
  };

  @override
  String get id => event.meta.id;

  @override
  DateTime get at => event.meta.dateFrom;
}

/// Which slice of the timeline the user is looking at.
enum PersonTimelineFilter {
  all,
  checkIns,

  /// Typed notes and voice notes.
  notes,
  tasks,
  photos,
  meetings;

  bool admits(PersonTimelineItem item) => switch (this) {
    all => true,
    checkIns => item is TimelineCheckIn,
    notes => item is TimelineNote || item is TimelineVoiceNote,
    tasks => item is TimelineTask,
    photos => item is TimelinePhotos,
    meetings => item is TimelineMeeting,
  };
}

/// What a timeline section is, for its heading.
enum PersonTimelineSectionKind {
  /// Meetings ahead and open tasks with a due date, soonest first.
  upcoming,
  today,

  /// The six days before today.
  thisWeek,

  /// One calendar month, before this week.
  month,
}

/// A run of rows under one heading.
final class PersonTimelineSection {
  const PersonTimelineSection({
    required this.kind,
    required this.items,
    this.month,
  });

  final PersonTimelineSectionKind kind;

  /// The first day of the month, as a day key, for a [month] section.
  final DateTime? month;

  final List<PersonTimelineItem> items;
}

/// Everything the person page renders below the briefing.
final class PersonTimeline {
  const PersonTimeline({
    required this.pinned,
    required this.sections,
    required this.itemCount,
  });

  static const empty = PersonTimeline(pinned: [], sections: [], itemCount: 0);

  /// The notes pinned under *About*, newest first. They are not repeated on
  /// the timeline: one fact in one place.
  final List<TimelineNote> pinned;

  /// The sections, upcoming first, then newest to oldest.
  final List<PersonTimelineSection> sections;

  /// How many rows the unfiltered timeline holds, pinned notes excluded —
  /// what decides whether the filter is worth offering.
  final int itemCount;

  bool get isEmpty => itemCount == 0 && pinned.isEmpty;
}

/// How many rows a timeline needs before its filter is offered: a short
/// timeline has nothing to filter.
const personTimelineFiltersFrom = 8;

/// Builds a person's timeline.
///
/// [entries] are the notes, voice notes, photos and meetings on the
/// person's timeline (`PersonTimelineRepository.getTimelineEntries`);
/// [checkInEntries] what each check-in holds; [now] is the device's local
/// time, the reference for *Upcoming*, *Today* and *This week*. Days are
/// compared on the calendar day each stored time names, so the sections
/// are the same on every device (ADR 0114).
PersonTimeline buildPersonTimeline({
  required DateTime now,
  required List<CheckInEntry> checkIns,
  required List<JournalEntity> entries,
  required List<Task> tasks,
  Map<String, List<JournalEntity>> checkInEntries = const {},
  PersonTimelineFilter filter = PersonTimelineFilter.all,
}) {
  final pinned = <TimelineNote>[];
  final rows = <PersonTimelineItem>[
    for (final checkIn in checkIns)
      TimelineCheckIn(
        checkIn,
        entries: checkInEntries[checkIn.meta.id] ?? const [],
      ),
    for (final task in tasks) TimelineTask(task),
  ];
  final photos = <JournalImage>[];
  for (final entry in entries) {
    switch (entry) {
      case JournalEntry():
        final note = TimelineNote(entry);
        (note.pinned ? pinned : rows).add(note);
      case JournalAudio():
        rows.add(TimelineVoiceNote(entry));
      case JournalImage():
        photos.add(entry);
      case JournalEvent():
        rows.add(TimelineMeeting(entry));
      default:
        break;
    }
  }
  rows.addAll(_photosByDay(photos));
  pinned.sort(_newestFirst);

  final today = relationshipCalendarDay(now);
  final upcoming = <PersonTimelineItem>[];
  final past = <PersonTimelineItem>[];
  for (final row in rows) {
    if (!filter.admits(row)) continue;
    (_isUpcoming(row, now) ? upcoming : past).add(row);
  }
  upcoming.sort((a, b) => a.at.compareTo(b.at));
  past.sort(_newestFirst);

  return PersonTimeline(
    pinned: pinned,
    itemCount: rows.length,
    sections: [
      if (upcoming.isNotEmpty)
        PersonTimelineSection(
          kind: PersonTimelineSectionKind.upcoming,
          items: upcoming,
        ),
      ..._pastSections(past, today),
    ],
  );
}

int _newestFirst(PersonTimelineItem a, PersonTimelineItem b) =>
    b.at.compareTo(a.at);

/// A meeting that has not started yet, or an open task with a due date —
/// overdue ones included, since they are still ahead of the user.
bool _isUpcoming(PersonTimelineItem row, DateTime now) => switch (row) {
  TimelineMeeting() => !row.calledOff && row.at.isAfter(now),
  TimelineTask() => row.open && row.due != null,
  _ => false,
};

/// Photos grouped by the calendar day they were taken on, one row each.
Iterable<TimelinePhotos> _photosByDay(List<JournalImage> photos) {
  final byDay = <DateTime, List<JournalImage>>{};
  for (final photo in photos) {
    byDay
        .putIfAbsent(relationshipCalendarDay(photo.meta.dateFrom), () => [])
        .add(photo);
  }
  return byDay.values.map(
    (day) => TimelinePhotos(
      day..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom)),
    ),
  );
}

/// [past] (newest first) cut into *Today*, *This week* and one section per
/// calendar month. A row dated after today — a meeting called off before it
/// came — takes its month's section: *Today* is only today.
List<PersonTimelineSection> _pastSections(
  List<PersonTimelineItem> past,
  DateTime today,
) {
  final sections = <PersonTimelineSection>[];
  for (final row in past) {
    final day = relationshipCalendarDay(row.at);
    final daysAgo = today.difference(day).inDays;
    final kind = daysAgo == 0
        ? PersonTimelineSectionKind.today
        : daysAgo > 0 && daysAgo < 7
        ? PersonTimelineSectionKind.thisWeek
        : PersonTimelineSectionKind.month;
    final month = kind == PersonTimelineSectionKind.month
        ? DateTime.utc(day.year, day.month)
        : null;
    final last = sections.isEmpty ? null : sections.last;
    if (last != null && last.kind == kind && last.month == month) {
      last.items.add(row);
    } else {
      sections.add(
        PersonTimelineSection(kind: kind, month: month, items: [row]),
      );
    }
  }
  return sections;
}
