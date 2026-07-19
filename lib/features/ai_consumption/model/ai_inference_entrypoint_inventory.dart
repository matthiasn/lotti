import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';

/// Attribution guarantee enforced at a production inference entry point.
enum AiAttributionCoverage {
  /// A durable pending session exists before the backend call and the output
  /// is blocked until interaction evidence crossed the publication barrier.
  strictPublicationSaga,

  /// Durable pending state and terminal evidence surround the backend call,
  /// while the funnel explicitly records that no syncable output carrier is
  /// available yet.
  durablePartialCapture,

  /// Development-only verification/evaluation and therefore not product data.
  developmentOnly,
}

/// Auditable inventory row for every production-level AI call funnel.
class AiInferenceEntrypoint {
  const AiInferenceEntrypoint({
    required this.id,
    required this.owner,
    required this.workTypes,
    required this.coverage,
    required this.outputCarrier,
  });

  final String id;
  final String owner;
  final Set<AiWorkType> workTypes;
  final AiAttributionCoverage coverage;
  final String? outputCarrier;
}

/// Source-controlled contract used during reviews whenever an inference call
/// is added or moved. Repository-level provider adapters are intentionally not
/// repeated: attribution belongs at these logical product-operation funnels.
const aiInferenceEntrypoints = <AiInferenceEntrypoint>[
  AiInferenceEntrypoint(
    id: 'skill-inference-runner',
    owner: 'lib/features/ai/services/skill_inference_runner.dart',
    workTypes: {
      AiWorkType.codingPrompt,
      AiWorkType.textGeneration,
      AiWorkType.imageGeneration,
      AiWorkType.imageAnalysis,
      AiWorkType.audioTranscription,
    },
    coverage: AiAttributionCoverage.strictPublicationSaga,
    outputCarrier: 'AiResponseData, ImageData, or AudioTranscript',
  ),
  AiInferenceEntrypoint(
    id: 'agent-wake-workflows',
    owner: 'lib/features/agents/workflow',
    workTypes: {AiWorkType.agentReport},
    coverage: AiAttributionCoverage.strictPublicationSaga,
    outputCarrier: 'AgentReportEntity.provenance',
  ),
  AiInferenceEntrypoint(
    id: 'agent-log-compaction',
    owner: 'lib/features/agents/service/agent_log_llm_summarizer.dart',
    workTypes: {AiWorkType.internalInference},
    coverage: AiAttributionCoverage.durablePartialCapture,
    outputCarrier: null,
  ),
  AiInferenceEntrypoint(
    id: 'unified-inference',
    owner: 'lib/features/ai/repository/unified_ai_inference_repository.dart',
    workTypes: {
      AiWorkType.codingPrompt,
      AiWorkType.textGeneration,
      AiWorkType.imageAnalysis,
      AiWorkType.audioTranscription,
    },
    coverage: AiAttributionCoverage.strictPublicationSaga,
    outputCarrier: 'AiResponseData, ImageData, or AudioTranscript',
  ),
  AiInferenceEntrypoint(
    id: 'conversation-repository',
    owner: 'lib/features/ai/conversation/conversation_repository.dart',
    workTypes: {AiWorkType.internalInference},
    coverage: AiAttributionCoverage.durablePartialCapture,
    outputCarrier: null,
  ),
  AiInferenceEntrypoint(
    id: 'embedding-indexing',
    owner: 'lib/features/ai/service/embedding_processor.dart',
    workTypes: {AiWorkType.embeddingIndexing},
    coverage: AiAttributionCoverage.strictPublicationSaga,
    outputCarrier: 'EmbeddingStore vector set keyed by entity/content hash',
  ),
  AiInferenceEntrypoint(
    id: 'onboarding-task-structuring',
    owner:
        'lib/features/onboarding/services/onboarding_task_structuring_service.dart',
    workTypes: {AiWorkType.textGeneration},
    coverage: AiAttributionCoverage.durablePartialCapture,
    outputCarrier: null,
  ),
  AiInferenceEntrypoint(
    id: 'ai-chat',
    owner: 'lib/features/ai_chat',
    workTypes: {
      AiWorkType.textGeneration,
      AiWorkType.audioTranscription,
    },
    coverage: AiAttributionCoverage.durablePartialCapture,
    outputCarrier: null,
  ),
  AiInferenceEntrypoint(
    id: 'provider-verification-and-evals',
    owner: 'lib/features/ai/eval and AI settings verification services',
    workTypes: {AiWorkType.internalInference},
    coverage: AiAttributionCoverage.developmentOnly,
    outputCarrier: null,
  ),
];
