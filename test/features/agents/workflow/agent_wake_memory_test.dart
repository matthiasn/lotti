import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/workflow/agent_wake_memory.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/utils/consts.dart';
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

  setUp(() {
    syncService = MockAgentSyncService();
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
    test('compaction-off view forwards the actual capture result', () async {
      final memory = AgentWakeMemory(
        journalDb: null,
        syncService: syncService,
        compactionEnabled: false,
      );

      final view = await assemble(memory, captureSucceeded: true);

      // Capture ran before the flag read — the view must distinguish
      // "capture failed" from "compaction disabled".
      expect(view.captureSucceeded, isTrue);
      expect(view.compactionOn, isFalse);
      expect(view.compactedLog, isNull);
      expect(view.useCompactedLog, isFalse);
    });

    test('null journalDb without an override keeps compaction off', () async {
      final memory = AgentWakeMemory(
        journalDb: null,
        syncService: syncService,
      );

      final view = await assemble(memory, captureSucceeded: true);

      expect(view.compactionOn, isFalse);
      expect(view.captureSucceeded, isTrue);
    });

    test('a failed flag read degrades to compaction off, not a thrown '
        'wake', () async {
      final journalDb = MockJournalDb();
      when(
        () => journalDb.getConfigFlag(enableAgentCompactionFlag),
      ).thenThrow(StateError('db unavailable'));
      final memory = AgentWakeMemory(
        journalDb: journalDb,
        syncService: syncService,
      );

      final view = await assemble(memory, captureSucceeded: true);

      expect(view.compactionOn, isFalse);
      expect(view.captureSucceeded, isTrue);
      expect(view.useCompactedLog, isFalse);
    });
  });

  group('capture', () {
    test('returns false when no capture service is wired', () async {
      final memory = AgentWakeMemory(
        journalDb: null,
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
        journalDb: null,
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
