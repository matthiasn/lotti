import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:openai_dart/openai_dart.dart';

/// Widens the task agent's tool surface as a wake proceeds.
///
/// A wake advertises every enabled tool on every turn, so the opening request
/// carries the whole registry whether or not the wake will use any of it. The
/// lean-payload probe measured what that costs the models most likely to run
/// locally: Qwen3.6 27B went from 10/14 to 13/14 on the scenario suite purely
/// as the prompt shrank, while the frontier models were unaffected at 14/14.
///
/// The opening turn is narrowed to the tools that change the task, and
/// `update_report` is withheld until the second turn. Two reasons:
///
/// * **Get to the work first.** The shipped directive is evidence-first —
///   establish what changed, then report it. A model that can publish on turn
///   one can satisfy the wake protocol before looking at anything, and weaker
///   models do exactly that.
/// * **It costs nothing.** The turns already exist. This changes which tools
///   each one advertises, not how many round trips a wake makes.
///
/// A wake with genuinely nothing to do is unaffected: finishing with a
/// plain-text note and no tool call is available on the first turn, and is
/// still the correct ending.
///
/// The one case that pays a turn is a report-only wake, where nothing needs
/// changing but the report does. That model must wait for turn two to publish.
/// Whether that trade is worth it is a measurement, not an assumption, which is
/// why this is opt-in.
class TaskAgentStagedToolExposure {
  TaskAgentStagedToolExposure({
    required this.allTools,
    Set<String>? openingTurnExclusions,
  }) : openingTurnExclusions =
           openingTurnExclusions ?? defaultOpeningTurnExclusions;

  /// Every tool the wake would otherwise advertise on every turn.
  final List<ChatCompletionTool> allTools;

  /// Tool names withheld from the opening turn only.
  final Set<String> openingTurnExclusions;

  /// Withheld on turn one: publishing before doing the work.
  ///
  /// `record_observations` is deliberately *not* here. Observations are the
  /// agent's private notes for later wakes rather than user-visible output, and
  /// a model that wants to note something on its first turn should be able to.
  static const defaultOpeningTurnExclusions = <String>{
    TaskAgentToolNames.updateReport,
  };

  /// The tools to advertise for [turnIndex], zero-based.
  ///
  /// Returns the full list from the second turn onward, so nothing is
  /// permanently unreachable and a wake can always finish its report.
  List<ChatCompletionTool> toolsForTurn(int turnIndex) {
    if (turnIndex > 0) return allTools;
    return [
      for (final tool in allTools)
        if (!openingTurnExclusions.contains(tool.function.name)) tool,
    ];
  }
}
