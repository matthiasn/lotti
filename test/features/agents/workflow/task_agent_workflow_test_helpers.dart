import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';

// ── Mock conversation repository hierarchy ───────────────────────────────────

/// Minimal mock of [ConversationRepository] that avoids Riverpod build().
///
/// ConversationRepository is a Riverpod notifier, so we extend it directly and
/// override the methods the workflow calls rather than using `Mock`.
class MockConversationRepository extends ConversationRepository {
  MockConversationRepository(this._mockManager);

  final MockConversationManager _mockManager;
  final List<String> deletedConversationIds = [];

  /// Delegate for sendMessage — set in tests to control behavior.
  Future<InferenceUsage?> Function({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    double temperature,
    ConversationStrategy? strategy,
  })?
  sendMessageDelegate;

  @override
  void build() {
    // No-op for test mock.
  }

  @override
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    return 'test-conv-id';
  }

  @override
  ConversationManager? getConversation(String conversationId) {
    return _mockManager;
  }

  @override
  void deleteConversation(String conversationId) {
    deletedConversationIds.add(conversationId);
  }

  @override
  Future<InferenceUsage?> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    double temperature = 0.7,
    ConversationStrategy? strategy,
  }) async {
    if (sendMessageDelegate != null) {
      return sendMessageDelegate!(
        conversationId: conversationId,
        message: message,
        model: model,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: temperature,
        strategy: strategy,
      );
    }
    return null;
  }
}

/// Like [MockConversationRepository] but captures the system message passed
/// to createConversation.
class CapturingConversationRepository extends MockConversationRepository {
  // ignore: use_super_parameters
  CapturingConversationRepository(
    MockConversationManager mockManager, {
    required this.onSystemMessage,
  }) : super(mockManager);

  final void Function(String?) onSystemMessage;

  @override
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    onSystemMessage(systemMessage);
    return 'test-conv-id';
  }
}

/// Like [MockConversationRepository] but returns null from getConversation,
/// simulating a scenario where the conversation was already cleaned up.
class NullManagerConversationRepository extends MockConversationRepository {
  // ignore: use_super_parameters
  NullManagerConversationRepository(MockConversationManager mockManager)
    : super(mockManager);

  @override
  ConversationManager? getConversation(String conversationId) => null;
}

// ── Common stub helpers ──────────────────────────────────────────────────────

/// Stubs the minimal set of dependencies needed to reach the "resolve provider"
/// step in [TaskAgentWorkflow.execute]. Most error-path tests share this setup.
void stubPreExecuteDefaults({
  required MockAgentRepository mockAgentRepository,
  required MockAiInputRepository mockAiInputRepository,
  required AgentStateEntity testAgentState,
  required String agentId,
  required String taskId,
}) {
  when(
    () => mockAgentRepository.getAgentState(agentId),
  ).thenAnswer((_) async => testAgentState);
  when(
    () => mockAgentRepository.getLatestReport(agentId, 'current'),
  ).thenAnswer((_) async => null);
  when(
    () => mockAgentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    ),
  ).thenAnswer((_) async => []);
  when(
    () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
  ).thenAnswer((_) async => '{"title":"Test Task"}');
  when(
    () => mockAiInputRepository.buildLinkedTasksJson(taskId),
  ).thenAnswer((_) async => '{}');
  when(
    () => mockAiInputRepository.buildProjectContextJsonForTask(taskId),
  ).thenAnswer((_) async => '{}');
}

/// Extends [stubPreExecuteDefaults] with the model/provider stubs needed for
/// a successful execute path (including the conversation).
void stubFullExecutePath({
  required MockAgentRepository mockAgentRepository,
  required MockAiInputRepository mockAiInputRepository,
  required MockAiConfigRepository mockAiConfigRepository,
  required MockConversationManager mockConversationManager,
  required AgentStateEntity testAgentState,
  required AiConfigModel geminiModel,
  required AiConfigInferenceProvider geminiProvider,
  required String agentId,
  required String taskId,
}) {
  stubPreExecuteDefaults(
    mockAgentRepository: mockAgentRepository,
    mockAiInputRepository: mockAiInputRepository,
    testAgentState: testAgentState,
    agentId: agentId,
    taskId: taskId,
  );
  when(
    () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
  ).thenAnswer((_) async => [geminiModel]);
  when(
    () => mockAiConfigRepository.getConfigById(geminiModel.inferenceProviderId),
  ).thenAnswer((_) async => geminiProvider);
  when(
    () => mockAgentRepository.getReportHead(agentId, 'current'),
  ).thenAnswer((_) async => null);
  when(() => mockConversationManager.messages).thenReturn([]);
}

// ── Workflow factory ─────────────────────────────────────────────────────────

/// Creates a [TaskAgentWorkflow] with all standard mocks. Avoids repeating
/// the 12-parameter constructor in every test that needs a custom repo.
TaskAgentWorkflow createTestWorkflow({
  required MockAgentRepository agentRepository,
  required MockConversationRepository conversationRepository,
  required MockAiInputRepository aiInputRepository,
  required MockAiConfigRepository aiConfigRepository,
  required MockJournalDb journalDb,
  required MockCloudInferenceRepository cloudInferenceRepository,
  required MockJournalRepository journalRepository,
  required MockChecklistRepository checklistRepository,
  required MockLabelsRepository labelsRepository,
  required MockAgentSyncService syncService,
  required MockAgentTemplateService templateService,
  MockSoulDocumentService? soulDocumentService,
}) {
  return TaskAgentWorkflow(
    agentRepository: agentRepository,
    conversationRepository: conversationRepository,
    aiInputRepository: aiInputRepository,
    aiConfigRepository: aiConfigRepository,
    journalDb: journalDb,
    cloudInferenceRepository: cloudInferenceRepository,
    journalRepository: journalRepository,
    checklistRepository: checklistRepository,
    labelsRepository: labelsRepository,
    syncService: syncService,
    templateService: templateService,
    soulDocumentService: soulDocumentService,
  );
}

// ── Capture helpers ──────────────────────────────────────────────────────────

/// Extracts all [AgentDomainEntity] instances of type [T] from a list of
/// captured `upsertEntity` arguments.
List<T> capturedEntitiesOfType<T extends AgentDomainEntity>(
  List<dynamic> captured,
) {
  return captured.whereType<AgentDomainEntity>().whereType<T>().toList();
}

/// Extracts [WakeTokenUsageEntity] instances from captured upsert arguments.
List<WakeTokenUsageEntity> capturedTokenUsageEntities(
  List<dynamic> captured,
) {
  return captured
      .whereType<AgentDomainEntity>()
      .where((e) => e.mapOrNull(wakeTokenUsage: (_) => true) ?? false)
      .cast<WakeTokenUsageEntity>()
      .toList();
}

/// Extracts [AgentStateEntity] instances from captured upsert arguments.
List<AgentStateEntity> capturedStateEntities(List<dynamic> captured) {
  return captured
      .whereType<AgentDomainEntity>()
      .where((e) => e.mapOrNull(agentState: (_) => true) ?? false)
      .cast<AgentStateEntity>()
      .toList();
}

/// Extracts [AgentMessagePayloadEntity] instances from captured upsert
/// arguments.
List<AgentMessagePayloadEntity> capturedPayloadEntities(
  List<dynamic> captured,
) {
  return captured
      .whereType<AgentDomainEntity>()
      .where(
        (e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false,
      )
      .cast<AgentMessagePayloadEntity>()
      .toList();
}

// ── Deferred tool verification ───────────────────────────────────────────────

/// Verifies that a tool response was sent indicating the tool call was
/// deferred (proposal recorded / queued for review).
void verifyDeferredToolResponse(
  MockConversationManager mockConversationManager, {
  String toolCallId = 'tc-1',
}) {
  verify(
    () => mockConversationManager.addToolResponse(
      toolCallId: toolCallId,
      response: any(
        named: 'response',
        that: anyOf(
          contains('proposal recorded'),
          contains('Proposal queued'),
        ),
      ),
    ),
  ).called(1);
}

/// Verifies that a deferred tool call was NOT executed immediately (no
/// journal update).
void verifyNotExecutedImmediately(
  MockJournalRepository mockJournalRepository,
) {
  verifyNever(() => mockJournalRepository.updateJournalEntity(any()));
}

/// Combines [verifyNotExecutedImmediately] and [verifyDeferredToolResponse].
void verifyToolWasDeferred({
  required MockConversationManager mockConversationManager,
  required MockJournalRepository mockJournalRepository,
  String toolCallId = 'tc-1',
}) {
  verifyNotExecutedImmediately(mockJournalRepository);
  verifyDeferredToolResponse(
    mockConversationManager,
    toolCallId: toolCallId,
  );
}
