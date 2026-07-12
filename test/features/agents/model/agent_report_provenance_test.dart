import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';

void main() {
  const executor = InferenceRouteSnapshot(
    modelConfigId: 'model-config-1',
    providerModelId: 'qwen3.5-plus',
    modelName: 'Qwen 3.5 Plus',
    publisherName: 'Alibaba',
    servingProviderConfigId: 'provider-1',
    servingProviderType: InferenceProviderType.melious,
    servingProviderName: 'Melious.ai',
    runtimeSettings: <String, Object?>{'geminiThinkingMode': 'low'},
  );

  test('route snapshot preserves display identity and structural identity', () {
    final decoded = InferenceRouteSnapshot.fromJson(executor.toJson());

    expect(decoded, executor);
    expect(decoded.hashCode, executor.hashCode);
    expect(
      decoded.fingerprint,
      const InferenceRouteFingerprint(
        modelConfigId: 'model-config-1',
        providerModelId: 'qwen3.5-plus',
        providerConfigId: 'provider-1',
        providerType: InferenceProviderType.melious,
        runtimeSettings: <String, Object?>{'geminiThinkingMode': 'low'},
      ),
    );
  });

  test(
    'resolved profile snapshot omits unknown publisher without guessing',
    () {
      final provider = AiConfigInferenceProvider(
        id: 'provider-1',
        baseUrl: 'https://example.invalid',
        apiKey: 'secret',
        name: 'OpenRouter',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openRouter,
      );
      final snapshot = InferenceRouteSnapshot.fromResolvedProfile(
        ResolvedProfile(
          thinkingModelId: 'custom/model',
          thinkingProvider: provider,
        ),
      );

      expect(snapshot.modelName, 'custom/model');
      expect(snapshot.publisherName, isNull);
      expect(snapshot.toJson(), isNot(contains('publisherName')));
      expect(snapshot.toJson().toString(), isNot(contains('secret')));
      expect(snapshot.toJson().toString(), isNot(contains('example.invalid')));
    },
  );

  test('executor-only report provenance round-trips from report map', () {
    const snapshot = InferenceRunSnapshot(
      runKey: 'run-1',
      threadId: 'thread-1',
      setupSource: AgentSetupResolutionSource.directModel,
      setupOrigin: AgentInferenceSetupOrigin.categorySnapshot,
      profileId: 'profile-1',
      executor: executor,
    );

    final provenance = ReportInferenceProvenance.executorOnly(snapshot);
    final decoded = ReportInferenceProvenance.tryRead(
      provenance.toReportMap(),
    );

    expect(decoded, isNotNull);
    expect(decoded!.runKey, 'run-1');
    expect(decoded.threadId, 'thread-1');
    expect(decoded.setupSource, AgentSetupResolutionSource.directModel);
    expect(decoded.setupOrigin, AgentInferenceSetupOrigin.categorySnapshot);
    expect(decoded.profileId, 'profile-1');
    expect(decoded.finalContentAuthor, ReportContentAuthor.executor);
    expect(decoded.finalAuthorRoute, executor);
  });

  test('accepted finalizer is the final content author', () {
    const finalizer = InferenceRouteSnapshot(
      providerModelId: 'gemini-3-pro',
      modelName: 'Gemini 3 Pro',
      publisherName: 'Google',
      servingProviderType: InferenceProviderType.gemini,
      servingProviderName: 'Gemini',
      runtimeSettings: <String, Object?>{},
    );
    const provenance = ReportInferenceProvenance(
      runKey: 'run-1',
      threadId: 'thread-1',
      executor: executor,
      finalizer: finalizer,
      finalizerOutcome: ReportFinalizerOutcome.accepted,
      finalContentAuthor: ReportContentAuthor.finalizer,
    );

    final decoded = ReportInferenceProvenance.fromJson(provenance.toJson());

    expect(decoded.finalizerOutcome, ReportFinalizerOutcome.accepted);
    expect(decoded.finalAuthorRoute, finalizer);
  });

  test('missing or malformed report provenance is attribution unavailable', () {
    expect(ReportInferenceProvenance.tryRead(const {}), isNull);
    expect(
      ReportInferenceProvenance.tryRead(const {
        taskAgentInferenceProvenanceKey: <String, Object?>{'runKey': 'broken'},
      }),
      isNull,
    );
  });

  test('unknown optional enum values decode without losing attribution', () {
    final json =
        const ReportInferenceProvenance(
            runKey: 'run-1',
            threadId: 'thread-1',
            executor: executor,
            finalContentAuthor: ReportContentAuthor.executor,
          ).toJson()
          ..['setupSource'] = 'futureSource'
          ..['setupOrigin'] = 'futureOrigin'
          ..['finalizerOutcome'] = 'futureOutcome'
          ..['finalContentAuthor'] = 'futureAuthor';

    final decoded = ReportInferenceProvenance.fromJson(json);

    expect(decoded.setupSource, isNull);
    expect(decoded.setupOrigin, isNull);
    expect(decoded.finalizerOutcome, isNull);
    expect(decoded.finalContentAuthor, ReportContentAuthor.executor);
  });
}
