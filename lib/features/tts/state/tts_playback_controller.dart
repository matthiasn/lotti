import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Language-agnostic synthesis mode; Supertonic infers from the text.
const String kDefaultTtsLanguage = 'na';

/// Orchestrates a single TTS utterance — ensure model → synthesize → play —
/// and exposes the [TtsPlaybackState] that the AI-card header's play button
/// binds to.
///
/// App-wide (keepAlive) so playback survives header rebuilds and only one
/// utterance plays at a time. [TtsPlaybackState.sourceId] tracks which content
/// is active so each header reflects only its own play/stop state.
final ttsPlaybackControllerProvider =
    NotifierProvider<TtsPlaybackController, TtsPlaybackState>(
      TtsPlaybackController.new,
      name: 'ttsPlaybackControllerProvider',
    );

class TtsPlaybackController extends Notifier<TtsPlaybackState> {
  StreamSubscription<void>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  int _generation = 0;
  Future<void> _preparation = Future<void>.value();
  File? _file;
  TtsAudioPlayer? _player;
  late DomainLogger _logger;

  @override
  TtsPlaybackState build() {
    // Cleanup can finish after provider disposal, when ref is no longer usable.
    _logger = getIt<DomainLogger>();
    ref.onDispose(() {
      _generation++;
      _cancelPlayerSubscriptions();
      final file = _file;
      _file = null;
      unawaited(_stopAndDelete(_player, file));
    });
    return const TtsPlaybackState();
  }

  /// Speaks [text], attributing the utterance to [sourceId]. A no-op while a
  /// previous utterance is still being prepared or playing. Cancelled native
  /// synthesis may finish, but its result is deleted and never played.
  Future<void> speak({
    required String sourceId,
    required String text,
    String language = kDefaultTtsLanguage,
    Future<bool> Function()? canPlay,
  }) async {
    if (state.isBusy) return;
    final generation = ++_generation;

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
    final previous = _preparation;
    final finished = Completer<void>();
    _preparation = finished.future;
    state = TtsPlaybackState(
      status: TtsPlaybackStatus.synthesizing,
      sourceId: sourceId,
    );
    bool current() => ref.mounted && generation == _generation;

    try {
      // ONNX sessions are shared. A new request waits for cancelled native
      // synthesis to finish instead of running two jobs through one session.
      await previous;
      if (!current()) return;
      final modelDir = await _ensureModel(
        repo,
        settings.modelId,
        sourceId,
        current,
      );
      if (!current()) return;

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
      if (!current()) {
        await _deleteFile(file);
        return;
      }
      _file = file;
      final allowed = canPlay == null || await canPlay();
      if (!current() || !allowed) {
        if (identical(_file, file)) _file = null;
        await _deleteFile(file);
        if (current()) _onPlaybackEnded();
        return;
      }

      final player = ref.read(ttsAudioPlayerProvider);
      _player = player;
      _listenToPlayer(player);
      state = state.copyWith(
        status: TtsPlaybackStatus.playing,
        sourceId: sourceId,
      );
      await player.play(file, speed: settings.speed);
    } catch (error) {
      if (!current()) return;
      _cancelPlayerSubscriptions();
      final file = _file;
      _file = null;
      await _stopAndDelete(_player, file);
      if (!current()) return;
      state = state.copyWith(
        status: TtsPlaybackStatus.error,
        sourceId: sourceId,
        errorMessage: error.toString(),
      );
    } finally {
      finished.complete();
    }
  }

  /// Stops the current utterance. When [sourceId] is supplied, another
  /// surface's utterance is left playing. Preparation is invalidated before
  /// awaiting native work, and any owned temporary WAV is removed.
  Future<void> stop({String? sourceId}) async {
    if (!ref.mounted || (sourceId != null && state.sourceId != sourceId)) {
      return;
    }
    _generation++;
    final file = _file;
    _file = null;
    final player = _player;
    // Invalidate preparation and presentation before the native await.
    _onPlaybackEnded();
    await _stopAndDelete(player, file);
  }

  Future<String> _ensureModel(
    TtsModelRepository repo,
    String modelId,
    String sourceId,
    bool Function() current,
  ) async {
    if (await repo.isInstalled(modelId)) {
      return repo.modelDirectory(modelId);
    }
    if (!current()) return '';
    state = state.copyWith(
      status: TtsPlaybackStatus.downloadingModel,
      sourceId: sourceId,
      downloadProgress: 0,
    );
    return repo.ensureInstalled(
      modelId,
      onProgress: (progress) {
        if (current() && state.status == TtsPlaybackStatus.downloadingModel) {
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
    final file = _file;
    _file = null;
    unawaited(_deleteFile(file));
    if (!ref.mounted) return;
    state = state.copyWith(
      status: TtsPlaybackStatus.stopped,
      sourceId: null,
      position: Duration.zero,
    );
  }

  Future<void> _stopAndDelete(TtsAudioPlayer? player, File? file) async {
    try {
      await player?.stop();
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.speech,
        StateError('TTS player shutdown failed (${error.runtimeType})'),
        subDomain: 'ttsPlayback.stop',
        stackTrace: stackTrace,
      );
    } finally {
      await _deleteFile(file);
    }
  }

  Future<void> _deleteFile(File? file) async {
    if (file == null) return;
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error, stackTrace) {
      // ENOENT also covers a temporary WAV removed between exists and delete.
      if (error.osError?.errorCode == 2) return;
      _logger.error(
        LogDomain.speech,
        StateError(
          'Temporary TTS audio deletion failed (OS error ${error.osError?.errorCode})',
        ),
        subDomain: 'ttsPlayback.delete',
        stackTrace: stackTrace,
      );
    }
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
