part of 'query_answer_builder.dart';

/// The plan's searches by meaning: a full question can need several facts,
/// and each is found best by a search of its own.
const _searchesField =
    '"searches":["1 to 3 short searches in natural language, one for each '
    'separate thing the answer needs, in the language of the question; for a '
    'request about the user that names no topic (roast me, how am I doing), '
    'search their recent habits, struggles, slipped plans and complaints"]';

/// Whether the user asked to be roasted. Decided once, in the plan, so the
/// answer is written as a roast and its uncited jabs are dropped
/// (`withCitedParagraphs`) on the same reading of the question.
const _roastField =
    '"roast":false (true only when the user asks to be roasted, teased or '
    'judged)';

/// How the answer is written: short paragraphs with each citation beside
/// its claim, and for a roast what one is made of. Without it a request to
/// be roasted came back as one dense report, its jokes resting on nothing
/// in particular.
const _registerRule =
    'Write short paragraphs, one point each, separated by a blank line; put '
    'each citation right after the claim it supports; quote at most a few '
    'words; a plain fact needs a sentence or two. Evidence may carry tasks: '
    'the facts of the task it is or belongs to (status, since when, due, how '
    'often the status changed), which are true and may be stated with that '
    "evidence's citation. "
    'When roast is true the user asked to be roasted: write a playful roast, '
    'not a report. Its material is the gap between what they said and what '
    'they did: a plan promised and slipped, the same task put off again, a '
    'due date long past today on a task still open, a status that keeps '
    'moving, a project begun and left, a complaint that keeps coming back. '
    'Each paragraph is one jab: a specific observation with its date, count '
    "or the user's own words, then the joke, then its citation; an opening "
    'or closing line belongs inside a cited paragraph, since a paragraph '
    'without a citation is removed. Aim at habits and patterns, never at '
    'body, health, grief, money worries or another person; affectionate, '
    'never cruel, and no generic joke that would fit anyone. Say nothing the '
    'evidence does not show; when it is too thin for a fair roast, say so in '
    'one line and roast only what it shows.';

/// The final answer, written from the verified evidence alone.
const _answerSystem =
    '${QueryAnswerBuilder._untrusted}Answer from the supplied evidence and '
    'relevant memories only. Cite evidence numbers as [1], [2]. Distinguish '
    'recorded decisions, suggestions and inference. When evidence conflicts '
    'show the disagreement. With no evidence say what could not be '
    'established; incomplete coverage never proves a discussion did not '
    'happen. $_registerRule Return {"answer":"the answer with citations", '
    '"conclusion":"one useful durable conclusion, or empty"}. A remembered '
    'conclusion is not a newly verified source.';

/// The categories a journal question names, which narrow its search.
const _categoriesField =
    '"categories":["each name from the supplied categories that the question '
    'explicitly limits itself to; none when it names none"]';

/// The categories a journal-wide question may name, by id: those of its
/// scope the reader may see, under their names. Empty for every other
/// scope, whose plan is not asked for categories.
Map<String, String> _nameableCategories(
  QueryAccessSnapshot access,
  QueryScope scope,
) {
  if (!scope.spansCategories) return const {};
  final selection = scope.journalCategoryIds;
  return {
    for (final MapEntry(key: id, value: category) in access.categories.entries)
      if (access.allowsCategory(id) &&
          (selection == null || selection.contains(id)))
        id: category.name,
  };
}

/// The ids of the categories the plan named, matched by name against
/// [nameable] regardless of case; null when it named none it may.
Set<String>? _namedCategoryIds(
  Object? named,
  Map<String, String> nameable,
) {
  if (named is! List || nameable.isEmpty) return null;
  final wanted = {
    for (final name in named.whereType<String>())
      if (name.trim().isNotEmpty) name.trim().toLowerCase(),
  };
  if (wanted.isEmpty) return null;
  // A name that matches none of them narrows to nothing: dropping it would
  // widen the search past what the question asked.
  return {
    for (final MapEntry(key: id, value: name) in nameable.entries)
      if (wanted.contains(name.trim().toLowerCase())) id,
  };
}

const _batchSystem =
    '${QueryAnswerBuilder._untrusted}Inspect sources together in this disposable retrieval context. '
    'Resolve the question using only this chat conversation. Extract relevant exact '
    'contiguous passages, preserving qualifications and disagreements. Source text '
    'is complete, not a preview. Return '
    '{"question":"standalone question","terms":["specific fallback search terms"], '
    '$_searchesField, $_roastField, '
    '"passages":[{"sourceId":"supplied source id","quote":"EXACT source text", '
    '"summary":"short relevance summary","reason":"why relevant"}], '
    '"sufficient":true,"searchCategory":false,"memoryIds":["useful supplied memory id"]}. '
    'Use only supplied IDs. Return no passages for irrelevant sources. '
    'Sharing a topic alone does not establish a missing requested fact. '
    'Each passage must supply at least one requested fact, or a necessary '
    'qualification or contradiction of that fact. A shared name, a general '
    'task instruction, or unrelated activity is not evidence of the requested '
    'measurement or outcome. Do not include a passage merely to explain that '
    'it does not contain the answer. Return an empty passages list instead. '
    'sufficient is true only when accepted passages or relevant memories establish '
    'all requested facts without hiding uncertainty or disagreement. '
    'Set searchCategory true when the user asks to search other category entries, '
    'even if a home passage already answers part of the question. '
    'Choose relevant memories in this same inspection; a memory is not fresh evidence. '
    'Do not write the final answer. Never invent a missing fact.';

/// One source's passages that bear on the question, quoted exactly.
const _extractSystem =
    '${QueryAnswerBuilder._untrusted}Extract passages relevant to the '
    'question. Return {"passages":[{"quote":"EXACT contiguous source text", '
    '"summary":"short relevance summary","reason":"why relevant"}]}. '
    'If irrelevant, return {"passages":[]}. Never paraphrase a quote. '
    'Include enough surrounding discussion to preserve decisions, '
    'disagreement and qualifications.';

/// The sources worth reading in full, chosen from their previews.
const _shortlistSystem =
    '${QueryAnswerBuilder._untrusted}Shortlist sources for exact-text '
    'inspection. Review these source previews together. Return '
    '{"ids":["source id"]} in descending relevance, at most 8 sources. '
    'Prefer sources likely to contain the requested discussion or decision. '
    'Previews may be truncated; include plausible sources even when '
    'uncertain. Use only IDs supplied here. Return no quotes or answer.';

/// The verified [evidence] as the answer reads it, numbered from 1 as it is
/// cited, each with the facts of its tasks read from [access]
/// ([queryTaskFacts]).
List<Map<String, Object?>> _answerEvidence(
  List<QueryEvidence> evidence,
  QueryAccessSnapshot access,
  Map<String, QueryAffiliation> affiliations,
) => [
  for (final (index, piece) in evidence.indexed)
    {
      'number': index + 1,
      'label': piece.label,
      'date': piece.sourceDate.toIso8601String(),
      'quote': piece.quote,
      'affiliations': piece.affiliations,
      'tasks': queryTaskFacts(access, affiliations, piece.source),
    },
];
