import 'dart:math' as math;

import 'package:lotti/database/title_search.dart';
import 'package:meta/meta.dart';

/// One project the matcher may suggest, as plain text — no entities, so the
/// matcher stays a pure function a test can drive without a database.
@immutable
class ProjectMatchCandidate {
  const ProjectMatchCandidate({
    required this.projectId,
    required this.title,
    this.description = '',
    this.taskTitles = const [],
  });

  final String projectId;

  /// The project's name — the strongest evidence a task belongs to it.
  final String title;

  /// The project's own description text.
  final String description;

  /// Titles of tasks already filed under the project: the vocabulary the
  /// user actually uses for its work, which the project's name alone rarely
  /// covers ("Garden" holds "Prune the roses" and "Order mulch").
  final List<String> taskTitles;
}

/// The task being matched: its title, body text and label names.
@immutable
class ProjectMatchTask {
  const ProjectMatchTask({
    required this.title,
    this.body = '',
    this.labels = const [],
  });

  final String title;
  final String body;
  final List<String> labels;
}

/// One project's relevance to a task. Higher is more relevant; only
/// positive scores are ever reported.
@immutable
class ProjectMatchScore {
  const ProjectMatchScore({required this.projectId, required this.score});

  final String projectId;
  final double score;

  @override
  bool operator ==(Object other) =>
      other is ProjectMatchScore &&
      other.projectId == projectId &&
      other.score == score;

  @override
  int get hashCode => Object.hash(projectId, score);

  @override
  String toString() => 'ProjectMatchScore($projectId, $score)';
}

/// Ranks a category's projects against a task's words, entirely on-device.
///
/// Built once per candidate set — the projects' vocabularies are tokenised
/// up front — so re-ranking after a title edit only tokenises the task. Every
/// operation is linear in the task's words and the candidates' names; the
/// task-history vocabulary is reached through hash lookups only.
///
/// ## Scoring
///
/// Words are lower-cased, accent-folded and split the way title search
/// splits them ([searchWords]), stop words are dropped and a light suffix
/// stemmer folds plurals and `-ing`/`-ed` forms. Each distinct task word
/// contributes once per project:
///
/// `taskFieldWeight × projectFieldWeight × similarity × specificity`
///
/// - **task field**: title [taskTitleWeight], labels [taskLabelWeight], body
///   [taskBodyWeight] — the strongest field the word appears in.
/// - **project field**: name [projectTitleWeight], description
///   [projectDescriptionWeight], earlier task titles [historyWeightFor] (a
///   word several of the project's tasks share counts more than a one-off).
/// - **similarity**: exact stem 1, typo ([fuzzySimilarity], trigram Dice ≥
///   [minFuzzyDice]) or prefix ([prefixSimilarity]) — the latter two only
///   against the project's name and description, never its task history,
///   which keeps a large history from turning into noise.
/// - **specificity**: a word every candidate shares tells them apart not at
///   all; it is weighted by how few projects use it.
///
/// A project whose name the task covers also earns up to
/// [titleCoverageBonus] for the share of its name's words the task says —
/// exactly or misspelt, never as a mere prefix — so "Work" outranks "Work
/// travel" for "Prepare work presentation", and "Plan workshop" alone does
/// not suggest "Work".
///
/// [suggest] stays quiet unless the best score reaches [minSuggestionScore]
/// and beats the runner-up by [ambiguityMargin]: a wrong suggestion costs
/// the user more than a missing one.
class ProjectSuggestionMatcher {
  factory ProjectSuggestionMatcher(Iterable<ProjectMatchCandidate> candidates) {
    final profiles = [
      for (final candidate in candidates) _ProjectProfile.of(candidate),
    ];
    final documentFrequency = <String, int>{};
    for (final profile in profiles) {
      for (final stem in profile.vocabulary.keys) {
        documentFrequency[stem] = (documentFrequency[stem] ?? 0) + 1;
      }
    }
    return ProjectSuggestionMatcher._(profiles, documentFrequency);
  }

  ProjectSuggestionMatcher._(this._profiles, this._documentFrequency);

  final List<_ProjectProfile> _profiles;
  final Map<String, int> _documentFrequency;

  static const double taskTitleWeight = 1;
  static const double taskLabelWeight = 0.75;
  static const double taskBodyWeight = 0.5;

  static const double projectTitleWeight = 3;
  static const double projectDescriptionWeight = 1;

  static const double fuzzySimilarity = 0.7;
  static const double prefixSimilarity = 0.6;
  static const double minFuzzyDice = 0.6;

  /// Words shorter than this take part only through exact matches.
  static const int minApproximateLength = 4;

  static const double titleCoverageBonus = 1;
  static const double minSuggestionScore = 2;
  static const double ambiguityMargin = 1.25;

  /// The body is read up to this many words: enough for the gist of a long
  /// note without letting a pasted document dominate the ranking.
  static const int maxBodyWords = 300;

  /// Weight of a word that [occurrences] of the project's earlier task titles
  /// share: 0.75 for a one-off, rising by 0.25 per repeat to 1.5.
  static double historyWeightFor(int occurrences) =>
      math.min(1.5, 0.75 + 0.25 * (occurrences - 1));

  /// Whether there is anything to rank against.
  bool get isEmpty => _profiles.isEmpty;

  /// Every candidate with a positive score, best first. Ties keep the
  /// candidates' order by id, so the result never depends on input order.
  List<ProjectMatchScore> rank(ProjectMatchTask task) {
    final taskStems = _taskStems(task);
    if (taskStems.isEmpty || _profiles.isEmpty) return const [];

    final scores = <ProjectMatchScore>[];
    for (final profile in _profiles) {
      final score = _score(profile, taskStems);
      if (score > 0) {
        scores.add(ProjectMatchScore(projectId: profile.id, score: score));
      }
    }
    scores.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.projectId.compareTo(b.projectId);
    });
    return scores;
  }

  /// The one project worth suggesting for [task], or null when none is
  /// clearly relevant: the best score is too low, or a second project scores
  /// within [ambiguityMargin] of it.
  ProjectMatchScore? suggest(ProjectMatchTask task) {
    final ranked = rank(task);
    if (ranked.isEmpty) return null;
    final best = ranked.first;
    if (best.score < minSuggestionScore) return null;
    if (ranked.length > 1 && best.score < ranked[1].score * ambiguityMargin) {
      return null;
    }
    return best;
  }

  double _score(_ProjectProfile profile, Map<String, double> taskStems) {
    var total = 0.0;
    final coveredTitleStems = <String>{};
    for (final MapEntry(key: stem, value: taskWeight) in taskStems.entries) {
      final match = _bestMatch(profile, stem);
      if (match == null) continue;
      total += taskWeight * match.weight * _specificity(match.projectStem);
      // A name word counts as covered when the task says it — exactly or
      // misspelt — but not when the task only says a longer word starting
      // with it: "workshop" is not the project "Work".
      if (match.similarity >= fuzzySimilarity &&
          profile.titleStems.contains(match.projectStem)) {
        coveredTitleStems.add(match.projectStem);
      }
    }
    if (coveredTitleStems.isNotEmpty) {
      total +=
          titleCoverageBonus *
          coveredTitleStems.length /
          profile.titleStems.length;
    }
    return total;
  }

  /// The strongest way [stem] matches [profile]: exactly against any field,
  /// else approximately against the name and description.
  _Match? _bestMatch(_ProjectProfile profile, String stem) {
    final exact = profile.vocabulary[stem];
    if (exact != null) {
      return (projectStem: stem, weight: exact, similarity: 1);
    }
    if (stem.length < minApproximateLength) return null;

    _Match? best;
    final stemTrigrams = _trigrams(stem);
    for (final MapEntry(key: nameStem, value: fieldWeight)
        in profile.nameVocabulary.entries) {
      if (nameStem.length < minApproximateLength) continue;
      final similarity = _approximateSimilarity(
        stem,
        stemTrigrams,
        nameStem,
        profile.trigramsOf(nameStem),
      );
      if (similarity == 0) continue;
      final weight = fieldWeight * similarity;
      if (best == null || weight > best.weight) {
        best = (projectStem: nameStem, weight: weight, similarity: similarity);
      }
    }
    return best;
  }

  static double _approximateSimilarity(
    String a,
    Set<String> aTrigrams,
    String b,
    Set<String> bTrigrams,
  ) {
    if (_dice(aTrigrams, bTrigrams) >= minFuzzyDice) return fuzzySimilarity;
    final (shorter, longer) = a.length <= b.length ? (a, b) : (b, a);
    if (longer.startsWith(shorter)) return prefixSimilarity;
    return 0;
  }

  /// 1 for a word only one candidate uses, falling towards 1/N for a word
  /// all N share. With a single candidate every word is fully specific.
  double _specificity(String stem) {
    final n = _profiles.length;
    if (n <= 1) return 1;
    final df = _documentFrequency[stem] ?? 1;
    return (n - df + 1) / n;
  }

  static Map<String, double> _taskStems(ProjectMatchTask task) {
    final stems = <String, double>{};
    void add(Iterable<String> words, double weight) {
      for (final word in words) {
        final stem = stemWord(word);
        if (stem == null) continue;
        final current = stems[stem];
        if (current == null || weight > current) stems[stem] = weight;
      }
    }

    add(searchWords(task.title), taskTitleWeight);
    for (final label in task.labels) {
      add(searchWords(label), taskLabelWeight);
    }
    add(searchWords(task.body).take(maxBodyWords), taskBodyWeight);
    return stems;
  }
}

/// Folds an already lower-cased, accent-folded [word] to the stem the
/// matcher compares, or null for a word that carries no topic: a stop word,
/// a single character, or a bare number.
///
/// The stemmer is deliberately light — plurals, `-ing` and `-ed` — so it
/// never merges two genuinely different words; typos and other inflections
/// are left to the trigram comparison.
@visibleForTesting
String? stemWord(String word) {
  if (word.length < 2 || _stopWords.contains(word)) return null;
  if (_digitsOnly.hasMatch(word)) return null;
  if (word.length > 4 && word.endsWith('ies')) {
    return '${word.substring(0, word.length - 3)}y';
  }
  if (word.length >= 6 && word.endsWith('ing')) {
    return _undoubled(word.substring(0, word.length - 3));
  }
  if (word.length >= 5 && word.endsWith('ed') && !word.endsWith('eed')) {
    return _undoubled(word.substring(0, word.length - 2));
  }
  if (word.length >= 4 &&
      word.endsWith('s') &&
      !word.endsWith('ss') &&
      !word.endsWith('us') &&
      !word.endsWith('is')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// How a task word met a project: the project's stem it matched, the field
/// weight times the similarity, and the similarity alone.
typedef _Match = ({String projectStem, double weight, double similarity});

/// Drops the consonant an `-ing`/`-ed` ending doubled ("runn" → "run",
/// "plann" → "plan"), keeping the doubles English writes in the base word
/// itself ("roll", "pass", "buzz") and short stems that are whole words
/// ("add", "egg").
String _undoubled(String stem) {
  if (stem.length < 4) return stem;
  final last = stem[stem.length - 1];
  if (last != stem[stem.length - 2]) return stem;
  if ('aeiouylsz'.contains(last)) return stem;
  return stem.substring(0, stem.length - 1);
}

final _digitsOnly = RegExp(r'^\p{N}+$', unicode: true);

/// Function words of the languages the app ships in most, accent-folded the
/// way [searchWords] folds them. Without them a project whose tasks say
/// "the" and "for" would match every task that does too.
const _stopWords = <String>{
  // English
  'a', 'an', 'the', 'and', 'or', 'but', 'of', 'to', 'in', 'on', 'at', 'for',
  'with', 'by', 'from', 'up', 'out', 'about', 'into', 'over', 'after',
  'is', 'are', 'was', 'were', 'be', 'been', 'it', 'its', 'this', 'that',
  'these', 'those', 'my', 'our', 'your', 'me', 'we', 'you', 'i', 'he', 'she',
  'they', 'them', 'his', 'her', 'their', 'do', 'does', 'did', 'done', 'not',
  'no', 'yes', 'so', 'if', 'as', 'some', 'all', 'any', 'new', 'get', 'make',
  'via', 'per', 'etc', 'todo', 'task', 'tasks',
  // German
  'der', 'die', 'das', 'den', 'dem', 'des', 'ein', 'eine', 'einen', 'einem',
  'einer', 'und', 'oder', 'aber', 'zu', 'zum', 'zur', 'im', 'am', 'auf',
  'fur', 'mit', 'von', 'vom', 'bei', 'aus', 'nach', 'ist', 'sind', 'war',
  'mein', 'meine', 'unser', 'nicht', 'noch', 'auch', 'es', 'ich', 'wir',
  'sie', 'er', 'aufgabe',
  // French / Spanish / Italian / Portuguese basics ('an', 'per' and 'as'
  // are listed above already)
  'le', 'la', 'les', 'un', 'une', 'et', 'ou', 'du', 'pour', 'avec', 'el',
  'los', 'las', 'y', 'o', 'para', 'con', 'il', 'lo', 'gli', 'e', 'di',
  'da', 'os', 'um', 'uma', 'de',
};

Set<String> _trigrams(String stem) => titleTrigrams(stem);

double _dice(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final shared = a.intersection(b).length;
  return 2 * shared / (a.length + b.length);
}

/// A candidate's tokenised vocabulary, built once per matcher.
class _ProjectProfile {
  _ProjectProfile({
    required this.id,
    required this.vocabulary,
    required this.nameVocabulary,
    required this.titleStems,
  });

  factory _ProjectProfile.of(ProjectMatchCandidate candidate) {
    final vocabulary = <String, double>{};
    final nameVocabulary = <String, double>{};
    void put(Map<String, double> into, String stem, double weight) {
      final current = into[stem];
      if (current == null || weight > current) into[stem] = weight;
    }

    final titleStems = <String>{};
    for (final word in searchWords(candidate.title)) {
      final stem = stemWord(word);
      if (stem == null) continue;
      titleStems.add(stem);
      put(nameVocabulary, stem, ProjectSuggestionMatcher.projectTitleWeight);
    }
    for (final word in searchWords(candidate.description)) {
      final stem = stemWord(word);
      if (stem == null) continue;
      put(
        nameVocabulary,
        stem,
        ProjectSuggestionMatcher.projectDescriptionWeight,
      );
    }
    nameVocabulary.forEach((stem, weight) => put(vocabulary, stem, weight));

    // A word counts once per earlier task, however often that title says it.
    final occurrences = <String, int>{};
    for (final title in candidate.taskTitles) {
      final stems = {
        for (final word in searchWords(title)) ?stemWord(word),
      };
      for (final stem in stems) {
        occurrences[stem] = (occurrences[stem] ?? 0) + 1;
      }
    }
    occurrences.forEach(
      (stem, count) => put(
        vocabulary,
        stem,
        ProjectSuggestionMatcher.historyWeightFor(count),
      ),
    );

    return _ProjectProfile(
      id: candidate.projectId,
      vocabulary: vocabulary,
      nameVocabulary: nameVocabulary,
      titleStems: titleStems,
    );
  }

  final String id;

  /// Every stem of the name, description and task history, at the weight of
  /// the strongest field it appears in.
  final Map<String, double> vocabulary;

  /// The name and description stems only — the ones approximate matching
  /// compares against.
  final Map<String, double> nameVocabulary;
  final Set<String> titleStems;

  final Map<String, Set<String>> _trigramCache = {};

  Set<String> trigramsOf(String stem) =>
      _trigramCache[stem] ??= _trigrams(stem);
}
