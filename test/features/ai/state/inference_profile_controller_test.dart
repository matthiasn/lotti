import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

enum _GeneratedProfileBatchSlot {
  empty,
  single,
  pair,
  duplicateIds,
  reordered,
  defaultDesktopOnly,
}

List<AiConfigInferenceProfile> _generatedProfileBatch(
  _GeneratedProfileBatchSlot slot,
) {
  return switch (slot) {
    _GeneratedProfileBatchSlot.empty => <AiConfigInferenceProfile>[],
    _GeneratedProfileBatchSlot.single => [
      testInferenceProfile(id: 'generated-profile-1', name: 'Generated One'),
    ],
    _GeneratedProfileBatchSlot.pair => [
      testInferenceProfile(id: 'generated-profile-1', name: 'Generated One'),
      testInferenceProfile(id: 'generated-profile-2', name: 'Generated Two'),
    ],
    _GeneratedProfileBatchSlot.duplicateIds => [
      testInferenceProfile(id: 'generated-profile-1', name: 'First Copy'),
      testInferenceProfile(id: 'generated-profile-1', name: 'Second Copy'),
    ],
    _GeneratedProfileBatchSlot.reordered => [
      testInferenceProfile(id: 'generated-profile-3', name: 'Generated Three'),
      testInferenceProfile(id: 'generated-profile-1', name: 'Generated One'),
      testInferenceProfile(id: 'generated-profile-2', name: 'Generated Two'),
    ],
    _GeneratedProfileBatchSlot.defaultDesktopOnly => [
      testInferenceProfile(
        id: 'generated-default',
        name: 'Generated Default',
        isDefault: true,
      ),
      testInferenceProfile(
        id: 'generated-desktop',
        name: 'Generated Desktop',
        desktopOnly: true,
      ),
    ],
  };
}

class _GeneratedProfileStreamScenario {
  const _GeneratedProfileStreamScenario({required this.slots});

  final List<_GeneratedProfileBatchSlot> slots;

  Iterable<List<AiConfigInferenceProfile>> get batches =>
      slots.map(_generatedProfileBatch);

  @override
  String toString() {
    return '_GeneratedProfileStreamScenario(slots: $slots)';
  }
}

extension _AnyGeneratedProfileStreamScenario on glados.Any {
  glados.Generator<_GeneratedProfileBatchSlot> get profileBatchSlot =>
      glados.AnyUtils(this).choose(_GeneratedProfileBatchSlot.values);

  glados.Generator<_GeneratedProfileStreamScenario> get profileStreamScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(1, 30, profileBatchSlot)
          .map((slots) => _GeneratedProfileStreamScenario(slots: slots));
}

void main() {
  late MockAiConfigRepository mockRepository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      testInferenceProfile(id: 'fallback', name: 'Fallback'),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();
  });

  tearDown(() {
    container.dispose();
  });

  ProviderContainer createContainer() {
    return container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  }

  group('InferenceProfileController', () {
    test('build returns stream from repository.watchProfiles', () async {
      final profile = testInferenceProfile(id: 'p1');
      final streamController = StreamController<List<AiConfigInferenceProfile>>(
        sync: true,
      );

      when(
        () => mockRepository.watchProfiles(),
      ).thenAnswer((_) => streamController.stream);

      final c = createContainer();
      final subscription = c.listen(
        inferenceProfileControllerProvider,
        (_, _) {},
      );

      // Initially loading
      expect(
        c.read(inferenceProfileControllerProvider),
        const AsyncValue<List<AiConfig>>.loading(),
      );

      // Emit data
      streamController.add([profile]);

      final state = c.read(inferenceProfileControllerProvider);
      expect(state.hasValue, isTrue);
      expect(state.value, hasLength(1));
      expect(
        (state.value!.first as AiConfigInferenceProfile).name,
        'Test Profile',
      );

      subscription.close();
      await streamController.close();
    });

    test('saveProfile calls repository.saveConfig', () async {
      final profile = testInferenceProfile(id: 'p1', name: 'My Profile');
      final streamController = StreamController<List<AiConfigInferenceProfile>>(
        sync: true,
      );

      when(
        () => mockRepository.watchProfiles(),
      ).thenAnswer((_) => streamController.stream);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      final c = createContainer();

      // Wait for the provider to initialize
      streamController.add([]);

      await c
          .read(inferenceProfileControllerProvider.notifier)
          .saveProfile(profile);

      verify(() => mockRepository.saveConfig(profile)).called(1);

      await streamController.close();
    });

    test('emits updated list when stream emits new data', () async {
      final profile1 = testInferenceProfile(id: 'p1', name: 'Profile 1');
      final profile2 = testInferenceProfile(id: 'p2', name: 'Profile 2');
      final streamController = StreamController<List<AiConfigInferenceProfile>>(
        sync: true,
      );

      when(
        () => mockRepository.watchProfiles(),
      ).thenAnswer((_) => streamController.stream);

      final c = createContainer();
      final subscription = c.listen(
        inferenceProfileControllerProvider,
        (_, _) {},
      );

      // First emission: one profile
      streamController.add([profile1]);

      var state = c.read(inferenceProfileControllerProvider);
      expect(state.value, hasLength(1));

      // Second emission: two profiles
      streamController.add([profile1, profile2]);

      state = c.read(inferenceProfileControllerProvider);
      expect(state.value, hasLength(2));

      subscription.close();
      await streamController.close();
    });

    glados.Glados(
      glados.any.profileStreamScenario,
      glados.ExploreConfig(),
    ).test('passes generated profile stream batches unchanged', (
      scenario,
    ) async {
      final generatedRepository = MockAiConfigRepository();
      final streamController = StreamController<List<AiConfigInferenceProfile>>(
        sync: true,
      );
      final generatedContainer = container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(generatedRepository),
        ],
      );

      when(
        generatedRepository.watchProfiles,
      ).thenAnswer((_) => streamController.stream);

      final subscription = generatedContainer.listen(
        inferenceProfileControllerProvider,
        (_, _) {},
      );

      try {
        expect(
          generatedContainer.read(inferenceProfileControllerProvider),
          const AsyncValue<List<AiConfig>>.loading(),
        );

        for (final batch in scenario.batches) {
          streamController.add(batch);

          final state = generatedContainer.read(
            inferenceProfileControllerProvider,
          );
          expect(state.hasValue, isTrue, reason: '$scenario');
          final profiles = state.value!.cast<AiConfigInferenceProfile>();
          expect(
            profiles.map((profile) => profile.id),
            equals(batch.map((profile) => profile.id)),
            reason: '$scenario',
          );
          expect(
            profiles.map((profile) => profile.name),
            equals(batch.map((profile) => profile.name)),
            reason: '$scenario',
          );
          expect(
            profiles.map((profile) => profile.isDefault),
            equals(batch.map((profile) => profile.isDefault)),
            reason: '$scenario',
          );
          expect(
            profiles.map((profile) => profile.desktopOnly),
            equals(batch.map((profile) => profile.desktopOnly)),
            reason: '$scenario',
          );
        }
      } finally {
        subscription.close();
        await streamController.close();
      }
    });
  });
}
