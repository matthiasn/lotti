import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/services/domain_logging.dart';

/// The model the front agent's own setup routes to (the owner's decision 8:
/// her own cheap setup for routing, so the prefix stays stable and cached;
/// a question walked through a door runs on the destination's setup).
typedef FrontModelResolution = ({
  String modelId,
  ResolvedAgentSetup setup,
  AiConfigInferenceProvider provider,
  GeminiThinkingMode? geminiThinkingMode,
});

/// The built-in route when nothing is configured: the cheapest hosted model
/// the task-agent scaffolds are tuned for, on whichever provider holds it —
/// Melious first, then Mistral, which serves the same model under its own
/// id. A setup with only one of them still gets an answer.
const List<String> frontAgentBuiltInModelIds = [
  meliousDeepseekV41FlashModelId,
  mistralDeepseekV41Flash1017ModelId,
];

/// Resolves the front agent's inference route through
/// [ProfileResolver.resolveStandalone]: an explicit typed setup is
/// authoritative (including disabled or broken); otherwise the identity's
/// profile, then the Settings default, then the built-in cheap model
/// ([frontAgentBuiltInModelIds], in order). No
/// category step — the front agent spans categories and must not inherit
/// one of them. Null when no route resolves.
Future<FrontModelResolution?> resolveFrontAgentModel({
  required AgentIdentityEntity agentIdentity,
  required AiConfigRepository aiConfigRepository,
  required DomainLogger domainLogger,
}) async {
  final resolver = ProfileResolver(
    aiConfigRepository: aiConfigRepository,
    domainLogger: domainLogger,
  );
  late ResolvedAgentSetup setup;
  for (final builtIn in frontAgentBuiltInModelIds) {
    setup = await resolver.resolveStandalone(
      agentConfig: agentIdentity.config,
      legacyModelId: builtIn,
    );
    // Only the built-in step tries the next provider: an explicit setup, a
    // profile or the Settings default answers the same for every id.
    if (setup.profile != null) break;
  }
  final profile = setup.profile;
  if (profile == null) return null;
  return (
    setup: setup,
    modelId: profile.thinkingModelId,
    provider: profile.thinkingProvider,
    geminiThinkingMode: profile.thinkingModel?.geminiThinkingMode,
  );
}
