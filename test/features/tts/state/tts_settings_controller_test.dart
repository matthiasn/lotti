import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/model/tts_voice.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';

final AiConfigInferenceProvider _mistral = testInferenceProvider(
  id: 'mistral',
  inferenceProviderType: InferenceProviderType.mistral,
);
final AiConfigInferenceProvider _eleven = testInferenceProvider(
  id: 'eleven',
  inferenceProviderType: InferenceProviderType.elevenLabs,
);

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: getItServiceOverrides());
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

  test('loads per-language cloud voices, skipping malformed entries', () async {
    when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
      (_) async => {ttsCloudVoicesKey: '{"de": "v-de-1", "en": 7}'},
    );
    final container = makeContainer()..read(ttsSettingsControllerProvider);
    await pumpEventQueue();
    expect(
      container.read(ttsSettingsControllerProvider).cloudVoiceByLanguage,
      {'de': 'v-de-1'},
    );
  });

  for (final stored in ['not json', '["de"]']) {
    test('an unreadable cloud-voice entry ($stored) reads as none', () async {
      when(
        () => mocks.settingsDb.itemsByKeys(any()),
      ).thenAnswer((_) async => {ttsCloudVoicesKey: stored});
      final container = makeContainer()..read(ttsSettingsControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(ttsSettingsControllerProvider).cloudVoiceByLanguage,
        isEmpty,
      );
    });
  }

  test('setCloudVoice chooses and clears per language, persisting the last '
      'choice', () async {
    final container = makeContainer();
    final controller = container.read(ttsSettingsControllerProvider.notifier)
      ..setCloudVoice(_mistral, 'de', 'v-de-2')
      ..setCloudVoice(_mistral, 'en', 'v-en-1');
    expect(
      container.read(ttsSettingsControllerProvider).cloudVoiceByLanguage,
      {'de': 'v-de-2', 'en': 'v-en-1'},
    );
    controller.setCloudVoice(_mistral, 'de', null);
    expect(
      container.read(ttsSettingsControllerProvider).cloudVoiceByLanguage,
      {'en': 'v-en-1'},
    );
    await pumpEventQueue();
    verifyInOrder([
      () => mocks.settingsDb.saveSettingsItem(
        ttsCloudVoicesKey,
        '{"de":"v-de-2"}',
      ),
      () => mocks.settingsDb.saveSettingsItem(
        ttsCloudVoicesKey,
        '{"de":"v-de-2","en":"v-en-1"}',
      ),
      () => mocks.settingsDb.saveSettingsItem(
        ttsCloudVoicesKey,
        '{"en":"v-en-1"}',
      ),
    ]);
  });

  test("each provider type keeps its own choice: ElevenLabs' never "
      "replaces Mistral's for the same language", () {
    final container = makeContainer();
    final controller = container.read(ttsSettingsControllerProvider.notifier)
      ..setCloudVoice(_mistral, 'de', 'mistral-voice')
      ..setCloudVoice(_eleven, 'de', 'eleven-voice');
    final settings = container.read(ttsSettingsControllerProvider);
    expect(settings.cloudVoiceByLanguage, {
      'de': 'mistral-voice',
      'eleven/de': 'eleven-voice',
    });
    expect(
      settings.cloudVoiceFor(_mistral, 'de'),
      'mistral-voice',
    );
    expect(
      settings.cloudVoiceFor(_eleven, 'de'),
      'eleven-voice',
    );

    controller.setCloudVoice(_eleven, 'de', null);
    expect(
      container.read(ttsSettingsControllerProvider).cloudVoiceByLanguage,
      {'de': 'mistral-voice'},
    );
  });

  test('two accounts of one provider type keep their own choices', () {
    final work = testInferenceProvider(
      id: 'eleven-work',
      inferenceProviderType: InferenceProviderType.elevenLabs,
    );
    final container = makeContainer();
    container.read(ttsSettingsControllerProvider.notifier)
      ..setCloudVoice(_eleven, 'en', 'my-clone')
      ..setCloudVoice(work, 'en', 'work-clone');
    final settings = container.read(ttsSettingsControllerProvider);

    expect(settings.cloudVoiceFor(_eleven, 'en'), 'my-clone');
    expect(settings.cloudVoiceFor(work, 'en'), 'work-clone');
  });

  test('a failed cloud-voice save keeps the choice and later saves', () async {
    var calls = 0;
    when(
      () => mocks.settingsDb.saveSettingsItem(ttsCloudVoicesKey, any()),
    ).thenAnswer((_) async {
      if (calls++ == 0) throw StateError('storage closed');
      return 1;
    });
    final container = makeContainer();
    container.read(ttsSettingsControllerProvider.notifier)
      ..setCloudVoice(_mistral, 'de', 'v-de-1')
      ..setCloudVoice(_mistral, 'de', 'v-de-2');
    await pumpEventQueue();
    expect(
      container.read(ttsSettingsControllerProvider).cloudVoiceByLanguage,
      {'de': 'v-de-2'},
    );
    expect(calls, 2);
  });

  test("setVoice updates state and persists, as the user's own pick", () {
    final container = makeContainer();
    container.read(ttsSettingsControllerProvider.notifier).setVoice('F4');

    final settings = container.read(ttsSettingsControllerProvider);
    expect(settings.voiceId, 'F4');
    expect(settings.voicePicked, isTrue);
    verify(
      () => mocks.settingsDb.saveSettingsItem(ttsVoiceIdKey, 'F4'),
    ).called(1);
    verify(
      () => mocks.settingsDb.saveSettingsItem(ttsVoicePickedKey, 'true'),
    ).called(1);
  });

  group('matchVoice', () {
    test('moves an unpicked voice to the gender asked, keeping its number, '
        'and stores it as not picked', () async {
      final container = makeContainer();
      final controller = container.read(ttsSettingsControllerProvider.notifier);
      await controller.matchVoice(TtsVoiceGender.male);

      expect(container.read(ttsSettingsControllerProvider).voiceId, 'M1');
      expect(
        container.read(ttsSettingsControllerProvider).voicePicked,
        isFalse,
      );
      verify(
        () => mocks.settingsDb.saveSettingsItem(ttsVoiceIdKey, 'M1'),
      ).called(1);
      verify(
        () => mocks.settingsDb.saveSettingsItem(ttsVoicePickedKey, 'false'),
      ).called(1);

      await controller.matchVoice(TtsVoiceGender.female);
      expect(container.read(ttsSettingsControllerProvider).voiceId, 'F1');
    });

    test('a voice of that gender already is left as it is, unsaved', () async {
      final container = makeContainer();
      await container
          .read(ttsSettingsControllerProvider.notifier)
          .matchVoice(TtsVoiceGender.female);

      expect(container.read(ttsSettingsControllerProvider).voiceId, 'F1');
      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(ttsVoiceIdKey, any()),
      );
    });

    test("never moves the user's own pick", () async {
      final container = makeContainer();
      final controller = container.read(ttsSettingsControllerProvider.notifier)
        ..setVoice('F3');
      await controller.matchVoice(TtsVoiceGender.male);

      expect(container.read(ttsSettingsControllerProvider).voiceId, 'F3');
    });

    test('asked before storage loaded, it waits: a stored pick is never '
        'matched away, and what else was stored still loads', () async {
      when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
        (_) async => {
          ttsVoiceIdKey: 'F3',
          ttsVoicePickedKey: 'true',
          ttsSpeedKey: '1.5',
        },
      );
      final container = makeContainer();
      // The provider's first touch: storage has not been read yet.
      await container
          .read(ttsSettingsControllerProvider.notifier)
          .matchVoice(TtsVoiceGender.male);

      final settings = container.read(ttsSettingsControllerProvider);
      expect(settings.voiceId, 'F3');
      expect(settings.voicePicked, isTrue);
      expect(settings.speed, 1.5);
      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(ttsVoiceIdKey, any()),
      );
    });

    test('asked before storage loaded, an unpicked stored voice is matched '
        'from where it stands, not from the default', () async {
      when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
        (_) async => {ttsVoiceIdKey: 'M4', ttsVoicePickedKey: 'false'},
      );
      final container = makeContainer();
      await container
          .read(ttsSettingsControllerProvider.notifier)
          .matchVoice(TtsVoiceGender.female);

      expect(container.read(ttsSettingsControllerProvider).voiceId, 'F4');
    });

    test('a matched voice goes on following after a restart: what the match '
        'stored loads as not picked', () async {
      final stored = <String, String>{};
      when(() => mocks.settingsDb.saveSettingsItem(any(), any())).thenAnswer((
        invocation,
      ) async {
        stored[invocation.positionalArguments[0] as String] =
            invocation.positionalArguments[1] as String;
        return 1;
      });
      when(
        () => mocks.settingsDb.itemsByKeys(any()),
      ).thenAnswer((_) async => Map.of(stored));

      await makeContainer()
          .read(ttsSettingsControllerProvider.notifier)
          .matchVoice(TtsVoiceGender.male);
      expect(stored[ttsVoiceIdKey], 'M1');

      // The next launch: a new container over the same storage.
      final restarted = makeContainer();
      final controller = restarted.read(ttsSettingsControllerProvider.notifier);
      await pumpEventQueue();
      expect(restarted.read(ttsSettingsControllerProvider).voiceId, 'M1');
      expect(
        restarted.read(ttsSettingsControllerProvider).voicePicked,
        isFalse,
      );

      await controller.matchVoice(TtsVoiceGender.female);
      expect(restarted.read(ttsSettingsControllerProvider).voiceId, 'F1');
    });
  });

  group("whether a stored voice is the user's own pick", () {
    Future<TtsSettings> load(Map<String, String> stored) async {
      when(
        () => mocks.settingsDb.itemsByKeys(any()),
      ).thenAnswer((_) async => stored);
      final container = makeContainer()..read(ttsSettingsControllerProvider);
      await pumpEventQueue();
      return container.read(ttsSettingsControllerProvider);
    }

    test('it is when stored as one', () async {
      final settings = await load({
        ttsVoiceIdKey: 'F1',
        ttsVoicePickedKey: 'true',
      });
      expect(settings.voicePicked, isTrue);
    });

    test('a voice stored before picks were noted counts as picked unless it '
        'is the default, so it is never matched away', () async {
      expect((await load({ttsVoiceIdKey: 'M3'})).voicePicked, isTrue);
      expect((await load({ttsVoiceIdKey: 'F1'})).voicePicked, isFalse);
      expect((await load({})).voicePicked, isFalse);
    });

    test('a voice stored as not picked goes on following', () async {
      final settings = await load({
        ttsVoiceIdKey: 'M1',
        ttsVoicePickedKey: 'false',
      });
      expect(settings.voicePicked, isFalse);
    });
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
