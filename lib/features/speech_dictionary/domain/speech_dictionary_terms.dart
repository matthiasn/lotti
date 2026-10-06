import 'package:lotti/classes/entity_definitions.dart';
import 'package:uuid/uuid.dart';

/// Maximum length of one dictionary term, enforced where a term is typed and
/// again where it is stored.
const int kMaxTermLength = 50;

/// How many misheard spellings an entry keeps. Learning appends, so the
/// oldest drop out first; a handful of examples is what helps a model, and a
/// long tail would only crowd the prompt.
const int kMaxMisheardForms = 8;

/// Above this many entries the dictionary page warns that a very long list
/// dilutes the hints a transcription model can use.
const int kDictionaryWarningThreshold = 500;

/// Namespace of the entry ids, so they never collide with another v5 id.
const _entryIdNamespace = '5b0a1f3e-8d2c-5f6e-9a47-3c1d2e4b6a70';

/// The comparison form of a term: trimmed, inner whitespace collapsed,
/// lower-cased. Two spellings that normalize alike are one term.
String normalizeSpeechTerm(String term) =>
    term.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// The id of [term]'s entry. Derived, not random, so the same term added on
/// two devices, or migrated by both, is one entry (SpeechDictionarySync.tla).
String speechDictionaryEntryId(String term) =>
    const Uuid().v5(_entryIdNamespace, normalizeSpeechTerm(term));

/// Splits the `;`-separated input of a terms field into trimmed, non-empty
/// terms, each truncated to [kMaxTermLength].
List<String> parseSpeechTerms(String text) {
  return text
      .split(';')
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .map(
        (term) => term.length > kMaxTermLength
            ? term.substring(0, kMaxTermLength)
            : term,
      )
      .toList();
}

/// Joins [terms] for a terms field, the inverse of [parseSpeechTerms].
String formatSpeechTerms(List<String>? terms) => terms?.join('; ') ?? '';

extension SpeechDictionaryEntryScope on SpeechDictionaryEntry {
  /// Whether the entry is limited to no category, and so applies to all.
  bool get appliesToAllCategories => categoryIds?.isEmpty ?? true;

  /// Whether the entry reaches a recording in [categoryId]. A recording
  /// without a category gets only the entries that apply to all.
  bool appliesTo(String? categoryId) =>
      deletedAt == null &&
      (appliesToAllCategories ||
          (categoryId != null && categoryIds!.contains(categoryId)));
}

/// The live entries that reach a recording in [categoryId], in the order
/// given.
List<SpeechDictionaryEntry> entriesForCategory(
  Iterable<SpeechDictionaryEntry> entries,
  String? categoryId,
) => entries.where((entry) => entry.appliesTo(categoryId)).toList();

/// [existing] with [added] appended: blank forms, forms that are the term
/// itself and forms already present (ignoring case) are skipped, and only the
/// newest [kMaxMisheardForms] are kept. Null when nothing remains.
List<String>? mergeMisheardForms(
  List<String>? existing,
  Iterable<String> added, {
  required String term,
}) {
  final normalizedTerm = normalizeSpeechTerm(term);
  final merged = <String>[];
  final seen = <String>{};
  for (final form in [...?existing, ...added]) {
    final trimmed = form.trim();
    final key = normalizeSpeechTerm(trimmed);
    if (key.isEmpty || key == normalizedTerm || !seen.add(key)) continue;
    merged.add(
      trimmed.length > kMaxTermLength
          ? trimmed.substring(0, kMaxTermLength)
          : trimmed,
    );
  }
  if (merged.isEmpty) return null;
  return merged.length > kMaxMisheardForms
      ? merged.sublist(merged.length - kMaxMisheardForms)
      : merged;
}
