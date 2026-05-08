import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/title_diff.dart';

void main() {
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
      // emit an empty segment list. The page should branch on this and
      // fall back to a non-diff title.
      final diff = computeTitleDiff('', '');
      expect(diff.local, isEmpty);
      expect(diff.remote, isEmpty);
      expect(diff.isIdentical, isFalse);
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
  });
}
