import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';

/// Builds a deterministic title/subtitle map from a list of
/// `(flagName, title, subtitle)` triples and returns the matching
/// resolver. Lets every test phrase its scenario inline without
/// pulling `AppLocalizations` or `BuildContext` into the picture.
FlagLabelResolver _resolverFrom(
  List<({String name, String title, String subtitle})> labels,
) {
  final byName = {for (final l in labels) l.name: l};
  return (flag) {
    final entry = byName[flag.name];
    if (entry == null) {
      return (title: flag.name, subtitle: flag.description);
    }
    return (title: entry.title, subtitle: entry.subtitle);
  };
}

ConfigFlag _flag(String name) =>
    ConfigFlag(name: name, description: '$name desc', status: false);

void main() {
  group('filterDisplayedFlags — query normalization', () {
    final flags = [_flag('alpha'), _flag('beta')];
    final resolver = _resolverFrom([
      (name: 'alpha', title: 'Alpha', subtitle: 'first letter'),
      (name: 'beta', title: 'Beta', subtitle: 'second letter'),
    ]);

    test('empty query returns the input list unchanged (and in order)', () {
      expect(
        filterDisplayedFlags(query: '', flags: flags, resolver: resolver),
        equals(flags),
      );
    });

    test('whitespace-only query is treated as empty (returns all flags)', () {
      expect(
        filterDisplayedFlags(
          query: '   \t\n',
          flags: flags,
          resolver: resolver,
        ),
        equals(flags),
      );
    });

    test('leading/trailing whitespace is trimmed before matching', () {
      // Without trimming, "  alpha  " would never match the resolver
      // value "Alpha" (no surrounding whitespace). The trim step is
      // what lets it land.
      final result = filterDisplayedFlags(
        query: '  alpha  ',
        flags: flags,
        resolver: resolver,
      );
      expect(result, [flags.first]);
    });
  });

  group('filterDisplayedFlags — case-insensitive matching', () {
    final flags = [_flag('alpha')];
    final resolver = _resolverFrom([
      (name: 'alpha', title: 'Alpha Title', subtitle: 'Some Subtitle'),
    ]);

    test('matches when query letters differ in case from the title', () {
      final result = filterDisplayedFlags(
        query: 'ALPHA',
        flags: flags,
        resolver: resolver,
      );
      expect(result, [flags.first]);
    });

    test('matches when the title differs in case from the query', () {
      final result = filterDisplayedFlags(
        query: 'alpha',
        flags: flags,
        resolver: resolver,
      );
      expect(result, [flags.first]);
    });
  });

  group('filterDisplayedFlags — substring matching', () {
    test('matches when the query is a substring of the title', () {
      final flags = [_flag('alpha')];
      final resolver = _resolverFrom([
        (name: 'alpha', title: 'AlphaCentauri', subtitle: ''),
      ]);
      final result = filterDisplayedFlags(
        query: 'centauri',
        flags: flags,
        resolver: resolver,
      );
      expect(result, [flags.first]);
    });

    test(
      'matches when the query only appears in the subtitle, not the title',
      () {
        final flags = [_flag('alpha')];
        final resolver = _resolverFrom([
          (name: 'alpha', title: 'Lock', subtitle: 'Hide private entries'),
        ]);
        final result = filterDisplayedFlags(
          query: 'private',
          flags: flags,
          resolver: resolver,
        );
        expect(result, [flags.first]);
      },
    );

    test('drops a flag when neither title nor subtitle contains the query', () {
      final flags = [_flag('alpha')];
      final resolver = _resolverFrom([
        (name: 'alpha', title: 'Lock', subtitle: 'Hide private entries'),
      ]);
      final result = filterDisplayedFlags(
        query: 'matrix',
        flags: flags,
        resolver: resolver,
      );
      expect(result, isEmpty);
    });
  });

  group('filterDisplayedFlags — multiple flags', () {
    final flags = [
      _flag('alpha'),
      _flag('beta'),
      _flag('gamma'),
    ];
    final resolver = _resolverFrom([
      (name: 'alpha', title: 'Lock', subtitle: 'Make entries private'),
      (name: 'beta', title: 'Notifications', subtitle: 'Push alerts'),
      (name: 'gamma', title: 'Logging', subtitle: 'Verbose log output'),
    ]);

    test('returns only flags whose title or subtitle matches the query', () {
      final result = filterDisplayedFlags(
        query: 'log',
        flags: flags,
        resolver: resolver,
      );
      expect(result.map((f) => f.name).toList(), ['gamma']);
    });

    test('preserves the input order across matches', () {
      // 'e' appears in "Entries" (alpha subtitle), "Notifications" /
      // "alerts" (beta), and "Verbose" (gamma) — so all three match.
      // The result must come back in the original order, not sorted.
      final result = filterDisplayedFlags(
        query: 'e',
        flags: flags,
        resolver: resolver,
      );
      expect(result.map((f) => f.name).toList(), ['alpha', 'beta', 'gamma']);
    });

    test('returns an empty list when nothing matches', () {
      final result = filterDisplayedFlags(
        query: 'no-such-thing',
        flags: flags,
        resolver: resolver,
      );
      expect(result, isEmpty);
    });
  });

  group('FlagsBody.displayedItems — registered flag set', () {
    test('includes the AI summary TTS flag', () {
      expect(FlagsBody.displayedItems, contains('enable_ai_summary_tts'));
    });

    test('includes the new enable_whats_new flag', () {
      // Locks the wiring contract — the canonical render order must
      // carry `enable_whats_new` so the in-page list and the search
      // filter both see it.
      expect(FlagsBody.displayedItems, contains('enable_whats_new'));
    });

    test('every entry is a non-empty unique string', () {
      // Authoring guard: a duplicate id would silently render the same
      // flag twice (the lookup map keeps the last entry but the
      // ordered list still iterates twice).
      expect(
        FlagsBody.displayedItems.toSet().length,
        FlagsBody.displayedItems.length,
      );
      for (final id in FlagsBody.displayedItems) {
        expect(id, isNotEmpty);
      }
    });
  });

  // Additive Glados property groups — appended, no existing tests modified.
  _runFilterDisplayedFlagsGladosTests();
}

// ---------------------------------------------------------------------------
// Generators and Glados property tests for filterDisplayedFlags.
// ---------------------------------------------------------------------------

/// A fixed pool of [ConfigFlag] values used by the generators.
final List<ConfigFlag> _flagPool = List<ConfigFlag>.unmodifiable([
  const ConfigFlag(name: 'alpha', description: 'Alpha subtitle', status: false),
  const ConfigFlag(name: 'beta', description: 'Beta subtitle', status: true),
  const ConfigFlag(name: 'gamma', description: 'Gamma subtitle', status: false),
  const ConfigFlag(name: 'delta', description: 'Delta subtitle', status: false),
  const ConfigFlag(
    name: 'epsilon',
    description: 'Epsilon subtitle',
    status: false,
  ),
]);

/// A resolver that uses each flag's `name` as its title and `description`
/// as its subtitle — deterministic, no localisation needed.
({String title, String subtitle}) _identityResolver(ConfigFlag flag) =>
    (title: flag.name, subtitle: flag.description);

extension _AnyFlagFilterInput on glados.Any {
  /// Produces a non-empty sub-list of [_flagPool].  Using `choose` on a
  /// list of pre-built lists keeps the generator simple and deterministic.
  glados.Generator<List<ConfigFlag>> get flagSublist =>
      glados.AnyUtils(this).choose(<List<ConfigFlag>>[
        [_flagPool[0]],
        [_flagPool[0], _flagPool[1]],
        [_flagPool[1], _flagPool[2]],
        [_flagPool[0], _flagPool[1], _flagPool[2]],
        [_flagPool[0], _flagPool[2], _flagPool[4]],
        List<ConfigFlag>.from(_flagPool),
        [_flagPool[3], _flagPool[4]],
      ]);

  /// Generates query strings: empty, whitespace, partial matches, and
  /// values that definitely do not appear in any flag name/description.
  glados.Generator<String> get filterQuery =>
      glados.AnyUtils(this).choose(<String>[
        '',
        '   ',
        'alpha',
        'BETA',
        'subtitle',
        'zzz_no_match',
        'a',
        'ALPHA',
        'gamma',
        'delta subtitle',
      ]);
}

/// Returns true if [sub] is a subsequence of [full] (order-preserving).
bool _isSubsequence(List<ConfigFlag> sub, List<ConfigFlag> full) {
  var subIdx = 0;
  for (final item in full) {
    if (subIdx < sub.length && sub[subIdx] == item) {
      subIdx++;
    }
  }
  return subIdx == sub.length;
}

void _runFilterDisplayedFlagsGladosTests() {
  group('filterDisplayedFlags — Glados properties', () {
    glados.Glados2<List<ConfigFlag>, String>(
      glados.any.flagSublist,
      glados.any.filterQuery,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result is always a subsequence of the input (order-preserving subset)',
      (flags, query) {
        final result = filterDisplayedFlags(
          query: query,
          flags: flags,
          resolver: _identityResolver,
        );
        expect(
          _isSubsequence(result, flags),
          isTrue,
          reason: 'query="$query" result=$result input=$flags',
        );
      },
      tags: 'glados',
    );

    glados.Glados2<List<ConfigFlag>, String>(
      glados.any.flagSublist,
      glados.any.filterQuery,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'applying the filter twice with the same query is idempotent',
      (flags, query) {
        final once = filterDisplayedFlags(
          query: query,
          flags: flags,
          resolver: _identityResolver,
        );
        final twice = filterDisplayedFlags(
          query: query,
          flags: once,
          resolver: _identityResolver,
        );
        expect(
          twice,
          equals(once),
          reason: 'query="$query"',
        );
      },
      tags: 'glados',
    );

    glados.Glados<List<ConfigFlag>>(
      glados.any.flagSublist,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'empty or whitespace-only query returns the full input list unchanged',
      (flags) {
        for (final emptyQuery in <String>['', '   ', '\t\n']) {
          final result = filterDisplayedFlags(
            query: emptyQuery,
            flags: flags,
            resolver: _identityResolver,
          );
          expect(
            result,
            equals(flags),
            reason: 'query="$emptyQuery"',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados2<List<ConfigFlag>, String>(
      glados.any.flagSublist,
      glados.any.filterQuery,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result length is always ≤ input length',
      (flags, query) {
        final result = filterDisplayedFlags(
          query: query,
          flags: flags,
          resolver: _identityResolver,
        );
        expect(
          result.length,
          lessThanOrEqualTo(flags.length),
          reason: 'query="$query"',
        );
      },
      tags: 'glados',
    );
  });
}
