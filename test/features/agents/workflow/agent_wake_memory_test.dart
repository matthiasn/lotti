import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/workflow/agent_wake_memory.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

final _provider =
    AiConfig.inferenceProvider(
          id: 'provider-1',
          baseUrl: 'https://example.com',
          apiKey: 'key',
          name: 'Test',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        )
        as AiConfigInferenceProvider;

/// A capture service that always fails, for the absorb-and-degrade path.
class _ThrowingCaptureService implements AgentInputCaptureService {
  @override
  Future<CaptureDelta> captureWakeInputs({
    required String agentId,
    required List<RenderedSource> sources,
    required DateTime at,
    String? threadId,
    String? runKey,
    List<AgentMessageEntity>? systemMessages,
    List<AgentLink>? links,
  }) async {
    throw StateError('capture blew up');
  }
}

void main() {
  late MockAgentSyncService syncService;
  late MockAgentRepository agentRepository;

  setUp(() {
    syncService = MockAgentSyncService();
    agentRepository = MockAgentRepository();
  });

  Future<WakeMemoryView> assemble(
    AgentWakeMemory memory, {
    required bool captureSucceeded,
  }) => memory.compactAndAssemble(
    agentId: 'agent-1',
    captureSucceeded: captureSucceeded,
    model: 'model-1',
    provider: _provider,
    at: DateTime(2024, 3, 15),
    threadId: 'thread-1',
    runKey: 'run-1',
  );

  group('compactAndAssemble read-flip gates', () {
    test('skips compactor reads when this wake did not refresh capture', () async {
      final memory = AgentWakeMemory(
        syncService: syncService,
      );

      final view = await assemble(memory, captureSucceeded: false);

      expect(view.captureSucceeded, isFalse);
      expect(view.compactedLog, isNull);
      expect(view.useCompactedLog, isFalse);
      verifyNever(() => syncService.repository);
    });

    test('empty assembled log falls back to inline context', () async {
      when(() => syncService.repository).thenReturn(agentRepository);
      when(
        () => agentRepository.getMessagesByKind(
          'agent-1',
          AgentMessageKind.system,
        ),
      ).thenAnswer((_) async => []);
      when(
        () => agentRepository.getMessagesByKind(
          'agent-1',
          AgentMessageKind.observation,
        ),
      ).thenAnswer((_) async => []);
      when(() => agentRepository.getLinksFrom('agent-1')).thenAnswer(
        (_) async => [],
      );
      final memory = AgentWakeMemory(
        syncService: syncService,
      );

      final view = await assemble(memory, captureSucceeded: true);

      expect(view.captureSucceeded, isTrue);
      expect(view.compactedLog, isEmpty);
      expect(view.useCompactedLog, isFalse);
    });
  });

  group('capture', () {
    test('returns false when no capture service is wired', () async {
      final memory = AgentWakeMemory(
        syncService: syncService,
      );

      final succeeded = await memory.capture(
        agentId: 'agent-1',
        sources: const [],
        at: DateTime(2024, 3, 15),
        threadId: 'thread-1',
        runKey: 'run-1',
      );

      expect(succeeded, isFalse);
    });

    test('absorbs capture failures and returns false', () async {
      final memory = AgentWakeMemory(
        syncService: syncService,
        inputCaptureService: _ThrowingCaptureService(),
      );

      final succeeded = await memory.capture(
        agentId: 'agent-1',
        sources: const [],
        at: DateTime(2024, 3, 15),
        threadId: 'thread-1',
        runKey: 'run-1',
      );

      expect(succeeded, isFalse);
    });
  });
}
