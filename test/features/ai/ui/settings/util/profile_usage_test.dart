import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/profile_usage.dart';

import '../../../../agents/test_utils.dart';
import '../../../test_utils.dart';

CategoryDefinition _category({String? profileId, String id = 'cat-1'}) {
  return CategoryDefinition(
    id: id,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    name: 'Work',
    vectorClock: null,
    private: false,
    active: true,
    defaultProfileId: profileId,
  );
}

AgentIdentityEntity _agent({
  required AgentConfig config,
  String id = 'agent-1',
}) {
  return makeTestIdentity(
    id: id,
    agentId: id,
    displayName: 'Task Agent',
    currentStateId: 'state-$id',
    config: config,
  );
}

AgentConfig _setup(
  AgentInferenceSetupMode mode, {
  String? baseProfileId,
  String? legacyProfileId,
}) {
  return AgentConfig(
    profileId: legacyProfileId,
    inferenceSetup: AgentInferenceSetup(
      mode: mode,
      origin: AgentInferenceSetupOrigin.user,
      baseProfileId: baseProfileId,
    ),
  );
}

AiConfigModel _model({
  required String id,
  required String providerModelId,
  String providerId = 'provider-1',
}) {
  return AiTestDataFactory.createTestModel(
    id: id,
    providerModelId: providerModelId,
    inferenceProviderId: providerId,
  );
}

void main() {
  group('profileIdsInUse', () {
    test('counts a category default', () {
      final inUse = profileIdsInUse(
        categories: [_category(profileId: 'profile-1')],
        agents: const [],
      );

      expect(inUse, {'profile-1'});
    });

    test('counts an agent base profile', () {
      final inUse = profileIdsInUse(
        categories: const [],
        agents: [
          _agent(
            config: _setup(
              AgentInferenceSetupMode.configured,
              baseProfileId: 'profile-agent',
            ),
          ),
        ],
      );

      expect(inUse, {'profile-agent'});
    });

    // A disabled setup runs no inference, so a profile it still names is not
    // routing anything.
    test('ignores a disabled agent setup', () {
      final inUse = profileIdsInUse(
        categories: const [],
        agents: [
          _agent(
            config: _setup(
              AgentInferenceSetupMode.disabled,
              baseProfileId: 'profile-disabled',
            ),
          ),
        ],
      );

      expect(inUse, isEmpty);
    });

    // Agents created before typed setups resolve through config.profileId.
    test('falls back to the legacy profileId when no typed setup exists', () {
      final inUse = profileIdsInUse(
        categories: const [],
        agents: [
          _agent(config: const AgentConfig(profileId: 'profile-legacy')),
        ],
      );

      expect(inUse, {'profile-legacy'});
    });

    // A typed setup is authoritative: it must not fall through to the legacy
    // id the agent still carries.
    test('a typed setup shadows the legacy profileId', () {
      final inUse = profileIdsInUse(
        categories: const [],
        agents: [
          _agent(
            config: _setup(
              AgentInferenceSetupMode.configured,
              baseProfileId: 'profile-typed',
              legacyProfileId: 'profile-legacy',
            ),
          ),
        ],
      );

      expect(inUse, {'profile-typed'});
    });

    test('merges every source and de-duplicates', () {
      final inUse = profileIdsInUse(
        categories: [
          _category(profileId: 'profile-shared'),
          _category(id: 'cat-2', profileId: 'profile-2'),
          _category(id: 'cat-3'),
        ],
        agents: [
          _agent(
            config: _setup(
              AgentInferenceSetupMode.configured,
              baseProfileId: 'profile-shared',
            ),
          ),
          _agent(
            id: 'agent-2',
            config: _setup(
              AgentInferenceSetupMode.configured,
              baseProfileId: 'profile-3',
            ),
          ),
        ],
      );

      expect(inUse, {'profile-shared', 'profile-2', 'profile-3'});
    });

    // The whole point of the change: a profile nothing points at is not in
    // use, however its model slots happen to be wired.
    test('an unreferenced profile is not in use', () {
      final inUse = profileIdsInUse(
        categories: [_category()],
        agents: [
          _agent(config: _setup(AgentInferenceSetupMode.configured)),
        ],
      );

      expect(inUse, isEmpty);
    });
  });

  group('profilesUsingProviderModels', () {
    final providerModel = _model(id: 'model-1', providerModelId: 'gpt-5.2');
    final otherModel = _model(
      id: 'model-2',
      providerModelId: 'claude-x',
      providerId: 'provider-2',
    );

    AiConfigInferenceProfile profile({
      required String id,
      String? thinking,
      String? transcription,
    }) {
      return AiTestDataFactory.createTestProfile(id: id).copyWith(
        thinkingModelId: thinking ?? 'unrelated-model',
        transcriptionModelId: transcription,
      );
    }

    test('returns every profile touching the provider, not just one', () {
      final first = profile(id: 'profile-1', thinking: 'model-1');
      final second = profile(id: 'profile-2', transcription: 'model-1');
      final unrelated = profile(id: 'profile-3', thinking: 'model-2');

      final matches = profilesUsingProviderModels(
        profiles: [first, second, unrelated],
        providerModels: [providerModel],
      );

      expect(matches.map((p) => p.id), ['profile-1', 'profile-2']);
    });

    // Legacy rows store the provider-native id in the slot; it resolves only
    // while unambiguous.
    test('matches a legacy provider-native slot value', () {
      final legacy = profile(id: 'profile-legacy', thinking: 'gpt-5.2');

      final matches = profilesUsingProviderModels(
        profiles: [legacy],
        providerModels: [providerModel],
      );

      expect(matches.single.id, 'profile-legacy');
    });

    test('is empty when the provider owns no models', () {
      expect(
        profilesUsingProviderModels(
          profiles: [profile(id: 'profile-1', thinking: 'model-1')],
          providerModels: const [],
        ),
        isEmpty,
      );
    });

    test('is empty when no profile references the provider', () {
      expect(
        profilesUsingProviderModels(
          profiles: [profile(id: 'profile-1', thinking: 'model-1')],
          providerModels: [otherModel],
        ),
        isEmpty,
      );
    });
  });

  group('modelByProfileSlotId', () {
    test('indexes by row id and by unique provider-native id', () {
      final index = modelByProfileSlotId([
        _model(id: 'model-1', providerModelId: 'gpt-5.2'),
      ]);

      expect(index['model-1']?.id, 'model-1');
      expect(index['gpt-5.2']?.id, 'model-1');
    });

    // An ambiguous provider-native id must not resolve to an arbitrary row.
    test('omits a provider-native id owned by two rows', () {
      final index = modelByProfileSlotId([
        _model(id: 'model-1', providerModelId: 'gpt-5.2'),
        _model(id: 'model-2', providerModelId: 'gpt-5.2', providerId: 'p-2'),
      ]);

      expect(index.containsKey('gpt-5.2'), isFalse);
      expect(index['model-1'], isNotNull);
      expect(index['model-2'], isNotNull);
    });
  });
}
