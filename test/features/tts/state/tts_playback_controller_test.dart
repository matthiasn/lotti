import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';

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
