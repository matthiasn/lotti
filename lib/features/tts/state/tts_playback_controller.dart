import 'dart:async';

import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tts_playback_controller.g.dart';

/// Language-agnostic synthesis mode; Supertonic infers from the text.
const String kDefaultTtsLanguage = 'na';

/// Orchestrates a single TTS utterance — ensure model → synthesize → play —
/// and exposes the [TtsPlaybackState] that the AI-card header's play button
/// binds to.
///
/// App-wide (keepAlive) so playback survives header rebuilds and only one
/// utterance plays at a time. [TtsPlaybackState.sourceId] tracks which content
/// is active so each header reflects only its own play/stop state.
@Riverpod(keepAlive: true)
class TtsPlaybackController extends _$TtsPlaybackController {
  StreamSubscription<void>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  @override
  TtsPlaybackState build() {
    ref.onDispose(_cancelPlayerSubscriptions);
    return const TtsPlaybackState();
  }

  /// Speaks [text], attributing the utterance to [sourceId]. A no-op while a
  /// previous utterance is still being prepared or playing.
  Future<void> speak({
    required String sourceId,
    required String text,
    String language = kDefaultTtsLanguage,
  }) async {
    if (state.isBusy) return;

    final engine = ref.read(ttsEngineProvider);
    if (!engine.isSupported) {
      state = state.copyWith(
        status: TtsPlaybackStatus.error,
        sourceId: sourceId,
        errorMessage: 'TTS engine is not available on this device.',
      );
      return;
    }

    final settings = ref.read(ttsSettingsControllerProvider);
    final repo = ref.read(ttsModelRepositoryProvider);

    try {
      final modelDir = await _ensureModel(repo, settings.modelId, sourceId);

      state = state.copyWith(
        status: TtsPlaybackStatus.synthesizing,
        sourceId: sourceId,
      );
      final file = await engine.synthesizeToFile(
        text: text,
        voiceId: settings.voiceId,
        modelDirectory: modelDir,
        language: language,
      );

      final player = ref.read(ttsAudioPlayerProvider);
      _listenToPlayer(player);
      state = state.copyWith(
        status: TtsPlaybackStatus.playing,
        sourceId: sourceId,
      );
      await player.play(file, speed: settings.speed);
    } catch (error) {
      _cancelPlayerSubscriptions();
      state = state.copyWith(
        status: TtsPlaybackStatus.error,
        sourceId: sourceId,
        errorMessage: error.toString(),
      );
    }
  }

  /// Stops the current utterance and returns to idle.
  Future<void> stop() async {
    await ref.read(ttsAudioPlayerProvider).stop();
    _onPlaybackEnded();
  }

  Future<String> _ensureModel(
    TtsModelRepository repo,
    String modelId,
    String sourceId,
  ) async {
    if (await repo.isInstalled(modelId)) {
      return repo.modelDirectory(modelId);
    }
    state = state.copyWith(
      status: TtsPlaybackStatus.downloadingModel,
      sourceId: sourceId,
      downloadProgress: 0,
    );
    return repo.ensureInstalled(
      modelId,
      onProgress: (progress) {
        if (state.status == TtsPlaybackStatus.downloadingModel) {
          state = state.copyWith(downloadProgress: progress);
        }
      },
    );
  }

  void _listenToPlayer(TtsAudioPlayer player) {
    _cancelPlayerSubscriptions();
    _completedSub = player.completedStream.listen((_) => _onPlaybackEnded());
    _positionSub = player.positionStream.listen((position) {
      if (state.status == TtsPlaybackStatus.playing) {
        state = state.copyWith(position: position);
      }
    });
    _durationSub = player.durationStream.listen((duration) {
      if (state.status == TtsPlaybackStatus.playing) {
        state = state.copyWith(duration: duration);
      }
    });
  }

  void _onPlaybackEnded() {
    _cancelPlayerSubscriptions();
    state = state.copyWith(
      status: TtsPlaybackStatus.stopped,
      sourceId: null,
      position: Duration.zero,
    );
  }

  void _cancelPlayerSubscriptions() {
    _completedSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub = null;
    _positionSub = null;
    _durationSub = null;
  }
}
