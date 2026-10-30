/// Which of the agent's own observations a goal wake reads (ADR 0057,
/// ADR 0146).
///
/// The newest [goalObservationLookback] always; beyond them, every critical
/// one the bounded window still holds, within [goalCriticalObservationTokenBudget].
/// Recency alone let an injury or a doctor's advice noted months ago fall out
/// of every wake once a dozen routine notes had been written since — exactly
/// the facts a coach must never forget.
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

/// Tokens the older critical observations may take beside the recent ones.
const goalCriticalObservationTokenBudget = 400;

/// The observations a wake reads, newest first, from [recalled] (newest
/// first, as `recallAgentObservations` returns them).
List<GoalObservationFact> goalObservationSelection(
  List<RecalledObservation> recalled, {
  int lookback = goalObservationLookback,
  int criticalBudget = goalCriticalObservationTokenBudget,
}) {
  GoalObservationFact fact(RecalledObservation observation) => (
    recordedAt: observation.at,
    text: observation.text,
    critical: observation.priority == ObservationPriority.critical,
  );

  final selected = [for (final o in recalled.take(lookback)) fact(o)];
  var spent = 0;
  for (final observation in recalled.skip(lookback)) {
    if (observation.priority != ObservationPriority.critical) continue;
    final cost = TextChunker.estimateTokens(observation.text);
    if (spent + cost > criticalBudget) break;
    spent += cost;
    selected.add(fact(observation));
  }
  return selected;
}

/// Reads and selects a goal wake's observations.
Future<List<GoalObservationFact>> goalObservationFacts(
  AgentRepository repository,
  String agentId,
) async => goalObservationSelection(
  await recallAgentObservations(
    repository,
    agentId,
    limit: goalCriticalObservationWindow,
  ),
);
