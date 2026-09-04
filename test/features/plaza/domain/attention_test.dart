import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';

final _now = DateTime.utc(2026, 7, 15, 10);

PlazaTask _task({
  String id = 't',
  PlazaTaskState state = PlazaTaskState.open,
  DateTime? due,
  DateTime? lastActivityAt,
  DateTime? createdAt,
  int? priority,
  List<String> links = const [],
  int items = 0,
  bool deleted = false,
}) => PlazaTask(
  id: id,
  createdAt: createdAt ?? DateTime.utc(2026, 7),
  title: 'Task $id',
  state: state,
  progress: 0,
  checklistItems: items,
  openChecklistItems: List.filled(items, 'x'),
  linkedTaskIds: links,
  categoryColor: 0,
  due: due,
  priority: priority ?? 2,
  lastActivityAt: lastActivityAt,
  deleted: deleted,
);

void main() {
  group('attentionFor', () {
    test('an unremarkable open task scores zero with a warm-white lantern', () {
      final a = attentionFor(_task(), _now);
      expect(a.score, 0);
      expect(a.reason, isEmpty);
      expect(a.anomalous, isFalse);
      expect(a.lantern, LanternState.open);
    });

    test('blocked scores 3 and says why', () {
      final a = attentionFor(_task(state: PlazaTaskState.blocked), _now);
      expect(a.score, 3);
      expect(a.anomalous, isTrue);
      expect(a.reason, 'blocked — needs a decision');
      expect(a.lantern, LanternState.blocked);
    });

    test('overdue scores 3 plus one per week, capped at 6', () {
      final oneDay = attentionFor(
        _task(due: _now.subtract(const Duration(days: 1))),
        _now,
      );
      expect(oneDay.score, 3);
      expect(oneDay.overdue, isTrue);
      expect(oneDay.reason, 'overdue since Jul 14 — finish or move it');
      expect(oneDay.lantern, LanternState.overdue);

      final twoWeeks = attentionFor(
        _task(due: _now.subtract(const Duration(days: 15))),
        _now,
      );
      expect(twoWeeks.score, 5);

      final ancient = attentionFor(
        _task(due: _now.subtract(const Duration(days: 400))),
        _now,
      );
      expect(ancient.score, 6);
    });

    test('due today or within three days scores 2, not overdue', () {
      final today = attentionFor(_task(due: _now), _now);
      expect(today.score, 2);
      expect(today.dueSoon, isTrue);
      expect(today.overdue, isFalse);
      expect(today.reason, 'due Jul 15 — finish it');

      final inThree = attentionFor(
        _task(due: _now.add(const Duration(days: 3))),
        _now,
      );
      expect(inThree.score, 2);

      final inFour = attentionFor(
        _task(due: _now.add(const Duration(days: 4))),
        _now,
      );
      expect(inFour.score, 0);
      expect(inFour.reason, isEmpty);
    });

    test('stale in-progress work scores 2 after fourteen quiet days', () {
      final fresh = attentionFor(
        _task(
          state: PlazaTaskState.inProgress,
          lastActivityAt: _now.subtract(const Duration(days: 13)),
        ),
        _now,
      );
      expect(fresh.score, 0);
      expect(fresh.lantern, LanternState.inProgress);

      final stale = attentionFor(
        _task(
          state: PlazaTaskState.inProgress,
          lastActivityAt: _now.subtract(const Duration(days: 14)),
        ),
        _now,
      );
      expect(stale.score, 2);
      expect(stale.stale, isTrue);
      expect(stale.reason, 'quiet for 14 days — pick it back up');

      // With no activity recorded, creation counts as the last touch.
      final neverTouched = attentionFor(
        _task(
          state: PlazaTaskState.inProgress,
          createdAt: _now.subtract(const Duration(days: 30)),
        ),
        _now,
      );
      expect(neverTouched.stale, isTrue);
    });

    test('an open task that is urgent, or heavy and old, earns a point', () {
      expect(attentionFor(_task(priority: 1), _now).score, 1);
      expect(attentionFor(_task(priority: 0), _now).score, 1);
      expect(
        attentionFor(
          _task(
            priority: 1,
            state: PlazaTaskState.inProgress,
            lastActivityAt: _now,
          ),
          _now,
        ).score,
        0,
      );
      final heavyOld = _task(
        links: const ['a', 'b', 'c'],
        items: 2,
        createdAt: _now.subtract(const Duration(days: 60)),
      );
      expect(heavyOld.heft, 7);
      expect(attentionFor(heavyOld, _now).score, 1);
      final heavyNew = _task(links: const ['a', 'b', 'c'], items: 2);
      expect(attentionFor(heavyNew, _now).score, 0);
    });

    test('signals stack, and the first reason wins', () {
      final a = attentionFor(
        _task(
          state: PlazaTaskState.blocked,
          due: _now.subtract(const Duration(days: 2)),
          priority: 0,
        ),
        _now,
      );
      expect(a.score, 6); // blocked 3 + overdue 3; priority only when open.
      expect(a.reason, 'blocked — needs a decision');
    });

    test(
      'done, cancelled and deleted tasks score zero with the lantern off',
      () {
        for (final task in [
          _task(
            state: PlazaTaskState.done,
            due: _now.subtract(const Duration(days: 30)),
          ),
          _task(state: PlazaTaskState.cancelled, priority: 0),
          _task(state: PlazaTaskState.blocked, deleted: true),
        ]) {
          final a = attentionFor(task, _now);
          expect(a.score, 0);
          expect(a.lantern, LanternState.off);
        }
      },
    );

    test('is a function of the day, not the time of day', () {
      final task = _task(due: DateTime.utc(2026, 7, 14, 23, 59));
      final morning = attentionFor(task, DateTime.utc(2026, 7, 15, 0, 1));
      final night = attentionFor(task, DateTime.utc(2026, 7, 15, 23, 59));
      expect(morning.score, night.score);
      expect(morning.overdue, isTrue);
    });
  });

  group('ranking', () {
    final tasks = [
      _task(id: 'c', state: PlazaTaskState.blocked), // 3
      _task(id: 'a', due: _now.subtract(const Duration(days: 1))), // 3
      _task(id: 'b', due: _now), // 2
      _task(id: 'd', priority: 1), // 1
      _task(id: 'e'), // 0
      _task(
        id: 'f',
        state: PlazaTaskState.blocked,
        priority: 0,
        due: _now.subtract(const Duration(days: 20)),
      ), // 3+5
    ];
    final all = attentionForAll(tasks, _now);

    test('anomalies are score ≥ 3, highest first, id as tiebreak', () {
      expect(anomalies(all).map((a) => a.task.id), ['f', 'a', 'c']);
    });

    test('billboard candidates include score 2 and stop at six', () {
      expect(billboardCandidates(all).map((a) => a.task.id), [
        'f',
        'a',
        'c',
        'b',
      ]);
      final many = [
        for (var i = 0; i < 10; i++) _task(id: 'x$i', due: _now),
      ];
      expect(
        billboardCandidates(attentionForAll(many, _now)),
        hasLength(billboardSlots),
      );
    });

    test('attentionForAll keeps input order', () {
      expect(all.map((a) => a.task.id), tasks.map((t) => t.id));
    });
  });

  test('shortDate', () {
    expect(shortDate(DateTime.utc(2026, 1, 3)), 'Jan 3');
    expect(shortDate(DateTime.utc(2026, 12, 25)), 'Dec 25');
  });
}
