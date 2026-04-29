import 'package:flutter_test/flutter_test.dart';
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
}
