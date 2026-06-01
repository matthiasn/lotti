import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/title_diff.dart';

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
}
