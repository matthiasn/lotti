import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_diff.dart';

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
  Set<String> advertisedUnclocked = const {},
  Map<String, int> advertisedMedia = const {},
  Map<String, int> localMedia = const {},
}) => diffDeepBackfillBatch(
  advertised: advertised,
  advertisedConflicts: advertisedConflicts,
  local: local,
  localConflicts: localConflicts,
  outstanding: outstanding,
  advertisedUnclocked: advertisedUnclocked,
  advertisedMedia: advertisedMedia,
  localMedia: localMedia,
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

  group(
    'diffDeepBackfillBatch — rows the advertiser holds without a clock',
    () {
      test('a record both hold is neither pushed back nor requested — every '
          'round used to push it again', () {
        final diff = _diff(
          local: {'clocked': _older, 'clockless': null},
          advertisedUnclocked: {'clocked', 'clockless'},
        );

        expect(diff.pushes, isEmpty);
        expect(diff.advertiserLacks, isEmpty);
        expect(diff.requests, isEmpty);
      });

      test(
        'a record this device lacks is asked for as any row, with media',
        () {
          final diff = _diff(advertisedUnclocked: {'x'});

          expect(diff.requests, {
            'x': [unclockedVersion],
          });
          expect(diff.absentLocally, {'x'});
        },
      );

      test('is not asked for again while outstanding', () {
        final diff = _diff(
          advertisedUnclocked: {'x'},
          outstanding: {'x'},
        );

        expect(diff.requests, isEmpty);
      });

      test('a record the range covers but the advertiser holds nowhere is '
          'still pushed', () {
        final diff = _diff(
          local: {'mine': _older},
          advertisedUnclocked: {'other'},
        );

        expect(diff.pushes, {'mine'});
        expect(diff.advertiserLacks, {'mine'});
        expect(diff.requests.keys, ['other']);
      });
    },
  );

  group('diffDeepBackfillBatch — files behind media records', () {
    test('requests a missing or truncated file at equal clocks, asking for '
        'no version', () {
      final diff = _diff(
        advertised: {'missing': _newer, 'short': _newer, 'whole': _newer},
        local: {'missing': _newer, 'short': _newer, 'whole': _newer},
        advertisedMedia: {'missing': 10, 'short': 10, 'whole': 10},
        localMedia: {'missing': 0, 'short': 4, 'whole': 10},
      );

      expect(diff.requests, {'missing': isEmpty, 'short': isEmpty});
      expect(diff.mediaRequests, {'missing': 10, 'short': 10});
      expect(diff.absentLocally, isEmpty);
      expect(diff.pushes, isEmpty);
    });

    test('pushes a larger file back, at equal clocks', () {
      final diff = _diff(
        advertised: {'x': _newer},
        local: {'x': _newer},
        advertisedMedia: {'x': 3},
        localMedia: {'x': 10},
      );

      expect(diff.pushes, {'x'});
      expect(diff.mediaPushes, {'x'});
      expect(diff.advertiserLacks, isEmpty);
      expect(diff.requests, isEmpty);
    });

    test('asks for the file in the same request as a newer version', () {
      final diff = _diff(
        advertised: {'x': _newer},
        local: {'x': _older},
        advertisedMedia: {'x': 10},
        localMedia: {'x': 0},
      );

      expect(diff.requests, {
        'x': [_newer],
      });
      expect(diff.mediaRequests, {'x': 10});
    });

    test('pushes a newer version with its file when the file is larger', () {
      final diff = _diff(
        advertised: {'x': _older},
        local: {'x': _newer},
        advertisedMedia: {'x': 0},
        localMedia: {'x': 10},
      );

      expect(diff.pushes, {'x'});
      expect(diff.mediaPushes, {'x'});
    });

    test('compares nothing for a peer that lists no sizes, a record deleted '
        'here, or one held nowhere here', () {
      final diff = _diff(
        advertised: {'old-peer': _newer, 'deleted': _newer, 'absent': _newer},
        local: {'old-peer': _newer, 'deleted': _newer},
        advertisedMedia: {'deleted': 10, 'absent': 10},
        localMedia: {'old-peer': 0},
      );

      expect(diff.mediaRequests, isEmpty);
      expect(diff.mediaPushes, isEmpty);
      // The absent record travels with its media through `absentLocally`.
      expect(diff.requests.keys, ['absent']);
      expect(diff.absentLocally, {'absent'});
    });

    test('does not ask for a file already requested, but still pushes', () {
      final diff = _diff(
        advertised: {'short': _newer, 'long': _newer},
        local: {'short': _newer, 'long': _newer},
        advertisedMedia: {'short': 10, 'long': 1},
        localMedia: {'short': 2, 'long': 5},
        outstanding: {'short', 'long'},
      );

      expect(diff.requests, isEmpty);
      expect(diff.mediaRequests, isEmpty);
      expect(diff.mediaPushes, {'long'});
    });
  });

  group('deepBackfillRequestSettled', () {
    test('a request for a file waits for a local copy at least as large as '
        'the one asked for', () {
      bool settled(int? localMediaSize) => deepBackfillRequestSettled(
        asked: const [],
        holdsRow: true,
        local: _newer,
        openConflicts: const [],
        askedMediaSize: 10,
        localMediaSize: localMediaSize,
      );

      expect(settled(4), isFalse);
      expect(settled(10), isTrue);
      expect(settled(12), isTrue);
      // No live media row here any more: a deletion makes no claim.
      expect(settled(null), isTrue);
    });

    test('a request for a version and its file needs both', () {
      expect(
        deepBackfillRequestSettled(
          asked: const [_newer],
          holdsRow: true,
          local: _older,
          openConflicts: const [],
          askedMediaSize: 10,
          localMediaSize: 10,
        ),
        isFalse,
      );
    });

    test('is settled once the row covers every version asked for', () {
      expect(
        deepBackfillRequestSettled(
          asked: const [_older],
          holdsRow: true,
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
          holdsRow: true,
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
          holdsRow: true,
          local: _older,
          openConflicts: const [],
        ),
        isFalse,
      );
      expect(
        deepBackfillRequestSettled(
          asked: const [_newer],
          holdsRow: false,
          local: null,
          openConflicts: const [],
        ),
        isFalse,
      );
    });

    test('a request for a clockless row is settled by holding any row', () {
      expect(
        deepBackfillRequestSettled(
          asked: const [unclockedVersion],
          holdsRow: true,
          local: null,
          openConflicts: const [],
        ),
        isTrue,
      );
      expect(
        deepBackfillRequestSettled(
          asked: const [unclockedVersion],
          holdsRow: false,
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
          holdsRow: true,
          local: _newer,
          openConflicts: const [],
        ),
        isFalse,
      );
    });
  });

  group('properties', () {
    glados.Glados(
      glados.any.mediaScenario,
      glados.ExploreConfig(numRuns: 400),
    ).test('a smaller copy is requested and a larger one pushed, never '
        'both, and a request is settled exactly by a copy as large as the '
        "advertiser's", (scenario) {
      final (theirs, mine, outstanding) = scenario;
      final diff = _diff(
        advertised: {'x': _newer},
        local: {'x': _newer},
        advertisedMedia: {'x': ?theirs},
        localMedia: {'x': ?mine},
        outstanding: {if (outstanding) 'x'},
      );

      final compared = theirs != null && mine != null;
      expect(
        diff.mediaRequests.containsKey('x'),
        compared && mine < theirs && !outstanding,
      );
      expect(diff.mediaPushes.contains('x'), compared && mine > theirs);
      expect(diff.pushes.contains('x'), diff.mediaPushes.contains('x'));
      if (diff.mediaRequests['x'] case final asked?) {
        expect(asked, theirs);
        for (var received = 0; received <= 3; received++) {
          expect(
            deepBackfillRequestSettled(
              asked: diff.requests['x']!,
              holdsRow: true,
              local: _newer,
              openConflicts: const [],
              askedMediaSize: asked,
              localMediaSize: received,
            ),
            received >= asked,
          );
        }
      }
    }, tags: 'glados');

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
          holdsRow: scenario.holdsRow,
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
  /// A file size 0–3, or -1 for none listed.
  glados.Generator<int?> get mediaSize =>
      glados.IntAnys(this).intInRange(-1, 4).map((s) => s < 0 ? null : s);

  /// The advertiser's size, this device's, and whether a request is out.
  glados.Generator<(int?, int?, bool)> get mediaScenario =>
      glados.CombinableAny(this).combine3(
        mediaSize,
        mediaSize,
        glados.BoolAny(this).bool,
        (theirs, mine, outstanding) => (theirs, mine, outstanding),
      );

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
