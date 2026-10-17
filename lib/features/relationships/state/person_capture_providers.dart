import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/one_shot_text_generation.dart';
import 'package:lotti/features/journal/create/create_entry.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/person_capture_filer.dart';
import 'package:lotti/features/relationships/service/person_capture_sort_tool.dart';
import 'package:lotti/features/relationships/service/person_capture_sorter.dart';
import 'package:lotti/features/relationships/service/person_recording_summarizer.dart';
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

/// The most a one-line summary may answer with.
const personRecordingSummaryMaxTokens = 200;

/// Gives spoken check-ins their one-line summary, on the person's briefing
/// route — the sorter's — and saves it as the recording's audio summary.
final personRecordingSummarizerProvider = Provider<PersonRecordingSummarizer>(
  (ref) => PersonRecordingSummarizer(
    modelFor: (person) =>
        ref.read(personCaptureSorterProvider).modelFor(person),
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
                maxCompletionTokens: personRecordingSummaryMaxTokens,
                geminiThinkingMode: GeminiThinkingMode.minimal,
                reasoningEffort: ReasoningEffort.minimal,
                tools: const [personRecordingSummaryTool],
                toolChoice: personRecordingSummaryToolChoiceFor(model.modelId),
                attribution: OneShotGenerationAttribution(
                  workType: AiWorkType.audioSummary,
                  triggerType: AiTriggerType.automatic,
                  categoryId: categoryId,
                ),
              );
          return answer.toolCalls;
        },
    save:
        ({
          required audioId,
          required summary,
          required modelId,
          required categoryId,
        }) => ref
            .read(personTimelineRepositoryProvider)
            .saveRecordingSummary(
              audioId: audioId,
              summary: summary,
              modelId: modelId,
              categoryId: categoryId,
            ),
    hasSummary: (audioId) async {
      final linked = await ref
          .read(journalDbProvider)
          .getLinkedEntities(audioId);
      return linked.any(
        (entity) =>
            entity is AiResponseEntry &&
            entity.data.type == AiResponseType.audioSummary,
      );
    },
    logger: ref.watch(domainLoggerProvider),
  ),
  name: 'personRecordingSummarizerProvider',
);

/// Files what the user accepted from a spoken capture about a person.
final personCaptureFilerProvider = Provider<PersonCaptureFiler>(
  (ref) => PersonCaptureFiler(
    relationships: ref.watch(relationshipRepositoryProvider),
    timeline: ref.watch(personTimelineRepositoryProvider),
    createTask:
        ({
          required title,
          required due,
          required categoryId,
          required inheritContextFrom,
        }) async {
          final logger = ref.read(domainLoggerProvider);
          final agentService = ref.read(taskAgentServiceProvider);
          final task = await createTask(
            domainLogger: logger,
            title: title,
            due: due,
            categoryId: categoryId,
            inheritContextFrom: inheritContextFrom,
          );
          // The follow-up every other create path performs, so a task filed
          // from a capture is not the one left without its category's agent.
          if (task != null) {
            await autoAssignCategoryAgentWith(
              agentService,
              task,
              domainLogger: logger,
            );
          }
          return task;
        },
    link: ({required fromId, required toId}) => ref
        .read(persistenceLogicProvider)
        .createLink(fromId: fromId, toId: toId),
    logger: ref.watch(domainLoggerProvider),
  ),
  name: 'personCaptureFilerProvider',
);
