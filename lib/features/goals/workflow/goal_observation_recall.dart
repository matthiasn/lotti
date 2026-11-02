/// Which of the agent's own observations a goal wake reads (ADR 0057,
/// ADR 0146).
///
/// The newest [goalObservationLookback] always; beyond them, every critical
/// one the bounded window still holds, within [goalCriticalObservationTokenBudget].
/// Recency alone let an injury or a doctor's advice noted months ago fall out
/// of every wake once a dozen routine notes had been written since — exactly
/// the facts a coach must never forget. The rest of its notes reach a wake
/// condensed, a digest per finished month ([goalObservationMemory], ADR 0156).
library;

import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/goals/workflow/goal_facts_renderer.dart';

/// How many recent observations feed the FACTS block.
const goalObservationLookback = 12;

/// How far back critical observations are looked for: a bounded read, not
/// the whole log.
const goalCriticalObservationWindow = 200;

/// How many observations a wake reads for its month digests.
const goalObservationMemoryWindow = 1000;

/// What a wake remembers of its own notes: the [goalObservationSelection]
/// verbatim, and the older ones as month digests.
typedef GoalObservationMemory = ({
  List<GoalObservationFact> recent,
  List<GoalObservationDigestFact> digests,
});

/// Writes and picks the month digests of a wake, given its observation
/// window (newest first) and the ids it already shows verbatim.
typedef GoalObservationDigester =
    Future<List<GoalObservationDigestFact>> Function(
      List<RecalledObservation> recalled,
      Set<String> shownVerbatim,
    );

/// Tokens the older critical observations may take beside the recent ones.
const goalCriticalObservationTokenBudget = 400;

/// The observations a wake reads, newest first, from [recalled] (newest
/// first, as `recallAgentObservations` returns them).
List<GoalObservationFact> goalObservationSelection(
  List<RecalledObservation> recalled, {
  int lookback = goalObservationLookback,
  int criticalBudget = goalCriticalObservationTokenBudget,
}) => [
  for (final observation in _selected(recalled, lookback, criticalBudget))
    (
      recordedAt: observation.at,
      text: observation.text,
      critical: observation.priority == ObservationPriority.critical,
    ),
];

List<RecalledObservation> _selected(
  List<RecalledObservation> recalled,
  int lookback,
  int criticalBudget,
) {
  final selected = [...recalled.take(lookback)];
  var spent = 0;
  for (final observation
      in recalled.take(goalCriticalObservationWindow).skip(lookback)) {
    if (observation.priority != ObservationPriority.critical) continue;
    final cost = TextChunker.estimateTokens(observation.text);
    if (spent + cost > criticalBudget) break;
    spent += cost;
    selected.add(observation);
  }
  return selected;
}

/// Reads a goal wake's observations once: the selection verbatim, and —
/// with a [digester] — the month digests of the rest.
Future<GoalObservationMemory> goalObservationMemory(
  AgentRepository repository,
  String agentId, {
  GoalObservationDigester? digester,
}) async {
  final recalled = await recallAgentObservations(
    repository,
    agentId,
    limit: digester == null
        ? goalCriticalObservationWindow
        : goalObservationMemoryWindow,
  );
  final selected = _selected(
    recalled,
    goalObservationLookback,
    goalCriticalObservationTokenBudget,
  );
  return (
    recent: goalObservationSelection(selected, lookback: selected.length),
    digests: digester == null
        ? const <GoalObservationDigestFact>[]
        : await digester(recalled, {for (final o in selected) o.id}),
  );
}
