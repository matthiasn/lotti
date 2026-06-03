import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/ui/widgets/conflicts/title_diff.dart';

// ---------------------------------------------------------------------------
// Glados generators (from computeTitleDiff property tests)
// ---------------------------------------------------------------------------

enum _GeneratedTitleTokenSlot { alpha, beta, gamma, one, two, repeated }

String _generatedTitleToken(_GeneratedTitleTokenSlot slot) {
  return switch (slot) {
    _GeneratedTitleTokenSlot.alpha => 'alpha',
    _GeneratedTitleTokenSlot.beta => 'beta',
    _GeneratedTitleTokenSlot.gamma => 'gamma',
    _GeneratedTitleTokenSlot.one => '1',
    _GeneratedTitleTokenSlot.two => '2',
    _GeneratedTitleTokenSlot.repeated => 'alpha',
  };
}

class _GeneratedTitleDiffScenario {
  const _GeneratedTitleDiffScenario({
    required this.localSlots,
    required this.remoteSlots,
    required this.localWhitespaceShape,
    required this.remoteWhitespaceShape,
  });

  final List<_GeneratedTitleTokenSlot> localSlots;
  final List<_GeneratedTitleTokenSlot> remoteSlots;
  final int localWhitespaceShape;
  final int remoteWhitespaceShape;

  List<String> get localTokens => localSlots.map(_generatedTitleToken).toList();

  List<String> get remoteTokens =>
      remoteSlots.map(_generatedTitleToken).toList();

  String get localTitle => _joinTitle(localTokens, localWhitespaceShape);

  String get remoteTitle => _joinTitle(remoteTokens, remoteWhitespaceShape);

  @override
  String toString() {
    return '_GeneratedTitleDiffScenario('
        'localTokens: $localTokens, remoteTokens: $remoteTokens, '
        'localWhitespaceShape: $localWhitespaceShape, '
        'remoteWhitespaceShape: $remoteWhitespaceShape)';
  }
}

extension _AnyGeneratedTitleDiff on glados.Any {
  glados.Generator<_GeneratedTitleTokenSlot> get titleTokenSlot =>
      glados.AnyUtils(this).choose(_GeneratedTitleTokenSlot.values);

  glados.Generator<List<_GeneratedTitleTokenSlot>> get titleTokenSlots =>
      glados.ListAnys(this).listWithLengthInRange(0, 9, titleTokenSlot);

  glados.Generator<_GeneratedTitleDiffScenario> get titleDiffScenario =>
      glados.CombinableAny(this).combine4(
        titleTokenSlots,
        titleTokenSlots,
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 4),
        (
          List<_GeneratedTitleTokenSlot> localSlots,
          List<_GeneratedTitleTokenSlot> remoteSlots,
          int localWhitespaceShape,
          int remoteWhitespaceShape,
        ) => _GeneratedTitleDiffScenario(
          localSlots: localSlots,
          remoteSlots: remoteSlots,
          localWhitespaceShape: localWhitespaceShape,
          remoteWhitespaceShape: remoteWhitespaceShape,
        ),
      );
}

String _joinTitle(List<String> tokens, int whitespaceShape) {
  if (tokens.isEmpty) {
    return switch (whitespaceShape % 3) {
      0 => '',
      1 => '   ',
      _ => '\n\t',
    };
  }

  final separator = switch (whitespaceShape % 4) {
    0 => ' ',
    1 => '   ',
    2 => '\n',
    _ => '\t ',
  };
  final joined = tokens.join(separator);
  return switch (whitespaceShape % 4) {
    0 => joined,
    1 => ' $joined ',
    2 => '\n$joined\n',
    _ => '\t$joined ',
  };
}

String _segmentsText(Iterable<TitleDiffSegment> segments) =>
    segments.map((segment) => segment.text).join(' ');

void _expectNoAdjacentSameKind(
  List<TitleDiffSegment> segments, {
  required String reason,
}) {
  for (var i = 1; i < segments.length; i++) {
    expect(segments[i].kind, isNot(segments[i - 1].kind), reason: reason);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TitleDiffSegment', () {
    test('equality is value-based over text and kind', () {
      const a = TitleDiffSegment(text: 'foo', kind: TitleDiffKind.added);
      const b = TitleDiffSegment(text: 'foo', kind: TitleDiffKind.added);
      const differentText = TitleDiffSegment(
        text: 'bar',
        kind: TitleDiffKind.added,
      );
      const differentKind = TitleDiffSegment(
        text: 'foo',
        kind: TitleDiffKind.removed,
      );

      expect(a, equals(b));
      expect(a == a, isTrue);
      expect(a == differentText, isFalse);
      expect(a == differentKind, isFalse);
      // ignore: unrelated_type_equality_checks
      expect(a == 'foo', isFalse);
    });

    test('hashCode is consistent with equality', () {
      const a = TitleDiffSegment(text: 'hello', kind: TitleDiffKind.common);
      const b = TitleDiffSegment(text: 'hello', kind: TitleDiffKind.common);
      const differentText = TitleDiffSegment(
        text: 'world',
        kind: TitleDiffKind.common,
      );
      const differentKind = TitleDiffSegment(
        text: 'hello',
        kind: TitleDiffKind.replaced,
      );

      // Equal values must share a hashCode.
      expect(a.hashCode, equals(b.hashCode));
      // Distinct values are unequal (hash collisions are allowed and not
      // asserted here, since unequal objects may legally share a hashCode).
      expect(a == differentText, isFalse);
      expect(a == differentKind, isFalse);
      // Hashing must be stable across invocations.
      expect(a.hashCode, equals(a.hashCode));
    });

    test('toString embeds the kind name and quoted text', () {
      const segment = TitleDiffSegment(
        text: 'quick brown',
        kind: TitleDiffKind.removed,
      );

      expect(
        segment.toString(),
        equals('TitleDiffSegment(removed: "quick brown")'),
      );
    });

    test('toString reflects each kind name', () {
      for (final kind in TitleDiffKind.values) {
        const text = 'x';
        final segment = TitleDiffSegment(text: text, kind: kind);
        expect(
          segment.toString(),
          equals('TitleDiffSegment(${kind.name}: "$text")'),
        );
      }
    });
  });

  group('TitleDiff.isIdentical', () {
    test('two empty titles are identical', () {
      final diff = computeTitleDiff('   ', '');
      expect(diff.local, isEmpty);
      expect(diff.remote, isEmpty);
      expect(diff.isIdentical, isTrue);
    });

    test('same single-word title is identical (one common segment)', () {
      final diff = computeTitleDiff('hello', 'hello');
      expect(diff.local, [
        const TitleDiffSegment(text: 'hello', kind: TitleDiffKind.common),
      ]);
      expect(diff.remote, [
        const TitleDiffSegment(text: 'hello', kind: TitleDiffKind.common),
      ]);
      expect(diff.isIdentical, isTrue);
    });

    test('identical multi-word titles merge to one common segment', () {
      final diff = computeTitleDiff('a b c', 'a b c');
      expect(diff.local, [
        const TitleDiffSegment(text: 'a b c', kind: TitleDiffKind.common),
      ]);
      expect(diff.isIdentical, isTrue);
    });

    test('differing titles are not identical', () {
      final diff = computeTitleDiff('hello', 'world');
      expect(diff.isIdentical, isFalse);
    });

    test(
      'one empty and one non-empty side is not identical',
      () {
        final diff = computeTitleDiff('', 'hello');
        expect(diff.local, isEmpty);
        expect(diff.remote, [
          const TitleDiffSegment(text: 'hello', kind: TitleDiffKind.replaced),
        ]);
        expect(diff.isIdentical, isFalse);
      },
    );

    test('non-common first segment is not identical', () {
      final diff = computeTitleDiff('foo', 'bar');
      // No shared token: local is one `added` segment; remote carries the
      // dropped local word (`removed`) plus the remote-only word (`replaced`).
      expect(diff.local, [
        const TitleDiffSegment(text: 'foo', kind: TitleDiffKind.added),
      ]);
      expect(diff.remote, [
        const TitleDiffSegment(text: 'foo', kind: TitleDiffKind.removed),
        const TitleDiffSegment(text: 'bar', kind: TitleDiffKind.replaced),
      ]);
      expect(diff.local.first.kind, TitleDiffKind.added);
      expect(diff.isIdentical, isFalse);
    });
  });

  group('computeTitleDiff segments', () {
    test('local-only trailing word: added on local, removed on remote', () {
      final diff = computeTitleDiff('hello world', 'hello');

      // Local sees common "hello" then its own extra word as added.
      expect(diff.local, [
        const TitleDiffSegment(text: 'hello', kind: TitleDiffKind.common),
        const TitleDiffSegment(text: 'world', kind: TitleDiffKind.added),
      ]);
      // Remote sees common "hello" then the word it dropped, struck-through
      // as removed so the user sees what the remote side is missing.
      expect(diff.remote, [
        const TitleDiffSegment(text: 'hello', kind: TitleDiffKind.common),
        const TitleDiffSegment(text: 'world', kind: TitleDiffKind.removed),
      ]);
    });

    test('remote-only trailing word: absent on local, replaced on remote', () {
      final diff = computeTitleDiff('hello', 'hello world');

      // Local has only the shared "hello"; remote-only insertions never
      // appear on the local card.
      expect(diff.local, [
        const TitleDiffSegment(text: 'hello', kind: TitleDiffKind.common),
      ]);
      // Remote shows common "hello" then the remote-only "world" as replaced.
      expect(diff.remote, [
        const TitleDiffSegment(text: 'hello', kind: TitleDiffKind.common),
        const TitleDiffSegment(text: 'world', kind: TitleDiffKind.replaced),
      ]);
    });

    test('replacement: middle word changed', () {
      final diff = computeTitleDiff('the quick fox', 'the slow fox');

      // Local: common "the", added "quick", common "fox".
      expect(diff.local, [
        const TitleDiffSegment(text: 'the', kind: TitleDiffKind.common),
        const TitleDiffSegment(text: 'quick', kind: TitleDiffKind.added),
        const TitleDiffSegment(text: 'fox', kind: TitleDiffKind.common),
      ]);
      // Remote: common "the", then the dropped "quick" (removed) and the
      // remote-only "slow" (replaced), then common "fox".
      expect(diff.remote, [
        const TitleDiffSegment(text: 'the', kind: TitleDiffKind.common),
        const TitleDiffSegment(text: 'quick', kind: TitleDiffKind.removed),
        const TitleDiffSegment(text: 'slow', kind: TitleDiffKind.replaced),
        const TitleDiffSegment(text: 'fox', kind: TitleDiffKind.common),
      ]);
    });

    test('adjacent same-kind tokens are merged into one segment', () {
      // Local adds two consecutive words "big red"; they must merge.
      final diff = computeTitleDiff('a big red car', 'a car');

      expect(diff.local, [
        const TitleDiffSegment(text: 'a', kind: TitleDiffKind.common),
        const TitleDiffSegment(text: 'big red', kind: TitleDiffKind.added),
        const TitleDiffSegment(text: 'car', kind: TitleDiffKind.common),
      ]);
      // The two dropped words also merge into a single `removed` run on remote.
      expect(diff.remote, [
        const TitleDiffSegment(text: 'a', kind: TitleDiffKind.common),
        const TitleDiffSegment(text: 'big red', kind: TitleDiffKind.removed),
        const TitleDiffSegment(text: 'car', kind: TitleDiffKind.common),
      ]);
    });

    test('completely different titles share no common segment', () {
      final diff = computeTitleDiff('alpha beta', 'gamma delta');

      // Local shows both local words merged as a single added run.
      expect(diff.local, [
        const TitleDiffSegment(
          text: 'alpha beta',
          kind: TitleDiffKind.added,
        ),
      ]);
      // Remote shows the dropped local words (removed) followed by the
      // remote-only words (replaced), each merged into one run.
      expect(diff.remote, [
        const TitleDiffSegment(
          text: 'alpha beta',
          kind: TitleDiffKind.removed,
        ),
        const TitleDiffSegment(
          text: 'gamma delta',
          kind: TitleDiffKind.replaced,
        ),
      ]);
    });

    test('extra whitespace collapses and does not create empty tokens', () {
      final diff = computeTitleDiff('  hello   world  ', 'hello world');

      expect(diff.isIdentical, isTrue);
      expect(diff.local, [
        const TitleDiffSegment(text: 'hello world', kind: TitleDiffKind.common),
      ]);
    });
  });

  group('computeTitleDiff', () {
    test('identical strings collapse to one common segment per side', () {
      final diff = computeTitleDiff('hello world', 'hello world');
      expect(diff.local, hasLength(1));
      expect(diff.remote, hasLength(1));
      expect(diff.local.first.kind, TitleDiffKind.common);
      expect(diff.local.first.text, 'hello world');
      expect(diff.isIdentical, isTrue);
    });

    test(
      'pure additions on local become added on local and removed (line-through) '
      'on remote',
      () {
        // Per spec, the remote side shows what it dropped struck-through
        // so the user can see what was deleted, not just what stayed.
        final diff = computeTitleDiff(
          'Testing the mic 1 and 2',
          'Testing the mic',
        );
        expect(diff.local, [
          const TitleDiffSegment(
            text: 'Testing the mic',
            kind: TitleDiffKind.common,
          ),
          const TitleDiffSegment(
            text: '1 and 2',
            kind: TitleDiffKind.added,
          ),
        ]);
        expect(diff.remote, [
          const TitleDiffSegment(
            text: 'Testing the mic',
            kind: TitleDiffKind.common,
          ),
          const TitleDiffSegment(
            text: '1 and 2',
            kind: TitleDiffKind.removed,
          ),
        ]);
        expect(diff.isIdentical, isFalse);
      },
    );

    test(
      'pure additions on remote become replaced segments on remote side',
      () {
        // "Testing" matches; "for conflicts" is remote-only.
        final diff = computeTitleDiff('Testing', 'Testing for conflicts');
        expect(diff.local, [
          const TitleDiffSegment(text: 'Testing', kind: TitleDiffKind.common),
        ]);
        expect(diff.remote, [
          const TitleDiffSegment(text: 'Testing', kind: TitleDiffKind.common),
          const TitleDiffSegment(
            text: 'for conflicts',
            kind: TitleDiffKind.replaced,
          ),
        ]);
      },
    );

    test(
      'mixed delete/insert on opposite sides yields all four kinds across both sides',
      () {
        final diff = computeTitleDiff(
          'Testing the mic 1 and 2',
          'Testing for conflicts',
        );
        // Local sees what's local-only as added; common stays common.
        expect(
          diff.local,
          contains(
            const TitleDiffSegment(
              text: 'Testing',
              kind: TitleDiffKind.common,
            ),
          ),
        );
        expect(
          diff.local
              .where((s) => s.kind == TitleDiffKind.added)
              .map((s) => s.text),
          ['the mic 1 and 2'],
        );
        // Remote shows what was dropped (line-through) + what replaced it.
        final remoteRemoved = diff.remote
            .where((s) => s.kind == TitleDiffKind.removed)
            .map((s) => s.text);
        final remoteReplaced = diff.remote
            .where((s) => s.kind == TitleDiffKind.replaced)
            .map((s) => s.text);
        expect(remoteRemoved, ['the mic 1 and 2']);
        expect(remoteReplaced, ['for conflicts']);
      },
    );

    test('adjacent same-kind tokens are merged into a single segment', () {
      // Three adjacent local-only tokens must produce ONE segment, not
      // three. The widget uses one styled span per segment, so merging
      // here keeps line-break behavior natural.
      final diff = computeTitleDiff('common a b c done', 'common done');
      final added = diff.local
          .where((s) => s.kind == TitleDiffKind.added)
          .toList();
      expect(added, hasLength(1));
      expect(added.first.text, 'a b c');
    });

    test('whitespace-only or empty strings degrade gracefully', () {
      // Empty strings tokenize to []; LCS produces no ops; both sides
      // emit an empty segment list. `isIdentical` covers this as a
      // dedicated branch so the caller can short-circuit just like
      // for two equal single-token titles.
      final diff = computeTitleDiff('', '');
      expect(diff.local, isEmpty);
      expect(diff.remote, isEmpty);
      expect(diff.isIdentical, isTrue);
    });

    test('local empty + remote non-empty: remote shows replaced only', () {
      final diff = computeTitleDiff('', 'fresh content');
      expect(diff.local, isEmpty);
      expect(diff.remote, [
        const TitleDiffSegment(
          text: 'fresh content',
          kind: TitleDiffKind.replaced,
        ),
      ]);
    });

    test(
      r'multiple whitespace runs collapse — tokenization splits on \s+',
      () {
        final diff = computeTitleDiff('a   b', 'a b');
        expect(diff.isIdentical, isTrue);
      },
    );

    glados.Glados(
      glados.any.titleDiffScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('preserves generated token-side invariants', (scenario) {
      final diff = computeTitleDiff(scenario.localTitle, scenario.remoteTitle);
      final localText = scenario.localTokens.join(' ');
      final remoteText = scenario.remoteTokens.join(' ');

      expect(_segmentsText(diff.local), localText, reason: '$scenario');
      expect(
        _segmentsText(
          diff.remote.where(
            (segment) => segment.kind != TitleDiffKind.removed,
          ),
        ),
        remoteText,
        reason: '$scenario',
      );
      expect(
        diff.isIdentical,
        scenario.localTokens.join(' ') ==
            scenario.remoteTokens.join(' '),
        reason: '$scenario',
      );
      expect(
        diff.local.map((segment) => segment.kind).toSet(),
        isNot(contains(TitleDiffKind.removed)),
        reason: '$scenario',
      );
      expect(
        diff.local.map((segment) => segment.kind).toSet(),
        isNot(contains(TitleDiffKind.replaced)),
        reason: '$scenario',
      );
      expect(
        diff.remote.map((segment) => segment.kind).toSet(),
        isNot(contains(TitleDiffKind.added)),
        reason: '$scenario',
      );
      _expectNoAdjacentSameKind(diff.local, reason: '$scenario local');
      _expectNoAdjacentSameKind(diff.remote, reason: '$scenario remote');
    }, tags: 'glados');
  });
}
