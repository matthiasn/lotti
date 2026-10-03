import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/shutdown_facts.dart';

const _work = DayAgentCategory(id: 'work', name: 'Work', colorHex: '3366CC');
const _home = DayAgentCategory(id: 'home', name: 'Home', colorHex: '33CC66');

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 10, 3, hour, minute);

TimeBlock _block(
  String id,
  DateTime start,
  int minutes, {
  String? taskId,
  String title = 'Work',
  DayAgentCategory category = _work,
  TimeBlockType type = TimeBlockType.manual,
}) => TimeBlock(
  id: 'actual:$id',
  title: title,
  start: start,
  end: start.add(Duration(minutes: minutes)),
  type: type,
  state: TimeBlockState.completed,
  category: category,
  taskId: taskId,
);

const ShutdownTask _invoices = (
  taskId: 'invoices',
  title: 'Invoices',
  category: _work,
);

void main() {
  group('completedItems', () {
    test('groups by task, counts overlaps once and sorts longest first', () {
      final items = completedItems(
        blocks: [
          _block('a', _at(9), 30, taskId: 'deck', title: 'Deck'),
          // Overlaps the first by 10 minutes: 50 minutes of union, not 60.
          _block('b', _at(9, 20), 30, taskId: 'deck', title: 'Deck'),
          _block('c', _at(14), 60, taskId: 'invoices', title: 'Invoices'),
        ],
        doneToday: const [],
      );

      expect(
        items.map((i) => (i.taskId, i.durationMinutes, i.sessionCount)),
        [('invoices', 60, 1), ('deck', 50, 2)],
      );
    });

    test('untasked recordings group by title within their category', () {
      final items = completedItems(
        blocks: [
          _block('a', _at(7), 30, title: 'Run', category: _home),
          _block('b', _at(18), 20, title: 'Run', category: _home),
          _block('c', _at(12), 10, title: 'Run'),
        ],
        doneToday: const [],
      );

      expect(
        items.map((i) => (i.title, i.category.id, i.durationMinutes)),
        [('Run', 'home', 50), ('Run', 'work', 10)],
      );
    });

    test('marks done tasks and lists done tasks without recorded time', () {
      final items = completedItems(
        blocks: [_block('a', _at(9), 45, taskId: 'invoices')],
        doneToday: [
          _invoices,
          (taskId: 'call', title: 'Call the bank', category: _home),
        ],
      );

      expect(items.first.doneToday, isTrue);
      expect(
        items.last,
        isA<CompletedItem>()
            .having((i) => i.title, 'title', 'Call the bank')
            .having((i) => i.durationMinutes, 'minutes', 0)
            .having((i) => i.sessionCount, 'sessions', 0)
            .having((i) => i.doneToday, 'done', true),
      );
    });
  });

  test('carryoverItems sums each task’s minutes and suggests the next day', () {
    final items = carryoverItems(
      openTasks: const [
        _invoices,
        (taskId: 'docs', title: 'Docs', category: _work),
      ],
      blocks: [
        _block('a', _at(9), 25, taskId: 'invoices'),
        _block('b', _at(11), 15, taskId: 'invoices'),
        _block('c', _at(13), 60, taskId: 'other'),
      ],
      forDate: DateTime(2026, 10, 31),
    );

    expect(items.map((i) => (i.taskId, i.loggedMinutes)), [
      ('invoices', 40),
      ('docs', 0),
    ]);
    // Month boundary: the next day is November 1st.
    expect(items.first.suggestedDate, DateTime(2026, 11));
  });

  group('contextSwitches', () {
    test('counts changes of what was worked on, not pauses', () {
      expect(
        contextSwitches([
          _block('a', _at(9), 30, taskId: 'deck'),
          // A 5-minute pause continues the same run.
          _block('b', _at(9, 35), 30, taskId: 'deck'),
          _block('c', _at(10, 10), 20, taskId: 'mail'),
          _block('d', _at(11), 20, taskId: 'deck'),
        ]),
        2,
      );
    });

    test('returning to the same thing after a long gap is not a switch', () {
      expect(
        contextSwitches([
          _block('a', _at(9), 30, taskId: 'deck'),
          _block('b', _at(13), 30, taskId: 'deck'),
        ]),
        0,
      );
    });

    test('calendar events are not work and do not split runs', () {
      expect(
        contextSwitches([
          _block('a', _at(9), 30, taskId: 'deck'),
          _block(
            'e',
            _at(9, 30),
            30,
            title: 'Standup',
            type: TimeBlockType.cal,
          ),
          _block('b', _at(10), 30, taskId: 'deck'),
        ]),
        0,
      );
    });
  });

  group('shutdownMetrics', () {
    test('focus is recorded work only; a long run is a flow session', () {
      final metrics = shutdownMetrics(
        blocks: [
          _block('a', _at(9), 30, taskId: 'deck'),
          _block('b', _at(9, 34), 20, taskId: 'deck'),
          _block('c', _at(11), 44, taskId: 'mail'),
          _block('e', _at(13), 60, title: 'Offsite', type: TimeBlockType.cal),
        ],
        energy: const [],
        priorDays: const [],
        priorEnergy: const [],
      );

      expect(metrics.focusMinutes, 94);
      // deck: 9:00–9:54 is one run of 50 minutes of recordings → flow;
      // mail is 44 minutes → not.
      expect(metrics.flowSessions, 1);
      expect(metrics.contextSwitches, 1);
      expect(metrics.contextSwitchesWeekAvg, isNull);
      expect(metrics.energyScore, isNull);
      expect(metrics.energyDeltaVsWeek, isNull);
    });

    test('week average skips days without recorded work', () {
      final metrics = shutdownMetrics(
        blocks: const [],
        energy: const [],
        priorDays: [
          [
            _block('a', _at(9), 10, taskId: 'x'),
            _block('b', _at(10), 10, taskId: 'y'),
            _block('c', _at(11), 10, taskId: 'x'),
          ],
          const [],
          [_block('e', _at(9), 60, title: 'Event', type: TimeBlockType.cal)],
          [_block('d', _at(9), 10, taskId: 'x')],
        ],
        priorEnergy: const [],
      );

      // (2 + 0) / 2 days with work; the empty and events-only days are out.
      expect(metrics.contextSwitchesWeekAvg, 1);
    });

    test('energy is the mean rating on a 0–10 scale, compared to the week', () {
      final metrics = shutdownMetrics(
        blocks: const [],
        energy: const [0.8, 0.6],
        priorDays: const [],
        priorEnergy: const [0.5, 0.5, 0.8],
      );

      expect(metrics.energyScore, closeTo(7, 1e-9));
      expect(metrics.energyDeltaVsWeek, closeTo(1, 1e-9));
    });

    test('energy without prior ratings has no delta', () {
      final metrics = shutdownMetrics(
        blocks: const [],
        energy: const [0.4],
        priorDays: const [],
        priorEnergy: const [],
      );

      expect(metrics.energyScore, closeTo(4, 1e-9));
      expect(metrics.energyDeltaVsWeek, isNull);
    });
  });

  group('properties', () {
    glados.Glados(
      glados.any.listWithLengthInRange(0, 12, glados.any.intInRange(0, 4)),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'recordings 5 minutes apart: runs follow the task sequence exactly',
      (keys) {
        // 15-minute recordings every 20 minutes: each gap is exactly
        // workRunMaxGap, so consecutive recordings of one task form a run.
        final blocks = [
          for (var i = 0; i < keys.length; i++)
            _block(
              'b$i',
              _at(8).add(Duration(minutes: 20 * i)),
              15,
              taskId: 't${keys[i]}',
            ),
        ];
        final runLengths = <int>[];
        for (var i = 0; i < keys.length; i++) {
          if (i > 0 && keys[i] == keys[i - 1]) {
            runLengths[runLengths.length - 1]++;
          } else {
            runLengths.add(1);
          }
        }
        final metrics = shutdownMetrics(
          blocks: blocks,
          energy: const [],
          priorDays: const [],
          priorEnergy: const [],
        );

        expect(metrics.focusMinutes, 15 * keys.length);
        expect(
          metrics.contextSwitches,
          runLengths.isEmpty ? 0 : runLengths.length - 1,
        );
        // A run of n recordings covers 15n minutes of work.
        expect(
          metrics.flowSessions,
          runLengths.where((n) => 15 * n >= 45).length,
        );
      },
      tags: 'glados',
    );
  });
}
