import 'package:meta/meta.dart';

/// How a row of the side-by-side review changes its block (ADR 0167,
/// direction B).
enum MarkdownBlockChange {
  /// The same block on both sides.
  same,

  /// Only in the proposed version.
  added,

  /// Only in the current version.
  removed,

  /// Rewritten: a current block and the proposed block that replaces it,
  /// similar enough to read as one paragraph changed rather than one
  /// removed and another added.
  rewritten,
}

/// One row of the review: a current block, a proposed one, or both.
@immutable
class MarkdownBlockPair {
  const MarkdownBlockPair({
    required this.kind,
    this.base,
    this.proposed,
  }) : assert(
         (kind == MarkdownBlockChange.added) == (base == null) &&
             (kind == MarkdownBlockChange.removed) == (proposed == null),
         'added has no base block, removed no proposed one, the rest both',
       );

  final MarkdownBlockChange kind;

  /// The block in the current version; null for [MarkdownBlockChange.added].
  final String? base;

  /// The block in the proposed version; null for
  /// [MarkdownBlockChange.removed].
  final String? proposed;

  @override
  bool operator ==(Object other) =>
      other is MarkdownBlockPair &&
      other.kind == kind &&
      other.base == base &&
      other.proposed == proposed;

  @override
  int get hashCode => Object.hash(kind, base, proposed);

  @override
  String toString() => 'MarkdownBlockPair(${kind.name}, $base | $proposed)';
}

/// How many rows of each kind of change a review holds, for its summary.
@immutable
class MarkdownBlockDiffStats {
  const MarkdownBlockDiffStats({
    required this.added,
    required this.removed,
    required this.rewritten,
  });

  factory MarkdownBlockDiffStats.of(Iterable<MarkdownBlockPair> pairs) {
    var added = 0;
    var removed = 0;
    var rewritten = 0;
    for (final pair in pairs) {
      switch (pair.kind) {
        case MarkdownBlockChange.added:
          added++;
        case MarkdownBlockChange.removed:
          removed++;
        case MarkdownBlockChange.rewritten:
          rewritten++;
        case MarkdownBlockChange.same:
          break;
      }
    }
    return MarkdownBlockDiffStats(
      added: added,
      removed: removed,
      rewritten: rewritten,
    );
  }

  final int added;
  final int removed;
  final int rewritten;

  bool get isUnchanged => added == 0 && removed == 0 && rewritten == 0;

  @override
  bool operator ==(Object other) =>
      other is MarkdownBlockDiffStats &&
      other.added == added &&
      other.removed == removed &&
      other.rewritten == rewritten;

  @override
  int get hashCode => Object.hash(added, removed, rewritten);

  @override
  String toString() =>
      'MarkdownBlockDiffStats(+$added, -$removed, ~$rewritten)';
}

final _fence = RegExp('^ {0,3}(`{3,}|~{3,})');
final _heading = RegExp(r'^ {0,3}#{1,6}(\s|$)');
final _listItem = RegExp(r'^ {0,3}([-*+]|\d{1,9}[.)])(\s|$)');
final _indented = RegExp(r'^( {2,}|\t)');

/// Splits [markdown] into the blocks a review compares: headings, paragraphs,
/// whole lists and fenced code, split on blank lines.
///
/// A heading is a block of its own even without a blank line after it. A
/// fenced code block keeps its blank lines. A list stays one block across
/// the blank lines of a loose list — an item, or a line indented under one,
/// after the blank line continues it — so an ordered list is never split
/// into cells that each restart at "1.". Line endings are normalised to
/// `\n`, and each block's trailing whitespace is dropped.
List<String> splitMarkdownBlocks(String markdown) {
  final lines = markdown
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final blocks = <String>[];
  final current = <String>[];
  var inList = false;
  String? fence;

  void flush() {
    while (current.isNotEmpty && current.last.trim().isEmpty) {
      current.removeLast();
    }
    if (current.isNotEmpty) {
      blocks.add(current.join('\n').trimRight());
    }
    current.clear();
    inList = false;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final openFence = fence;
    if (openFence != null) {
      current.add(line);
      final close = _fence.firstMatch(line);
      if (close != null &&
          close.group(1)![0] == openFence[0] &&
          close.group(1)!.length >= openFence.length &&
          line.trim() == close.group(1)) {
        fence = null;
        flush();
      }
      continue;
    }
    if (line.trim().isEmpty) {
      if (inList) {
        final next = lines.skip(i + 1).where((l) => l.trim().isNotEmpty);
        final following = next.isEmpty ? null : next.first;
        if (following != null &&
            (_listItem.hasMatch(following) || _indented.hasMatch(following))) {
          current.add(line);
          continue;
        }
      }
      flush();
      continue;
    }
    if (_fence.firstMatch(line) case final match?) {
      flush();
      fence = match.group(1);
      current.add(line);
      continue;
    }
    if (_heading.hasMatch(line)) {
      flush();
      blocks.add(line.trimRight());
      continue;
    }
    if (current.isEmpty && _listItem.hasMatch(line)) inList = true;
    current.add(line);
  }
  flush();
  return blocks;
}

/// The word overlap at which an adjacent removed and added block read as
/// one block rewritten: the Dice coefficient of their word sets.
const rewrittenBlockSimilarity = 0.5;

/// The most pairs of blocks the alignment weighs between the unchanged
/// start and end of a document — about 500 changed blocks a side. Past it
/// the changed middle is listed removed then added, without rewrites: the
/// review stays open, at the cost of finer rows, rather than spend a
/// quadratic table on the UI isolate.
const markdownBlockAlignMaxCells = 250000;

/// Aligns the blocks of the current version ([base]) with those of the
/// proposed one into the rows of the review.
///
/// The blocks both versions start and end with are matched first. Between
/// them, unchanged blocks are matched by a longest common subsequence on
/// their text with whitespace collapsed, and between two matches a removed
/// block and an added one whose words overlap by at least
/// [rewrittenBlockSimilarity] become one [MarkdownBlockChange.rewritten]
/// row — while the changed middle stays within [markdownBlockAlignMaxCells];
/// past it, its blocks are rows removed and then added. Every block of each
/// side appears in exactly one row, and in its own order; a moved block
/// reads as removed in one place and added in another.
List<MarkdownBlockPair> alignMarkdownBlocks(
  List<String> base,
  List<String> proposed,
) {
  final a = [for (final block in base) _normalise(block)];
  final b = [for (final block in proposed) _normalise(block)];
  var start = 0;
  while (start < a.length && start < b.length && a[start] == b[start]) {
    start++;
  }
  var endA = a.length;
  var endB = b.length;
  while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
    endA--;
    endB--;
  }
  MarkdownBlockPair same(int i, int j) => MarkdownBlockPair(
    kind: MarkdownBlockChange.same,
    base: base[i],
    proposed: proposed[j],
  );
  final middleA = endA - start;
  final middleB = endB - start;
  return [
    for (var k = 0; k < start; k++) same(k, k),
    if ((middleA + 1) * (middleB + 1) > markdownBlockAlignMaxCells) ...[
      for (final block in base.sublist(start, endA))
        MarkdownBlockPair(kind: MarkdownBlockChange.removed, base: block),
      for (final block in proposed.sublist(start, endB))
        MarkdownBlockPair(kind: MarkdownBlockChange.added, proposed: block),
    ] else
      ..._alignMiddle(
        base.sublist(start, endA),
        proposed.sublist(start, endB),
        a.sublist(start, endA),
        b.sublist(start, endB),
      ),
    for (var k = 0; k < a.length - endA; k++) same(endA + k, endB + k),
  ];
}

/// The rows for the changed middle of two versions: [base] and [proposed]
/// as written, [a] and [b] the same blocks normalised.
List<MarkdownBlockPair> _alignMiddle(
  List<String> base,
  List<String> proposed,
  List<String> a,
  List<String> b,
) {
  // lcs[i][j]: the longest common subsequence of a[i..] and b[j..].
  final lcs = List.generate(
    a.length + 1,
    (_) => List<int>.filled(b.length + 1, 0),
  );
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }

  final pairs = <MarkdownBlockPair>[];
  final removed = <String>[];
  final added = <String>[];
  void flushRun() {
    pairs.addAll(_pairRun(removed, added));
    removed.clear();
    added.clear();
  }

  var i = 0;
  var j = 0;
  while (i < a.length || j < b.length) {
    if (i < a.length && j < b.length && a[i] == b[j]) {
      flushRun();
      pairs.add(
        MarkdownBlockPair(
          kind: MarkdownBlockChange.same,
          base: base[i],
          proposed: proposed[j],
        ),
      );
      i++;
      j++;
    } else if (j >= b.length ||
        (i < a.length && lcs[i + 1][j] >= lcs[i][j + 1])) {
      removed.add(base[i]);
      i++;
    } else {
      added.add(proposed[j]);
      j++;
    }
  }
  flushRun();
  return pairs;
}

/// The rows for one run of removed and added blocks between two unchanged
/// ones: a removed block meets the first added block after the ones already
/// placed that it is similar enough to, and the added blocks before that
/// one come first, so both sides keep their order.
List<MarkdownBlockPair> _pairRun(List<String> removed, List<String> added) {
  final rows = <MarkdownBlockPair>[];
  var j = 0;
  for (final block in removed) {
    final words = _words(block);
    var match = -1;
    for (var k = j; k < added.length; k++) {
      if (_similarity(words, _words(added[k])) >= rewrittenBlockSimilarity) {
        match = k;
        break;
      }
    }
    if (match < 0) {
      rows.add(
        MarkdownBlockPair(kind: MarkdownBlockChange.removed, base: block),
      );
      continue;
    }
    for (; j < match; j++) {
      rows.add(
        MarkdownBlockPair(kind: MarkdownBlockChange.added, proposed: added[j]),
      );
    }
    rows.add(
      MarkdownBlockPair(
        kind: MarkdownBlockChange.rewritten,
        base: block,
        proposed: added[match],
      ),
    );
    j = match + 1;
  }
  for (; j < added.length; j++) {
    rows.add(
      MarkdownBlockPair(kind: MarkdownBlockChange.added, proposed: added[j]),
    );
  }
  return rows;
}

String _normalise(String block) => block.trim().split(RegExp(r'\s+')).join(' ');

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

Set<String> _words(String block) => {
  for (final match in _word.allMatches(block.toLowerCase())) match.group(0)!,
};

double _similarity(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final common = a.intersection(b).length;
  return 2 * common / (a.length + b.length);
}
