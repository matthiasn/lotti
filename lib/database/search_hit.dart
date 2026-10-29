import 'package:meta/meta.dart';

/// Marks where a matched word starts in a [SearchHit.snippet]. A private-use
/// character, so no text a user wrote can contain one.
const snippetMatchStart = '';

/// Marks where a matched word ends in a [SearchHit.snippet].
const snippetMatchEnd = '';

/// One entity a full-text search matched, best first in its list.
@immutable
class SearchHit {
  const SearchHit({
    required this.entityId,
    required this.type,
    required this.snippet,
  });

  final String entityId;

  /// The journal row's `type`.
  final String type;

  /// A few words around the best match, from the column that matched best,
  /// each matched word wrapped in [snippetMatchStart] and [snippetMatchEnd];
  /// cut text is marked with an ellipsis.
  final String snippet;
}

/// One run of a [SearchHit.snippet]: matched or not.
typedef SnippetSpan = ({String text, bool matched});

/// [snippet] split at its match markers, the markers themselves dropped.
List<SnippetSpan> snippetSpans(String snippet) {
  final spans = <SnippetSpan>[];
  var matched = false;
  final run = StringBuffer();
  void close() {
    if (run.isEmpty) return;
    spans.add((text: run.toString(), matched: matched));
    run.clear();
  }

  for (final rune in snippet.runes) {
    final char = String.fromCharCode(rune);
    if (char == snippetMatchStart || char == snippetMatchEnd) {
      close();
      matched = char == snippetMatchStart;
    } else {
      run.write(char);
    }
  }
  close();
  return spans;
}
