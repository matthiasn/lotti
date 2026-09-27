import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/deep_backfill/deep_backfill_diff.dart';
import 'package:lotti/features/sync/vector_clock.dart';

const _older = VectorClock({'a': 1});
const _newer = VectorClock({'a': 2});
const _mineConcurrent = VectorClock({'a': 1, 'b': 1});
const _theirsConcurrent = VectorClock({'a': 2});
const _malformed = VectorClock({'a': -1});

DeepBackfillDiff _diff({
  Map<String, VectorClock> advertised = const {},
  Map<String, List<VectorClock>> advertisedConflicts = const {},
  Map<String, VectorClock?> local = const {},
  Map<String, List<VectorClock>> localConflicts = const {},
  Set<String> outstanding = const {},
}) => diffDeepBackfillBatch(
  advertised: advertised,
  advertisedConflicts: advertisedConflicts,
  local: local,
  localConflicts: localConflicts,
  outstanding: outstanding,
);

void main() {
  group('diffDeepBackfillBatch — the advertised row', () {
    test('requests a record this device has no row for, with media', () {
      final diff = _diff(advertised: {'x': _newer});

      expect(diff.requests, {
        'x': [_newer],
      });
      expect(diff.absentLocally, {'x'});
      expect(diff.pushes, isEmpty);
    });

    test('requests a newer version, without media', () {
      final diff = _diff(advertised: {'x': _newer}, local: {'x': _older});

      expect(diff.requests, {
        'x': [_newer],
      });
      expect(diff.absentLocally, isEmpty);
      expect(diff.pushes, isEmpty);
    });

    test('pushes an older advertised version back, without media', () {
      final diff = _diff(advertised: {'x': _older}, local: {'x': _newer});

      expect(diff.requests, isEmpty);
      expect(diff.pushes, {'x'});
      expect(diff.advertiserLacks, isEmpty);
    });

    test('does nothing for an equal version', () {
      final diff = _diff(advertised: {'x': _newer}, local: {'x': _newer});

      expect(diff.requests, isEmpty);
      expect(diff.pushes, isEmpty);
    });

    test('requests and pushes a concurrent version', () {
      final diff = _diff(
        advertised: {'x': _theirsConcurrent},
        local: {'x': _mineConcurrent},
      );

      expect(diff.requests, {
        'x': [_theirsConcurrent],
      });
      expect(diff.pushes, {'x'});
    });

    test('skips a concurrent version either side already holds as a '
        'conflict, so the pair does not travel every round', () {
      final diff = _diff(
        advertised: {'x': _theirsConcurrent},
        advertisedConflicts: {
          'x': [_mineConcurrent],
        },
        local: {'x': _mineConcurrent},
        localConflicts: {
          'x': [_theirsConcurrent],
        },
      );

      expect(diff.requests, isEmpty);
      expect(diff.pushes, isEmpty);
    });

    test('requests over a row written before clocks, and never pushes it', () {
      final diff = _diff(advertised: {'x': _older}, local: {'x': null});

      expect(diff.requests, {
        'x': [_older],
      });
      expect(diff.pushes, isEmpty);
    });

    test('pushes, with media, a record the range covers but the advertiser '
        'did not list', () {
      final diff = _diff(local: {'x': _older, 'y': null});

      expect(diff.pushes, {'x', 'y'});
      expect(diff.advertiserLacks, {'x', 'y'});
      expect(diff.requests, isEmpty);
    });

    test('does not request what is outstanding, but still pushes', () {
      final diff = _diff(
        advertised: {'x': _theirsConcurrent, 'y': _newer},
        local: {'x': _mineConcurrent},
        outstanding: {'x', 'y'},
      );

      expect(diff.requests, isEmpty);
      expect(diff.absentLocally, isEmpty);
      expect(diff.pushes, {'x'});
    });

    test('reports a record whose clocks cannot be compared and leaves it '
        'alone', () {
      final diff = _diff(
        advertised: {'x': _malformed, 'y': _newer},
        local: {'x': _older, 'y': _older},
      );

      expect(diff.incomparable, {'x'});
      expect(diff.requests.keys, ['y']);
      expect(diff.pushes, isEmpty);
    });
  });

  group('diffDeepBackfillBatch — conflict versions travel like rows', () {
    test('requests an advertised conflict version this device does not '
        'keep, even when the rows are equal', () {
      final diff = _diff(
        advertised: {'x': _theirsConcurrent},
        advertisedConflicts: {
          'x': [_mineConcurrent],
        },
        local: {'x': _theirsConcurrent},
      );

      expect(diff.requests, {
        'x': [_mineConcurrent],
      });
      expect(diff.pushes, isEmpty);
    });

    test('asks for the row and a conflict in one request', () {
      final diff = _diff(
        advertised: {'x': _theirsConcurrent},
        advertisedConflicts: {
          'x': [_mineConcurrent],
        },
      );

      expect(diff.requests, {
        'x': [_theirsConcurrent, _mineConcurrent],
      });
      expect(diff.absentLocally, {'x'});
    });

    test('does not request a conflict version the row already covers', () {
      final diff = _diff(
        advertised: {'x': _newer},
        advertisedConflicts: {
          'x': [_older],
        },
        local: {'x': _newer},
      );

      expect(diff.requests, isEmpty);
    });

    test('pushes a local conflict version the advertiser does not keep', () {
      final diff = _diff(
        advertised: {'x': _theirsConcurrent},
        local: {'x': _theirsConcurrent},
        localConflicts: {
          'x': [_mineConcurrent],
        },
      );

      expect(diff.pushes, {'x'});
      expect(diff.requests, isEmpty);
    });
  });

  group('deepBackfillRequestSettled', () {
    test('is settled once the row covers every version asked for', () {
      expect(
        deepBackfillRequestSettled(
          asked: const [_older],
          local: _newer,
          openConflicts: const [],
        ),
        isTrue,
      );
    });

    test('is settled when an open conflict keeps the version', () {
      expect(
        deepBackfillRequestSettled(
          asked: const [_theirsConcurrent, _mineConcurrent],
          local: _theirsConcurrent,
          openConflicts: const [_mineConcurrent],
        ),
        isTrue,
      );
    });

    test('stays open while any asked version is not kept — another '
        "advertiser's older answer does not settle it", () {
      expect(
        deepBackfillRequestSettled(
          asked: const [_newer],
          local: _older,
          openConflicts: const [],
        ),
        isFalse,
      );
      expect(
        deepBackfillRequestSettled(
          asked: const [_newer],
          local: null,
          openConflicts: const [],
        ),
        isFalse,
      );
    });

    test('stays open for a malformed clock', () {
      expect(
        deepBackfillRequestSettled(
          asked: const [_malformed],
          local: _newer,
          openConflicts: const [],
        ),
        isFalse,
      );
    });
  });

  group('properties', () {
    glados.Glados(
      glados.any.recordScenario,
      glados.ExploreConfig(numRuns: 400),
    ).test('requests exactly the advertised versions this device does not '
        'keep, and never outstanding ones', (scenario) {
      final diff = scenario.diff();
      final asked = diff.requests['x'] ?? const <VectorClock>[];

      for (final version in asked) {
        expect(scenario.keptHere(version), isFalse, reason: '$scenario');
      }
      if (scenario.outstanding) {
        expect(diff.requests, isEmpty, reason: '$scenario');
        return;
      }
      final theirs = scenario.theirs;
      if (theirs != null && !scenario.keptHere(theirs)) {
        final ownConflictHoldsIt =
            scenario.mine != null &&
            VectorClock.compare(scenario.mine!, theirs) ==
                VclockStatus.concurrent &&
            scenario.myConflicts.any((c) => vectorClockCovers(theirs, c));
        if (!ownConflictHoldsIt) {
          expect(asked, contains(theirs), reason: '$scenario');
        }
      }
      for (final conflict in scenario.theirConflicts) {
        expect(
          asked.contains(conflict),
          !scenario.keptHere(conflict),
          reason: '$scenario',
        );
      }
    }, tags: 'glados');

    glados.Glados(
      glados.any.recordScenario,
      glados.ExploreConfig(numRuns: 400),
    ).test("pushes exactly when the advertiser does not keep this device's "
        'row or one of its conflicts', (scenario) {
      final diff = scenario.diff();
      final mine = scenario.mine;
      final owesRow =
          scenario.holdsRow &&
          (scenario.theirs == null ||
              mine != null && !scenario.keptThere(mine));
      final owesConflict = scenario.myConflicts.any(
        (c) => !scenario.keptThere(c),
      );

      expect(
        diff.pushes.contains('x'),
        owesRow || owesConflict,
        reason: '$scenario',
      );
      expect(
        diff.advertiserLacks.contains('x'),
        scenario.holdsRow && scenario.theirs == null,
        reason: '$scenario',
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.recordScenario,
      glados.ExploreConfig(numRuns: 400),
    ).test('a request the diff sends is not settled by the state that sent '
        'it', (scenario) {
      final asked = scenario.diff().requests['x'];
      if (asked == null) return;

      expect(
        deepBackfillRequestSettled(
          asked: asked,
          local: scenario.mine,
          openConflicts: scenario.myConflicts,
        ),
        isFalse,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });
}

/// One record as two devices hold it: each side's row (none, or a clock over
/// two hosts) and open conflict versions, and whether a request for it is
/// already outstanding.
class _RecordScenario {
  const _RecordScenario({
    required this.theirs,
    required this.theirConflicts,
    required this.holdsRow,
    required this.mine,
    required this.myConflicts,
    required this.outstanding,
  });

  final VectorClock? theirs;
  final List<VectorClock> theirConflicts;
  final bool holdsRow;
  final VectorClock? mine;
  final List<VectorClock> myConflicts;
  final bool outstanding;

  DeepBackfillDiff diff() => diffDeepBackfillBatch(
    advertised: {'x': ?theirs},
    advertisedConflicts: {if (theirConflicts.isNotEmpty) 'x': theirConflicts},
    local: {if (holdsRow) 'x': mine},
    localConflicts: {if (myConflicts.isNotEmpty) 'x': myConflicts},
    outstanding: {if (outstanding) 'x'},
  );

  bool _keeps(VectorClock? row, List<VectorClock> conflicts, VectorClock v) =>
      (row != null && vectorClockCovers(v, row)) ||
      conflicts.any((c) => vectorClockCovers(v, c));

  bool keptHere(VectorClock v) => _keeps(mine, myConflicts, v);
  bool keptThere(VectorClock v) => _keeps(theirs, theirConflicts, v);

  @override
  String toString() =>
      '_RecordScenario(theirs: ${theirs?.vclock}, '
      'theirConflicts: ${theirConflicts.map((c) => c.vclock).toList()}, '
      'holdsRow: $holdsRow, mine: ${mine?.vclock}, '
      'myConflicts: ${myConflicts.map((c) => c.vclock).toList()}, '
      'outstanding: $outstanding)';
}

/// The conflicts a device can hold over [row]: the write decision applies a
/// newer version as the row, so an open conflict is always concurrent with
/// it, and a device without a clocked row holds none.
List<VectorClock> _openConflictsOf(
  VectorClock? row,
  List<VectorClock> clocks,
) => row == null
    ? const []
    : clocks
          .where((c) => VectorClock.compare(row, c) == VclockStatus.concurrent)
          .toList();

extension _AnyRecordScenario on glados.Any {
  /// A clock over hosts a and b, each counter 0–2; `[-1, _]` is no clock.
  glados.Generator<VectorClock?> get twoHostClock => glados.ListAnys(this)
      .listWithLength(2, glados.IntAnys(this).intInRange(-1, 3))
      .map(
        (counters) => counters.first < 0
            ? null
            : VectorClock({
                'a': counters.first,
                'b': counters.last.clamp(0, 2),
              }),
      );

  glados.Generator<List<VectorClock>> get conflictClocks =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 3, twoHostClock)
          .map((clocks) => [...clocks.nonNulls]);

  glados.Generator<_RecordScenario> get recordScenario =>
      glados.CombinableAny(this).combine6(
        twoHostClock,
        conflictClocks,
        glados.BoolAny(this).bool,
        twoHostClock,
        conflictClocks,
        glados.BoolAny(this).bool,
        (theirs, theirConflicts, holdsRow, mine, myConflicts, outstanding) =>
            _RecordScenario(
              theirs: theirs,
              theirConflicts: _openConflictsOf(theirs, theirConflicts),
              holdsRow: holdsRow,
              mine: holdsRow ? mine : null,
              myConflicts: holdsRow
                  ? _openConflictsOf(mine, myConflicts)
                  : const [],
              outstanding: outstanding,
            ),
      );
}
