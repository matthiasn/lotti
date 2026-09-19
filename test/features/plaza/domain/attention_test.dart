import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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
      expect(today.reason, 'due today — finish it');

      final inThree = attentionFor(
        _task(due: _now.add(const Duration(days: 3))),
        _now,
      );
      expect(inThree.score, 2);
      expect(inThree.reason, 'due in 3 days — finish it');
      expect(
        attentionFor(
          _task(due: _now.add(const Duration(days: 1))),
          _now,
        ).reason,
        'due tomorrow — finish it',
      );

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

  test('every lantern state has its own glyph and word', () {
    final glyphs = {for (final s in LanternState.values) s.glyph};
    final words = {for (final s in LanternState.values) s.word};
    expect(glyphs, hasLength(LanternState.values.length));
    expect(words, hasLength(LanternState.values.length));
    expect(LanternState.blocked.glyph, '✕');
    expect(LanternState.overdue.word, 'overdue');
    expect(LanternState.inProgress.word, 'in progress');
    expect(LanternState.off.word, 'done');
  });

  test('the meta bits name only what the task has', () {
    expect(taskMetaBits(_task()), isEmpty);
    expect(taskMetaBits(_task(due: DateTime.utc(2026, 8, 2))), ['due Aug 2']);
    expect(taskMetaBits(_task(links: const ['a', 'b'])), ['links 2']);
    expect(
      taskMetaBits(_task(due: DateTime.utc(2026, 8, 2), links: const ['a'])),
      ['due Aug 2', 'links 1'],
    );
  });

  group('properties', () {
    // Tasks with every state, due dates from ten weeks late to ten days out,
    // activity up to a quarter back, and project portals with or without
    // flags.
    final task = glados.any.combine5(
      glados.any.choose(PlazaTaskState.values),
      glados.any.intInRange(-70, 11),
      glados.any.intInRange(0, 120),
      glados.any.combine3(
        glados.any.intInRange(0, 4),
        glados.any.intInRange(0, 40),
        glados.any.bool,
        (int priority, int items, bool deleted) =>
            (priority: priority, items: items, deleted: deleted),
      ),
      glados.any.intInRange(0, 3),
      (
        PlazaTaskState state,
        int dueIn,
        int idleDays,
        ({int priority, int items, bool deleted}) extra,
        int project,
      ) => (
        state: state,
        dueIn: dueIn == 10 ? null : dueIn,
        idleDays: idleDays,
        extra: extra,
        project: project,
      ),
    );

    List<PlazaTask> build(
      List<
        ({
          PlazaTaskState state,
          int? dueIn,
          int idleDays,
          ({int priority, int items, bool deleted}) extra,
          int project,
        })
      >
      specs,
    ) => [
      for (final (i, s) in specs.indexed)
        PlazaTask(
          id: 'task-${i.toString().padLeft(2, '0')}',
          createdAt: _now.subtract(Duration(days: s.idleDays + 30)),
          title: 'Task $i',
          state: s.state,
          progress: 0,
          checklistItems: s.extra.items,
          openChecklistItems: List.filled(s.extra.items, 'x'),
          linkedTaskIds: const [],
          categoryColor: 0,
          due: s.dueIn == null ? null : _now.add(Duration(days: s.dueIn!)),
          priority: s.extra.priority,
          lastActivityAt: _now.subtract(Duration(days: s.idleDays)),
          deleted: s.extra.deleted,
          project: s.project == 0
              ? null
              : PlazaProjectInfo(
                  state: PlazaProjectState.active,
                  taskCount: 5,
                  doneCount: 1,
                  attentionCount: s.project == 1 ? 1 : 0,
                  overdueCount: s.project == 2 ? 1 : 0,
                ),
        ),
    ];

    glados.Glados2(
      glados.any.listWithLengthInRange(0, 16, task),
      glados.any.intInRange(0, 1000),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'scores are bounded, finished tasks go dark, billboards are stable',
      (specs, seed) {
        final tasks = build(specs);
        final all = attentionForAll(tasks, _now);

        for (final a in all) {
          final finished =
              a.task.deleted ||
              a.task.state == PlazaTaskState.done ||
              a.task.state == PlazaTaskState.cancelled;
          if (finished) {
            expect((a.score, a.lantern, a.reason), (0, LanternState.off, ''));
          }
          // project 3 + blocked 3 + overdue 6 + stale 2 + priority 1 +
          // heft 1; due-soon and overdue exclude each other.
          expect(a.score, inInclusiveRange(0, 16));
          expect(a.anomalous, a.score >= anomalyThreshold);
        }

        // compareAttention is a total order: antisymmetric, and zero only
        // for the same task.
        for (final a in all) {
          for (final b in all) {
            final ab = compareAttention(a, b);
            expect(ab.sign, -compareAttention(b, a).sign);
            expect(ab == 0, identical(a.task, b.task));
          }
        }

        final billboards = billboardCandidates(all);
        expect(billboards.length, lessThanOrEqualTo(billboardSlots));
        expect(
          billboards.every((a) => a.score >= billboardThreshold),
          isTrue,
        );
        for (var i = 1; i < billboards.length; i++) {
          expect(compareAttention(billboards[i - 1], billboards[i]), -1);
        }
        final eligible = all.where((a) => a.score >= billboardThreshold);
        expect(
          billboards.length,
          eligible.length < billboardSlots ? eligible.length : billboardSlots,
        );

        final shuffled = billboardCandidates(
          attentionForAll([...tasks]..shuffle(Random(seed)), _now),
        );
        expect(
          shuffled.map((a) => a.task.id),
          billboards.map((a) => a.task.id),
        );
      },
      tags: 'glados',
    );
  });
}
