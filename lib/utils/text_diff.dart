import 'dart:math' as math;

import 'package:meta/meta.dart';

/// What one step of a token diff does.
enum TextDiffOp {
  /// The token is in both sequences.
  equal,

  /// The token is only in the first sequence.
  deleted,

  /// The token is only in the second sequence.
  inserted,
}

/// One step of the edit script [diffTokens] returns.
@immutable
class TextDiffEdit {
  const TextDiffEdit(this.op, this.token);

  final TextDiffOp op;
  final String token;

  @override
  bool operator ==(Object other) =>
      other is TextDiffEdit && other.op == op && other.token == token;

  @override
  int get hashCode => Object.hash(op, token);

  @override
  String toString() => 'TextDiffEdit(${op.name}: "$token")';
}

/// The edit script that turns [a] into [b], by a longest common subsequence
/// of their tokens, in reading order: [TextDiffOp.equal] for a token both
/// keep, [TextDiffOp.deleted] for one only [a] has, [TextDiffOp.inserted] for
/// one only [b] has.
///
/// Walking the script consumes [a] on `equal` and `deleted` and [b] on
/// `equal` and `inserted`, so a caller can map every step back to its
/// token's index. Where a deletion and an insertion could go in either
/// order, the deletion comes first. It takes time and memory in the product
/// of the two lengths — words of a title or a paragraph, not a whole book.
List<TextDiffEdit> diffTokens(List<String> a, List<String> b) {
  final m = a.length;
  final n = b.length;
  final dp = List<List<int>>.generate(
    m + 1,
    (_) => List<int>.filled(n + 1, 0),
  );
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (a[i - 1] == b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
  }
  final edits = <TextDiffEdit>[];
  var i = m;
  var j = n;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && a[i - 1] == b[j - 1]) {
      edits.add(TextDiffEdit(TextDiffOp.equal, a[i - 1]));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      edits.add(TextDiffEdit(TextDiffOp.inserted, b[j - 1]));
      j--;
    } else {
      edits.add(TextDiffEdit(TextDiffOp.deleted, a[i - 1]));
      i--;
    }
  }
  return edits.reversed.toList();
}
