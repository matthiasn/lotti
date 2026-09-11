import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
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
  }) {
    final container = ProviderContainer(
      overrides: [
        ttsEngineProvider.overrideWithValue(engine ?? FakeTtsEngine()),
        ttsAudioPlayerProvider.overrideWithValue(
          player ?? FakeTtsAudioPlayer(),
        ),
        ttsModelRepositoryProvider.overrideWithValue(
          repo ?? FakeTtsModelRepository(),
        ),
      ],
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

  for (final throws in [false, true]) {
    test(
      'a ${throws ? 'failed' : 'denied'} playback gate deletes synthesized audio without playing it',
      () async {
        final file = MockIoFile();
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

  test('missing model: downloads with progress before synthesizing', () async {
    final repo = FakeTtsModelRepository(installed: false);
    final h = harness(repo: repo);

    await controllerOf(h.container).speak(sourceId: 'task-1', text: 'x');

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
}
