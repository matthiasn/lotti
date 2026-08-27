import 'dart:convert';

import 'package:lotti/features/agents/projection/compaction_plan.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';

/// How many tokens of the user's own voice one wake may carry.
///
/// A goal wake targets ≤8k input tokens on a cold prefill (ADR 0057), and the
/// deterministic FACTS already own most of that. This is the slice left for
/// what the user actually said.
const int goalUserVoiceTokenBudget = 1200;

/// Selects and renders the check-in summaries a wake can afford.
///
/// Bounded by TOKENS, not by count, using the same pure `planCompaction` split
/// the agent log uses: the oldest summaries fall away first and the most
/// recent one is always kept, even if it alone exceeds the budget. A check-in
/// the user recorded five minutes ago is the one thing the agent must not
/// miss.
///
/// Rendered oldest-last so the model reads toward the present, matching the
/// rest of the FACTS block.
List<Map<String, Object?>> goalUserVoiceEntries(
  List<GoalCheckInSummary> summaries, {
  int budget = goalUserVoiceTokenBudget,
}) {
  if (summaries.isEmpty) return const [];

  final chronological = [...summaries]
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  final plan = planCompaction(
    tail: [
      for (final summary in chronological)
        TailEntry(
          id: summary.id,
          tokens: TextChunker.estimateTokens(_renderForBudget(summary)),
        ),
    ],
    budget: budget,
  );

  final kept = plan.keepIds.toSet();
  return [
    for (final summary in chronological)
      if (kept.contains(summary.id)) goalUserVoiceEntry(summary),
  ];
}

/// The policy line that rides with the block.
///
/// Without it a cheerful check-in reads as evidence, and a model asked to
/// weigh "I felt great about it" against a measured miss will sometimes pick
/// the feeling. The deterministic results are the verdict; this is context for
/// coaching and for noticing what the user committed to.
const String goalUserVoiceInterpretationPolicy =
    "the user's own words inform coaching and record what they committed "
    'to; they never override deterministic criterion results';

/// The wire shape of one verbatim check-in inside the `userVoice` block.
///
/// Shared by every compaction strategy, so a strategy can only change WHICH
/// check-ins the agent sees, never how a kept one reads.
Map<String, Object?> goalUserVoiceEntry(GoalCheckInSummary summary) =>
    <String, Object?>{
      // The date is load-bearing: "you said on Tuesday you would walk after
      // lunch" is only sayable if it survives compaction.
      'recordedAtLocal': summary.recordedAt.toLocal().toIso8601String(),
      'sourceEntryId': summary.sourceEntryId,
      'whatHappened': summary.whatHappened,
      if (summary.committedTo != null) 'committedTo': summary.committedTo,
      if (summary.blockers != null) 'blockers': summary.blockers,
      if (summary.mood != null) 'mood': summary.mood,
      if (summary.asks != null) 'asks': summary.asks,
    };

/// Estimates against the JSON actually emitted, keys and all.
///
/// Estimating from the values alone under-counted every key and the entry id —
/// an opaque string longer than several of the values — so the selected set
/// could exceed the budget it was chosen to fit, by more the more entries were
/// retained.
String _renderForBudget(GoalCheckInSummary summary) =>
    jsonEncode(goalUserVoiceEntry(summary));
