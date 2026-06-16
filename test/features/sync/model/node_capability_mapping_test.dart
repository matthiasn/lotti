// Verifies the explicit NodeCapability ↔ InferenceProviderType mapping.
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
  group('NodeCapability.providerType', () {
    test('maps to the inference provider it advertises', () {
      expect(
        NodeCapability.mlxAudio.providerType,
        InferenceProviderType.mlxAudio,
      );
      expect(
        NodeCapability.omlxLlm.providerType,
        InferenceProviderType.omlx,
      );
      expect(
        NodeCapability.ollamaLlm.providerType,
        InferenceProviderType.ollama,
      );
      expect(
        NodeCapability.voxtral.providerType,
        InferenceProviderType.voxtral,
      );
      expect(
        NodeCapability.whisper.providerType,
        InferenceProviderType.whisper,
      );
    });

    test(
      'every NodeCapability returns a non-null providerType',
      () {
        // Exhaustiveness check: if a new value is added without filling out
        // the switch, this test catches it.
        for (final cap in NodeCapability.values) {
          expect(cap.providerType, isNotNull, reason: 'cap=$cap');
        }
      },
    );
  });

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
      'round-trips through providerType for every NodeCapability',
      () {
        // For local providers: cap → providerType → cap returns the same.
        for (final cap in NodeCapability.values) {
          expect(
            nodeCapabilityFromProviderType(cap.providerType),
            cap,
            reason: 'cap=$cap',
          );
        }
      },
    );

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
        // Property: for every InferenceProviderType, either:
        //  (a) mapping returns null and the provider is cloud-typed (no
        //      capability token exists or is needed), OR
        //  (b) mapping returns a capability whose providerType getter
        //      returns the same input.
        //
        // Future-proofs against a new enum value that doesn't have a switch
        // case in nodeCapabilityFromProviderType — the test would surface it
        // here instead of letting the mapping silently fall through.
        final capability = nodeCapabilityFromProviderType(providerType);
        if (capability == null) {
          // Cloud providers MUST not round-trip. Catches: "I added a new
          // cloud provider type and forgot to extend the switch with a
          // null-returning case."
          const localTypes = {
            InferenceProviderType.mlxAudio,
            InferenceProviderType.omlx,
            InferenceProviderType.ollama,
            InferenceProviderType.voxtral,
            InferenceProviderType.whisper,
          };
          expect(localTypes.contains(providerType), isFalse);
        } else {
          expect(capability.providerType, providerType);
        }
      },
      tags: 'glados',
    );
  });
}
