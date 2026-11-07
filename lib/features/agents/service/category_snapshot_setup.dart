import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';

/// The setup of an agent that takes its category's default rather than a
/// profile the user picked for it: it follows [categoryId]
/// (`AgentInferenceSetup.followsCategory`), so every run resolves what the
/// category names then, else the Settings default — also when the category
/// names nothing yet, or the agent has no category at all.
///
/// [profileId] records what the category named when the setup was written,
/// for the legacy mirror and older clients; it never decides a run. The setup
/// is always configured: an agent the user has not touched runs on the
/// default, it is never created switched off.
AgentInferenceSetup categoryFollowingSetup({
  required String? categoryId,
  String? profileId,
}) => AgentInferenceSetup(
  mode: AgentInferenceSetupMode.configured,
  origin: AgentInferenceSetupOrigin.categorySnapshot,
  baseProfileId: profileId,
  originEntityId: categoryId,
);

/// The inference setup a subject's agent — a person's or a goal's — starts
/// with: [categoryFollowingSetup] for its category, as a task's agent takes
/// its category default (`assignCategoryDefaultTaskAgent`), until the user
/// picks a profile or a model for it in the setup sheet.
///
/// Null for a subject in no category: such an agent keeps its kind's own
/// standalone resolution, which ends on the Settings default too.
Future<AgentInferenceSetup?> categorySnapshotSetup({
  required String? categoryId,
  required CategoryProfileLookup lookup,
}) async {
  if (categoryId == null) return null;
  return categoryFollowingSetup(
    categoryId: categoryId,
    profileId: await lookup(categoryId),
  );
}
