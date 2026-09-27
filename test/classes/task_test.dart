import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:glados/glados.dart' show AnyUtils, ExploreConfig, Glados, any;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('TaskData', () {
    late DateTime testDate;
    late TaskStatus testStatus;

    setUp(() {
      testDate = DateTime(2024);
      testStatus = TaskStatus.open(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      );
    });

    test('creates TaskData with language code', () {
      final taskData = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
        languageCode: 'de',
      );

      expect(taskData.languageCode, equals('de'));
      expect(taskData.title, equals('Test Task'));
      expect(taskData.status, equals(testStatus));
    });

    test('creates TaskData without language code', () {
      final taskData = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
      );

      expect(taskData.languageCode, isNull);
      expect(taskData.title, equals('Test Task'));
    });

    TaskData makeTask({String? languageCode}) => TaskData(
      status: testStatus,
      dateFrom: testDate,
      dateTo: testDate,
      statusHistory: [],
      title: 'Test Task',
      languageCode: languageCode,
    );

    // The copyWith languageCode contract, parameterized over (initial code,
    // copyWith arguments, expected code after the copy).
    for (final (description, initial, copy, expectedCode) in [
      (
        'copyWith() preserves the language code',
        'es',
        (TaskData d) => d.copyWith(),
        'es',
      ),
      (
        'copyWith(title: ...) leaves the language code untouched',
        'fr',
        (TaskData d) => d.copyWith(title: 'Updated Task'),
        'fr',
      ),
      (
        'copyWith(languageCode: ...) updates the language code',
        'en',
        (TaskData d) => d.copyWith(languageCode: 'de'),
        'de',
      ),
      (
        'copyWith(languageCode: null) clears the language code',
        'en',
        (TaskData d) => d.copyWith(languageCode: null),
        null,
      ),
    ]) {
      test(description, () {
        final copied = copy(makeTask(languageCode: initial));
        expect(copied.languageCode, expectedCode);
        // Untouched fields survive every copy.
        expect(copied.status, testStatus);
        expect(copied.dateFrom, testDate);
      });
    }

    test('equality with language code', () {
      expect(makeTask(languageCode: 'fr'), makeTask(languageCode: 'fr'));
      expect(
        makeTask(languageCode: 'fr'),
        isNot(makeTask(languageCode: 'de')),
      );
    });

    group('onStored (ADR 0098)', () {
      TaskData data({
        String title = 'Test Task',
        List<String>? checklistIds,
        Set<String>? effects,
      }) => TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: const [],
        title: title,
        checklistIds: checklistIds,
        appliedChangeEffects: effects,
      );

      test(
        'takes the stored checklists and joins both records of applied '
        "changes, keeping the caller's own fields",
        () {
          final written =
              data(
                title: 'Renamed',
                checklistIds: ['stale'],
                effects: {'set-2:0'},
              ).onStored(
                data(checklistIds: ['kept', 'new'], effects: {'set-1:0'}),
              );

          expect(written.title, 'Renamed');
          expect(written.checklistIds, ['kept', 'new']);
          expect(written.appliedChangeEffects, {'set-1:0', 'set-2:0'});
        },
      );

      test(
        'keeps the stored record when the caller copied the task before a '
        'change was applied',
        () {
          final written = data(title: 'Renamed').onStored(
            data(effects: {'set-1:0'}),
          );

          expect(written.appliedChangeEffects, {'set-1:0'});
        },
      );

      test('records nothing where neither side records a change', () {
        expect(data().onStored(data()).appliedChangeEffects, isNull);
      });

      test('survives the JSON round trip that sync and storage take', () {
        final original = data(effects: {'set-1:0', 'set-1:1'});

        expect(
          TaskData.fromJson(
            jsonDecode(jsonEncode(original)) as Map<String, dynamic>,
          ).appliedChangeEffects,
          {'set-1:0', 'set-1:1'},
        );
      });
    });

    group('withStatus', () {
      final base = TaskData(
        status: TaskStatus.open(
          id: 'open-1',
          createdAt: DateTime(2024, 3, 15, 9),
          utcOffset: 60,
        ),
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        statusHistory: [
          TaskStatus.open(
            id: 'open-1',
            createdAt: DateTime(2024, 3, 15, 9),
            utcOffset: 60,
          ),
        ],
        title: 'Feed the penguins',
        priority: TaskPriority.p1High,
        estimate: const Duration(minutes: 30),
      );

      test('sets a new status and appends it to the history, keeping every '
          'other field', () {
        final inProgress = TaskStatus.inProgress(
          id: 'progress-1',
          createdAt: DateTime(2024, 3, 15, 10),
          utcOffset: 60,
        );

        final next = base.withStatus(inProgress);

        expect(next.status, inProgress);
        expect(next.statusHistory, [...base.statusHistory, inProgress]);
        expect(
          next.copyWith(
            status: base.status,
            statusHistory: base.statusHistory,
          ),
          base,
        );
      });

      test('leaves the data as it is for a status of the same kind — a '
          'repeated "done" records no second entry', () {
        final done = base.withStatus(
          TaskStatus.done(
            id: 'done-1',
            createdAt: DateTime(2024, 3, 15, 11),
            utcOffset: 60,
          ),
        );

        final again = done.withStatus(
          TaskStatus.done(
            id: 'done-2',
            createdAt: DateTime(2024, 3, 15, 12),
            utcOffset: 60,
          ),
        );

        expect(again, same(done));
        expect(again.statusHistory.map((s) => s.id), ['open-1', 'done-1']);
      });

      test('compares by the database string, not the status id or reason', () {
        final blocked = base.withStatus(
          TaskStatus.blocked(
            id: 'blocked-1',
            createdAt: DateTime(2024, 3, 15, 11),
            utcOffset: 60,
            reason: 'waiting for fish',
          ),
        );

        expect(
          blocked.withStatus(
            TaskStatus.blocked(
              id: 'blocked-2',
              createdAt: DateTime(2024, 3, 15, 12),
              utcOffset: 60,
              reason: 'still waiting',
            ),
          ),
          same(blocked),
        );
      });
    });

    group('withHistoryOf', () {
      TaskStatus at(String id, int hour, {bool done = false}) => done
          ? TaskStatus.done(
              id: id,
              createdAt: DateTime(2024, 3, 15, hour),
              utcOffset: 60,
            )
          : TaskStatus.inProgress(
              id: id,
              createdAt: DateTime(2024, 3, 15, hour),
              utcOffset: 60,
            );

      TaskData withHistory(List<TaskStatus> history, {String title = 't'}) =>
          TaskData(
            status: history.isEmpty ? testStatus : history.last,
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: history,
            title: title,
          );

      test("joins the other side's statuses by id, in the order they were "
          'set, each once', () {
        final local = withHistory([at('a', 9), at('c', 11)], title: 'local');
        final remote = withHistory([at('a', 9), at('b', 10), at('d', 12)]);

        final joined = local.withHistoryOf(remote);

        expect(joined.statusHistory.map((s) => s.id), ['a', 'b', 'c', 'd']);
        // Only the history is joined: the kept side's fields stand.
        expect(joined.title, 'local');
        expect(joined.status, local.status);
      });

      test('returns the data itself when the other side adds nothing', () {
        final local = withHistory([at('a', 9), at('b', 10)]);

        expect(local.withHistoryOf(withHistory([at('b', 10)])), same(local));
        expect(local.withHistoryOf(withHistory(const [])), same(local));
      });

      test('orders statuses set at the same instant by id, so both '
          'directions of a join agree', () {
        final local = withHistory([at('b', 9), at('z', 10)]);
        final remote = withHistory([at('a', 9), at('c', 9)]);

        final ids = local.withHistoryOf(remote).statusHistory.map((s) => s.id);
        final reversed = remote
            .withHistoryOf(local)
            .statusHistory
            .map((s) => s.id);

        expect(ids, ['a', 'b', 'c', 'z']);
        expect(reversed, ids);
      });

      test('keeps its own entry for an id both sides hold', () {
        final local = withHistory([at('a', 9)]);
        final remote = withHistory([at('a', 9, done: true), at('b', 10)]);

        final joined = local.withHistoryOf(remote);

        expect(joined.statusHistory.first, local.statusHistory.first);
        expect(joined.statusHistory.map((s) => s.id), ['a', 'b']);
      });
    });
  });

  group('TaskStatus.colorForBrightness', () {
    // Dark-mode status colors (moved from test/utils/task_utils_test.dart —
    // colorForBrightness lives on TaskStatus in lib/classes/task.dart).
    for (final (status, expected) in [
      (
        TaskStatus.open(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
        ),
        Colors.orange,
      ),
      (
        TaskStatus.groomed(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
        ),
        Colors.lightGreenAccent,
      ),
      (
        TaskStatus.inProgress(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
        ),
        Colors.blue,
      ),
      (
        TaskStatus.blocked(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
          reason: '',
        ),
        Colors.red,
      ),
      (
        TaskStatus.onHold(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
          reason: '',
        ),
        Colors.red,
      ),
      (
        TaskStatus.done(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
        ),
        Colors.green,
      ),
      (
        TaskStatus.rejected(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
        ),
        Colors.red,
      ),
    ]) {
      test('${status.runtimeType} maps to its dark-mode color', () {
        expect(status.colorForBrightness(Brightness.dark), expected);
      });
    }
  });

  group('Task entity', () {
    late DateTime testDate;
    late Metadata testMetadata;
    late TaskStatus testStatus;

    setUp(() {
      testDate = DateTime(2024);
      testMetadata = Metadata(
        id: 'task-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      );
      testStatus = TaskStatus.open(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      );
    });

    test('creates Task with language code in data', () {
      final task = Task(
        meta: testMetadata,
        data: TaskData(
          status: testStatus,
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [],
          title: 'Test Task',
          languageCode: 'ja',
        ),
      );

      expect(task.data.languageCode, equals('ja'));
      expect(task.meta.id, equals('task-1'));
    });

    test('copyWith preserves language code in task data', () {
      final task = Task(
        meta: testMetadata,
        data: TaskData(
          status: testStatus,
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [],
          title: 'Test Task',
          languageCode: 'ko',
        ),
      );

      final updatedTask = task.copyWith(
        data: task.data.copyWith(
          title: 'Updated Title',
        ),
      );

      expect(updatedTask.data.languageCode, equals('ko'));
      expect(updatedTask.data.title, equals('Updated Title'));
    });
  });

  group('taskStatusFromString', () {
    // Each branch maps a string to the correct TaskStatus subtype and the
    // toDbString round-trip returns the canonical DB string.
    final cases = <(String, Type, String)>[
      ('DONE', TaskDone, 'DONE'),
      ('GROOMED', TaskGroomed, 'GROOMED'),
      ('IN PROGRESS', TaskInProgress, 'IN PROGRESS'),
      ('BLOCKED', TaskBlocked, 'BLOCKED'),
      ('ON HOLD', TaskOnHold, 'ON HOLD'),
      ('REJECTED', TaskRejected, 'REJECTED'),
      ('OPEN', TaskOpen, 'OPEN'),
      ('anything else', TaskOpen, 'OPEN'),
    ];

    for (final (input, expectedType, expectedDb) in cases) {
      test('parses "$input" → $expectedType, toDbString == "$expectedDb"', () {
        final status = taskStatusFromString(input);
        expect(status.runtimeType, equals(expectedType));
        expect(status.toDbString, equals(expectedDb));
      });
    }

    test('BLOCKED result carries default reason', () {
      final status = taskStatusFromString('BLOCKED') as TaskBlocked;
      expect(status.reason, equals('needs a reason'));
    });

    test('ON HOLD result carries default reason', () {
      final status = taskStatusFromString('ON HOLD') as TaskOnHold;
      expect(status.reason, equals('needs a reason'));
    });
  });

  group('TaskData.withHistoryOf properties (glados)', () {
    // A status is identified by its id: the same id always carries the same
    // status, each set at its own moment, as on a real device.
    TaskStatus status(int n) {
      final createdAt = DateTime.utc(2024, 3, 15).add(Duration(minutes: n));
      return n.isEven
          ? TaskStatus.inProgress(id: 's$n', createdAt: createdAt, utcOffset: 0)
          : TaskStatus.done(id: 's$n', createdAt: createdAt, utcOffset: 0);
    }

    TaskData side(List<int> ns) {
      final history = (ns.toSet().toList()..sort()).map(status).toList();
      return TaskData(
        status: history.isEmpty ? status(0) : history.last,
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        statusHistory: history,
        title: 'side',
      );
    }

    final generator = any.combine2(
      any.list(any.intInRange(0, 30)),
      any.list(any.intInRange(0, 30)),
      (List<int> a, List<int> b) => (side(a), side(b)),
    );

    Glados(generator, ExploreConfig(numRuns: 200)).test(
      'holds every status of both sides once, in the order they were set',
      (sides) {
        final (a, b) = sides;
        final joined = a.withHistoryOf(b).statusHistory;
        final ids = joined.map((s) => s.id).toList();

        expect(ids.toSet(), {
          ...a.statusHistory.map((s) => s.id),
          ...b.statusHistory.map((s) => s.id),
        });
        expect(ids.length, ids.toSet().length);
        final times = joined.map((s) => s.createdAt).toList();
        expect(times, [...times]..sort());
      },
      tags: 'glados',
    );

    Glados(generator, ExploreConfig(numRuns: 200)).test(
      'is commutative in the history and idempotent',
      (sides) {
        final (a, b) = sides;
        final ab = a.withHistoryOf(b);

        expect(ab.statusHistory, b.withHistoryOf(a).statusHistory);
        expect(ab.withHistoryOf(b), same(ab));
        expect(ab.withHistoryOf(a), same(ab));
        expect(ab.withHistoryOf(ab), same(ab));
      },
      tags: 'glados',
    );
  });

  group('taskStatusFromString / toDbString round-trip (glados)', () {
    final knownInputs = [
      'DONE',
      'GROOMED',
      'IN PROGRESS',
      'BLOCKED',
      'ON HOLD',
      'REJECTED',
      'OPEN',
    ];

    Glados(any.choose(knownInputs), ExploreConfig(numRuns: 50)).test(
      'toDbString is the canonical form for known statuses',
      (input) {
        final status = taskStatusFromString(input);
        // The DB string must equal the input for the canonical set.
        expect(status.toDbString, equals(input));
      },
      tags: 'glados',
    );
  });
}
