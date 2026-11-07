import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';

/// The inference setup a subject's agent — a person's or a goal's — starts
/// with: a `categorySnapshot` of the profile its category names, as a task's
/// agent takes its category default (`assignCategoryDefaultTaskAgent`). The
/// copy only records where the agent came from — such a setup follows its
/// category (`AgentInferenceSetup.followsCategory`), so a later change to the
/// category's profile moves the agent on its next run, until the user picks
/// a profile or a model for it in the setup sheet.
///
/// Null when there is no category or the category names no profile. Unlike a
/// task's, such an agent is not created switched off: it keeps its kind's
/// own resolution — the Settings default — rather than a disabled setup,
/// because a person's or a goal's agent was always created running.
Future<AgentInferenceSetup?> categorySnapshotSetup({
  required String? categoryId,
  required CategoryProfileLookup lookup,
}) async {
  if (categoryId == null) return null;
  final profileId = await lookup(categoryId);
  if (profileId == null) return null;
  return AgentInferenceSetup(
    mode: AgentInferenceSetupMode.configured,
    origin: AgentInferenceSetupOrigin.categorySnapshot,
    baseProfileId: profileId,
    originEntityId: categoryId,
  );
}
