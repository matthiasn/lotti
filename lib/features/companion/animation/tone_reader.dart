import 'package:lotti/features/companion/model/companion_reaction.dart';

/// Where a stretch of the words starts and how it reads: an approval on the
/// `companionReaction` scale, or null where it reads neither way.
typedef ToneCue = ({int offset, int? approval});

/// Reads how each sentence of [text] lands, on the device and without a
/// model: praise, neither, or something that needs work.
///
/// [text] is what the voice speaks, Markdown included. Every line and every
/// sentence within a line gets a cue at its first character. A sentence's
/// own words decide its tone; one that reads neither way takes the tone of
/// its section, set by the heading above it — so the lines under "⚠️ Risks"
/// keep her concerned and the ones under "✅ Achieved" keep her pleased.
///
/// The words are a short English and German list, and a few emoji that read
/// the same in any language; a report in another language reads neither way
/// except by its emoji. A cue repeating the one before it is left out.
List<ToneCue> readTones(String text) {
  final cues = <ToneCue>[];
  int? section;
  void add(int offset, int? approval) {
    if (cues.isEmpty || cues.last.approval != approval) {
      cues.add((offset: offset, approval: approval));
    }
  }

  var lineStart = 0;
  while (lineStart <= text.length) {
    final newline = text.indexOf('\n', lineStart);
    final lineEnd = newline < 0 ? text.length : newline;
    final line = text.substring(lineStart, lineEnd);
    if (line.trim().isNotEmpty) {
      if (_heading.hasMatch(line)) {
        section = _approval(line);
        add(lineStart, section);
      } else {
        for (final match in _sentence.allMatches(line)) {
          add(lineStart + match.start, _approval(match[0]!) ?? section);
        }
      }
    }
    if (newline < 0) break;
    lineStart = newline + 1;
  }
  return cues;
}

final _heading = RegExp(r'^\s{0,3}#{1,6}\s');

/// A sentence: up to and including its stop, or the rest of the line.
final _sentence = RegExp(r'[^.!?]+(?:[.!?]+|$)');

final _token = RegExp(r"[\p{L}\p{N}']+", unicode: true);

/// The approval [words] read as, or null where they read neither way.
int? _approval(String words) {
  final lower = words.toLowerCase();
  var score = 0;
  for (final MapEntry(key: mark, value: weight) in _marks.entries) {
    if (lower.contains(mark)) score += weight;
  }
  for (final MapEntry(key: phrase, value: weight) in _phrases.entries) {
    if (lower.contains(phrase)) score += weight;
  }
  final tokens = [for (final m in _token.allMatches(lower)) m[0]!];
  for (var i = 0; i < tokens.length; i++) {
    final weight = _weight(tokens[i]);
    if (weight == 0) continue;
    // "Not done", "no progress", "nicht erledigt": praise denied is a
    // concern; "no blockers", "keine Probleme": trouble denied is good news.
    final negated = [
      for (var k = i - 2; k < i; k++)
        if (k >= 0) tokens[k],
    ].any(_negators.contains);
    score += negated ? (weight > 0 ? -1 : 1) : weight;
  }
  if (score == 0) return null;
  return score.clamp(minApproval, maxApproval);
}

int _weight(String token) {
  final exact = _exact[token];
  if (exact != null) return exact;
  for (final MapEntry(key: stem, value: weight) in _stems.entries) {
    if (token.startsWith(stem)) return weight;
  }
  return 0;
}

const _negators = {
  'not',
  'no',
  'never',
  "isn't",
  "wasn't",
  'nicht',
  'kein',
  'keine',
  'nie',
};

/// Emoji that read the same in any language.
const _marks = {
  '✅': 2,
  '🎉': 2,
  '🏆': 2,
  '👏': 2,
  '💪': 1,
  '✨': 1,
  '⚠': -2,
  '❌': -2,
  '🚧': -1,
  '🔴': -2,
  '⛔': -2,
  '🛑': -2,
};

const _phrases = {
  'well done': 2,
  'great job': 2,
  'on track': 1,
  'off track': -2,
  'at risk': -1,
  'falling behind': -2,
  'gut gemacht': 2,
  'im plan': 1,
  'im verzug': -2,
};

/// Short words, matched whole so "done" never matches "doner".
const _exact = {
  'done': 2,
  'great': 2,
  'super': 2,
  'toll': 2,
  'fertig': 2,
  'good': 1,
  'nice': 1,
  'gut': 1,
  'behind': -2,
  'late': -1,
  'needs': -1,
  'risk': -1,
  'issue': -1,
  'issues': -1,
  'offen': -1,
};

/// Word beginnings, so "complete", "completed" and "completing" all count.
const _stems = {
  'achiev': 2,
  'accomplish': 2,
  'complet': 2,
  'finish': 2,
  'excellent': 2,
  'outstanding': 2,
  'fantastic': 2,
  'brilliant': 2,
  'congrat': 2,
  'success': 2,
  'milestone': 2,
  'erreicht': 2,
  'geschafft': 2,
  'erledigt': 2,
  'abgeschlossen': 2,
  'hervorragend': 2,
  'großartig': 2,
  'glückwunsch': 2,
  'erfolg': 2,
  'progress': 1,
  'improv': 1,
  'steady': 1,
  'streak': 1,
  'fortschritt': 1,
  'verbesser': 1,
  'overdue': -2,
  'block': -2,
  'missed': -2,
  'fail': -2,
  'stall': -2,
  'slipp': -2,
  'überfällig': -2,
  'verpasst': -2,
  'gescheitert': -2,
  'rückstand': -2,
  'delay': -1,
  'concern': -1,
  'problem': -1,
  'lacking': -1,
  'risiko': -1,
  'verzög': -1,
  'fehlt': -1,
};
