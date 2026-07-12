import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';

void main() {
  final provider = AiConfigInferenceProvider(
    id: 'provider-1',
    baseUrl: 'https://example.invalid',
    apiKey: 'secret',
    name: 'Melious.ai',
    createdAt: DateTime(2024),
    inferenceProviderType: InferenceProviderType.melious,
  );
  final model = AiConfigModel(
    id: 'model-1',
    name: 'Qwen 3.5 Plus',
    providerModelId: 'qwen3.5-plus',
    inferenceProviderId: provider.id,
    createdAt: DateTime(2024),
    inputModalities: const [Modality.text],
    outputModalities: const [Modality.text],
    isReasoningModel: true,
    publisher: 'Alibaba',
    supportsFunctionCalling: true,
  );
  final profile = ResolvedProfile(
    thinkingModelId: model.providerModelId,
    thinkingProvider: provider,
    thinkingModel: model,
  );
  final resolved = ResolvedAgentSetup(
    status: AgentSetupResolutionStatus.resolved,
    profile: profile,
    source: AgentSetupResolutionSource.baseProfile,
    routeFingerprint: InferenceRouteFingerprint.fromProfile(profile),
  );
  final route = InferenceRouteSnapshot.fromResolvedProfile(profile);

  test(
    'formats model, publisher, and serving provider as separate concepts',
    () {
      expect(
        formatInferenceRouteIdentity(route, viaLabel: 'via'),
        'Qwen 3.5 Plus · Alibaba · via Melious.ai',
      );
      expect(
        formatInferenceRouteIdentity(
          InferenceRouteSnapshot(
            providerModelId: route.providerModelId,
            modelName: 'Custom Model',
            servingProviderType: route.servingProviderType,
            servingProviderName: 'OpenRouter',
            runtimeSettings: const {},
          ),
          viaLabel: 'via',
        ),
        'Custom Model · via OpenRouter',
      );
    },
  );

  test('no report shows current setup only', () {
    final data = TaskAgentModelIdentityViewData.fromResolution(
      setup: resolved,
      reportProvenance: null,
      hasReport: false,
    );

    expect(data.presentation, TaskAgentIdentityPresentation.currentOnly);
    expect(data.currentRoute, route);
    expect(data.reportRoute, isNull);
  });

  test('equivalent report and setup collapse to one identity row', () {
    final data = TaskAgentModelIdentityViewData.fromResolution(
      setup: resolved,
      reportProvenance: ReportInferenceProvenance(
        runKey: 'run-1',
        threadId: 'thread-1',
        executor: route,
        finalContentAuthor: ReportContentAuthor.executor,
      ),
      hasReport: true,
    );

    expect(data.presentation, TaskAgentIdentityPresentation.combined);
    expect(data.reportRoute, route);
  });

  test('same model name through another provider stays split', () {
    final data = TaskAgentModelIdentityViewData.fromResolution(
      setup: resolved,
      reportProvenance: ReportInferenceProvenance(
        runKey: 'run-1',
        threadId: 'thread-1',
        executor: InferenceRouteSnapshot(
          modelConfigId: route.modelConfigId,
          providerModelId: route.providerModelId,
          modelName: route.modelName,
          publisherName: route.publisherName,
          servingProviderConfigId: 'provider-2',
          servingProviderType: InferenceProviderType.openRouter,
          servingProviderName: 'OpenRouter',
          runtimeSettings: route.runtimeSettings,
        ),
        finalContentAuthor: ReportContentAuthor.executor,
      ),
      hasReport: true,
    );

    expect(data.presentation, TaskAgentIdentityPresentation.split);
    expect(data.reportRoute?.servingProviderName, 'OpenRouter');
  });

  test('unstamped historical report never borrows live attribution', () {
    final data = TaskAgentModelIdentityViewData.fromResolution(
      setup: resolved,
      reportProvenance: null,
      hasReport: true,
    );

    expect(data.presentation, TaskAgentIdentityPresentation.split);
    expect(data.reportAttributionUnavailable, isTrue);
    expect(data.reportRoute, isNull);
  });

  test('disabled and broken setup remain visible fix-it states', () {
    final disabled = TaskAgentModelIdentityViewData.fromResolution(
      setup: const ResolvedAgentSetup(
        status: AgentSetupResolutionStatus.disabled,
      ),
      reportProvenance: null,
      hasReport: false,
    );
    final broken = TaskAgentModelIdentityViewData.fromResolution(
      setup: const ResolvedAgentSetup(
        status: AgentSetupResolutionStatus.broken,
        brokenSelectionId: 'missing-model',
      ),
      reportProvenance: null,
      hasReport: false,
    );

    expect(disabled.presentation, TaskAgentIdentityPresentation.disabled);
    expect(broken.presentation, TaskAgentIdentityPresentation.broken);
    expect(broken.brokenSelectionId, 'missing-model');
  });
}
