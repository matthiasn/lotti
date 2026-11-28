import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/text_diff.dart';

void main() {
  const equal = TextDiffOp.equal;
  const deleted = TextDiffOp.deleted;
  const inserted = TextDiffOp.inserted;

  List<(TextDiffOp, String)> script(List<String> a, List<String> b) => [
    for (final edit in diffTokens(a, b)) (edit.op, edit.token),
  ];

  test('two equal sequences keep every token', () {
    expect(script(['feed', 'the', 'birds'], ['feed', 'the', 'birds']), [
      (equal, 'feed'),
      (equal, 'the'),
      (equal, 'birds'),
    ]);
  });

  test('an empty side is all insertions or all deletions', () {
    expect(script([], ['a', 'b']), [(inserted, 'a'), (inserted, 'b')]);
    expect(script(['a', 'b'], []), [(deleted, 'a'), (deleted, 'b')]);
    expect(script([], []), isEmpty);
  });

  test('a replaced token is deleted before its replacement is inserted', () {
    expect(script(['fed', '37', 'birds'], ['fed', '38', 'birds']), [
      (equal, 'fed'),
      (deleted, '37'),
      (inserted, '38'),
      (equal, 'birds'),
    ]);
  });

  test('the script rebuilds both sides and keeps a longest common run', () {
    final random = Random(166);
    const words = ['a', 'b', 'c', 'd'];
    for (var round = 0; round < 200; round++) {
      final a = [
        for (var k = random.nextInt(9); k > 0; k--)
          words[random.nextInt(words.length)],
      ];
      final b = [
        for (var k = random.nextInt(9); k > 0; k--)
          words[random.nextInt(words.length)],
      ];
      final edits = diffTokens(a, b);
      expect(
        [
          for (final e in edits)
            if (e.op != inserted) e.token,
        ],
        a,
      );
      expect(
        [
          for (final e in edits)
            if (e.op != deleted) e.token,
        ],
        b,
      );
      expect(
        edits.where((e) => e.op == equal).length,
        _lcsLength(a, b),
        reason: '$a → $b',
      );
    }
  });

  test('an edit is a value', () {
    const edit = TextDiffEdit(inserted, 'chick');
    expect(edit, const TextDiffEdit(inserted, 'chick'));
    expect(edit.hashCode, const TextDiffEdit(inserted, 'chick').hashCode);
    expect(edit, isNot(const TextDiffEdit(deleted, 'chick')));
    expect(edit.toString(), 'TextDiffEdit(inserted: "chick")');
  });
}

/// The length of a longest common subsequence, by brute-force recursion —
/// independent of the table [diffTokens] fills.
int _lcsLength(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a.first == b.first) return 1 + _lcsLength(a.sublist(1), b.sublist(1));
  return max(_lcsLength(a.sublist(1), b), _lcsLength(a, b.sublist(1)));
}
