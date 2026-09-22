import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/domain/recent_search_list.dart';

RecentSearch _tasks(String query) =>
    RecentSearch(surface: RecentSearchSurface.tasks, query: query);

RecentSearch _habits(String query) =>
    RecentSearch(surface: RecentSearchSurface.habits, query: query);

/// One generated recording: a surface and a raw query drawn from a small
/// vocabulary, so repeats, casing variants, prefixes and unrecordable input
/// all collide often instead of once in a thousand runs.
class _GeneratedRecording {
  const _GeneratedRecording(this.surface, this.rawQuery);

  final RecentSearchSurface surface;
  final String rawQuery;

  @override
  String toString() => '_GeneratedRecording(${surface.wireName}, "$rawQuery")';
}

const _vocabulary = <String>[
  '',
  '  ',
  'f',
  'pe',
  'pen',
  'penguin',
  'Penguin',
  '  penguin   habitat ',
  'penguin habitat',
  'fish',
  'FISH',
  'fish feeder',
  'sardine futures',
  'ice pad',
];

extension _AnyRecording on glados.Any {
  glados.Generator<_GeneratedRecording> get recording => combine2(
    glados.AnyUtils(this).choose(RecentSearchSurface.values),
    glados.AnyUtils(this).choose(_vocabulary),
    _GeneratedRecording.new,
  );

  glados.Generator<List<_GeneratedRecording>> get recordings =>
      glados.ListAnys(this).listWithLengthInRange(0, 40, recording);
}

void main() {
  group('normalizeRecentSearchQuery', () {
    test('trims and collapses inner whitespace but keeps the casing', () {
      expect(
        normalizeRecentSearchQuery('  Penguin \t  habitat\n'),
        'Penguin habitat',
      );
    });
  });

  group('isRecordableRecentSearchQuery', () {
    test('rejects blanks and a single character, accepts two', () {
      expect(isRecordableRecentSearchQuery(''), isFalse);
      expect(isRecordableRecentSearchQuery('   '), isFalse);
      expect(isRecordableRecentSearchQuery(' p '), isFalse);
      expect(isRecordableRecentSearchQuery(' pe '), isTrue);
    });
  });

  group('recordRecentSearch', () {
    test('puts a new search at the top, normalized', () {
      final result = recordRecentSearch(
        [_tasks('fish')],
        RecentSearchSurface.habits,
        '  morning   run ',
      );

      expect(result, [_habits('morning run'), _tasks('fish')]);
    });

    test('hands back the identical list for an unrecordable query', () {
      final current = [_tasks('fish')];

      expect(
        identical(
          recordRecentSearch(current, RecentSearchSurface.tasks, ' p '),
          current,
        ),
        isTrue,
      );
    });

    test('moves a repeat to the top and adopts the newer casing', () {
      final result = recordRecentSearch(
        [_tasks('fish'), _habits('run'), _tasks('penguin')],
        RecentSearchSurface.tasks,
        'Penguin',
      );

      expect(result, [_tasks('Penguin'), _tasks('fish'), _habits('run')]);
    });

    test('keeps the same words apart when the surface differs', () {
      final result = recordRecentSearch(
        [_tasks('penguin')],
        RecentSearchSurface.habits,
        'penguin',
      );

      expect(result, [_habits('penguin'), _tasks('penguin')]);
    });

    test("replaces the surface's newest entry when the query continues it", () {
      final result = recordRecentSearch(
        [_habits('run'), _tasks('Pen'), _tasks('fish')],
        RecentSearchSurface.tasks,
        'penguin',
      );

      expect(result, [_tasks('penguin'), _habits('run'), _tasks('fish')]);
    });

    test('leaves an older, shorter search on the surface alone', () {
      // "pen" is not the surface's newest entry — "fish" is — so it was a
      // search of its own rather than the beginning of this one.
      final result = recordRecentSearch(
        [_tasks('fish'), _tasks('pen')],
        RecentSearchSurface.tasks,
        'penguin',
      );

      expect(result, [_tasks('penguin'), _tasks('fish'), _tasks('pen')]);
    });

    test('a repeat still counts as the newest entry on its surface', () {
      // The repeat of "penguin" is the surface's newest entry, so the
      // continuation rule must not slide down onto "pen" behind it.
      final result = recordRecentSearch(
        [_tasks('penguin'), _tasks('pen')],
        RecentSearchSurface.tasks,
        'penguin',
      );

      expect(result, [_tasks('penguin'), _tasks('pen')]);
    });

    test('does not treat a shortened query as a continuation', () {
      final result = recordRecentSearch(
        [_tasks('penguin')],
        RecentSearchSurface.tasks,
        'pen',
      );

      expect(result, [_tasks('pen'), _tasks('penguin')]);
    });

    test('drops the oldest entry once the cap is reached', () {
      final full = [
        for (var i = 0; i < maxRecentSearches; i++) _tasks('query $i'),
      ];

      final result = recordRecentSearch(
        full,
        RecentSearchSurface.habits,
        'run',
      );

      expect(result, hasLength(maxRecentSearches));
      expect(result.first, _habits('run'));
      expect(result.last, _tasks('query ${maxRecentSearches - 2}'));
    });

    test('returns a list that cannot be mutated behind the state', () {
      final result = recordRecentSearch(
        const [],
        RecentSearchSurface.tasks,
        'fish',
      );

      expect(() => result.add(_tasks('x')), throwsUnsupportedError);
    });

    glados.Glados(
      glados.any.recordings,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'any sequence of recordings keeps the list well-formed',
      (recordings) {
        var list = const <RecentSearch>[];
        for (final recording in recordings) {
          final before = list;
          list = recordRecentSearch(
            before,
            recording.surface,
            recording.rawQuery,
          );
          final reason = '$recording after $before';

          if (!isRecordableRecentSearchQuery(recording.rawQuery)) {
            expect(identical(list, before), isTrue, reason: reason);
            continue;
          }

          expect(
            list.first,
            RecentSearch(
              surface: recording.surface,
              query: normalizeRecentSearchQuery(recording.rawQuery),
            ),
            reason: reason,
          );
          expect(
            list.length,
            lessThanOrEqualTo(maxRecentSearches),
            reason: reason,
          );
          for (var i = 0; i < list.length; i++) {
            expect(
              list[i].query,
              normalizeRecentSearchQuery(list[i].query),
              reason: reason,
            );
            for (var j = i + 1; j < list.length; j++) {
              expect(list[i].matches(list[j]), isFalse, reason: reason);
            }
          }
          // Recording on one surface never removes or reorders another
          // surface's history; only the cap can trim its tail.
          final othersBefore = before
              .where((entry) => entry.surface != recording.surface)
              .toList();
          final othersAfter = list
              .where((entry) => entry.surface != recording.surface)
              .toList();
          expect(
            othersBefore.take(othersAfter.length).toList(),
            othersAfter,
            reason: reason,
          );
          // Recording the same search again changes nothing further.
          expect(
            recordRecentSearch(list, recording.surface, recording.rawQuery),
            list,
            reason: reason,
          );
        }
      },
      tags: 'glados',
    );
  });

  group('recentSearchesOn', () {
    test('keeps only the given surfaces, in order', () {
      final searches = [_tasks('fish'), _habits('run'), _tasks('penguin')];

      expect(
        recentSearchesOn(searches, {RecentSearchSurface.tasks}),
        [_tasks('fish'), _tasks('penguin')],
      );
      expect(recentSearchesOn(searches, const {}), isEmpty);
    });
  });
}
