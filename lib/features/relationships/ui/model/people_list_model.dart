import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';

/// The three bands of the People list, in display order (design 2026-09-06
/// §2): people whose cadence has lapsed, people the agent is watching and
/// who are fine, and people it is not watching at all.
enum PeopleListGroup { due, onTrack, notEnrolled }

/// What the trailing pill on a People row says — a *truthful* read of the
/// cadence (HANDOVER P5: an overdue person must never read as "Due Sun").
enum PeopleCadencePillKind {
  /// Cadence lapsed: `{n} days over`, warning tint.
  overdue,

  /// Due within the coming week: `Due {weekday}`.
  dueSoon,

  /// Enrolled and fine, or enrolled with no cadence set.
  onTrack,

  /// Active but not important — the agent is not watching.
  notEnrolled,

  /// Kept, not nurtured (ADR 0039: excluded from cadence).
  dormant,

  /// Closed.
  archived,
}

/// The pill for one row: its kind plus the fact it names.
typedef PeopleCadencePill = ({
  PeopleCadencePillKind kind,

  /// Whole days over for the `overdue` kind; zero otherwise.
  int daysOver,

  /// The due date for the `dueSoon` kind; null otherwise.
  DateTime? dueAt,
});

/// One band of the list and the rows in it, most recent contact first.
typedef PeopleListSection = ({
  PeopleListGroup group,
  List<RelationshipListItem> items,
});

/// The numbers the summary card above the list shows.
typedef PeopleSummary = ({
  /// Enrolled people whose cadence has lapsed.
  int dueNow,

  /// People the agent watches: important *and* active.
  int enrolled,

  /// Everyone else.
  int notEnrolled,

  /// The enrolled, not-yet-due person whose cadence lapses next.
  RelationshipListItem? nextDue,

  /// When [nextDue]'s cadence lapses.
  DateTime? nextDueAt,
});

/// How far ahead "due soon" looks, in days. A person due within the coming
/// week gets `Due {weekday}` instead of `On track`.
const int peopleDueSoonWindowDays = 7;

/// Whether the agent watches this person: the `important` consent switch is
/// on *and* the relationship is active. A dormant or archived important
/// person is kept but not nurtured (ADR 0039), so they are not enrolled.
bool isEnrolled(RelationshipEntry relationship) =>
    relationship.data.important &&
    relationship.data.status is RelationshipActive;

/// Whole days the cadence is over (positive) or still ahead (negative), or
/// null when the person has no cadence.
int? peopleOverdueDaysOf(RelationshipListItem item, {DateTime? now}) =>
    cadenceOverdueDays(
      lastCheckInAt: item.lastCheckInAt,
      trackingStartedAt: item.relationship.meta.dateFrom,
      cadenceDays: item.relationship.data.checkInCadenceDays,
      now: now,
    );

/// When the cadence lapses, or null without a cadence.
DateTime? peopleDueDateOf(RelationshipListItem item, {DateTime? now}) =>
    cadenceDueDate(
      lastCheckInAt: item.lastCheckInAt,
      trackingStartedAt: item.relationship.meta.dateFrom,
      cadenceDays: item.relationship.data.checkInCadenceDays,
      now: now,
    );

/// The band a row belongs to.
PeopleListGroup peopleListGroupOf(RelationshipListItem item, {DateTime? now}) {
  if (!isEnrolled(item.relationship)) return PeopleListGroup.notEnrolled;
  return (peopleOverdueDaysOf(item, now: now) ?? 0) > 0
      ? PeopleListGroup.due
      : PeopleListGroup.onTrack;
}

/// The row's pill.
PeopleCadencePill peopleCadencePillOf(
  RelationshipListItem item, {
  DateTime? now,
}) {
  final relationship = item.relationship;
  if (!isEnrolled(relationship)) {
    final kind = switch (relationship.data.status) {
      RelationshipDormant() => PeopleCadencePillKind.dormant,
      RelationshipArchived() => PeopleCadencePillKind.archived,
      RelationshipActive() => PeopleCadencePillKind.notEnrolled,
    };
    return (kind: kind, daysOver: 0, dueAt: null);
  }
  final overdue = peopleOverdueDaysOf(item, now: now);
  if (overdue == null) {
    return (kind: PeopleCadencePillKind.onTrack, daysOver: 0, dueAt: null);
  }
  if (overdue > 0) {
    return (
      kind: PeopleCadencePillKind.overdue,
      daysOver: overdue,
      dueAt: null,
    );
  }
  if (overdue >= -peopleDueSoonWindowDays) {
    return (
      kind: PeopleCadencePillKind.dueSoon,
      daysOver: 0,
      dueAt: peopleDueDateOf(item, now: now),
    );
  }
  return (kind: PeopleCadencePillKind.onTrack, daysOver: 0, dueAt: null);
}

/// The most recent contact, or the tracking start for a person without one,
/// so a freshly added person sorts to the top of their band.
DateTime peopleRecencyOf(RelationshipListItem item) =>
    item.lastCheckInAt ?? item.relationship.meta.dateFrom;

/// The list split into its bands, empty bands omitted, each band most recent
/// contact first. Favorites do not get a band of their own — `important`
/// decides enrolment, and the sparkle on the name is a marker.
List<PeopleListSection> peopleListSections(
  List<RelationshipListItem> items, {
  DateTime? now,
}) {
  final byGroup = <PeopleListGroup, List<RelationshipListItem>>{};
  for (final item in items) {
    byGroup.putIfAbsent(peopleListGroupOf(item, now: now), () => []).add(item);
  }
  return [
    for (final group in PeopleListGroup.values)
      if (byGroup[group] case final rows? when rows.isNotEmpty)
        (
          group: group,
          items: rows
            ..sort((a, b) => peopleRecencyOf(b).compareTo(peopleRecencyOf(a))),
        ),
  ];
}

/// The summary card's numbers over the whole list.
PeopleSummary peopleSummaryOf(
  List<RelationshipListItem> items, {
  DateTime? now,
}) {
  var dueNow = 0;
  var enrolled = 0;
  var notEnrolled = 0;
  RelationshipListItem? nextDue;
  DateTime? nextDueAt;
  for (final item in items) {
    if (!isEnrolled(item.relationship)) {
      notEnrolled++;
      continue;
    }
    enrolled++;
    final overdue = peopleOverdueDaysOf(item, now: now);
    if (overdue != null && overdue > 0) {
      dueNow++;
      continue;
    }
    final due = peopleDueDateOf(item, now: now);
    if (due != null && (nextDueAt == null || due.isBefore(nextDueAt))) {
      nextDue = item;
      nextDueAt = due;
    }
  }
  return (
    dueNow: dueNow,
    enrolled: enrolled,
    notEnrolled: notEnrolled,
    nextDue: nextDue,
    nextDueAt: nextDueAt,
  );
}
