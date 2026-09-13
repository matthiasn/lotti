import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
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

  test('starts with defaults before storage loads', () {
    final container = makeContainer();
    expect(container.read(ttsSettingsControllerProvider), const TtsSettings());
  });

  test('loads persisted voice/model/speed from SettingsDb', () async {
    when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
      (_) async => {
        ttsVoiceIdKey: 'M3',
        ttsModelIdKey: 'supertonic-3',
        ttsSpeedKey: '1.5',
        ttsAutoPrepareChatAudioKey: 'true',
      },
    );

    final container = makeContainer();
    // Defaults show synchronously (this read also triggers the async load).
    expect(container.read(ttsSettingsControllerProvider), const TtsSettings());
    await pumpEventQueue();

    final settings = container.read(ttsSettingsControllerProvider);
    expect(settings.voiceId, 'M3');
    expect(settings.modelId, 'supertonic-3');
    expect(settings.speed, 1.5);
    expect(settings.autoPrepareChatAudio, isTrue);
  });

  test('clamps an out-of-range persisted speed on load', () async {
    when(
      () => mocks.settingsDb.itemsByKeys(any()),
    ).thenAnswer((_) async => {ttsSpeedKey: '9.0'});

    final container = makeContainer();
    // The read triggers the async load; default speed shows until it resolves.
    expect(
      container.read(ttsSettingsControllerProvider).speed,
      kDefaultTtsSpeed,
    );
    await pumpEventQueue();

    expect(container.read(ttsSettingsControllerProvider).speed, kMaxTtsSpeed);
  });

  test('automatic preparation persists both opt-in and opt-out', () async {
    final container = makeContainer();
    final controller = container.read(ttsSettingsControllerProvider.notifier);
    expect(
      container.read(ttsSettingsControllerProvider).autoPrepareChatAudio,
      isFalse,
    );
    controller.setAutoPrepareChatAudio(enabled: true);
    await pumpEventQueue();
    expect(
      container.read(ttsSettingsControllerProvider).autoPrepareChatAudio,
      isTrue,
    );
    verify(
      () =>
          mocks.settingsDb.saveSettingsItem(ttsAutoPrepareChatAudioKey, 'true'),
    ).called(1);
    controller.setAutoPrepareChatAudio(enabled: false);
    expect(
      container.read(ttsSettingsControllerProvider).autoPrepareChatAudio,
      isFalse,
    );
    verify(
      () => mocks.settingsDb.saveSettingsItem(
        ttsAutoPrepareChatAudioKey,
        'false',
      ),
    ).called(1);
  });

  test('setVoice updates state and persists', () {
    final container = makeContainer();
    container.read(ttsSettingsControllerProvider.notifier).setVoice('F4');

    expect(container.read(ttsSettingsControllerProvider).voiceId, 'F4');
    verify(
      () => mocks.settingsDb.saveSettingsItem(ttsVoiceIdKey, 'F4'),
    ).called(1);
  });

  test('setModel updates state and persists', () {
    final container = makeContainer();
    container.read(ttsSettingsControllerProvider.notifier).setModel('m2');

    expect(container.read(ttsSettingsControllerProvider).modelId, 'm2');
    verify(
      () => mocks.settingsDb.saveSettingsItem(ttsModelIdKey, 'm2'),
    ).called(1);
  });

  test('setSpeed clamps, updates state, and persists the clamped value', () {
    final container = makeContainer();
    container.read(ttsSettingsControllerProvider.notifier).setSpeed(5);

    expect(container.read(ttsSettingsControllerProvider).speed, kMaxTtsSpeed);
    verify(
      () => mocks.settingsDb.saveSettingsItem(
        ttsSpeedKey,
        kMaxTtsSpeed.toString(),
      ),
    ).called(1);
  });

  test(
    'a change made before load completes is not clobbered by load',
    () async {
      when(
        () => mocks.settingsDb.itemsByKeys(any()),
      ).thenAnswer((_) async => {ttsVoiceIdKey: 'M1'});

      final container = makeContainer();
      // Change the voice synchronously, before the async _load resolves.
      container.read(ttsSettingsControllerProvider.notifier).setVoice('F5');
      await pumpEventQueue();

      expect(container.read(ttsSettingsControllerProvider).voiceId, 'F5');
    },
  );
}
