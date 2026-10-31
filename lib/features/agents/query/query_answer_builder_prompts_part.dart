part of 'query_answer_builder.dart';

/// The plan's searches by meaning: a full question can need several facts,
/// and each is found best by a search of its own.
const _searchesField =
    '"searches":["1 to 3 short searches in natural language, one for each '
    'separate thing the answer needs, in the language of the question"]';

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
    '$_searchesField, '
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
