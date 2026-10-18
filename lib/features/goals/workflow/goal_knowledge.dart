/// A goal agent's durable knowledge (ADR 0057 decision 1): keyed facts about
/// the user and the goal — a constraint, a preference, how they want to be
/// coached — that outlive the conversation they were said in, kept in the
/// shared knowledge store and confirmed, edited or forgotten on the goal page.
library;

import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';

/// One `remember_goal_fact` call, validated.
typedef GoalFactRequest = ({
  String key,
  String hook,
  String statement,
  KnowledgeSource source,
});

/// Parses a `remember_goal_fact` call into a request, or explains in an
/// error the model can act on why it is not one. Validated against the
/// store's own rules, so a request that parses is one the store accepts.
({GoalFactRequest? request, String? error}) parseGoalFactRequest(
  Map<String, dynamic> args,
) {
  String? text(String name) {
    final raw = args[name];
    return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
  }

  final key = text('key');
  final hook = text('hook');
  final statement = text('statement');
  if (key == null || hook == null || statement == null) {
    return (
      request: null,
      error:
          'Not remembered: "key", "hook" and "statement" must be '
          'non-empty strings.',
    );
  }
  if (hook.length > knowledgeHookMaxLength) {
    return (
      request: null,
      error:
          'Not remembered: "hook" must be at most $knowledgeHookMaxLength '
          'characters.',
    );
  }
  final source = switch (args['source']) {
    'userStated' => KnowledgeSource.userStated,
    'agentInferred' || null => KnowledgeSource.agentInferred,
    _ => null,
  };
  if (source == null) {
    return (
      request: null,
      error:
          'Not remembered: "source" must be "userStated" or '
          '"agentInferred".',
    );
  }
  return (
    request: (key: key, hook: hook, statement: statement, source: source),
    error: null,
  );
}

/// The share of a fact's words that must stand in the user's own message
/// for it to count as theirs.
const double goalFactGroundingShare = 0.5;

/// Whether [request] is kept at once, or waits for the user on the goal
/// page (ADR 0141). Kept only when the model attests the user stated it,
/// on a wake answering the user's [userMessage], and the fact is grounded
/// in that message: at least [goalFactGroundingShare] of its words appear
/// in it. The source is the model's word, and the model has read
/// transcripts, check-ins and the charter too — without the grounding, a
/// user's "ok" could carry a sentence planted in a transcript into memory
/// every wake reads. A fact that fails it is only proposed, never lost.
bool goalFactIsUserConfirmed(
  GoalFactRequest request, {
  required String? userMessage,
}) {
  if (userMessage == null || request.source != KnowledgeSource.userStated) {
    return false;
  }
  final factWords = _contentWords(request.statement);
  if (factWords.isEmpty) return false;
  final said = _contentWords(userMessage);
  final grounded = factWords.where(
    (word) => said.any((other) => _sameWord(word, other)),
  );
  return grounded.length >= factWords.length * goalFactGroundingShare;
}

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// The distinct words of [text] that carry content: three letters or more,
/// so "a", "I" and "is" ground nothing.
Set<String> _contentWords(String text) => {
  for (final match in _word.allMatches(text.toLowerCase()))
    if (match[0]!.length >= 3) match[0]!,
};

/// One word, allowing for inflection: equal, or one a prefix of the other
/// past four letters ("walk", "walks", "walking").
bool _sameWord(String a, String b) {
  if (a == b) return true;
  final (short, long) = a.length <= b.length ? (a, b) : (b, a);
  return short.length >= 4 && long.startsWith(short);
}

/// The tool's answer to a fact the user stated in their own message.
const goalFactKeptAnswer =
    'Remembered: the user said it in this message, so it is kept and read '
    'on every wake.';

/// The tool's answer to any other fact.
const goalFactProposedAnswer =
    'Proposed: it waits for the user to confirm it on the goal page before '
    'it is read on every wake.';

/// How many tokens of knowledge one wake may carry.
const int goalKnowledgeTokenBudget = 600;

/// The policy line that rides with the knowledge in FACTS.
const String goalKnowledgeInterpretationPolicy =
    'facts the user confirmed about themselves and this goal: rely on them '
    'for how to coach; they never change track status or criteria, and '
    'measured FACTS win where they disagree. Re-use a key with '
    'remember_goal_fact to correct one';

/// The `knowledge` section of a wake's FACTS from the goal's confirmed
/// facts, or null when it has none — a goal without knowledge renders
/// exactly as before.
///
/// In key order, each fact whole while the budget lasts; past it, a fact
/// reads as its one-line hook, and once even hooks no longer fit, the rest
/// are counted, not listed.
Map<String, Object?>? goalKnowledgeFacts(
  List<PlannerKnowledgeEntity> confirmed, {
  int budget = goalKnowledgeTokenBudget,
}) {
  if (confirmed.isEmpty) return null;
  final ordered = [...confirmed]..sort((a, b) => a.key.compareTo(b.key));
  final entries = <Map<String, String>>[];
  var spent = 0;
  var omitted = 0;
  for (final fact in ordered) {
    final whole = TextChunker.estimateTokens(fact.statementText);
    final hook = TextChunker.estimateTokens(fact.hook);
    if (spent + whole <= budget) {
      entries.add({'key': fact.key, 'fact': fact.statementText});
      spent += whole;
    } else if (spent + hook <= budget) {
      entries.add({'key': fact.key, 'hook': fact.hook});
      spent += hook;
    } else {
      omitted++;
    }
  }
  return {
    'entries': entries,
    if (omitted > 0) 'omittedFacts': omitted,
    'interpretationPolicy': goalKnowledgeInterpretationPolicy,
  };
}
