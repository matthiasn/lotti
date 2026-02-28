import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

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
      final streamController =
          StreamController<List<AiConfigInferenceProfile>>();

      when(() => mockRepository.watchProfiles())
          .thenAnswer((_) => streamController.stream);

      final c = createContainer();
      final subscription = c.listen(
        inferenceProfileControllerProvider,
        (_, __) {},
      );

      // Initially loading
      expect(
        c.read(inferenceProfileControllerProvider),
        const AsyncValue<List<AiConfig>>.loading(),
      );

      // Emit data
      streamController.add([profile]);
      await Future<void>.delayed(Duration.zero);

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
      final streamController =
          StreamController<List<AiConfigInferenceProfile>>();

      when(() => mockRepository.watchProfiles())
          .thenAnswer((_) => streamController.stream);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      final c = createContainer();

      // Wait for the provider to initialize
      streamController.add([]);
      await Future<void>.delayed(Duration.zero);

      await c
          .read(inferenceProfileControllerProvider.notifier)
          .saveProfile(profile);

      verify(() => mockRepository.saveConfig(profile)).called(1);

      await streamController.close();
    });

    test('emits updated list when stream emits new data', () async {
      final profile1 = testInferenceProfile(id: 'p1', name: 'Profile 1');
      final profile2 = testInferenceProfile(id: 'p2', name: 'Profile 2');
      final streamController =
          StreamController<List<AiConfigInferenceProfile>>();

      when(() => mockRepository.watchProfiles())
          .thenAnswer((_) => streamController.stream);

      final c = createContainer();
      final subscription = c.listen(
        inferenceProfileControllerProvider,
        (_, __) {},
      );

      // First emission: one profile
      streamController.add([profile1]);
      await Future<void>.delayed(Duration.zero);

      var state = c.read(inferenceProfileControllerProvider);
      expect(state.value, hasLength(1));

      // Second emission: two profiles
      streamController.add([profile1, profile2]);
      await Future<void>.delayed(Duration.zero);

      state = c.read(inferenceProfileControllerProvider);
      expect(state.value, hasLength(2));

      subscription.close();
      await streamController.close();
    });
  });
}
