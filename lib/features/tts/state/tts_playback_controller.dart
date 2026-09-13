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

/// One disposable, device-local result. Its key includes every synthesis input;
/// playback speed is applied by the player and does not change the WAV.
class _PreparedSpeech {
  _PreparedSpeech(this.key);

  final ({
    String sourceId,
    String text,
    String voice,
    String model,
    String language,
  })
  key;
  final done = Completer<void>();
  File? file;
  bool cancelled = false;
}

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
  TtsPlaybackController({DomainLogger? logger})
    : _logger = logger ?? getIt<DomainLogger>();

  StreamSubscription<void>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  int _generation = 0;
  Future<void> _preparation = Future<void>.value();
  _PreparedSpeech? _prepared;
  File? _file;
  TtsAudioPlayer? _player;
  // Cleanup can finish after provider disposal, when ref is no longer usable.
  final DomainLogger _logger;

  @override
  TtsPlaybackState build() {
    ref.onDispose(() {
      _generation++;
      discardPrepared();
      _cancelPlayerSubscriptions();
      final file = _file;
      _file = null;
      unawaited(_stopAndDelete(_player, file));
    });
    return const TtsPlaybackState();
  }

  /// Silently prepares one utterance without taking playback ownership. A
  /// matching [speak] joins this work. Replacements and cancellation discard
  /// native results, and all synthesis shares the same serialized queue.
  Future<void> prepare({
    required String sourceId,
    required String text,
    required Future<bool> Function() canPrepare,
    String language = kDefaultTtsLanguage,
  }) async {
    if (!ref.mounted || state.isBusy) return;
    final settings = ref.read(ttsSettingsControllerProvider);
    final key = (
      sourceId: sourceId,
      text: text,
      voice: settings.voiceId,
      model: settings.modelId,
      language: language,
    );
    final existing = _prepared;
    if (existing != null && existing.key == key) return existing.done.future;
    discardPrepared();
    final engine = ref.read(ttsEngineProvider);
    if (!engine.isSupported) return;
    final repo = ref.read(ttsModelRepositoryProvider);
    final job = _prepared = _PreparedSpeech(key);
    final previous = _preparation;
    _preparation = job.done.future;
    bool current() => ref.mounted && !job.cancelled;
    File? file;
    try {
      await previous;
      if (!current() || !await canPrepare() || !current()) return;
      final directory = await repo.ensureInstalled(settings.modelId);
      if (!current() || !await canPrepare() || !current()) return;
      file = await engine.synthesizeToFile(
        text: text,
        voiceId: settings.voiceId,
        modelDirectory: directory,
        language: language,
      );
      if (!current() || !await canPrepare() || !current()) return;
      job.file = file;
      file = null;
    } on Object {
      // Speculative failure must not surface an error or disable explicit
      // playback: a later tap can retry through the normal visible path.
    } finally {
      try {
        await _deleteFile(file);
      } finally {
        job.done.complete();
      }
    }
  }

  /// Invalidates prepared audio synchronously, including in-flight work.
  /// Does not interrupt explicit playback, which owns its own file.
  void discardPrepared({String? sourceId}) {
    final job = _prepared;
    if (job == null || (sourceId != null && job.key.sourceId != sourceId)) {
      return;
    }
    _prepared = null;
    job.cancelled = true;
    final file = job.file;
    job.file = null;
    unawaited(_deleteFile(file));
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
    final prepared = _prepared;
    final matches =
        prepared?.key ==
        (
          sourceId: sourceId,
          text: text,
          voice: settings.voiceId,
          model: settings.modelId,
          language: language,
        );
    if (!matches) discardPrepared();
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
      File? file;
      if (matches && identical(_prepared, prepared) && !prepared!.cancelled) {
        file = prepared.file;
        prepared.file = null;
        _prepared = null;
      }
      if (file == null) {
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
        file = await engine.synthesizeToFile(
          text: text,
          voiceId: settings.voiceId,
          modelDirectory: modelDir,
          language: language,
        );
      }
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
