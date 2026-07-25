import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/state/profile_usage_provider.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

CategoryDefinition _category({String? profileId}) {
  return CategoryDefinition(
    id: 'cat-1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    name: 'Work',
    vectorClock: null,
    private: false,
    active: true,
    defaultProfileId: profileId,
  );
}

void main() {
  late MockAgentRepository mockAgents;

  setUp(() {
    mockAgents = MockAgentRepository();
  });

  /// Wires both sources and resolves the provider once.
  Future<Set<String>> readInUse({
    required List<CategoryDefinition> categories,
    required List<AgentIdentityEntity> agents,
  }) {
    when(mockAgents.getAllAgentIdentities).thenAnswer((_) async => agents);

    final container = ProviderContainer(
      overrides: [
        // Overriding the stream provider rather than the repository keeps the
        // test off getIt, which the real repository provider reaches into.
        categoriesStreamProvider.overrideWith(
          (ref) => Stream.value(categories),
        ),
        agentRepositoryProvider.overrideWithValue(mockAgents),
      ],
    );
    addTearDown(container.dispose);
    // A StreamProvider in this Riverpod version only subscribes once
    // something listens; awaiting `.future` off an unlistened container hangs
    // instead of resolving.
    container.listen(profileIdsInUseProvider, (_, _) {});
    return container.read(profileIdsInUseProvider.future);
  }

  group('profileIdsInUseProvider', () {
    test('combines category defaults and agent setups', () async {
      final inUse = await readInUse(
        categories: [_category(profileId: 'profile-category')],
        agents: [
          makeTestIdentity(
            id: 'agent-1',
            agentId: 'agent-1',
            currentStateId: 'state-1',
            config: const AgentConfig(
              inferenceSetup: AgentInferenceSetup(
                mode: AgentInferenceSetupMode.configured,
                origin: AgentInferenceSetupOrigin.user,
                baseProfileId: 'profile-agent',
              ),
            ),
          ),
        ],
      );

      expect(inUse, {'profile-category', 'profile-agent'});
    });

    test('is empty when nothing references a profile', () async {
      final inUse = await readInUse(
        categories: [_category()],
        agents: const [],
      );

      expect(inUse, isEmpty);
    });
  });
}
