import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/query/query_answer_guards.dart';

/// One point of an answer: what it says, and the pieces of evidence it
/// rests on, numbered from 1 as the answer cites them.
@immutable
class QueryAnswerPoint {
  const QueryAnswerPoint({required this.text, required this.sources});

  /// The point's words, its citations taken out.
  final String text;

  /// The evidence numbers it cites, each once, in the order first cited.
  final List<int> sources;

  @override
  bool operator ==(Object other) =>
      other is QueryAnswerPoint &&
      other.text == text &&
      listEquals(other.sources, sources);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(sources));

  @override
  String toString() => 'QueryAnswerPoint($text, $sources)';
}

/// [answer] as its points: a paragraph each, its `[n]` citations of the
/// [evidenceCount] pieces of evidence lifted out as its sources.
///
/// The model writes an answer as text, which streams to the screen while it
/// is written; drawn, each point carries the sources it rests on beside it,
/// so a claim and its evidence are read together instead of matched up by
/// footnote numbers. A citation naming no evidence is dropped, as
/// [withKnownCitations] does; a paragraph that is only citations adds its
/// sources to the point before it.
List<QueryAnswerPoint> queryAnswerPoints(String answer, int evidenceCount) {
  final points = <QueryAnswerPoint>[];
  for (final paragraph in queryAnswerParagraphs(answer)) {
    final sources = <int>[];
    for (final match in queryCitation.allMatches(paragraph)) {
      final number = int.parse(match.group(1)!);
      if (number >= 1 && number <= evidenceCount && !sources.contains(number)) {
        sources.add(number);
      }
    }
    final text = paragraph.replaceAll(queryCitation, '').trim();
    if (text.isEmpty) {
      if (points.isNotEmpty && sources.isNotEmpty) {
        final last = points.removeLast();
        points.add(
          QueryAnswerPoint(
            text: last.text,
            sources: [
              ...last.sources,
              ...sources.where((n) => !last.sources.contains(n)),
            ],
          ),
        );
      }
      continue;
    }
    points.add(QueryAnswerPoint(text: text, sources: sources));
  }
  return points;
}
