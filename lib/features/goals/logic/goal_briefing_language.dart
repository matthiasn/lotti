import 'package:flutter/foundation.dart';
import 'package:lotti/classes/supported_language.dart';

/// Resolves the language a goal's journal is kept in — its category's default
/// language — as a raw code, or null when there is none.
typedef GoalJournalLanguageReader = Future<String?> Function(String agentId);

/// Where the language a goal agent writes in came from.
enum GoalBriefingLanguageSource {
  /// The user picked it on the goal (`AgentConfig.languageCode`).
  chosen,

  /// Nobody picked one: it follows the goal's journal — the default language
  /// of the category the goal and its check-ins are filed in.
  journal,

  /// Neither is set. The agent writes in the language of the user's own
  /// words, and English when it has none to go by.
  unset,
}

/// The language a goal agent writes its briefings, reports, banners and
/// replies in, and where that came from.
@immutable
class GoalBriefingLanguage {
  const GoalBriefingLanguage._(this.language, this.source);

  /// Null exactly when [source] is [GoalBriefingLanguageSource.unset].
  final SupportedLanguage? language;
  final GoalBriefingLanguageSource source;

  /// How the wake's FACTS name the language: the code with its English name,
  /// or — with none set — the rule the model writes by instead. The system
  /// prompt points at this field for every word of prose.
  String get factsLine => switch (language) {
    final SupportedLanguage language => '${language.code} (${language.name})',
    null => goalUnsetLanguageFactsLine,
  };

  @override
  bool operator ==(Object other) =>
      other is GoalBriefingLanguage &&
      other.language == language &&
      other.source == source;

  @override
  int get hashCode => Object.hash(language, source);

  @override
  String toString() => 'GoalBriefingLanguage(${language?.code}, $source)';
}

/// What FACTS say when neither the goal nor its journal names a language:
/// the behaviour every goal had before a language could be set, made
/// explicit — so a goal whose check-ins are in German is not suddenly briefed
/// in English for want of a setting.
const goalUnsetLanguageFactsLine =
    "the language of the user's own words in userVoice and messages; "
    'English when there are none';

/// [code] as a language Lotti supports, or null for a blank or unknown code —
/// a code a newer client wrote, or one typed into a synced row by hand, reads
/// as not set rather than reaching the model as a bare string.
SupportedLanguage? goalSupportedLanguage(String? code) {
  final trimmed = code?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) return null;
  return SupportedLanguage.fromCode(trimmed);
}

/// The language a goal agent writes in: the one the user [chosen] for the
/// goal, else its [journal] language, else unset.
GoalBriefingLanguage resolveGoalBriefingLanguage({
  required String? chosen,
  required String? journal,
}) {
  if (goalSupportedLanguage(chosen) case final language?) {
    return GoalBriefingLanguage._(language, GoalBriefingLanguageSource.chosen);
  }
  if (goalSupportedLanguage(journal) case final language?) {
    return GoalBriefingLanguage._(
      language,
      GoalBriefingLanguageSource.journal,
    );
  }
  return const GoalBriefingLanguage._(null, GoalBriefingLanguageSource.unset);
}

/// The journal language to suggest in place of the one the user [chosen], or
/// null when there is nothing to suggest.
///
/// A goal that follows its journal needs no suggestion — it already changes
/// with it. Only a language picked by hand can fall behind the journal, and
/// then the edit page offers the journal's: never applied by itself, because
/// the pick was the user's.
SupportedLanguage? goalBriefingLanguageSuggestion({
  required String? chosen,
  required String? journal,
}) {
  final picked = goalSupportedLanguage(chosen);
  final journalLanguage = goalSupportedLanguage(journal);
  if (picked == null || journalLanguage == null) return null;
  return picked == journalLanguage ? null : journalLanguage;
}
