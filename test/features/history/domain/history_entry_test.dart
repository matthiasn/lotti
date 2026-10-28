import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/history_db.dart';
import 'package:lotti/features/history/domain/history_entry.dart';

void main() {
  group('historyTargetForRoute', () {
    const cases = <String, HistoryTarget?>{
      '/tasks/t1': HistoryTarget(
        kind: HistoryEntityKind.task,
        entityId: 't1',
        route: '/tasks/t1',
      ),
      '/journal/e1': HistoryTarget(
        kind: HistoryEntityKind.entry,
        entityId: 'e1',
        route: '/journal/e1',
      ),
      '/projects/p1': HistoryTarget(
        kind: HistoryEntityKind.project,
        entityId: 'p1',
        route: '/projects/p1',
      ),
      // The edit form counts as a visit to the project, at its own route.
      '/projects/p1/edit': HistoryTarget(
        kind: HistoryEntityKind.project,
        entityId: 'p1',
        route: '/projects/p1',
      ),
      '/events/v1': HistoryTarget(
        kind: HistoryEntityKind.event,
        entityId: 'v1',
        route: '/events/v1',
      ),
      '/people/r1/check-ins/c1': HistoryTarget(
        kind: HistoryEntityKind.person,
        entityId: 'r1',
        route: '/people/r1',
      ),
      '/dashboards/d1': HistoryTarget(
        kind: HistoryEntityKind.dashboard,
        entityId: 'd1',
        route: '/dashboards/d1',
      ),
      '/habits/edit/h1': HistoryTarget(
        kind: HistoryEntityKind.habit,
        entityId: 'h1',
        route: '/habits/edit/h1',
      ),
      // A query string does not change which entity is shown.
      '/tasks/t1?tab=checklist': HistoryTarget(
        kind: HistoryEntityKind.task,
        entityId: 't1',
        route: '/tasks/t1',
      ),
      // Lists, forms and pages that show no entity.
      '/tasks': null,
      '/tasks/': null,
      '/journal/fill_survey/cfq11': null,
      '/dashboards/impact': null,
      '/habits/create': null,
      '/habits': null,
      '/calendar/refine/2026-03-01': null,
      '/settings/advanced': null,
      '/goals/details/a1': null,
      '': null,
    };

    for (final MapEntry(key: route, value: expected) in cases.entries) {
      test('maps "$route"', () {
        expect(historyTargetForRoute(route), expected);
      });
    }
  });

  test('sameEntityAs ignores the route, compares kind and id', () {
    const a = HistoryTarget(
      kind: HistoryEntityKind.task,
      entityId: 't1',
      route: '/tasks/t1',
    );
    const sameTaskOtherRoute = HistoryTarget(
      kind: HistoryEntityKind.task,
      entityId: 't1',
      route: '/tasks/t1?x=1',
    );
    const sameIdOtherKind = HistoryTarget(
      kind: HistoryEntityKind.entry,
      entityId: 't1',
      route: '/journal/t1',
    );
    expect(a.sameEntityAs(sameTaskOtherRoute), isTrue);
    expect(a == sameTaskOtherRoute, isFalse);
    expect(a.sameEntityAs(sameIdOtherKind), isFalse);
  });

  test('equal targets and entries hash alike, and print what they hold', () {
    HistoryTarget target() => const HistoryTarget(
      kind: HistoryEntityKind.task,
      entityId: 't1',
      route: '/tasks/t1',
    );
    HistoryEntry entry() =>
        HistoryEntry(id: 3, target: target(), visitedAt: DateTime(2026, 3));

    expect({target(), target()}, hasLength(1));
    expect({entry(), entry()}, hasLength(1));
    expect(
      {
        entry(),
        HistoryEntry(id: 4, target: target(), visitedAt: DateTime(2026, 3)),
      },
      hasLength(2),
    );
    expect(target().toString(), contains('t1'));
  });

  group('HistoryEntry.fromRow', () {
    HistoryEntryRow row(String kind) => HistoryEntryRow(
      id: 7,
      kind: kind,
      entityId: 'p1',
      route: '/projects/p1',
      visitedAt: DateTime(2026, 3, 1, 9),
    );

    test('reads a known kind', () {
      expect(
        HistoryEntry.fromRow(row('project')),
        HistoryEntry(
          id: 7,
          target: const HistoryTarget(
            kind: HistoryEntityKind.project,
            entityId: 'p1',
            route: '/projects/p1',
          ),
          visitedAt: DateTime(2026, 3, 1, 9),
        ),
      );
    });

    test('skips a kind this build does not know', () {
      expect(HistoryEntry.fromRow(row('spaceship')), isNull);
    });
  });

  test('every kind round-trips through its stored name', () {
    for (final kind in HistoryEntityKind.values) {
      expect(HistoryEntityKind.tryParse(kind.name), kind);
    }
  });

  test('a resolved entry without a title is gone', () {
    final entry = HistoryEntry(
      id: 1,
      target: const HistoryTarget(
        kind: HistoryEntityKind.task,
        entityId: 't',
        route: '/tasks/t',
      ),
      visitedAt: DateTime(2026),
    );
    expect(ResolvedHistoryEntry(entry: entry, title: null).isGone, isTrue);
    expect(ResolvedHistoryEntry(entry: entry, title: '').isGone, isFalse);
  });
}
