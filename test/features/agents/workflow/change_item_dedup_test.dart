import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_item_dedup.dart';

import '../test_data/change_set_factories.dart';

ChangeItem _item(
  String toolName, {
  Map<String, dynamic> args = const {},
  String summary = 'summary',
  ChangeItemStatus status = ChangeItemStatus.pending,
}) => ChangeItem(
  toolName: toolName,
  args: args,
  humanSummary: summary,
  status: status,
);

ChangeItem _runningTimer({
  String? timerId,
  String summary = 'Running timer text',
  ChangeItemStatus status = ChangeItemStatus.pending,
}) => ChangeItem(
  toolName: TaskAgentToolNames.updateRunningTimer,
  args: {'timerId': ?timerId},
  humanSummary: summary,
  status: status,
);

void main() {
  group('deduplicateItems', () {
    test('returns proposed unchanged when no existing or rejections', () {
      final proposed = [
        _item('set_task_title', args: const {'title': 'A'}),
        _item('set_task_title', args: const {'title': 'B'}),
      ];

      final result = deduplicateItems(proposed, const []);

      // Same instance is returned (fast path) and contents are untouched.
      expect(result, same(proposed));
      expect(result.map((i) => i.args['title']), ['A', 'B']);
    });

    test('drops items whose fingerprint already exists', () {
      final existing = [
        _item('set_task_title', args: const {'title': 'A'}, summary: 'A'),
      ];
      final proposed = [
        // Identical fingerprint to existing (humanSummary is ignored).
        _item('set_task_title', args: const {'title': 'A'}, summary: 'other'),
        _item('set_task_title', args: const {'title': 'B'}, summary: 'B'),
      ];

      final result = deduplicateItems(proposed, existing);

      expect(result, hasLength(1));
      expect(result.single.args['title'], 'B');
    });

    test('keeps distinct items', () {
      final existing = [
        _item('set_task_title', args: const {'title': 'A'}, summary: 'A'),
      ];
      final proposed = [
        _item('set_task_title', args: const {'title': 'B'}, summary: 'B'),
        _item(
          'update_task_estimate',
          args: const {'minutes': 30},
          summary: 'est',
        ),
      ];

      final result = deduplicateItems(proposed, existing);

      expect(result, hasLength(2));
      expect(result[0].args['title'], 'B');
      expect(result[1].args['minutes'], 30);
    });

    test('preserves proposed order for kept items', () {
      final existing = [
        _item('set_task_title', args: const {'title': 'B'}, summary: 'B'),
      ];
      final proposed = [
        _item('set_task_title', args: const {'title': 'A'}, summary: 'A'),
        // Filtered out (duplicate of existing).
        _item('set_task_title', args: const {'title': 'B'}, summary: 'B'),
        _item('set_task_title', args: const {'title': 'C'}, summary: 'C'),
      ];

      final result = deduplicateItems(proposed, existing);

      expect(result.map((i) => i.args['title']), ['A', 'C']);
    });

    test('blocks items matching rejectedFingerprints', () {
      final proposed = [
        _item('set_task_title', args: const {'title': 'A'}),
        _item('set_task_title', args: const {'title': 'B'}),
      ];
      final rejected = ChangeItem.fingerprintFromParts(
        'set_task_title',
        const {'title': 'A'},
      );

      final result = deduplicateItems(
        proposed,
        const [],
        rejectedFingerprints: {rejected},
      );

      expect(result, hasLength(1));
      expect(result.single.args['title'], 'B');
    });

    test('blocks items matching rejectedDisplayKeys', () {
      final blocked = _item(
        'check_off_item',
        args: const {'itemId': 'x'},
        summary: 'Check off: "Buy milk"',
      );
      final allowed = _item(
        'check_off_item',
        args: const {'itemId': 'y'},
        summary: 'Check off: "Walk dog"',
      );
      final rejectedKey = ChangeItem.displayDuplicateKey(blocked);
      expect(rejectedKey, isNotNull);

      final result = deduplicateItems(
        [blocked, allowed],
        const [],
        rejectedDisplayKeys: {rejectedKey!},
      );

      expect(result, hasLength(1));
      expect(result.single.args['itemId'], 'y');
    });

    test('drops items whose display key matches an existing item', () {
      // Same rendered summary, but different args (so fingerprints differ).
      final existing = [
        _item(
          'check_off_item',
          args: const {'itemId': 'x'},
          summary: 'Check off: "Buy milk"',
        ),
      ];
      final proposed = [
        _item(
          'check_off_item',
          args: const {'itemId': 'y'},
          summary: 'Check off: "Buy milk"',
        ),
      ];

      // Fingerprints differ but the display keys collide.
      expect(
        ChangeItem.fingerprint(existing.single),
        isNot(ChangeItem.fingerprint(proposed.single)),
      );
      expect(
        ChangeItem.displayDuplicateKey(existing.single),
        ChangeItem.displayDuplicateKey(proposed.single),
      );

      final result = deduplicateItems(proposed, existing);

      expect(result, isEmpty);
    });
  });

  group('runningTimerIdFromArgs', () {
    test('returns trimmed id for a valid string', () {
      expect(
        runningTimerIdFromArgs(const {'timerId': '  timer-1  '}),
        'timer-1',
      );
    });

    test('returns null when key is missing', () {
      expect(runningTimerIdFromArgs(const {'summary': 'x'}), isNull);
    });

    test('returns null when value is not a string', () {
      expect(runningTimerIdFromArgs(const {'timerId': 42}), isNull);
    });

    test('returns null for an empty or whitespace-only string', () {
      expect(runningTimerIdFromArgs(const {'timerId': ''}), isNull);
      expect(runningTimerIdFromArgs(const {'timerId': '   '}), isNull);
    });
  });

  group('runningTimerId / isRunningTimerUpdate', () {
    test('isRunningTimerUpdate only matches the running-timer tool', () {
      expect(isRunningTimerUpdate(_runningTimer(timerId: 't1')), isTrue);
      expect(isRunningTimerUpdate(_item('set_task_title')), isFalse);
    });

    test('runningTimerId reads the trimmed timer id from item args', () {
      expect(runningTimerId(_runningTimer(timerId: '  t1 ')), 't1');
      expect(runningTimerId(_runningTimer()), isNull);
    });

    test('isRunningTimerUpdateForTimer matches tool and timer id', () {
      final item = _runningTimer(timerId: 't1');
      expect(isRunningTimerUpdateForTimer(item, 't1'), isTrue);
      expect(isRunningTimerUpdateForTimer(item, 't2'), isFalse);
      // Non running-timer items never match, even for the same id.
      expect(
        isRunningTimerUpdateForTimer(
          _item('set_task_title', args: const {'timerId': 't1'}),
          't1',
        ),
        isFalse,
      );
    });
  });

  group('runningTimerIds', () {
    test('collects distinct timer ids, including a single null', () {
      final items = [
        _runningTimer(timerId: 't1'),
        _runningTimer(timerId: 't1'),
        _runningTimer(timerId: 't2'),
        _runningTimer(),
        _runningTimer(),
        // Ignored: not a running-timer update.
        _item('set_task_title', args: const {'timerId': 't3'}),
      ];

      expect(runningTimerIds(items), {'t1', 't2', null});
    });

    test('is empty when no running-timer updates present', () {
      expect(runningTimerIds([_item('set_task_title')]), isEmpty);
    });
  });

  group('locatePendingRunningTimerUpdates', () {
    test('finds only pending running-timer items for the given ids', () {
      final setA = makeTestChangeSet(
        id: 'set-a',
        items: [
          _runningTimer(timerId: 't1'),
          _item('set_task_title', args: const {'title': 'X'}),
          _runningTimer(timerId: 't2', status: ChangeItemStatus.confirmed),
        ],
      );
      final setB = makeTestChangeSet(
        id: 'set-b',
        items: [
          _runningTimer(timerId: 't2'),
          _runningTimer(timerId: 't3'),
        ],
      );

      final matches = locatePendingRunningTimerUpdates(
        [setA, setB],
        {'t1', 't2'},
      );

      // t1 in set-a (index 0), t2 in set-b (index 0). The confirmed t2 in
      // set-a and the not-requested t3 in set-b are excluded.
      expect(matches, hasLength(2));
      expect(matches[0].changeSet.id, 'set-a');
      expect(matches[0].itemIndex, 0);
      expect(runningTimerId(matches[0].item), 't1');
      expect(matches[1].changeSet.id, 'set-b');
      expect(matches[1].itemIndex, 0);
      expect(runningTimerId(matches[1].item), 't2');
    });

    test('returns empty when no timer ids requested', () {
      final set = makeTestChangeSet(items: [_runningTimer(timerId: 't1')]);
      expect(locatePendingRunningTimerUpdates([set], const {}), isEmpty);
    });
  });

  group('markItemsRetracted', () {
    test('retracts only matched indexes and leaves other sets untouched', () {
      final target = makeTestChangeSet(
        id: 'target',
        items: [
          _runningTimer(timerId: 't1'),
          _item('set_task_title', args: const {'title': 'X'}),
          _runningTimer(timerId: 't2'),
        ],
      );
      final untouched = makeTestChangeSet(
        id: 'untouched',
        items: [_runningTimer(timerId: 't9')],
      );

      final matches = locatePendingRunningTimerUpdates(
        [target, untouched],
        {'t1'},
      );
      expect(matches, hasLength(1));

      final result = markItemsRetracted([target, untouched], matches);

      final updatedTarget = result.firstWhere((s) => s.id == 'target');
      expect(updatedTarget.items[0].status, ChangeItemStatus.retracted);
      // Non-matched items keep their original status.
      expect(updatedTarget.items[1].status, ChangeItemStatus.pending);
      expect(updatedTarget.items[2].status, ChangeItemStatus.pending);

      // A set with no matches is returned as the same instance.
      expect(result.firstWhere((s) => s.id == 'untouched'), same(untouched));
    });

    test('returns sets unchanged when matches are empty', () {
      final set = makeTestChangeSet(items: [_runningTimer(timerId: 't1')]);
      final result = markItemsRetracted([set], const []);
      expect(result.single, same(set));
    });
  });

  group('property: deduplicateItems invariants', () {
    glados.Glados(
      glados.any.dedupScenario,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'output never grows and every kept fingerprint is unique vs existing',
      (scenario) {
        final existing = scenario.existing;
        final proposed = scenario.proposed;

        final result = deduplicateItems(proposed, existing);

        // Output length is bounded by the input.
        expect(
          result.length,
          lessThanOrEqualTo(proposed.length),
          reason: '$scenario',
        );

        final existingFingerprints = existing
            .map(ChangeItem.fingerprint)
            .toSet();
        for (final item in result) {
          // No kept item collides with an existing fingerprint.
          expect(
            existingFingerprints.contains(ChangeItem.fingerprint(item)),
            isFalse,
            reason: '$scenario',
          );
          // Every kept item came from the proposed list (no fabrication).
          expect(proposed, contains(item), reason: '$scenario');
        }

        // Kept items preserve their relative order from proposed.
        var lastIndex = -1;
        for (final item in result) {
          final idx = proposed.indexOf(item, lastIndex + 1);
          expect(idx, greaterThan(lastIndex), reason: '$scenario');
          lastIndex = idx;
        }
      },
      tags: 'glados',
    );
  });
}

class _DedupScenario {
  const _DedupScenario({required this.existing, required this.proposed});

  final List<ChangeItem> existing;
  final List<ChangeItem> proposed;

  @override
  String toString() =>
      '_DedupScenario(existing: ${existing.map((i) => i.args).toList()}, '
      'proposed: ${proposed.map((i) => i.args).toList()})';
}

extension _AnyDedupScenario on glados.Any {
  glados.Generator<ChangeItem> get dedupItem =>
      glados.CombinableAny(this).combine2(
        glados.AnyUtils(this).choose(const ['set_task_title', 'set_task_note']),
        glados.IntAnys(this).intInRange(0, 4),
        (String toolName, int titleSeed) => _item(
          toolName,
          args: {'title': 'T$titleSeed'},
          summary: 'Summary $titleSeed',
        ),
      );

  glados.Generator<_DedupScenario> get dedupScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 4, dedupItem),
        glados.ListAnys(this).listWithLengthInRange(0, 6, dedupItem),
        (List<ChangeItem> existing, List<ChangeItem> proposed) =>
            _DedupScenario(existing: existing, proposed: proposed),
      );
}
