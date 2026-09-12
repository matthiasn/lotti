import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_runtime_settings.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('starts at three before persisted settings load', () {
    final container = makeContainer();

    expect(
      container.read(aiRuntimeSettingsControllerProvider),
      const AiRuntimeSettings(),
    );
  });

  test('default profile publishes only successful persisted choices', () async {
    final repository = MockAiConfigRepository();
    when(repository.getDefaultProfileId).thenAnswer((_) async => 'original');
    final saved = Completer<void>();
    when(
      () => repository.setDefaultProfileId('chosen'),
    ).thenAnswer((_) => saved.future);
    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(defaultInferenceProfileControllerProvider.future),
      'original',
    );
    final save = container
        .read(defaultInferenceProfileControllerProvider.notifier)
        .selectProfile('chosen');
    expect(
      container.read(defaultInferenceProfileControllerProvider).value,
      'original',
    );
    saved.complete();
    await save;
    expect(
      container.read(defaultInferenceProfileControllerProvider).value,
      'chosen',
    );
    when(
      () => repository.setDefaultProfileId(null),
    ).thenThrow(StateError('write failed'));
    await expectLater(
      container
          .read(defaultInferenceProfileControllerProvider.notifier)
          .selectProfile(null),
      throwsStateError,
    );
    expect(
      container.read(defaultInferenceProfileControllerProvider).value,
      'chosen',
    );
  });

  test('default profile writes preserve the order of rapid choices', () async {
    final repository = MockAiConfigRepository();
    final firstWrite = Completer<void>();
    final calls = <String?>[];
    when(() => repository.setDefaultProfileId('first')).thenAnswer((_) {
      calls.add('first');
      return firstWrite.future;
    });
    when(() => repository.setDefaultProfileId('second')).thenAnswer((_) async {
      calls.add('second');
    });
    final container = ProviderContainer(
      overrides: [aiConfigRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(defaultInferenceProfileControllerProvider.future);
    final controller = container.read(
      defaultInferenceProfileControllerProvider.notifier,
    );
    final first = controller.selectProfile('first');
    final second = controller.selectProfile('second');
    await pumpEventQueue();
    expect(calls, ['first']);
    firstWrite.complete();
    await Future.wait([first, second]);
    expect(calls, ['first', 'second']);
    expect(
      container.read(defaultInferenceProfileControllerProvider).value,
      'second',
    );
  });

  test('loads persisted wake concurrency', () async {
    when(
      () => mocks.settingsDb.itemByKey(agentWakeConcurrencySettingsKey),
    ).thenAnswer((_) async => '4');

    final container = makeContainer();
    expect(
      container.read(aiRuntimeSettingsControllerProvider),
      const AiRuntimeSettings(),
    );
    await pumpEventQueue();

    expect(
      container.read(aiRuntimeSettingsControllerProvider),
      const AiRuntimeSettings(agentWakeConcurrency: 4),
    );
  });

  test('updates state and persists a normalized wake concurrency', () {
    final container = makeContainer();

    container
        .read(aiRuntimeSettingsControllerProvider.notifier)
        .setAgentWakeConcurrency(99);

    expect(
      container.read(aiRuntimeSettingsControllerProvider).agentWakeConcurrency,
      maxAgentWakeConcurrency,
    );
    verify(
      () => mocks.settingsDb.saveSettingsItem(
        agentWakeConcurrencySettingsKey,
        maxAgentWakeConcurrency.toString(),
      ),
    ).called(1);
  });

  test('a user change made during loading is not overwritten', () async {
    final stored = Completer<String?>();
    when(
      () => mocks.settingsDb.itemByKey(agentWakeConcurrencySettingsKey),
    ).thenAnswer((_) => stored.future);

    final container = makeContainer();
    container
        .read(aiRuntimeSettingsControllerProvider.notifier)
        .setAgentWakeConcurrency(2);
    stored.complete('4');
    await pumpEventQueue();

    expect(
      container.read(aiRuntimeSettingsControllerProvider).agentWakeConcurrency,
      2,
    );
  });
}
