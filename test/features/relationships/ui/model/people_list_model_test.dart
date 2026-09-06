import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';

/// A Thursday, mid-morning — every date below is relative to it.
final _now = DateTime(2026, 8, 13, 10, 30);
final _trackingStart = DateTime(2026, 6, 1, 9);

/// One generated person, before it gets an id.
typedef _Spec = ({
  bool important,
  int statusIndex,
  int? cadenceDays,
  int? daysSinceLastCheckIn,
});

RelationshipListItem _itemFrom(
  String id,
  _Spec spec, {
  DateTime? trackingStart,
}) {
  final start = trackingStart ?? _trackingStart;
  final status = switch (spec.statusIndex) {
    0 => RelationshipStatus.active(id: 's-$id', createdAt: start, utcOffset: 0),
    1 => RelationshipStatus.dormant(
      id: 's-$id',
      createdAt: start,
      utcOffset: 0,
    ),
    _ => RelationshipStatus.archived(
      id: 's-$id',
      createdAt: start,
      utcOffset: 0,
    ),
  };
  final lastAt = spec.daysSinceLastCheckIn == null
      ? null
      : _now.subtract(Duration(days: spec.daysSinceLastCheckIn!, hours: 1));
  return (
    relationship: RelationshipEntry(
      meta: Metadata(
        id: id,
        createdAt: start,
        updatedAt: start,
        dateFrom: start,
        dateTo: start,
      ),
      data: RelationshipData(
        title: id,
        important: spec.important,
        checkInCadenceDays: spec.cadenceDays,
        status: status,
      ),
    ),
    lastCheckIn: lastAt == null
        ? null
        : CheckInEntry(
            meta: Metadata(
              id: 'check-$id',
              createdAt: lastAt,
              updatedAt: lastAt,
              dateFrom: lastAt,
              dateTo: lastAt,
            ),
            data: CheckInData(
              relationshipId: id,
              interactionType: CheckInInteractionType.call,
            ),
          ),
  );
}

List<RelationshipListItem> _itemsFrom(List<_Spec> specs) => [
  for (final (index, spec) in specs.indexed) _itemFrom('p$index', spec),
];

extension _AnyPeople on glados.Any {
  glados.Generator<_Spec> get personSpec =>
      glados.any.combine5<bool, int, int, int, int, _Spec>(
        glados.any.bool,
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 120),
        glados.IntAnys(this).intInRange(0, 3),
        (important, statusIndex, cadenceIndex, daysAgo, hasCheckIn) => (
          important: important,
          statusIndex: statusIndex,
          cadenceDays: const [null, 7, 14, 30, 90][cadenceIndex],
          daysSinceLastCheckIn: hasCheckIn == 0 ? null : daysAgo,
        ),
      );

  glados.Generator<List<_Spec>> get people => glados.any.list(personSpec);
}

void main() {
  group('peopleListSections — properties', () {
    glados.Glados(
      glados.any.people,
      glados.ExploreConfig(numRuns: 200),
    ).test('partitions the list: every person lands in exactly one band, '
        'bands are non-empty and in display order', (specs) {
      final items = _itemsFrom(specs);
      final sections = peopleListSections(items, now: _now);

      final ids = [
        for (final section in sections)
          for (final item in section.items) item.relationship.id,
      ];
      expect(ids.toSet(), {for (final item in items) item.relationship.id});
      expect(ids, hasLength(items.length));
      for (final section in sections) {
        expect(section.items, isNotEmpty);
      }
      final groupOrder = [for (final s in sections) s.group.index];
      expect(groupOrder, List.of(groupOrder)..sort());
      expect(groupOrder.toSet(), hasLength(groupOrder.length));
    }, tags: 'glados');

    glados.Glados(
      glados.any.people,
      glados.ExploreConfig(numRuns: 200),
    ).test('within a band the most recent contact comes first', (specs) {
      for (final section in peopleListSections(_itemsFrom(specs), now: _now)) {
        final recency = section.items.map(peopleRecencyOf).toList();
        for (var i = 1; i < recency.length; i++) {
          expect(recency[i - 1].isBefore(recency[i]), isFalse);
        }
      }
    }, tags: 'glados');

    glados.Glados2(
      glados.any.people,
      glados.any.int,
      glados.ExploreConfig(numRuns: 200),
    ).test('is a pure function of the set of people, not their order', (
      specs,
      seed,
    ) {
      final items = _itemsFrom(specs);
      final shuffled = List.of(items)..shuffle(Random(seed));
      final a = peopleListSections(items, now: _now);
      final b = peopleListSections(shuffled, now: _now);
      List<List<String>> shape(List<PeopleListSection> sections) => [
        for (final s in sections)
          [s.group.name, for (final i in s.items) i.relationship.id],
      ];
      // Ties on recency are the only freedom left; make them deterministic
      // by id before comparing.
      List<List<String>> normalised(List<PeopleListSection> sections) => [
        for (final s in sections)
          [
            s.group.name,
            ...(s.items.map((i) => i.relationship.id).toList()..sort(
              (x, y) {
                final ix = s.items.firstWhere((i) => i.relationship.id == x);
                final iy = s.items.firstWhere((i) => i.relationship.id == y);
                final byRecency = peopleRecencyOf(
                  iy,
                ).compareTo(peopleRecencyOf(ix));
                return byRecency != 0 ? byRecency : x.compareTo(y);
              },
            )),
          ],
      ];
      expect(normalised(b), normalised(a));
      expect(shape(a).length, shape(b).length);
    }, tags: 'glados');

    glados.Glados(
      glados.any.people,
      glados.ExploreConfig(numRuns: 200),
    ).test('the band and the pill never disagree about a person', (specs) {
      for (final item in _itemsFrom(specs)) {
        final group = peopleListGroupOf(item, now: _now);
        final pill = peopleCadencePillOf(item, now: _now);
        final expectedGroup = switch (pill.kind) {
          PeopleCadencePillKind.overdue => PeopleListGroup.due,
          PeopleCadencePillKind.dueSoon ||
          PeopleCadencePillKind.onTrack => PeopleListGroup.onTrack,
          PeopleCadencePillKind.notEnrolled ||
          PeopleCadencePillKind.dormant ||
          PeopleCadencePillKind.archived => PeopleListGroup.notEnrolled,
        };
        expect(group, expectedGroup, reason: item.relationship.id);
        if (pill.kind == PeopleCadencePillKind.overdue) {
          expect(pill.daysOver, greaterThan(0));
        } else {
          expect(pill.daysOver, 0);
        }
        expect(pill.dueAt != null, pill.kind == PeopleCadencePillKind.dueSoon);
      }
    }, tags: 'glados');

    glados.Glados(
      glados.any.people,
      glados.ExploreConfig(numRuns: 200),
    ).test('the summary counts what the bands hold, and names the earliest '
        'due among the on-track people', (specs) {
      final items = _itemsFrom(specs);
      final sections = {
        for (final s in peopleListSections(items, now: _now)) s.group: s.items,
      };
      final summary = peopleSummaryOf(items, now: _now);
      final due = sections[PeopleListGroup.due] ?? const [];
      final onTrack = sections[PeopleListGroup.onTrack] ?? const [];
      final notEnrolled = sections[PeopleListGroup.notEnrolled] ?? const [];

      expect(summary.dueNow, due.length);
      expect(summary.enrolled, due.length + onTrack.length);
      expect(summary.notEnrolled, notEnrolled.length);

      final candidates = [
        for (final item in onTrack)
          if (peopleDueDateOf(item, now: _now) case final d?) (item, d),
      ];
      if (candidates.isEmpty) {
        expect(summary.nextDue, isNull);
        expect(summary.nextDueAt, isNull);
      } else {
        final earliest = candidates
            .map((c) => c.$2)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        expect(summary.nextDueAt, earliest);
        expect(
          peopleDueDateOf(summary.nextDue!, now: _now),
          earliest,
        );
        expect(onTrack, contains(summary.nextDue));
      }
    }, tags: 'glados');
  });

  group('peopleCadencePillOf — the edges', () {
    RelationshipListItem person({
      bool important = true,
      int statusIndex = 0,
      int? cadenceDays = 7,
      int? daysAgo,
    }) => _itemFrom('x', (
      important: important,
      statusIndex: statusIndex,
      cadenceDays: cadenceDays,
      daysSinceLastCheckIn: daysAgo,
    ));

    test('one day past the cadence is overdue by one', () {
      final pill = peopleCadencePillOf(person(daysAgo: 8), now: _now);
      expect(pill.kind, PeopleCadencePillKind.overdue);
      expect(pill.daysOver, 1);
    });

    test('due seven days out is still "due soon"; eight is on track', () {
      // Weekly cadence, contacted today → due in seven days.
      expect(
        peopleCadencePillOf(person(daysAgo: 0), now: _now).kind,
        PeopleCadencePillKind.dueSoon,
      );
      // Fortnightly, contacted six days ago → due in eight.
      expect(
        peopleCadencePillOf(
          person(cadenceDays: 14, daysAgo: 6),
          now: _now,
        ).kind,
        PeopleCadencePillKind.onTrack,
      );
    });

    test('a person never contacted counts from the tracking start', () {
      // Tracking since 1 Jun, weekly: long lapsed by 13 Aug.
      final pill = peopleCadencePillOf(person(), now: _now);
      expect(pill.kind, PeopleCadencePillKind.overdue);
      expect(
        pill.daysOver,
        _now.difference(_trackingStart.add(const Duration(days: 7))).inDays,
      );
    });

    test('enrolled without a cadence is on track, never due', () {
      expect(
        peopleCadencePillOf(person(cadenceDays: null), now: _now).kind,
        PeopleCadencePillKind.onTrack,
      );
    });

    test('not important is not enrolled, whatever the cadence says', () {
      final pill = peopleCadencePillOf(
        person(important: false, daysAgo: 40),
        now: _now,
      );
      expect(pill.kind, PeopleCadencePillKind.notEnrolled);
    });

    test('an important but dormant or archived person is kept, not nurtured '
        '(ADR 0039)', () {
      expect(
        peopleCadencePillOf(
          person(statusIndex: 1, daysAgo: 40),
          now: _now,
        ).kind,
        PeopleCadencePillKind.dormant,
      );
      expect(
        peopleCadencePillOf(
          person(statusIndex: 2, daysAgo: 40),
          now: _now,
        ).kind,
        PeopleCadencePillKind.archived,
      );
      expect(
        peopleListGroupOf(person(statusIndex: 1), now: _now),
        PeopleListGroup.notEnrolled,
      );
    });
  });

  test('peopleSummaryOf on an empty list is all zeros and names no one', () {
    final summary = peopleSummaryOf(const [], now: _now);
    expect(summary.dueNow, 0);
    expect(summary.enrolled, 0);
    expect(summary.notEnrolled, 0);
    expect(summary.nextDue, isNull);
  });
}
