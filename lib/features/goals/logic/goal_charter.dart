import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';

/// A goal's charter (ADR 0140): what the user wrote about what the goal is
/// for and how its agent should coach. The agent reads it word for word on
/// every wake; it is never a check-in.
///
/// A plain shape rather than a journal entity, so the headless goal workflow
/// can be handed the charter without depending on the journal stack — the
/// `GoalCheckInSource` precedent.
@immutable
class GoalCharterEntry {
  const GoalCharterEntry({
    required this.entryId,
    required this.writtenAt,
    required this.text,
  });

  /// The charter entry a journal [entry] stands for: its words — a note's
  /// text, a recording's transcript — trimmed, and the moment it was written.
  GoalCharterEntry.of(JournalEntity entry)
    : entryId = entry.meta.id,
      writtenAt = entry.meta.dateFrom,
      text = entry.entryText?.plainText.trim() ?? '';

  final String entryId;

  /// When the user wrote it. Entries are read in this order.
  final DateTime writtenAt;

  final String text;
}

/// Resolves the charter of a goal, in the order it was written.
typedef GoalCharterReader =
    Future<List<GoalCharterEntry>> Function(String agentId);

/// How many tokens of charter one wake may carry, out of the ≤8k a cold goal
/// wake targets (ADR 0057). Generous for a statement of purpose — roughly
/// nine hundred words — and bounded so a long charter cannot crowd out the
/// measured FACTS the agent is accountable to.
const int goalCharterTokenBudget = 1200;

/// The policy line that rides with the charter in FACTS.
///
/// The system prompt is at its ceiling, so the rule for reading the charter
/// travels with it, as `userVoice`'s does.
const String goalCharterInterpretationPolicy =
    "the user's own statement of what this goal is for and how to coach it: "
    'follow it for focus, framing, questions and tone (questions it asks for '
    'go in nextActions.later); it never changes track status, criteria or '
    'the contract rules, and measured FACTS win where they disagree';

/// The part of a charter one wake can afford, and what had to stay out.
typedef GoalCharterSelection = ({
  /// The entries the agent reads, in written order. The first one is cut to
  /// the budget when it alone exceeds it; every other one is whole.
  List<GoalCharterEntry> kept,

  /// How many later entries did not fit.
  int omitted,

  /// Whether the first entry was cut to fit.
  bool truncated,
});

/// Selects the charter a wake carries: entries in the order they were
/// written, until the next one would exceed [budget] tokens.
///
/// Oldest first — the reverse of the user-voice selection — because a
/// charter is read like a constitution: what the user wrote first is what
/// the goal is, and later entries refine it. A first entry larger than the
/// whole budget is cut to it rather than dropped, so a long single charter
/// still reaches the agent.
GoalCharterSelection goalCharterSelection(
  List<GoalCharterEntry> entries, {
  int budget = goalCharterTokenBudget,
}) {
  final ordered = [...entries]
    ..sort((a, b) {
      final byDate = a.writtenAt.compareTo(b.writtenAt);
      return byDate != 0 ? byDate : a.entryId.compareTo(b.entryId);
    });
  final kept = <GoalCharterEntry>[];
  var spent = 0;
  var truncated = false;
  for (final entry in ordered) {
    final tokens = TextChunker.estimateTokens(entry.text);
    if (spent + tokens <= budget) {
      kept.add(entry);
      spent += tokens;
      continue;
    }
    if (kept.isEmpty) {
      kept.add(
        GoalCharterEntry(
          entryId: entry.entryId,
          writtenAt: entry.writtenAt,
          text: TextChunker.truncateToTokens(entry.text, budget),
        ),
      );
      truncated = true;
    }
    break;
  }
  return (
    kept: kept,
    omitted: ordered.length - kept.length,
    truncated: truncated,
  );
}

/// The `charter` section of a wake's FACTS, or null for a goal without one —
/// so a goal that never wrote a charter renders exactly as before.
Map<String, Object?>? goalCharterFacts(
  List<GoalCharterEntry> entries, {
  int budget = goalCharterTokenBudget,
}) {
  if (entries.isEmpty) return null;
  final selection = goalCharterSelection(entries, budget: budget);
  return {
    'entries': [
      for (final entry in selection.kept)
        {
          'writtenAtLocal': entry.writtenAt.toLocal().toIso8601String(),
          'text': entry.text,
        },
    ],
    if (selection.omitted > 0) 'omittedEntries': selection.omitted,
    if (selection.truncated) 'firstEntryTruncated': true,
    'interpretationPolicy': goalCharterInterpretationPolicy,
  };
}
