// Verifies the explicit InferenceProviderType → NodeCapability mapping.
// Replaces the deprecated assumption that "names mirror" — they don't
// (ollama vs ollamaLlm, omlx vs omlxLlm) — so the mapping must be table-driven
// and exhaustive.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';

extension _AnyNodeCapabilityMapping on glados.Any {
  glados.Generator<InferenceProviderType> get inferenceProviderType =>
      glados.AnyUtils(this).choose(InferenceProviderType.values);
}

void main() {
  group('nodeCapabilityFromProviderType', () {
    test('returns a capability for every local provider type', () {
      expect(
        nodeCapabilityFromProviderType(InferenceProviderType.mlxAudio),
        NodeCapability.mlxAudio,
      );
      expect(
        nodeCapabilityFromProviderType(InferenceProviderType.omlx),
        NodeCapability.omlxLlm,
      );
      expect(
        nodeCapabilityFromProviderType(InferenceProviderType.ollama),
        NodeCapability.ollamaLlm,
      );
      expect(
        nodeCapabilityFromProviderType(InferenceProviderType.voxtral),
        NodeCapability.voxtral,
      );
      expect(
        nodeCapabilityFromProviderType(InferenceProviderType.whisper),
        NodeCapability.whisper,
      );
    });

    test('returns null for every cloud provider type', () {
      const cloudTypes = [
        InferenceProviderType.alibaba,
        InferenceProviderType.anthropic,
        InferenceProviderType.gemini,
        InferenceProviderType.genericOpenAi,
        InferenceProviderType.melious,
        InferenceProviderType.mistral,
        InferenceProviderType.nebiusAiStudio,
        InferenceProviderType.openAi,
        InferenceProviderType.openRouter,
      ];
      for (final t in cloudTypes) {
        expect(nodeCapabilityFromProviderType(t), isNull, reason: 'type=$t');
      }
    });

    test(
      'every InferenceProviderType has a deterministic mapping outcome',
      () {
        // Exhaustiveness: every enum value either maps to a capability or
        // returns null. The switch in nodeCapabilityFromProviderType is
        // pattern-exhaustive; calling it across the whole enum proves that
        // intention by surfacing any future omission as a thrown switch.
        InferenceProviderType.values.forEach(nodeCapabilityFromProviderType);
      },
    );

    glados.Glados(
      glados.any.inferenceProviderType,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'round-trips or returns null for every generated provider type',
      (
        providerType,
      ) {
        // Property: for every InferenceProviderType, the mapping returns a
        // capability exactly for the five local provider types.
        //
        // Future-proofs against a new enum value that doesn't have a switch
        // case in nodeCapabilityFromProviderType — the test would surface it
        // here instead of letting the mapping silently fall through.
        final capability = nodeCapabilityFromProviderType(providerType);
        const expected = {
          InferenceProviderType.mlxAudio: NodeCapability.mlxAudio,
          InferenceProviderType.omlx: NodeCapability.omlxLlm,
          InferenceProviderType.ollama: NodeCapability.ollamaLlm,
          InferenceProviderType.voxtral: NodeCapability.voxtral,
          InferenceProviderType.whisper: NodeCapability.whisper,
        };
        expect(capability, expected[providerType]);
      },
      tags: 'glados',
    );
  });
}
