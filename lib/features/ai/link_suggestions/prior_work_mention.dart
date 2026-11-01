import 'package:flutter/foundation.dart';
import 'package:lotti/classes/directed_relation.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/ai/link_suggestions/prior_work_cues.dart';

/// A sentence in a task's notes or log that talks about other work.
@immutable
class PriorWorkMention {
  const PriorWorkMention({
    required this.sourceId,
    required this.sentence,
    required this.relation,
    required this.query,
  });

  /// The entry the sentence was found in: the task itself for its own notes,
  /// otherwise the linked log entry.
  final String sourceId;

  /// The whole sentence, trimmed.
  final String sentence;

  /// The relationship the cue suggests, the task being its subject.
  final DirectedRelation relation;

  /// What to search for: the sentence without its cue phrase. Null when
  /// nothing but the cue remains ("Same as last time."): the sentence then
  /// says the task itself was done before, and its title is the query.
  final String? query;

  @override
  bool operator ==(Object other) =>
      other is PriorWorkMention &&
      other.sourceId == sourceId &&
      other.sentence == sentence &&
      other.relation == relation &&
      other.query == query;

  @override
  int get hashCode => Object.hash(sourceId, sentence, relation, query);

  @override
  String toString() =>
      'PriorWorkMention(${relation.wireName}: "$sentence" → "$query")';
}

/// The fewest words of three or more letters a query needs once its cue is
/// removed. Fewer, and what is left ("it", "the one") names nothing to
/// search for.
const kMinMentionQueryWords = 2;

/// The longest sentence considered, in characters. A run-on transcript with
/// no punctuation would otherwise make one query of a whole recording.
const kMaxMentionSentenceLength = 400;

/// Every sentence of [text] that mentions other work, in the order they
/// appear, at most one per sentence.
///
/// A sentence with a cue for a specific relationship — blocked by, follows
/// up on, duplicates, … — takes the earliest such cue; only a sentence with
/// none of those falls back to a plain "relates to" cue. A sentence longer
/// than [kMaxMentionSentenceLength] is cut there.
List<PriorWorkMention> detectPriorWorkMentions(
  String text, {
  required String sourceId,
}) {
  final mentions = <PriorWorkMention>[];
  for (final raw in text.split(_sentenceBreak)) {
    var sentence = raw.trim();
    if (sentence.isEmpty) continue;
    if (sentence.length > kMaxMentionSentenceLength) {
      sentence = sentence.substring(0, kMaxMentionSentenceLength).trim();
    }
    final normalized = sentence.replaceAll('’', "'");
    final cue = _firstCue(normalized);
    if (cue == null) continue;
    mentions.add(
      PriorWorkMention(
        sourceId: sourceId,
        sentence: sentence,
        relation: cue.relation,
        query: _queryWithout(normalized, cue.match),
      ),
    );
  }
  return mentions;
}

/// The relationship to suggest between a task and a candidate task, given
/// the one a [mention] cued and whether the candidate is closed
/// (`DONE`/`REJECTED`).
///
/// Blocking needs an open task on both ends of the reading: a closed task
/// blocks nothing (blockedness counts only open blockers), and a task cannot
/// usefully block one that is already done. Such a mention still says the
/// two belong together, so it becomes a plain link.
DirectedRelation relationForCandidate(
  PriorWorkMention mention, {
  required bool candidateIsClosed,
}) {
  if (mention.relation.type == EntryLinkType.blocks && candidateIsClosed) {
    return const DirectedRelation(EntryLinkType.basic);
  }
  return mention.relation;
}

/// Ends of sentences: terminal punctuation followed by space, or a line
/// break.
final RegExp _sentenceBreak = RegExp(r'(?<=[.!?…;])\s+|[\r\n]+');

final RegExp _queryWord = RegExp(r'[\p{L}\p{N}]{3,}', unicode: true);

final RegExp _edgeNoise = RegExp(
  r'^[\s\p{P}]+|[\s\p{P}]+$',
  unicode: true,
);

class _CompiledCue {
  _CompiledCue(this.relation, this.pattern);

  final DirectedRelation relation;
  final RegExp pattern;
}

/// One pattern per cue set, its phrases longest first so "like last time"
/// wins over "last time" at the same position.
final List<_CompiledCue> _compiledCues = [
  for (final set in priorWorkCueSets)
    _CompiledCue(set.relation, _cuePattern(set.phrases)),
];

/// Any of [phrases] as whole words, ignoring case.
RegExp _cuePattern(Iterable<String> phrases) {
  final longestFirst = phrases.toList()..sort((a, b) => b.length - a.length);
  final alternatives = longestFirst.map(_phrasePattern).join('|');
  return RegExp(
    '(?<![\\p{L}\\p{N}])(?:$alternatives)(?![\\p{L}\\p{N}])',
    caseSensitive: false,
    unicode: true,
  );
}

/// [phrase] as a pattern in which every space or hyphen matches a run of
/// spaces and hyphens.
String _phrasePattern(String phrase) => phrase
    .replaceAll('’', "'")
    .split(RegExp(r'[\s-]+'))
    .where((word) => word.isNotEmpty)
    .map(RegExp.escape)
    .join(r'[\s\-]+');

({DirectedRelation relation, RegExpMatch match})? _firstCue(String sentence) {
  ({DirectedRelation relation, RegExpMatch match})? best;
  for (final cue in _compiledCues) {
    final match = cue.pattern.firstMatch(sentence);
    if (match == null) continue;
    final isPlain = cue.relation.type == EntryLinkType.basic;
    if (isPlain) {
      // The plain cue set is tried last: it only counts when no specific
      // relationship was cued anywhere in the sentence.
      return best ?? (relation: cue.relation, match: match);
    }
    if (best == null || match.start < best.match.start) {
      best = (relation: cue.relation, match: match);
    }
  }
  return best;
}

String? _queryWithout(String sentence, RegExpMatch cue) {
  final rest =
      '${sentence.substring(0, cue.start)} ${sentence.substring(cue.end)}'
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(_edgeNoise, '');
  return _queryWord.allMatches(rest).length >= kMinMentionQueryWords
      ? rest
      : null;
}
