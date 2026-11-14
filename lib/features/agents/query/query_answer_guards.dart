import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';

/// A citation in an answer: `[n]`, naming the n-th piece of evidence, with
/// the whitespace before it so a removed one leaves no gap behind.
final queryCitation = RegExp(r'\s*\[(\d+)\]');

/// [answer]'s paragraphs, split at blank lines — `\n` or `\r\n` — with a
/// paragraph of citations alone joined to the one before it, whose claim it
/// cites: an answer's points.
List<String> queryAnswerParagraphs(String answer) {
  final paragraphs = <String>[];
  for (final part in answer.split(RegExp(r'\r?\n[ \t]*\r?\n'))) {
    final paragraph = part.trim();
    if (paragraph.isEmpty) continue;
    if (paragraphs.isNotEmpty &&
        paragraph.replaceAll(queryCitation, '').trim().isEmpty) {
      paragraphs.add('${paragraphs.removeLast()} $paragraph');
    } else {
      paragraphs.add(paragraph);
    }
  }
  return paragraphs;
}

/// [answer] with every citation that names no evidence taken out, given
/// [evidenceCount] pieces of evidence numbered from 1.
///
/// A model sometimes cites a number past the evidence it was given — a
/// remembered conclusion numbered as if it were evidence, or a count that
/// ran on. Such a citation points at nothing, so it may not be shown, but
/// the answer around it still stands on the evidence it does cite; throwing
/// the whole answer away for it failed the question for nothing. Every
/// citation left names a piece of evidence that exists.
String withKnownCitations(String answer, int evidenceCount) =>
    answer.replaceAllMapped(queryCitation, (match) {
      final number = int.parse(match.group(1)!);
      return number >= 1 && number <= evidenceCount ? match.group(0)! : '';
    }).trim();

/// [roast] without its paragraphs that cite nothing.
///
/// Each paragraph of a roast is a jab, and a jab is only fair when it
/// points at the entry it comes from; one that cites nothing is a joke
/// about no one in particular, or about something the evidence never
/// showed. When no paragraph cites anything — there was nothing to cite,
/// and the roast says so — it is left as it is.
String withCitedParagraphs(String roast) {
  final cited = queryAnswerParagraphs(
    roast,
  ).where(queryCitation.hasMatch).toList();
  return cited.isEmpty ? roast : cited.join('\n\n');
}

/// What reading the next source may do, re-checked against the live access
/// snapshot right before each part of it is read ([sourceGate]).
enum QuerySourceGate {
  /// Read it.
  read,

  /// Leave it out: it, or something it is linked to, can no longer be read
  /// in this scope, but nothing of it is in the answer yet.
  skip,

  /// End the question: something the answer already stands on can no
  /// longer be read.
  stop,
}

/// Whether the source behind [sourceDependencies] — the source and what it
/// is linked to — may be read now, given what the answer already depends on
/// ([dependencies]).
///
/// A source hidden since the crawl found it is skipped, not the whole
/// question failed: the answer stays incomplete instead of empty. What the
/// answer already holds still ends the question when it goes, since an
/// answer may never rest on what can no longer be seen.
QuerySourceGate sourceGate(
  QueryAccessSnapshot current,
  QueryCorpus corpus, {
  required Iterable<QuerySourceRef> dependencies,
  required List<QuerySourceRef> sourceDependencies,
  required bool private,
}) {
  if (!current.allowsContent(dependencies, private: private)) {
    return QuerySourceGate.stop;
  }
  final source = sourceDependencies.first;
  return current.allowsContent(sourceDependencies, private: private) &&
          corpus.admits(current, current.entries[source.id]?.meta.categoryId)
      ? QuerySourceGate.read
      : QuerySourceGate.skip;
}
