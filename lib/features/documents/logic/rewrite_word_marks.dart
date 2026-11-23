import 'package:lotti/utils/text_diff.dart';

/// Opens a run of changed words in a rewritten block's Markdown (ADR 0167,
/// step 6). A Private Use Area code point, which neither a person nor a
/// model types, so the renderer can lift the run out before it parses the
/// Markdown around it.
const rewriteWordMarkOpen = '\u{E020}';

/// Closes a run [rewriteWordMarkOpen] opened.
const rewriteWordMarkClose = '\u{E021}';

/// The most word pairs a block's comparison weighs — about 500 words on
/// each side. A longer block keeps its rewrite surface without word marks,
/// rather than spend a quadratic diff on every build.
const rewriteWordMarkMaxCells = 250000;

final _token = RegExp(r'\S+');

/// A list item's, heading's or quote's marker: Markdown syntax, never a word
/// to mark, when it opens a line.
final _lineMarker = RegExp(r'^([-*+>]|#{1,6}|\d{1,9}[.)])$');

/// Emphasis that may wrap a word, kept outside its mark so the word stays
/// bold or struck through.
final _emphasis = RegExp(r'^([*_~]*)(.*?)([*_~]*)$', dotAll: true);

/// Characters that make a token Markdown syntax rather than prose.
final _syntax = RegExp(r'[`*_~\[\]()<>\\|$]');

/// Regions whose words stay unmarked: inline code, which shows a mark's
/// delimiters as written, and links and images, whose text and target the
/// parser reads as one.
final _opaque = RegExp(r'`+[^`]*`+|!?\[[^\]]*\]\([^)]*\)');

/// The two blocks of a rewritten row with every word one has and the other
/// lacks wrapped in [rewriteWordMarkOpen] … [rewriteWordMarkClose]: the
/// words the rewrite dropped in [base], and the words it brought in
/// [proposed].
///
/// Words are runs of non-space, compared exactly, so "fledged." and
/// "fledged" differ. Neighbouring changed words on one line share a mark.
/// Everything else in the source stays as written — line breaks, list
/// markers, the emphasis around a word — and a word that is Markdown
/// syntax, or sits in code or a link, stays unmarked. A fenced code block,
/// a block over [rewriteWordMarkMaxCells], or one that already holds a
/// delimiter comes back unmarked.
({String base, String proposed}) markRewrittenWords(
  String base,
  String proposed,
) {
  final unmarked = (base: base, proposed: proposed);
  if (_isFence(base) || _isFence(proposed)) return unmarked;
  if ('$base$proposed'.contains(rewriteWordMarkOpen) ||
      '$base$proposed'.contains(rewriteWordMarkClose)) {
    return unmarked;
  }
  final a = _token.allMatches(base).toList();
  final b = _token.allMatches(proposed).toList();
  if (a.length * b.length > rewriteWordMarkMaxCells) return unmarked;

  final dropped = <int>{};
  final brought = <int>{};
  var i = 0;
  var j = 0;
  for (final edit in diffTokens(
    [for (final m in a) m.group(0)!],
    [for (final m in b) m.group(0)!],
  )) {
    switch (edit.op) {
      case TextDiffOp.equal:
        i++;
        j++;
      case TextDiffOp.deleted:
        dropped.add(i++);
      case TextDiffOp.inserted:
        brought.add(j++);
    }
  }
  return (
    base: _mark(base, a, dropped),
    proposed: _mark(proposed, b, brought),
  );
}

bool _isFence(String block) {
  final start = block.trimLeft();
  return start.startsWith('```') || start.startsWith('~~~');
}

String _mark(String source, List<RegExpMatch> tokens, Set<int> changed) {
  if (changed.isEmpty) return source;
  final opaque = [
    for (final m in _opaque.allMatches(source)) (m.start, m.end),
  ];
  final out = StringBuffer();
  var cursor = 0;
  var open = false;
  void close() {
    if (open) out.write(rewriteWordMarkClose);
    open = false;
  }

  for (var k = 0; k < tokens.length; k++) {
    final token = tokens[k];
    final gap = source.substring(cursor, token.start);
    final parts = changed.contains(k) ? _markable(source, token, opaque) : null;
    // A run continues across spaces only, from a word with nothing after it
    // to one with nothing before it.
    if (parts == null || parts.$1.isNotEmpty || gap.contains('\n')) close();
    out.write(gap);
    if (parts == null) {
      out.write(token.group(0));
    } else {
      final (before, word, after) = parts;
      out.write(before);
      if (!open) out.write(rewriteWordMarkOpen);
      open = true;
      out.write(word);
      if (after.isNotEmpty) {
        close();
        out.write(after);
      }
    }
    cursor = token.end;
  }
  close();
  out.write(source.substring(cursor));
  return out.toString();
}

/// The emphasis before [token], its word and the emphasis after it — or
/// null when the token is Markdown syntax and must not be marked.
(String, String, String)? _markable(
  String source,
  RegExpMatch token,
  List<(int, int)> opaque,
) {
  for (final (start, end) in opaque) {
    if (token.start < end && token.end > start) return null;
  }
  final text = token.group(0)!;
  final lineStart = token.start == 0
      ? 0
      : source.lastIndexOf('\n', token.start - 1) + 1;
  if (source.substring(lineStart, token.start).trim().isEmpty &&
      _lineMarker.hasMatch(text)) {
    return null;
  }
  final match = _emphasis.firstMatch(text)!;
  final word = match.group(2)!;
  if (word.isEmpty || _syntax.hasMatch(word)) return null;
  return (match.group(1)!, word, match.group(3)!);
}
