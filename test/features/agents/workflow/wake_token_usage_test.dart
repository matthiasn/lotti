import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/workflow/agent_template_context.dart';
import 'package:lotti/features/agents/workflow/wake_token_usage.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/constants.dart';
import '../test_data/soul_factories.dart';
import '../test_data/template_factories.dart';

typedef _LoggedError = ({String message, Object? error, StackTrace? trace});

void main() {
  late MockAgentSyncService syncService;
  late List<_LoggedError> logged;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    syncService = MockAgentSyncService();
    logged = [];
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
  });

  void logError(String message, {Object? error, StackTrace? stackTrace}) =>
      logged.add((message: message, error: error, trace: stackTrace));

  Future<void> persist({
    InferenceUsage? usage = const InferenceUsage(
      inputTokens: 1200,
      outputTokens: 340,
      thoughtsTokens: 56,
      cachedInputTokens: 800,
    ),
    AgentTemplateContext? templateCtx,
  }) => persistWakeTokenUsage(
    syncService: syncService,
    usage: usage,
    agentId: 'agent-7',
    runKey: 'run-7',
    threadId: 'thread-7',
    modelId: 'models/gemini-3-flash-preview',
    now: kAgentTestDate,
    logError: logError,
    templateCtx: templateCtx,
  );

  WakeTokenUsageEntity captured() =>
      verify(() => syncService.upsertEntity(captureAny())).captured.single
          as WakeTokenUsageEntity;

  test('writes the counts, attributed to the wake and the model', () async {
    await persist();

    final row = captured();
    expect(row.agentId, 'agent-7');
    expect(row.runKey, 'run-7');
    expect(row.threadId, 'thread-7');
    expect(row.modelId, 'models/gemini-3-flash-preview');
    expect(row.createdAt, kAgentTestDate);
    expect(row.vectorClock, isNull);
    expect(row.inputTokens, 1200);
    expect(row.outputTokens, 340);
    expect(row.thoughtsTokens, 56);
    expect(row.cachedInputTokens, 800);
    expect(row.templateId, isNull);
    expect(row.templateVersionId, isNull);
    expect(row.soulDocumentId, isNull);
    expect(row.soulDocumentVersionId, isNull);
    expect(row.id, isNotEmpty);
    expect(logged, isEmpty);
  });

  test('attributes the row to the template, version and soul', () async {
    await persist(
      templateCtx: AgentTemplateContext(
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(id: 'version-9'),
        soulVersion: makeTestSoulDocumentVersion(id: 'soul-version-3'),
      ),
    );

    final row = captured();
    expect(row.templateId, kTestTemplateId);
    expect(row.templateVersionId, 'version-9');
    expect(row.soulDocumentId, kTestSoulId);
    expect(row.soulDocumentVersionId, 'soul-version-3');
  });

  test('leaves the soul fields empty for a template without a soul', () async {
    await persist(
      templateCtx: AgentTemplateContext(
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      ),
    );

    final row = captured();
    expect(row.templateId, kTestTemplateId);
    expect(row.soulDocumentId, isNull);
    expect(row.soulDocumentVersionId, isNull);
  });

  test('gives every row its own id', () async {
    await persist();
    await persist();

    final ids = verify(
      () => syncService.upsertEntity(captureAny()),
    ).captured.cast<WakeTokenUsageEntity>().map((row) => row.id);
    expect(ids.toSet(), hasLength(2));
  });

  test('writes nothing when the provider reported no usage', () async {
    await persist(usage: null);
    await persist(usage: InferenceUsage.empty);

    verifyNever(() => syncService.upsertEntity(any()));
    expect(logged, isEmpty);
  });

  test('a failed write is logged, never thrown', () async {
    final failure = StateError('sync outbox closed');
    when(() => syncService.upsertEntity(any())).thenThrow(failure);

    await expectLater(persist(), completes);

    expect(logged, hasLength(1));
    expect(logged.single.message, 'failed to persist wake token usage');
    expect(logged.single.error, same(failure));
    expect(logged.single.trace, isNotNull);
  });
}
