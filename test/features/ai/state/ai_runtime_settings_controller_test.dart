import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_runtime_settings.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:mocktail/mocktail.dart';

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
