import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/recent_searches/domain/recent_search.dart';

extension _AnyRecentSearch on glados.Any {
  /// Queries a user can really type: quotes, backslashes, emoji and
  /// non-Latin text are what a hand-rolled codec gets wrong.
  glados.Generator<RecentSearch> get recentSearch => combine2(
    glados.AnyUtils(this).choose(RecentSearchSurface.values),
    glados.AnyUtils(this).choose(const [
      'penguin',
      'Penguin habitat',
      r'back\slash',
      '"quoted"',
      '{"s":"tasks"}',
      'Füße & Öl',
      '企鹅 🐧',
      'a,b;c',
    ]),
    (surface, query) => RecentSearch(surface: surface, query: query),
  );

  glados.Generator<List<RecentSearch>> get recentSearches =>
      glados.ListAnys(this).listWithLengthInRange(0, 16, recentSearch);
}

void main() {
  group('RecentSearchSurface', () {
    test('every wire name resolves back to its own surface', () {
      for (final surface in RecentSearchSurface.values) {
        expect(RecentSearchSurface.fromWireName(surface.wireName), surface);
      }
    });

    test('wire names are distinct, so no two surfaces share stored rows', () {
      final names = RecentSearchSurface.values.map((s) => s.wireName).toSet();

      expect(names, hasLength(RecentSearchSurface.values.length));
    });

    test('an unknown wire name resolves to null', () {
      expect(RecentSearchSurface.fromWireName('plaza'), isNull);
    });
  });

  group('RecentSearch', () {
    const penguin = RecentSearch(
      surface: RecentSearchSurface.tasks,
      query: 'penguin',
    );

    test('matches ignores case but not the surface', () {
      expect(
        penguin.matches(
          const RecentSearch(
            surface: RecentSearchSurface.tasks,
            query: 'PENGUIN',
          ),
        ),
        isTrue,
      );
      expect(
        penguin.matches(
          const RecentSearch(
            surface: RecentSearchSurface.habits,
            query: 'penguin',
          ),
        ),
        isFalse,
      );
      expect(
        penguin.matches(
          const RecentSearch(
            surface: RecentSearchSurface.tasks,
            query: 'penguins',
          ),
        ),
        isFalse,
      );
    });

    test('equality is exact, casing included', () {
      const sameAgain = RecentSearch(
        surface: RecentSearchSurface.tasks,
        query: 'penguin',
      );
      const otherCasing = RecentSearch(
        surface: RecentSearchSurface.tasks,
        query: 'Penguin',
      );

      expect(penguin, sameAgain);
      expect(penguin.hashCode, sameAgain.hashCode);
      expect(penguin, isNot(otherCasing));
      expect(penguin, isNot(equals('penguin')));
    });

    test('toString names the surface and the query', () {
      expect(penguin.toString(), 'RecentSearch(tasks: "penguin")');
    });
  });

  group('encodeRecentSearches', () {
    test('writes the versioned snapshot, newest first', () {
      final raw = encodeRecentSearches(const [
        RecentSearch(surface: RecentSearchSurface.habits, query: 'run'),
        RecentSearch(surface: RecentSearchSurface.tasks, query: 'fish'),
      ]);

      expect(jsonDecode(raw), {
        'v': 1,
        'items': [
          {'s': 'habits', 'q': 'run'},
          {'s': 'tasks', 'q': 'fish'},
        ],
      });
    });
  });

  group('decodeRecentSearches', () {
    test('a missing or empty row is nothing remembered', () {
      expect(decodeRecentSearches(null), isEmpty);
      expect(decodeRecentSearches(''), isEmpty);
    });

    // Each of these is a row the decoder must survive without throwing:
    // bootstrap reads it, and a bad row must cost the history, not the app.
    const unreadable = <String, String>{
      'not JSON at all': '{oops',
      'JSON that is not an object': '[1,2,3]',
      'an unknown snapshot version': '{"v":2,"items":[]}',
      'a missing version': '{"items":[]}',
      'items that are not a list': '{"v":1,"items":"tasks"}',
      'missing items': '{"v":1}',
    };
    for (final MapEntry(key: description, value: raw) in unreadable.entries) {
      test('$description decodes to an empty list', () {
        expect(decodeRecentSearches(raw), isEmpty);
      });
    }

    test('skips malformed items and keeps the readable ones in order', () {
      final raw = jsonEncode({
        'v': 1,
        'items': [
          {'s': 'tasks', 'q': 'fish'},
          'not an object',
          {'s': 'plaza', 'q': 'from a newer build'},
          {'s': 'habits', 'q': 42},
          {'s': 7, 'q': 'surface is not a string'},
          {'s': 'projects', 'q': ''},
          {'s': 'projects', 'q': 'waddle'},
        ],
      });

      expect(decodeRecentSearches(raw), const [
        RecentSearch(surface: RecentSearchSurface.tasks, query: 'fish'),
        RecentSearch(surface: RecentSearchSurface.projects, query: 'waddle'),
      ]);
    });

    glados.Glados(
      glados.any.recentSearches,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'round-trips whatever encodeRecentSearches wrote',
      (searches) {
        expect(
          decodeRecentSearches(encodeRecentSearches(searches)),
          searches,
          reason: '$searches',
        );
      },
      tags: 'glados',
    );
  });
}
