import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  test('an edited report credits the editor only when accepted', () {
    const snapshot = InferenceRunSnapshot(
      runKey: 'run-1',
      threadId: 'thread-1',
      profileId: 'profile-1',
      executor: executor,
    );
    const editor = InferenceRouteSnapshot(
      providerModelId: 'qwen3.5-122b-a10b',
      modelName: 'qwen3.5-122b-a10b',
      servingProviderType: InferenceProviderType.melious,
      servingProviderName: 'Melious',
      runtimeSettings: <String, Object?>{},
    );

    for (final (outcome, author) in [
      (ReportFinalizerOutcome.accepted, editor),
      (ReportFinalizerOutcome.rejected, executor),
      (ReportFinalizerOutcome.failed, executor),
    ]) {
      final decoded = ReportInferenceProvenance.tryRead(
        ReportInferenceProvenance.edited(
          snapshot,
          finalizer: editor,
          outcome: outcome,
        ).toReportMap(),
      )!;
      expect(decoded.finalizerOutcome, outcome);
      expect(decoded.finalizer, editor);
      expect(decoded.finalAuthorRoute, author, reason: outcome.name);
      expect(decoded.profileId, 'profile-1');
    }
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

  group('properties', () {
    final optionalId = glados.any.choose<String?>([null, 'id-1', '']);
    final route = glados.any.combine5(
      optionalId,
      glados.any.choose(['qwen3.5-plus', 'penguin-small']),
      glados.any.choose(InferenceProviderType.values),
      optionalId,
      // Runtime settings are flat scalars; route equality compares them
      // shallowly.
      glados.any.choose(<Map<String, Object?>>[
        const {},
        const {'geminiThinkingMode': 'low'},
        const {'depth': 2, 'enabled': true},
      ]),
      (
        String? configId,
        String modelId,
        InferenceProviderType type,
        String? publisher,
        Map<String, Object?> settings,
      ) => InferenceRouteSnapshot(
        modelConfigId: configId,
        providerModelId: modelId,
        modelName: 'Model $modelId',
        publisherName: publisher,
        servingProviderConfigId: configId == null ? null : 'provider-1',
        servingProviderType: type,
        servingProviderName: 'Provider',
        runtimeSettings: settings,
      ),
    );
    final provenance = glados.any.combine5(
      route,
      glados.any.oneOf<InferenceRouteSnapshot?>([
        glados.any.always(null),
        route,
      ]),
      glados.any.choose<ReportFinalizerOutcome?>([
        null,
        ...ReportFinalizerOutcome.values,
      ]),
      glados.any.choose<AgentSetupResolutionSource?>([
        null,
        ...AgentSetupResolutionSource.values,
      ]),
      glados.any.choose(ReportContentAuthor.values),
      (
        InferenceRouteSnapshot executor,
        InferenceRouteSnapshot? finalizer,
        ReportFinalizerOutcome? outcome,
        AgentSetupResolutionSource? source,
        ReportContentAuthor author,
      ) => ReportInferenceProvenance(
        runKey: 'run-1',
        threadId: 'thread-1',
        executor: executor,
        finalizer: finalizer,
        finalizerOutcome: outcome,
        setupSource: source,
        setupOrigin: source == null
            ? null
            : AgentInferenceSetupOrigin.values.first,
        profileId: source == null ? null : 'profile-1',
        finalContentAuthor: author,
      ),
    );

    glados.Glados(provenance, glados.ExploreConfig(numRuns: 200)).test(
      'survives a JSON round-trip through the report map',
      (original) {
        final wire =
            jsonDecode(jsonEncode(original.toReportMap()))
                as Map<String, Object?>;
        final read = ReportInferenceProvenance.tryRead(wire)!;

        expect(jsonEncode(read.toJson()), jsonEncode(original.toJson()));
        expect(read.executor, original.executor);
        expect(read.finalizer, original.finalizer);
        expect(read.finalAuthorRoute, original.finalAuthorRoute);
      },
      tags: 'glados',
    );

    // Whatever a peer on another build wrote: wrong types, missing fields,
    // nested junk.
    final junk = glados.any.choose<Object?>([
      null,
      1,
      'text',
      true,
      const <Object?>[],
      const {'providerModelId': 3},
      const {'runKey': 'r', 'threadId': 't', 'executor': 'x'},
    ]);
    final field = glados.any.choose([
      'runKey',
      'threadId',
      'executor',
      'finalizer',
      'finalContentAuthor',
      'setupSource',
    ]);

    glados.Glados(
      glados.any.map(field, junk),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'tryRead never throws on malformed provenance',
      (payload) {
        expect(
          () => ReportInferenceProvenance.tryRead({
            taskAgentInferenceProvenanceKey: payload,
          }),
          returnsNormally,
        );
      },
      tags: 'glados',
    );
  });
}
