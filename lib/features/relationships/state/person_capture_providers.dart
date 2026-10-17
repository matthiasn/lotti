import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/one_shot_text_generation.dart';
import 'package:lotti/features/relationships/service/person_capture_sort_tool.dart';
import 'package:lotti/features/relationships/service/person_capture_sorter.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_workflow.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:openai_dart/openai_dart.dart' show ReasoningEffort;

/// The most a sort may answer with: three items of a few lines each. A
/// model that runs past it is cut, not billed for pages.
const personCaptureSortMaxTokens = 1200;

/// Sorts spoken captures about a person on the route their briefing names.
final personCaptureSorterProvider = Provider<PersonCaptureSorter>(
  (ref) => PersonCaptureSorter(
    modelFor: (person) async {
      final identity = await ref
          .read(agentRepositoryProvider)
          .getEntity(relationshipAgentIdFor(person.meta.id));
      final resolved = await resolveRelationshipAgentModel(
        relationship: person,
        agentIdentity: identity is AgentIdentityEntity ? identity : null,
        aiConfigRepository: ref.read(aiConfigRepositoryProvider),
        domainLogger: ref.read(domainLoggerProvider),
        categoryProfileLookup: ref.read(
          relationshipCategoryProfileLookupProvider,
        ),
      );
      final profile = resolved?.setup.profile;
      if (resolved == null || profile == null) return null;
      return (
        modelId: resolved.modelId,
        provider: resolved.provider,
        route: InferenceRouteSnapshot.fromResolvedProfile(profile),
        supportsTools: profile.thinkingModel?.supportsFunctionCalling ?? true,
      );
    },
    generate:
        ({
          required prompt,
          required systemMessage,
          required model,
          required categoryId,
        }) async {
          final answer = await ref
              .read(cloudInferenceRepositoryProvider)
              .generateToolCalls(
                prompt: prompt,
                systemMessage: systemMessage,
                model: model.modelId,
                provider: model.provider,
                temperature: 0.2,
                maxCompletionTokens: personCaptureSortMaxTokens,
                geminiThinkingMode: GeminiThinkingMode.minimal,
                reasoningEffort: ReasoningEffort.minimal,
                tools: const [personCaptureSortTool],
                toolChoice: personCaptureSortToolChoiceFor(model.modelId),
                attribution: OneShotGenerationAttribution(
                  workType: AiWorkType.textGeneration,
                  categoryId: categoryId,
                ),
              );
          return answer.toolCalls;
        },
    logger: ref.watch(domainLoggerProvider),
  ),
  name: 'personCaptureSorterProvider',
);
