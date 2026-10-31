import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/cloud/voxtral_tts_service.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  /// Builds a container wired with the given fakes and records every state.
  ({ProviderContainer container, List<TtsPlaybackState> states}) harness({
    FakeTtsEngine? engine,
    FakeTtsAudioPlayer? player,
    FakeTtsModelRepository? repo,
    FakeCloudSpeechSynthesizer? cloud,
  }) {
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        cloudSpeechSynthesizerProvider.overrideWithValue(
          cloud ?? FakeCloudSpeechSynthesizer(),
        ),
        ttsEngineProvider.overrideWithValue(engine ?? FakeTtsEngine()),
        ttsAudioPlayerProvider.overrideWithValue(
          player ?? FakeTtsAudioPlayer(),
        ),
        ttsModelRepositoryProvider.overrideWithValue(
          repo ?? FakeTtsModelRepository(),
        ),
      ]),
    );
    addTearDown(container.dispose);
    final states = <TtsPlaybackState>[];
    container.listen(
      ttsPlaybackControllerProvider,
      (_, next) => states.add(next),
    );
    return (container: container, states: states);
  }

  TtsPlaybackController controllerOf(ProviderContainer c) =>
      c.read(ttsPlaybackControllerProvider.notifier);

  MockIoFile preparedFile() {
    final file = MockIoFile();
    when(() => file.path).thenReturn('/tmp/tts_clip.wav');
    when(file.existsSync).thenReturn(true);
    when(file.delete).thenAnswer((_) async => file);
    return file;
  }

  final cloudRoute = TtsCloudRoute(
    provider: testInferenceProvider(
      id: 'mistral',
      inferenceProviderType: InferenceProviderType.mistral,
    ),
    model: testAiModel(id: 'voice', providerModelId: 'voxtral-mini-tts-3-0'),
    languageCode: 'de',
  );

  test('a cloud route speaks through the cloud voice on a device without '
      'the on-device engine, and never downloads the model', () async {
    final file = preparedFile();
    final cloud = FakeCloudSpeechSynthesizer(output: file);
    final engine = FakeTtsEngine(supported: false);
    final repo = FakeTtsModelRepository(installed: false);
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(engine: engine, player: player, repo: repo, cloud: cloud);
    final controller = controllerOf(h.container);
    h.container
        .read(ttsSettingsControllerProvider.notifier)
        .setCloudVoice('de', 'v-de-2');
    var asked = false;

    await controller.speak(
      sourceId: 'task-1',
      text: 'Zwei offen.',
      cloudRoute: cloudRoute,
      confirmModelDownload: (_) async => asked = true,
    );

    expect(cloud.calls.single.route, cloudRoute);
    expect(cloud.calls.single.text, 'Zwei offen.');
    expect(cloud.calls.single.voices, {'de': 'v-de-2'});
    expect(engine.calls, isEmpty);
    expect(repo.ensureCount, 0);
    expect(asked, isFalse);
    expect(player.playCount, 1);
    final playing = h.container.read(ttsPlaybackControllerProvider);
    expect(playing.status, TtsPlaybackStatus.playing);
    expect(playing.clip?.path, '/tmp/tts_clip.wav');
    await controller.stop();
    verify(file.delete).called(1);
  });

  Future<MockDomainLogger> mockLogger() async {
    final logger = MockDomainLogger();
    await getIt.unregister<DomainLogger>();
    getIt.registerSingleton<DomainLogger>(logger);
    return logger;
  }

  List<String?> speakErrorMessages(MockDomainLogger logger) => verify(
    () => logger.error(
      LogDomain.speech,
      any(),
      subDomain: 'ttsPlayback.speak',
      stackTrace: any(named: 'stackTrace'),
      message: captureAny(named: 'message'),
    ),
  ).captured.cast<String?>();

  test('a failed cloud synthesis ends in an error for its source, without '
      'playback, and a missing voice is logged with its route', () async {
    final logger = await mockLogger();
    final cloud = FakeCloudSpeechSynthesizer(
      error: const VoxtralTtsException(
        VoxtralTtsFailure.noVoice,
        'No voice for language de',
      ),
    );
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(player: player, cloud: cloud);

    await controllerOf(
      h.container,
    ).speak(sourceId: 'task-1', text: 'Hallo', cloudRoute: cloudRoute);

    final state = h.container.read(ttsPlaybackControllerProvider);
    expect(state.status, TtsPlaybackStatus.error);
    expect(state.sourceId, 'task-1');
    expect(state.errorMessage, contains('noVoice'));
    expect(player.playCount, 0);
    expect(speakErrorMessages(logger), [
      'Cloud speech failed (${cloudRoute.cacheKey})',
    ]);
  });

  test('a rejected cloud request is not logged twice: the Voxtral client '
      'already logged it with the server detail', () async {
    final logger = await mockLogger();
    final h = harness(
      cloud: FakeCloudSpeechSynthesizer(
        error: const VoxtralTtsException(
          VoxtralTtsFailure.rejected,
          'Request rejected by the Mistral API',
          statusCode: 422,
        ),
      ),
    );

    await controllerOf(
      h.container,
    ).speak(sourceId: 'task-1', text: 'Hallo', cloudRoute: cloudRoute);

    expect(
      h.container.read(ttsPlaybackControllerProvider).status,
      TtsPlaybackStatus.error,
    );
    verifyNever(
      () => logger.error(
        any(),
        any(),
        subDomain: 'ttsPlayback.speak',
        stackTrace: any(named: 'stackTrace'),
        message: any(named: 'message'),
      ),
    );
  });

  test('a failed on-device synthesis is logged, not only toasted', () async {
    final logger = await mockLogger();
    final h = harness(engine: FakeTtsEngine(throwOnSynthesize: true));

    await controllerOf(h.container).speak(sourceId: 'task-1', text: 'Hello');

    expect(
      h.container.read(ttsPlaybackControllerProvider).status,
      TtsPlaybackStatus.error,
    );
    expect(speakErrorMessages(logger), ['On-device speech failed']);
  });

  test('a stop while the voice catalog loads keeps the text on the '
      'device', () async {
    final loaded = Completer<void>();
    final cloud = FakeCloudSpeechSynthesizer(
      output: preparedFile(),
      catalogLoaded: loaded.future,
    );
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(player: player, cloud: cloud);
    final controller = controllerOf(h.container);

    final speaking = controller.speak(
      sourceId: 'chat',
      text: 'Private answer',
      cloudRoute: cloudRoute,
    );
    await pumpEventQueue();
    await controller.stop();
    loaded.complete();
    await speaking;

    expect(cloud.calls.single.sent, isFalse);
    expect(player.playCount, 0);
    expect(
      h.container.read(ttsPlaybackControllerProvider).status,
      TtsPlaybackStatus.stopped,
    );
  });

  test('a caller that withdraws permission before upload ends the '
      'utterance quietly, without sending', () async {
    final cloud = FakeCloudSpeechSynthesizer(output: preparedFile());
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(player: player, cloud: cloud);

    await controllerOf(h.container).speak(
      sourceId: 'chat',
      text: 'Now hidden',
      cloudRoute: cloudRoute,
      canPlay: () async => false,
    );

    expect(cloud.calls.single.sent, isFalse);
    expect(player.playCount, 0);
    final state = h.container.read(ttsPlaybackControllerProvider);
    expect(state.status, TtsPlaybackStatus.stopped);
    expect(state.sourceId, isNull);
  });

  test('preparation never calls a cloud voice', () async {
    final cloud = FakeCloudSpeechSynthesizer(output: preparedFile());
    final engine = FakeTtsEngine();
    final h = harness(engine: engine, cloud: cloud);

    await controllerOf(h.container).prepare(
      sourceId: 'chat',
      text: 'Answer',
      canPrepare: () async => true,
      cloudRoute: cloudRoute,
    );

    expect(cloud.calls, isEmpty);
    expect(engine.calls, isEmpty);
  });

  for (final pending in [false, true]) {
    test(
      'play reuses ${pending ? 'pending' : 'finished'} automatic preparation without autoplay',
      () async {
        final file = preparedFile();
        final ready = Completer<File>();
        final started = Completer<void>();
        final engine = FakeTtsEngine(
          output: file,
          pendingSynthesis: pending ? ready.future : null,
          onSynthesize: started.complete,
        );
        final player = FakeTtsAudioPlayer();
        addTearDown(player.dispose);
        final h = harness(engine: engine, player: player);
        final controller = controllerOf(h.container);
        final preparing = controller.prepare(
          sourceId: 'chat',
          text: 'Done.',
          canPrepare: () async => true,
        );
        await started.future;
        if (!pending) await preparing;
        expect(h.container.read(ttsPlaybackControllerProvider).isBusy, isFalse);
        expect(player.playCount, 0);
        // Query playback stops any previous utterance before claiming the cache.
        await controller.stop();
        final speaking = controller.speak(sourceId: 'chat', text: 'Done.');
        if (pending) ready.complete(file);
        await preparing;
        await speaking;
        expect(engine.calls, hasLength(1));
        expect(player.playCount, 1);
        await controller.stop();
        verify(file.delete).called(1);
      },
    );
  }

  test(
    'discarding in-flight preparation deletes its late result without playback',
    () async {
      final file = preparedFile();
      final ready = Completer<File>();
      final started = Completer<void>();
      final engine = FakeTtsEngine(
        pendingSynthesis: ready.future,
        onSynthesize: started.complete,
      );
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(engine: engine, player: player);
      final controller = controllerOf(h.container);
      final preparing = controller.prepare(
        sourceId: 'chat',
        text: 'Answer',
        canPrepare: () async => true,
      );
      await started.future;
      controller
        ..discardPrepared(sourceId: 'another-chat')
        ..discardPrepared(sourceId: 'chat');
      ready.complete(file);
      await preparing;
      expect(engine.calls, hasLength(1));
      expect(player.playCount, 0);
      verify(file.delete).called(1);
    },
  );

  for (final change in ['text', 'voice', 'model', 'language', 'source']) {
    test('a changed $change never plays a stale prepared result', () async {
      final file = preparedFile();
      final engine = FakeTtsEngine(output: file);
      final h = harness(engine: engine);
      final controller = controllerOf(h.container);
      await controller.prepare(
        sourceId: 'chat',
        text: 'First',
        canPrepare: () async => true,
      );
      final settings = h.container.read(ttsSettingsControllerProvider.notifier);
      if (change == 'voice') settings.setVoice('M2');
      if (change == 'model') settings.setModel('other');
      await controller.speak(
        sourceId: change == 'source' ? 'other' : 'chat',
        text: change == 'text' ? 'Second' : 'First',
        language: change == 'language' ? 'en' : kDefaultTtsLanguage,
      );
      expect(engine.calls, hasLength(2));
      verify(file.delete).called(1);
    });
  }

  test('prepared playback still checks live permission', () async {
    final file = preparedFile();
    final engine = FakeTtsEngine(output: file);
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(engine: engine, player: player);
    final controller = controllerOf(h.container);
    await controller.prepare(
      sourceId: 'chat',
      text: 'Answer',
      canPrepare: () async => true,
    );
    await controller.speak(
      sourceId: 'chat',
      text: 'Answer',
      canPlay: () async => false,
    );
    expect(engine.calls, hasLength(1));
    expect(player.playCount, 0);
    verify(file.delete).called(1);
  });

  test('denied preparation never invokes the engine', () async {
    final engine = FakeTtsEngine();
    final h = harness(engine: engine);
    await controllerOf(
      h.container,
    ).prepare(sourceId: 'chat', text: 'Answer', canPrepare: () async => false);
    expect(engine.calls, isEmpty);
    expect(h.container.read(ttsPlaybackControllerProvider).isBusy, isFalse);
  });

  test(
    'duplicate preparations share one synthesis and speed changes reuse it',
    () async {
      final engine = FakeTtsEngine();
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(engine: engine, player: player);
      final controller = controllerOf(h.container);
      await Future.wait([
        controller.prepare(
          sourceId: 'chat',
          text: 'Answer',
          canPrepare: () async => true,
        ),
        controller.prepare(
          sourceId: 'chat',
          text: 'Answer',
          canPrepare: () async => true,
        ),
      ]);
      h.container.read(ttsSettingsControllerProvider.notifier).setSpeed(1.5);
      await controller.speak(sourceId: 'chat', text: 'Answer');
      expect(engine.calls, hasLength(1));
      expect(player.lastSpeed, 1.5);
    },
  );

  test(
    'replacing preparation serializes native work and deletes the superseded WAV',
    () async {
      final file = preparedFile();
      final pending = Completer<File>();
      final started = Completer<void>();
      final engine = FakeTtsEngine(
        pendingSynthesis: pending.future,
        onSynthesize: () {
          if (!started.isCompleted) started.complete();
        },
      );
      final h = harness(engine: engine);
      final controller = controllerOf(h.container);
      final first = controller.prepare(
        sourceId: 'old-chat',
        text: 'First',
        canPrepare: () async => true,
      );
      await started.future;
      final second = controller.prepare(
        sourceId: 'new-chat',
        text: 'Second',
        canPrepare: () async => true,
      );
      await pumpEventQueue();
      expect(engine.calls, hasLength(1));
      pending.complete(file);
      await Future.wait([first, second]);
      expect(engine.calls.map((e) => e.text), ['First', 'Second']);
      verify(file.delete).called(1);
    },
  );

  for (final throws in [false, true]) {
    test(
      'lost permission after synthesis ${throws ? 'throwing' : 'denied'} discards prepared speech',
      () async {
        final file = preparedFile();
        var allowed = true;
        final engine = FakeTtsEngine(
          output: file,
          onSynthesize: () => allowed = false,
        );
        final h = harness(engine: engine);
        await controllerOf(h.container).prepare(
          sourceId: 'chat',
          text: 'Answer',
          canPrepare: () async {
            if (!allowed && throws) throw StateError('Revoked');
            return allowed;
          },
        );
        expect(engine.calls, hasLength(1));
        verify(file.delete).called(1);
        expect(h.container.read(ttsPlaybackControllerProvider).isBusy, isFalse);
      },
    );
  }

  test(
    'silent preparation failure leaves explicit play available to retry',
    () async {
      var authorized = false;
      final engine = FakeTtsEngine();
      final h = harness(engine: engine);
      final controller = controllerOf(h.container);
      await controller.prepare(
        sourceId: 'chat',
        text: 'Answer',
        canPrepare: () async {
          if (!authorized) throw StateError('Storage temporarily unavailable');
          return true;
        },
      );
      expect(h.container.read(ttsPlaybackControllerProvider).isBusy, isFalse);
      authorized = true;
      await controller.speak(
        sourceId: 'chat',
        text: 'Answer',
        canPlay: () async => authorized,
      );
      expect(engine.calls, hasLength(1));
      expect(
        h.container.read(ttsPlaybackControllerProvider).status,
        TtsPlaybackStatus.playing,
      );
    },
  );

  test('disposing the controller removes its prepared file', () async {
    final file = preparedFile();
    final h = harness(engine: FakeTtsEngine(output: file));
    await controllerOf(
      h.container,
    ).prepare(sourceId: 'chat', text: 'Answer', canPrepare: () async => true);
    h.container.dispose();
    await pumpEventQueue();
    verify(file.delete).called(1);
  });

  for (final throws in [false, true]) {
    test(
      'a ${throws ? 'failed' : 'denied'} playback gate deletes synthesized audio without playing it',
      () async {
        final file = MockIoFile();
        when(() => file.path).thenReturn('/tmp/tts_clip.wav');
        when(file.existsSync).thenReturn(true);
        when(file.delete).thenAnswer((_) async => file);
        final player = FakeTtsAudioPlayer();
        addTearDown(player.dispose);
        final h = harness(
          engine: FakeTtsEngine(output: file),
          player: player,
        );
        var gates = 0;
        await controllerOf(h.container).speak(
          sourceId: 'chat',
          text: 'Private answer',
          canPlay: () async {
            gates++;
            if (throws) throw StateError('visibility unavailable');
            return false;
          },
        );
        expect(gates, 1);
        expect(player.playCount, 0);
        verify(file.delete).called(1);
        expect(
          h.container.read(ttsPlaybackControllerProvider).status,
          throws ? TtsPlaybackStatus.error : TtsPlaybackStatus.stopped,
        );
      },
    );
  }

  test('source-specific stop leaves another surface playing', () async {
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(player: player);
    final controller = controllerOf(h.container);
    await controller.speak(sourceId: 'task-card', text: 'Summary');
    await controller.stop(sourceId: 'query-chat');
    expect(player.stopCount, 0);
    expect(
      h.container.read(ttsPlaybackControllerProvider).sourceId,
      'task-card',
    );
    await controller.stop(sourceId: 'task-card');
    expect(player.stopCount, 1);
  });

  test('stopping playback removes its temporary synthesized file', () async {
    final file = MockIoFile();
    when(() => file.path).thenReturn('/tmp/tts_clip.wav');
    when(file.existsSync).thenReturn(true);
    when(file.delete).thenAnswer((_) async => file);
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(
      engine: FakeTtsEngine(output: file),
      player: player,
    );
    final controller = controllerOf(h.container);
    await controller.speak(sourceId: 'chat', text: 'Answer');
    await controller.stop();
    verify(file.delete).called(1);
    expect(player.stopCount, 1);
  });

  test(
    'an already removed temporary WAV does not prevent stopping speech',
    () async {
      final file = MockIoFile();
      when(() => file.path).thenReturn('/tmp/tts_clip.wav');
      when(file.existsSync).thenReturn(true);
      when(file.delete).thenThrow(
        const FileSystemException('Already removed', '', OSError('', 2)),
      );
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(
        engine: FakeTtsEngine(output: file),
        player: player,
      );
      final controller = controllerOf(h.container);
      await controller.speak(sourceId: 'chat', text: 'Answer');
      await controller.stop();
      expect(
        h.container.read(ttsPlaybackControllerProvider).status,
        TtsPlaybackStatus.stopped,
      );
      expect(player.stopCount, 1);
      verify(file.delete).called(1);
    },
  );

  test(
    'failed native shutdown is reported and still deletes private audio',
    () async {
      final logger = MockDomainLogger();
      await getIt.unregister<DomainLogger>();
      getIt.registerSingleton<DomainLogger>(logger);
      final file = MockIoFile();
      when(() => file.path).thenReturn('/tmp/tts_clip.wav');
      when(file.existsSync).thenReturn(true);
      when(file.delete).thenAnswer((_) async => file);
      final player = FakeTtsAudioPlayer(
        stopError: StateError('native stop failed'),
      );
      addTearDown(player.dispose);
      final h = harness(
        engine: FakeTtsEngine(output: file),
        player: player,
      );
      await controllerOf(
        h.container,
      ).speak(sourceId: 'chat', text: 'Private answer');

      h.container.invalidate(ttsPlaybackControllerProvider);
      await h.container.pump();

      expect(player.stopCount, 1);
      verify(file.delete).called(1);
      verify(
        () => logger.error(
          LogDomain.speech,
          any(),
          subDomain: 'ttsPlayback.stop',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    },
  );

  test(
    'WAV permission failures are reported without disclosing its path',
    () async {
      final logger = MockDomainLogger();
      await getIt.unregister<DomainLogger>();
      getIt.registerSingleton<DomainLogger>(logger);
      final file = MockIoFile();
      when(() => file.path).thenReturn('/tmp/tts_clip.wav');
      when(file.existsSync).thenReturn(true);
      when(file.delete).thenThrow(
        const FileSystemException(
          'Permission denied',
          '/private/answer.wav',
          OSError('Permission denied', 13),
        ),
      );
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(
        engine: FakeTtsEngine(output: file),
        player: player,
      );
      final controller = controllerOf(h.container);
      await controller.speak(sourceId: 'chat', text: 'Private answer');
      await controller.stop();

      expect(player.stopCount, 1);
      verify(file.delete).called(1);
      final errors = verify(
        () => logger.error(
          LogDomain.speech,
          captureAny(),
          subDomain: 'ttsPlayback.delete',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).captured;
      expect(errors.single.toString(), contains('13'));
      expect(errors.single.toString(), isNot(contains('/private/answer.wav')));
      expect(
        h.container.read(ttsPlaybackControllerProvider).status,
        TtsPlaybackStatus.stopped,
      );
    },
  );

  test('stopping preparation prevents late synthesis from playing', () async {
    final pending = Completer<File>();
    final started = Completer<void>();
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(
      engine: FakeTtsEngine(
        pendingSynthesis: pending.future,
        onSynthesize: started.complete,
      ),
      player: player,
    );
    final controller = controllerOf(h.container);
    final speak = controller.speak(
      sourceId: 'private-chat',
      text: 'private text',
    );
    await started.future;
    await controller.stop();
    pending.complete(File('/tmp/nonexistent-lotti-cancelled-tts.wav'));
    await speak;
    expect(player.playCount, 0);
    expect(
      h.container.read(ttsPlaybackControllerProvider).status,
      TtsPlaybackStatus.stopped,
    );
    expect(h.container.read(ttsPlaybackControllerProvider).sourceId, isNull);
  });

  test('reports an error when the engine is unsupported', () async {
    final h = harness(engine: FakeTtsEngine(supported: false));

    await controllerOf(h.container).speak(sourceId: 'task-1', text: 'Hello');

    final state = h.container.read(ttsPlaybackControllerProvider);
    expect(state.status, TtsPlaybackStatus.error);
    expect(state.errorMessage, isNotNull);
  });

  test('installed model: synthesizes with settings, then plays', () async {
    final engine = FakeTtsEngine();
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(engine: engine, player: player);

    await controllerOf(h.container).speak(sourceId: 'task-1', text: 'Read me');

    final state = h.container.read(ttsPlaybackControllerProvider);
    expect(state.status, TtsPlaybackStatus.playing);
    expect(state.isActiveFor('task-1'), isTrue);

    // The engine received the default voice + model directory.
    expect(engine.calls.single.text, 'Read me');
    expect(engine.calls.single.voiceId, 'F1');
    expect(engine.calls.single.modelDirectory, '/tmp/tts_model');

    // Playback ran once at the default speed.
    expect(player.playCount, 1);
    expect(player.lastSpeed, 1.0);

    // Statuses passed through synthesizing before playing.
    expect(
      h.states.map((s) => s.status),
      containsAllInOrder([
        TtsPlaybackStatus.synthesizing,
        TtsPlaybackStatus.playing,
      ]),
    );
  });

  test('transitions to stopped when playback completes', () async {
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(player: player);

    await controllerOf(h.container).speak(sourceId: 'task-1', text: 'x');
    expect(
      h.container.read(ttsPlaybackControllerProvider).status,
      TtsPlaybackStatus.playing,
    );

    player.complete();
    await pumpEventQueue();

    final state = h.container.read(ttsPlaybackControllerProvider);
    expect(state.status, TtsPlaybackStatus.stopped);
    expect(state.sourceId, isNull);
  });

  group('replay', () {
    test('a clip that played to its end plays again without a second '
        'synthesis', () async {
      final file = preparedFile();
      final engine = FakeTtsEngine(output: file);
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(engine: engine, player: player);
      final controller = controllerOf(h.container);

      await controller.speak(sourceId: 'task-1', text: 'Summary');
      player.complete();
      await pumpEventQueue();
      verifyNever(file.delete);

      await controller.speak(sourceId: 'task-1', text: 'Summary');
      expect(engine.calls, hasLength(1));
      expect(player.playCount, 2);
      expect(
        h.container.read(ttsPlaybackControllerProvider).clip?.path,
        '/tmp/tts_clip.wav',
      );
    });

    test('a cloud voice is not asked again for the same words, but is for '
        'another voice', () async {
      final file = preparedFile();
      final cloud = FakeCloudSpeechSynthesizer(output: file);
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(player: player, cloud: cloud);
      final controller = controllerOf(h.container);
      Future<void> speak() => controller.speak(
        sourceId: 'task-1',
        text: 'Zwei offen.',
        cloudRoute: cloudRoute,
      );

      await speak();
      player.complete();
      await pumpEventQueue();
      await speak();
      expect(cloud.calls, hasLength(1));
      expect(player.playCount, 2);

      // A different voice for the language is a different clip.
      player.complete();
      await pumpEventQueue();
      h.container
          .read(ttsSettingsControllerProvider.notifier)
          .setCloudVoice('de', 'v-de-2');
      await speak();
      expect(cloud.calls, hasLength(2));
    });

    test('a replay still asks whether it may play, and drops the clip when '
        'it may not', () async {
      final file = preparedFile();
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(
        engine: FakeTtsEngine(output: file),
        player: player,
      );
      final controller = controllerOf(h.container);

      await controller.speak(sourceId: 'chat', text: 'Private answer');
      player.complete();
      await pumpEventQueue();
      await controller.speak(
        sourceId: 'chat',
        text: 'Private answer',
        canPlay: () async => false,
      );

      expect(player.playCount, 1);
      verify(file.delete).called(1);
    });

    test('other words, or disposal, delete the kept clip', () async {
      final kept = preparedFile();
      final next = MockIoFile();
      when(() => next.path).thenReturn('/tmp/tts_next.wav');
      when(next.existsSync).thenReturn(true);
      when(next.delete).thenAnswer((_) async => next);
      final engine = FakeTtsEngine(output: kept);
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(engine: engine, player: player);
      final controller = controllerOf(h.container);

      await controller.speak(sourceId: 'task-1', text: 'Summary');
      player.complete();
      await pumpEventQueue();
      engine.output = next;
      await controller.speak(sourceId: 'task-1', text: 'A new summary');
      await pumpEventQueue();
      verify(kept.delete).called(1);

      player.complete();
      await pumpEventQueue();
      h.container.dispose();
      await pumpEventQueue();
      verify(next.delete).called(1);
    });
  });

  test('missing model: asks with the model, then downloads with progress '
      'before synthesizing', () async {
    final repo = FakeTtsModelRepository(installed: false);
    final h = harness(repo: repo);
    final asked = <TtsModelOption>[];

    await controllerOf(h.container).speak(
      sourceId: 'task-1',
      text: 'x',
      confirmModelDownload: (model) async {
        asked.add(model);
        // Nothing has started downloading while the user is being asked.
        expect(repo.ensureCount, 0);
        return true;
      },
    );

    expect(asked.map((m) => m.id), [kDefaultTtsModelId]);
    expect(repo.ensureCount, 1);
    final statuses = h.states.map((s) => s.status).toList();
    expect(
      statuses,
      containsAllInOrder([
        TtsPlaybackStatus.downloadingModel,
        TtsPlaybackStatus.synthesizing,
        TtsPlaybackStatus.playing,
      ]),
    );
    // Progress was surfaced while downloading.
    final downloadStates = h.states.where(
      (s) => s.status == TtsPlaybackStatus.downloadingModel,
    );
    expect(downloadStates.map((s) => s.downloadProgress), contains(0.5));
  });

  group('missing model without consent', () {
    test(
      'a declined download fetches and speaks nothing, and ends quietly',
      () async {
        final repo = FakeTtsModelRepository(installed: false);
        final engine = FakeTtsEngine();
        final h = harness(repo: repo, engine: engine);

        await controllerOf(h.container).speak(
          sourceId: 'task-1',
          text: 'x',
          confirmModelDownload: (_) async => false,
        );

        expect(repo.ensureCount, 0);
        expect(engine.calls, isEmpty);
        expect(
          h.states.map((s) => s.status),
          isNot(contains(TtsPlaybackStatus.downloadingModel)),
        );
        final state = h.container.read(ttsPlaybackControllerProvider);
        expect(state.status, TtsPlaybackStatus.stopped);
        expect(state.sourceId, isNull);
        expect(state.errorMessage, isNull);
      },
    );

    test('without a way to ask, nothing downloads', () async {
      final repo = FakeTtsModelRepository(installed: false);
      final engine = FakeTtsEngine();
      final h = harness(repo: repo, engine: engine);

      await controllerOf(h.container).speak(sourceId: 'task-1', text: 'x');

      expect(repo.ensureCount, 0);
      expect(engine.calls, isEmpty);
      expect(
        h.container.read(ttsPlaybackControllerProvider).status,
        TtsPlaybackStatus.stopped,
      );
    });

    test('an installed model is never asked about', () async {
      final h = harness();
      var asked = false;

      await controllerOf(h.container).speak(
        sourceId: 'task-1',
        text: 'x',
        confirmModelDownload: (_) async => asked = true,
      );

      expect(asked, isFalse);
      expect(
        h.container.read(ttsPlaybackControllerProvider).status,
        TtsPlaybackStatus.playing,
      );
    });

    test('preparation never downloads the model', () async {
      final repo = FakeTtsModelRepository(installed: false);
      final engine = FakeTtsEngine();
      final h = harness(repo: repo, engine: engine);

      await controllerOf(h.container).prepare(
        sourceId: 'chat',
        text: 'Answer',
        canPrepare: () async => true,
      );

      expect(repo.ensureCount, 0);
      expect(engine.calls, isEmpty);
    });
  });

  test('ignores a second speak while already busy', () async {
    final engine = FakeTtsEngine();
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(engine: engine, player: player);

    await controllerOf(h.container).speak(sourceId: 'task-1', text: 'first');
    await controllerOf(h.container).speak(sourceId: 'task-2', text: 'second');

    final state = h.container.read(ttsPlaybackControllerProvider);
    expect(state.sourceId, 'task-1');
    expect(engine.calls, hasLength(1));
  });

  test('stop() stops the player and returns to stopped', () async {
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(player: player);

    await controllerOf(h.container).speak(sourceId: 'task-1', text: 'x');
    await controllerOf(h.container).stop();

    expect(player.stopCount, 1);
    expect(
      h.container.read(ttsPlaybackControllerProvider).status,
      TtsPlaybackStatus.stopped,
    );
  });

  test('updates position from the player while playing', () async {
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(player: player);

    await controllerOf(h.container).speak(sourceId: 'task-1', text: 'x');
    player.emitPosition(const Duration(seconds: 2));
    await pumpEventQueue();

    expect(
      h.container.read(ttsPlaybackControllerProvider).position,
      const Duration(seconds: 2),
    );
  });

  test('adopts the duration the player reports while playing', () async {
    final player = FakeTtsAudioPlayer();
    addTearDown(player.dispose);
    final h = harness(player: player);

    await controllerOf(h.container).speak(sourceId: 'task-1', text: 'x');
    player.emitDuration(const Duration(seconds: 42));
    await pumpEventQueue();

    expect(
      h.container.read(ttsPlaybackControllerProvider).duration,
      const Duration(seconds: 42),
    );
  });

  group('clip', () {
    // The fake engine writes every utterance to this file.
    const path = '/tmp/fake_tts_output.wav';

    test('names the clip and its words while it plays', () async {
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(player: player);

      await controllerOf(
        h.container,
      ).speak(sourceId: 'task-1', text: 'Four things today.');

      final state = h.container.read(ttsPlaybackControllerProvider);
      expect(state.status, TtsPlaybackStatus.playing);
      expect(state.clip, (path: path, text: 'Four things today.'));
    });

    test('is not named before playback starts', () async {
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(player: player);

      await controllerOf(h.container).speak(sourceId: 'task-1', text: 'x');

      final beforePlaying = h.states.where(
        (s) => s.status != TtsPlaybackStatus.playing,
      );
      expect(beforePlaying, isNotEmpty);
      expect(beforePlaying.map((s) => s.clip), everyElement(isNull));
    });

    test('is cleared when playback completes', () async {
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(player: player);

      await controllerOf(h.container).speak(sourceId: 'task-1', text: 'x');
      player.complete();
      await pumpEventQueue();

      expect(h.container.read(ttsPlaybackControllerProvider).clip, isNull);
    });

    test('is cleared when playback is stopped', () async {
      final player = FakeTtsAudioPlayer();
      addTearDown(player.dispose);
      final h = harness(player: player);

      await controllerOf(h.container).speak(sourceId: 'task-1', text: 'x');
      await controllerOf(h.container).stop();

      expect(h.container.read(ttsPlaybackControllerProvider).clip, isNull);
    });

    test('is cleared when the player fails to play the clip', () async {
      final player = FakeTtsAudioPlayer(playError: StateError('no output'));
      addTearDown(player.dispose);
      final h = harness(player: player);

      await controllerOf(h.container).speak(sourceId: 'task-1', text: 'x');

      final state = h.container.read(ttsPlaybackControllerProvider);
      expect(state.status, TtsPlaybackStatus.error);
      expect(state.clip, isNull);
      // It was named while playback was attempted.
      expect(h.states.map((s) => s.clip), contains((path: path, text: 'x')));
    });
  });
}
