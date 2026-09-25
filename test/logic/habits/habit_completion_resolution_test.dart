import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/habits/habit_completion_resolution.dart';

const List<HabitCompletionType> _completionTypes = [
  HabitCompletionType.success,
  HabitCompletionType.skip,
  HabitCompletionType.fail,
];

HabitCompletionEntry _completion({
  required String id,
  required String habitId,
  required DateTime day,
  required DateTime writtenAt,
  required HabitCompletionType completionType,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? dateTo,
  HabitCompletionSource source = HabitCompletionSource.manual,
}) {
  final effectiveDateTo = dateTo ?? day;
  return HabitCompletionEntry(
    meta: Metadata(
      id: id,
      createdAt: createdAt ?? writtenAt,
      updatedAt: updatedAt ?? writtenAt,
      dateFrom: day,
      dateTo: effectiveDateTo,
      private: false,
    ),
    data: HabitCompletionData(
      dateFrom: day,
      dateTo: effectiveDateTo,
      habitId: habitId,
      completionType: completionType,
      source: source,
    ),
  );
}

class _GeneratedHabitCompletionScenario {
  const _GeneratedHabitCompletionScenario({
    required this.habitCountSeed,
    required this.dayCountSeed,
    required this.writeCountSeed,
    required this.habitSeed,
    required this.daySeed,
    required this.statusSeed,
    required this.orderSeed,
    required this.sourceSeed,
  });

  final int habitCountSeed;
  final int dayCountSeed;
  final int writeCountSeed;
  final int habitSeed;
  final int daySeed;
  final int statusSeed;
  final int orderSeed;
  final int sourceSeed;

  int get habitCount => (habitCountSeed % 4) + 1;
  int get dayCount => (dayCountSeed % 5) + 1;
  int get writeCount => (writeCountSeed % 24) + 1;

  List<HabitCompletionEntry> get chronologicalEntries {
    final baseDay = DateTime(2024, 3);
    final baseWrittenAt = DateTime(2024, 4, 1, 8);

    return List.generate(writeCount, (index) {
      final habitIndex = (habitSeed + index * 3) % habitCount;
      final dayIndex = (daySeed + index * 5) % dayCount;
      final statusIndex = (statusSeed + index * 7) % _completionTypes.length;
      final day = baseDay.add(Duration(days: dayIndex, hours: habitIndex));
      final writtenAt = baseWrittenAt.add(Duration(minutes: index));

      return _completion(
        id: 'completion-$index-h$habitIndex-d$dayIndex',
        habitId: 'habit-$habitIndex',
        day: day,
        writtenAt: writtenAt,
        completionType: _completionTypes[statusIndex],
        // Roughly a third of the writes are the engine's.
        source: (sourceSeed + index * 13) % 3 == 0
            ? HabitCompletionSource.auto
            : HabitCompletionSource.manual,
      );
    });
  }

  List<HabitCompletionEntry> get shuffledEntries {
    final entries = chronologicalEntries.toList();

    for (var i = 0; i < entries.length; i++) {
      final swapWith = (orderSeed + i * 11) % entries.length;
      final current = entries[i];
      entries[i] = entries[swapWith];
      entries[swapWith] = current;
    }

    return orderSeed.isEven ? entries : entries.reversed.toList();
  }

  /// Per habit/day: the person's latest entry, or the latest automatic one
  /// when the person recorded nothing.
  Map<String, HabitCompletionEntry> get expectedLatestByKey {
    final latestManual = <String, HabitCompletionEntry>{};
    final latestAny = <String, HabitCompletionEntry>{};

    for (final entry in chronologicalEntries) {
      final key = habitCompletionDayKey(entry);
      latestAny[key] = entry;
      if (entry.data.source == HabitCompletionSource.manual) {
        latestManual[key] = entry;
      }
    }

    return {...latestAny, ...latestManual};
  }

  @override
  String toString() {
    return '_GeneratedHabitCompletionScenario('
        'habitCountSeed: $habitCountSeed, '
        'dayCountSeed: $dayCountSeed, '
        'writeCountSeed: $writeCountSeed, '
        'habitSeed: $habitSeed, '
        'daySeed: $daySeed, '
        'statusSeed: $statusSeed, '
        'orderSeed: $orderSeed, '
        'sourceSeed: $sourceSeed)';
  }
}

extension _AnyGeneratedHabitCompletionScenario on glados.Any {
  glados.Generator<_GeneratedHabitCompletionScenario>
  get habitCompletionScenario => glados.CombinableAny(this).combine8(
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      int habitCountSeed,
      int dayCountSeed,
      int writeCountSeed,
      int habitSeed,
      int daySeed,
      int statusSeed,
      int orderSeed,
      int sourceSeed,
    ) => _GeneratedHabitCompletionScenario(
      habitCountSeed: habitCountSeed,
      dayCountSeed: dayCountSeed,
      writeCountSeed: writeCountSeed,
      habitSeed: habitSeed,
      daySeed: daySeed,
      statusSeed: statusSeed,
      orderSeed: orderSeed,
      sourceSeed: sourceSeed,
    ),
  );
}

void main() {
  group('latestHabitCompletionsByDay', () {
    test('keeps the newest write for the same habit and day', () {
      final day = DateTime(2024, 3, 15, 21);
      final older = _completion(
        id: 'older-success',
        habitId: 'habit-1',
        day: day,
        writtenAt: DateTime(2024, 3, 15, 22),
        completionType: HabitCompletionType.success,
      );
      final newer = _completion(
        id: 'newer-fail',
        habitId: 'habit-1',
        day: day,
        writtenAt: DateTime(2024, 3, 15, 23),
        completionType: HabitCompletionType.fail,
      );

      final result = latestHabitCompletionsByDay([newer, older]);

      expect(result, hasLength(1));
      expect(result.single.meta.id, 'newer-fail');
      expect(result.single.data.completionType, HabitCompletionType.fail);
    });

    test('keeps separate habits and days independent', () {
      final firstDay = DateTime(2024, 3, 15, 21);
      final secondDay = DateTime(2024, 3, 16, 21);

      final result = latestHabitCompletionsByDay([
        _completion(
          id: 'habit-1-day-1-older',
          habitId: 'habit-1',
          day: firstDay,
          writtenAt: DateTime(2024, 3, 15, 22),
          completionType: HabitCompletionType.success,
        ),
        _completion(
          id: 'habit-1-day-1-newer',
          habitId: 'habit-1',
          day: firstDay,
          writtenAt: DateTime(2024, 3, 15, 23),
          completionType: HabitCompletionType.skip,
        ),
        _completion(
          id: 'habit-1-day-2',
          habitId: 'habit-1',
          day: secondDay,
          writtenAt: DateTime(2024, 3, 16, 22),
          completionType: HabitCompletionType.fail,
        ),
        _completion(
          id: 'habit-2-day-1',
          habitId: 'habit-2',
          day: firstDay,
          writtenAt: DateTime(2024, 3, 15, 22),
          completionType: HabitCompletionType.success,
        ),
      ]);

      expect(result.map((entry) => entry.meta.id), [
        'habit-1-day-1-newer',
        'habit-2-day-1',
        'habit-1-day-2',
      ]);
    });

    test('uses the id tie-breaker when write timestamps match', () {
      final day = DateTime(2024, 3, 15, 21);
      final writtenAt = DateTime(2024, 3, 15, 22);
      final lowerId = _completion(
        id: 'same-time-a',
        habitId: 'habit-1',
        day: day,
        writtenAt: writtenAt,
        completionType: HabitCompletionType.success,
      );
      final higherId = _completion(
        id: 'same-time-b',
        habitId: 'habit-1',
        day: day,
        writtenAt: writtenAt,
        completionType: HabitCompletionType.fail,
      );

      final result = latestHabitCompletionsByDay([higherId, lowerId]);

      expect(result, hasLength(1));
      expect(result.single.meta.id, 'same-time-b');
      expect(result.single.data.completionType, HabitCompletionType.fail);
    });

    test('uses createdAt when updatedAt timestamps match', () {
      final day = DateTime(2024, 3, 15, 21);
      final updatedAt = DateTime(2024, 3, 15, 23);
      final olderCreatedAt = _completion(
        id: 'created-earlier',
        habitId: 'habit-1',
        day: day,
        writtenAt: updatedAt,
        updatedAt: updatedAt,
        createdAt: DateTime(2024, 3, 15, 21),
        completionType: HabitCompletionType.success,
      );
      final newerCreatedAt = _completion(
        id: 'created-later',
        habitId: 'habit-1',
        day: day,
        writtenAt: updatedAt,
        updatedAt: updatedAt,
        createdAt: DateTime(2024, 3, 15, 22),
        completionType: HabitCompletionType.fail,
      );

      final result = latestHabitCompletionsByDay([
        newerCreatedAt,
        olderCreatedAt,
      ]);

      expect(result.single.meta.id, 'created-later');
      expect(result.single.data.completionType, HabitCompletionType.fail);
    });

    test('uses dateTo when write timestamps match', () {
      final day = DateTime(2024, 3, 15, 21);
      final writtenAt = DateTime(2024, 3, 15, 23);
      final earlierDateTo = _completion(
        id: 'date-to-earlier',
        habitId: 'habit-1',
        day: day,
        writtenAt: writtenAt,
        dateTo: DateTime(2024, 3, 15, 21),
        completionType: HabitCompletionType.success,
      );
      final laterDateTo = _completion(
        id: 'date-to-later',
        habitId: 'habit-1',
        day: day,
        writtenAt: writtenAt,
        dateTo: DateTime(2024, 3, 15, 22),
        completionType: HabitCompletionType.skip,
      );

      final result = latestHabitCompletionsByDay([laterDateTo, earlierDateTo]);

      expect(result.single.meta.id, 'date-to-later');
      expect(result.single.data.completionType, HabitCompletionType.skip);
    });

    test('a skip recorded on one device outranks a later automatic success '
        'another device wrote before the skip synced', () {
      // The HabitDaySettlement.tla counterexample: the phone records a skip
      // at 08:00; the desktop, which has the imported steps but not yet the
      // skip, sees an empty day and auto-completes it at 09:00. Every replica
      // must settle the day on the person's skip, whatever arrives first.
      final day = DateTime(2024, 3, 1, 7);
      final skip = _completion(
        id: 'phone-skip',
        habitId: 'habit-1',
        day: day,
        writtenAt: DateTime(2024, 3, 1, 8),
        completionType: HabitCompletionType.skip,
      );
      final auto = _completion(
        id: 'desktop-auto',
        habitId: 'habit-1',
        day: day,
        writtenAt: DateTime(2024, 3, 1, 9),
        completionType: HabitCompletionType.success,
        source: HabitCompletionSource.auto,
      );

      for (final arrival in [
        [skip, auto],
        [auto, skip],
      ]) {
        final settled = latestHabitCompletionsByDay(arrival).single;
        expect(settled.meta.id, 'phone-skip');
        expect(settled.data.completionType, HabitCompletionType.skip);
      }
      // A later entry by the person still replaces an earlier one.
      final redo = _completion(
        id: 'phone-redo',
        habitId: 'habit-1',
        day: day,
        writtenAt: DateTime(2024, 3, 1, 10),
        completionType: HabitCompletionType.success,
      );
      expect(
        latestHabitCompletionsByDay([redo, auto, skip]).single.meta.id,
        'phone-redo',
      );
    });

    test('ignores non-habit journal entities', () {
      final writtenAt = DateTime(2024, 3, 15, 22);
      final nonHabit = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'journal-entry',
          createdAt: writtenAt,
          updatedAt: writtenAt,
          dateFrom: writtenAt,
          dateTo: writtenAt,
        ),
      );

      final result = latestHabitCompletionsByDay([
        nonHabit,
        _completion(
          id: 'habit-entry',
          habitId: 'habit-1',
          day: writtenAt,
          writtenAt: writtenAt,
          completionType: HabitCompletionType.success,
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.single.meta.id, 'habit-entry');
    });

    glados.Glados(
      glados.any.habitCompletionScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test("settles every generated habit/day on the person's latest entry, "
        'else the latest automatic one', (
      scenario,
    ) {
      final result = latestHabitCompletionsByDay(scenario.shuffledEntries);
      final actualByKey = {
        for (final entry in result) habitCompletionDayKey(entry): entry,
      };
      final expectedByKey = scenario.expectedLatestByKey;

      expect(
        actualByKey.keys,
        unorderedEquals(expectedByKey.keys),
        reason: '$scenario',
      );

      for (final key in expectedByKey.keys) {
        expect(
          actualByKey[key]?.meta.id,
          expectedByKey[key]?.meta.id,
          reason: '$scenario key=$key',
        );
        expect(
          actualByKey[key]?.data.completionType,
          expectedByKey[key]?.data.completionType,
          reason: '$scenario key=$key',
        );
      }
    }, tags: 'glados');

    glados.Glados(
      glados.any.habitCompletionScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('re-delivered writes converge on the same result', (scenario) {
      // Sync can hand a replica rows it already merged, in any order. The
      // collapse must be idempotent: folding its own output back together
      // with every row again changes nothing, which with order independence
      // makes every replica converge whatever arrives when.
      final once = latestHabitCompletionsByDay(scenario.shuffledEntries);
      final again = latestHabitCompletionsByDay([
        ...scenario.shuffledEntries.reversed,
        ...once,
        ...scenario.shuffledEntries,
      ]);
      expect(
        [for (final entry in again) entry.meta.id],
        [for (final entry in once) entry.meta.id],
        reason: '$scenario',
      );
    }, tags: 'glados');
  });

  // Additive Glados groups for compareHabitCompletionPrecedence — appended.
  _runCompareHabitCompletionGladosTests();
}

// ---------------------------------------------------------------------------
// Generators and Glados property tests for compareHabitCompletionPrecedence.
// Antisymmetry and transitivity are the algebraic invariants of a comparator.
// ---------------------------------------------------------------------------

/// Base date used to derive deterministic test timestamps.
final DateTime _baseDate = DateTime(2024);

/// Creates a [HabitCompletionEntry] whose metadata timestamps are derived from
/// integer offsets relative to [_baseDate].  Every parameter is an offset in
/// minutes from [_baseDate], which keeps the entries fully deterministic.
HabitCompletionEntry _entryFromOffsets({
  required String id,
  required int updatedAtMinutes,
  required int createdAtMinutes,
  required int dateToMinutes,
  required bool auto,
}) {
  final updatedAt = _baseDate.add(Duration(minutes: updatedAtMinutes));
  final createdAt = _baseDate.add(Duration(minutes: createdAtMinutes));
  final dateTo = _baseDate.add(Duration(minutes: dateToMinutes));
  return _completion(
    id: id,
    habitId: 'h1',
    day: _baseDate,
    writtenAt: updatedAt,
    updatedAt: updatedAt,
    createdAt: createdAt,
    dateTo: dateTo,
    completionType: HabitCompletionType.success,
    source: auto ? HabitCompletionSource.auto : HabitCompletionSource.manual,
  );
}

/// The sign of an integer: -1, 0, or 1.
int _sign(int x) {
  if (x < 0) return -1;
  if (x > 0) return 1;
  return 0;
}

class _GeneratedComparePair {
  const _GeneratedComparePair({
    required this.updatedA,
    required this.updatedB,
    required this.createdA,
    required this.createdB,
    required this.dateToA,
    required this.dateToB,
    required this.idA,
    required this.idB,
    required this.autoA,
    required this.autoB,
  });

  final int updatedA;
  final int updatedB;
  final int createdA;
  final int createdB;
  final int dateToA;
  final int dateToB;
  final String idA;
  final String idB;
  final bool autoA;
  final bool autoB;

  HabitCompletionEntry get a => _entryFromOffsets(
    id: idA,
    updatedAtMinutes: updatedA,
    createdAtMinutes: createdA,
    dateToMinutes: dateToA,
    auto: autoA,
  );

  HabitCompletionEntry get b => _entryFromOffsets(
    id: idB,
    updatedAtMinutes: updatedB,
    createdAtMinutes: createdB,
    dateToMinutes: dateToB,
    auto: autoB,
  );

  @override
  String toString() =>
      '_GeneratedComparePair('
      'updatedA=$updatedA, updatedB=$updatedB, '
      'createdA=$createdA, createdB=$createdB, '
      'dateToA=$dateToA, dateToB=$dateToB, '
      'idA=$idA, idB=$idB, autoA=$autoA, autoB=$autoB)';
}

class _GeneratedCompareTriple {
  const _GeneratedCompareTriple({
    required this.pairAb,
    required this.pairBc,
  });

  /// Provides entries `a` and `b`.
  final _GeneratedComparePair pairAb;

  /// Provides entries `b` and `c` — shares the `b` slot with [pairAb].
  final _GeneratedComparePair pairBc;

  HabitCompletionEntry get a => pairAb.a;
  HabitCompletionEntry get b => pairAb.b;
  HabitCompletionEntry get c => pairBc.b;
}

extension _AnyCompareHabitCompletion on glados.Any {
  /// Generates pairs of entries with independently varying tie-break fields.
  glados.Generator<_GeneratedComparePair> get comparePair =>
      glados.CombinableAny(this).combine10(
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 5),
        glados.AnyUtils(this).choose(<String>['id-a', 'id-b', 'id-c']),
        glados.AnyUtils(this).choose(<String>['id-b', 'id-c', 'id-d']),
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        (
          int uA,
          int uB,
          int cA,
          int cB,
          int dtA,
          int dtB,
          String idA,
          String idB,
          bool autoA,
          bool autoB,
        ) => _GeneratedComparePair(
          updatedA: uA,
          updatedB: uB,
          createdA: cA,
          createdB: cB,
          dateToA: dtA,
          dateToB: dtB,
          idA: idA,
          idB: idB,
          autoA: autoA,
          autoB: autoB,
        ),
      );

  glados.Generator<_GeneratedCompareTriple> get compareTriple =>
      glados.CombinableAny(this).combine2(
        comparePair,
        comparePair,
        (
          _GeneratedComparePair pAb,
          _GeneratedComparePair pBc,
        ) => _GeneratedCompareTriple(pairAb: pAb, pairBc: pBc),
      );
}

void _runCompareHabitCompletionGladosTests() {
  group('compareHabitCompletionPrecedence — Glados algebraic properties', () {
    glados.Glados<_GeneratedComparePair>(
      glados.any.comparePair,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'antisymmetry: sign(compare(a,b)) == -sign(compare(b,a))',
      (scenario) {
        final ab = compareHabitCompletionPrecedence(scenario.a, scenario.b);
        final ba = compareHabitCompletionPrecedence(scenario.b, scenario.a);
        expect(
          _sign(ab),
          equals(-_sign(ba)),
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados<_GeneratedComparePair>(
      glados.any.comparePair,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'compare(a, a) == 0 for the same entry',
      (scenario) {
        final aa = compareHabitCompletionPrecedence(scenario.a, scenario.a);
        expect(
          aa,
          equals(0),
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados<_GeneratedCompareTriple>(
      glados.any.compareTriple,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'transitivity: if a≤b and b≤c then a≤c',
      (scenario) {
        final ab = compareHabitCompletionPrecedence(scenario.a, scenario.b);
        final bc = compareHabitCompletionPrecedence(scenario.b, scenario.c);
        final ac = compareHabitCompletionPrecedence(scenario.a, scenario.c);

        // If a ≤ b (ab ≤ 0) AND b ≤ c (bc ≤ 0), then a ≤ c (ac ≤ 0).
        if (ab <= 0 && bc <= 0) {
          expect(
            ac,
            lessThanOrEqualTo(0),
            reason: 'transitivity failed: ab=$ab bc=$bc ac=$ac $scenario',
          );
        }
        // Conversely: if a ≥ b (ab ≥ 0) AND b ≥ c (bc ≥ 0), then a ≥ c.
        if (ab >= 0 && bc >= 0) {
          expect(
            ac,
            greaterThanOrEqualTo(0),
            reason: 'transitivity failed: ab=$ab bc=$bc ac=$ac $scenario',
          );
        }
      },
      tags: 'glados',
    );
  });
}
