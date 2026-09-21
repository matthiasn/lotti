import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';

/// The three bands of the People list, in display order (design 2026-09-06
/// §2): people whose cadence has lapsed, people the agent is watching and
/// who are fine, and people it is not watching at all.
enum PeopleListGroup { due, onTrack, notEnrolled }

/// What the trailing pill on a People row says — a *truthful* read of the
/// cadence (HANDOVER P5: an overdue person must never read as "Due Sun").
enum PeopleCadencePillKind {
  /// Cadence lapsed — `{n} days over`, or `Due today` on the due day itself
  /// — warning tint.
  overdue,

  /// Due within the coming week: `Due {weekday}`.
  dueSoon,

  /// Enrolled and fine (an enrolled person always has a cadence — the
  /// runtime's default stands in for an unset one).
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

  /// Whole days over for the `overdue` kind (zero on the due day itself);
  /// zero for every other kind.
  int daysOver,

  /// The due date for the `dueSoon` kind; null otherwise.
  DateTime? dueAt,
});

/// One band of the list and the rows in it, ordered by what that band is
/// about (see [_orderWithin]) rather than by recency alone.
typedef PeopleListSection = ({
  PeopleListGroup group,
  List<RelationshipListItem> items,
});

/// The numbers the summary card above the list shows.
typedef PeopleSummary = ({
  /// Enrolled people whose cadence has lapsed, the due day included.
  int dueNow,

  /// People the agent watches: important *and* active.
  int enrolled,

  /// Everyone else.
  int notEnrolled,

  /// The enrolled, not-yet-due person whose cadence lapses next.
  RelationshipListItem? nextDue,

  /// When [nextDue]'s cadence lapses.
  DateTime? nextDueAt,

  /// The enrolled person whose cadence lapsed longest ago — what the due
  /// count is actually about, and so where the count's own tap leads.
  ///
  /// Deliberately separate from [nextDue] rather than folded into it: the
  /// card says "Next due {name}", and a card that says *next due* while
  /// pointing at someone already overdue is lying in order to be useful.
  /// Two facts, two doors.
  RelationshipListItem? mostOverdue,
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

/// The cadence the runtime actually applies to this person: the stored
/// value, or the production default when an enrolled person has none set
/// (ADR 0039 Decision 2 — the same substitution the deterministic tier
/// makes, so the list never says "on track" to someone the agent is about
/// to nudge). Null for a person who is not enrolled: the runtime clears
/// their reminders rather than scheduling any, so they have no due date.
int? effectiveCadenceDaysOf(RelationshipEntry relationship) {
  if (!isEnrolled(relationship)) return null;
  return relationship.data.checkInCadenceDays ?? relationshipDefaultCadenceDays;
}

/// Whole days the cadence is over (positive), zero on the due day itself,
/// negative while still ahead — or null for a person who is not enrolled.
int? peopleOverdueDaysOf(RelationshipListItem item, {DateTime? now}) =>
    cadenceOverdueDays(
      lastCheckInAt: item.lastCheckInAt,
      trackingStartedAt: item.relationship.meta.dateFrom,
      cadenceDays: effectiveCadenceDaysOf(item.relationship),
      now: now,
    );

/// When the cadence lapses, or null for a person who is not enrolled.
DateTime? peopleDueDateOf(RelationshipListItem item, {DateTime? now}) =>
    cadenceDueDate(
      lastCheckInAt: item.lastCheckInAt,
      trackingStartedAt: item.relationship.meta.dateFrom,
      cadenceDays: effectiveCadenceDaysOf(item.relationship),
      now: now,
    );

/// The band a row belongs to. Due *on* the due day, not only after it — the
/// runtime marks the cadence due once the current day is no longer before
/// the due day, and the list must agree with the nudge it sends.
PeopleListGroup peopleListGroupOf(RelationshipListItem item, {DateTime? now}) {
  if (!isEnrolled(item.relationship)) return PeopleListGroup.notEnrolled;
  return (peopleOverdueDaysOf(item, now: now) ?? -1) >= 0
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
  // Enrolled: the effective cadence is never null, so neither is this.
  final overdue = peopleOverdueDaysOf(item, now: now)!;
  if (overdue >= 0) {
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

/// Whether this pill would only restate the band heading it sits under.
///
/// `On track` inside *On track* and `Not enrolled` inside *Not enrolled* are
/// the same word twice. The band already groups by that state, so the pill
/// spends the row's trailing slot — and the width the person's name needs —
/// saying what the heading three rows up has already said.
///
/// The informative faces stay: `5 days over` and `Due Wed` carry a time no
/// heading can, and `Dormant` / `Archived` name a status the *Not enrolled*
/// heading does not. Each of those kinds occurs in exactly one band, so the
/// kind alone decides this — the caller does not have to pass its band in.
bool peopleCadencePillRestatesBand(PeopleCadencePillKind kind) =>
    kind == PeopleCadencePillKind.onTrack ||
    kind == PeopleCadencePillKind.notEnrolled;

/// The most recent contact, or the tracking start for a person without one,
/// so a freshly added person sorts to the top of their band.
DateTime peopleRecencyOf(RelationshipListItem item) =>
    item.lastCheckInAt ?? item.relationship.meta.dateFrom;

/// How a band orders its rows — each by the thing that band is *about*.
///
/// Ordering every band by recency made the list argue with its own summary
/// card: the card named the person whose cadence lapses next, and then the
/// *On track* band put someone with a later deadline above them. A band
/// that reports an obligation has to lead with the most urgent instance of
/// it, or the row the reader is looking for is not the row at the top.
///
/// Ties fall back to recency and then to id, so the order is total: two
/// people due the same day must not swap places between rebuilds.
int Function(RelationshipListItem, RelationshipListItem) _orderWithin(
  PeopleListGroup group,
  DateTime? now,
) {
  int byRecency(RelationshipListItem a, RelationshipListItem b) {
    final recency = peopleRecencyOf(b).compareTo(peopleRecencyOf(a));
    if (recency != 0) return recency;
    return a.relationship.meta.id.compareTo(b.relationship.meta.id);
  }

  return switch (group) {
    // The band exists to be discharged: the longest wait leads it.
    PeopleListGroup.due => (a, b) {
      final over = (peopleOverdueDaysOf(b, now: now) ?? 0).compareTo(
        peopleOverdueDaysOf(a, now: now) ?? 0,
      );
      return over != 0 ? over : byRecency(a, b);
    },
    // The next commitment leads — the person the summary card names.
    PeopleListGroup.onTrack => (a, b) {
      final dueA = peopleDueDateOf(a, now: now);
      final dueB = peopleDueDateOf(b, now: now);
      // Unreachable by construction: every member of this band is enrolled
      // (`peopleListGroupOf`), and an enrolled person always has a due date
      // (`effectiveCadenceDaysOf` substitutes the runtime default). Kept as
      // a guard so a future banding change misorders rather than crashes.
      // coverage:ignore-start
      if (dueA == null || dueB == null) return byRecency(a, b);
      // coverage:ignore-end
      final due = dueA.compareTo(dueB);
      return due != 0 ? due : byRecency(a, b);
    },
    // Nobody here has a deadline, so recency is the only honest order.
    PeopleListGroup.notEnrolled => byRecency,
  };
}

/// The list split into its bands, empty bands omitted, each band ordered by
/// what that band is about ([_orderWithin]). Favorites do not get a band of
/// their own — `important` decides enrolment, and the sparkle on the name is
/// a marker.
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
        (group: group, items: rows..sort(_orderWithin(group, now))),
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
  RelationshipListItem? mostOverdue;
  var mostOverdueDays = -1;
  for (final item in items) {
    if (!isEnrolled(item.relationship)) {
      notEnrolled++;
      continue;
    }
    enrolled++;
    final overdue = peopleOverdueDaysOf(item, now: now);
    if (overdue != null && overdue >= 0) {
      dueNow++;
      if (overdue > mostOverdueDays) {
        mostOverdueDays = overdue;
        mostOverdue = item;
      }
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
    mostOverdue: mostOverdue,
  );
}
