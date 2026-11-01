import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/cloud/voxtral_tts_service.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

/// Language-agnostic synthesis mode; Supertonic infers from the text.
const String kDefaultTtsLanguage = 'na';

/// Asks the user whether to download [model] — a download of
/// [TtsModelOption.totalBytes] — and answers whether they agreed.
typedef TtsModelDownloadConsent = Future<bool> Function(TtsModelOption model);

/// Every input that shapes a synthesized WAV; playback speed is applied by
/// the player and does not change it.
typedef _SpeechKey = ({
  String sourceId,
  String text,
  String voice,
  String model,
  String language,
});

/// One disposable, device-local result, keyed by everything that shaped it:
/// audio prepared ahead of a tap, or the utterance that just finished playing,
/// kept so playing it again replays the clip instead of synthesizing it — or,
/// for a cloud voice, uploading the text — a second time.
class _PreparedSpeech {
  _PreparedSpeech(this.key);

  final _SpeechKey key;
  final done = Completer<void>();
  File? file;
  bool cancelled = false;
}

/// Orchestrates a single TTS utterance — ensure model → synthesize → play —
/// and exposes the [TtsPlaybackState] that the AI-card header's play button
/// binds to.
///
/// An utterance with a [TtsCloudRoute] is synthesized by that cloud voice
/// instead of the on-device model; everything after synthesis is shared.
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
  TtsPlaybackController({DomainLogger? logger}) : _injectedLogger = logger;

  StreamSubscription<void>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  int _generation = 0;
  Future<void> _preparation = Future<void>.value();
  _PreparedSpeech? _prepared;
  File? _file;
  _SpeechKey? _fileKey;
  Future<bool> Function()? _fileGate;
  TtsAudioPlayer? _player;
  final DomainLogger? _injectedLogger;
  // Captured in build: cleanup can finish after provider disposal, when ref is
  // no longer usable.
  late DomainLogger _logger;

  @override
  TtsPlaybackState build() {
    _logger = _injectedLogger ?? ref.watch(domainLoggerProvider);
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
  ///
  /// Never downloads: with the model not installed it does nothing, because
  /// the model may only arrive through a download the user agreed to. Never
  /// calls a cloud voice either: with a [cloudRoute] it does nothing, so text
  /// leaves the device only when the user presses play.
  Future<void> prepare({
    required String sourceId,
    required String text,
    required Future<bool> Function() canPrepare,
    String language = kDefaultTtsLanguage,
    TtsCloudRoute? cloudRoute,
  }) async {
    if (!ref.mounted || state.isBusy || cloudRoute != null) return;
    final settings = ref.read(ttsSettingsControllerProvider);
    final key = _keyFor(sourceId, text, language, settings, null);
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
      if (!await repo.isInstalled(settings.modelId)) return;
      final directory = await repo.modelDirectory(settings.modelId);
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
  ///
  /// When the model is not installed yet, [confirmModelDownload] is asked
  /// first; without it, or when the user declines, nothing downloads and the
  /// utterance ends quietly.
  ///
  /// With a [cloudRoute] the text is spoken by that cloud voice, which needs
  /// neither the on-device model nor platform support for it.
  Future<void> speak({
    required String sourceId,
    required String text,
    String language = kDefaultTtsLanguage,
    Future<bool> Function()? canPlay,
    TtsModelDownloadConsent? confirmModelDownload,
    TtsCloudRoute? cloudRoute,
  }) async {
    if (state.isBusy) return;
    final generation = ++_generation;

    final engine = ref.read(ttsEngineProvider);
    if (cloudRoute == null && !engine.isSupported) {
      state = state.copyWith(
        status: TtsPlaybackStatus.error,
        sourceId: sourceId,
        errorMessage: 'TTS engine is not available on this device.',
      );
      return;
    }

    final settings = ref.read(ttsSettingsControllerProvider);
    final prepared = _prepared;
    final key = _keyFor(sourceId, text, language, settings, cloudRoute);
    final matches = prepared?.key == key;
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
      if (file == null && cloudRoute != null) {
        // Checked again right before the text is uploaded: a stop, or the
        // caller withdrawing permission, while the voice catalog loads must
        // keep the text on the device.
        file = await ref
            .read(cloudSpeechSynthesizerProvider)
            .synthesizeToFile(
              route: cloudRoute,
              text: text,
              voiceByLanguage: settings.cloudVoiceByLanguage,
              canSend: () async =>
                  current() && (canPlay == null || await canPlay()),
            );
        if (file == null) {
          if (current()) _onPlaybackEnded();
          return;
        }
      }
      if (file == null) {
        final modelDir = await _ensureModel(
          repo,
          settings.modelId,
          sourceId,
          current,
          confirmModelDownload,
        );
        if (!current()) return;
        if (modelDir == null) {
          _onPlaybackEnded();
          return;
        }

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
      _fileKey = key;
      _fileGate = canPlay;
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
        clip: (path: file.path, text: text),
      );
      await player.play(file, speed: settings.speed);
    } catch (error, stackTrace) {
      if (!current()) return;
      // The Voxtral client logs its own request failures with their detail;
      // everything else — the on-device engine, the player, a language with
      // no cloud voice — would otherwise surface only as the generic toast.
      if (error is! VoxtralTtsException ||
          error.failure == VoxtralTtsFailure.noVoice) {
        _logger.error(
          LogDomain.speech,
          error,
          stackTrace: stackTrace,
          subDomain: 'ttsPlayback.speak',
          message: cloudRoute == null
              ? 'On-device speech failed'
              : 'Cloud speech failed (${cloudRoute.cacheKey})',
        );
      }
      _cancelPlayerSubscriptions();
      final file = _file;
      _file = null;
      await _stopAndDelete(_player, file);
      if (!current()) return;
      state = state.copyWith(
        status: TtsPlaybackStatus.error,
        sourceId: sourceId,
        clip: null,
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

  /// The model's directory, downloading it first when the user agrees, or
  /// null when it is missing and may not be downloaded.
  Future<String?> _ensureModel(
    TtsModelRepository repo,
    String modelId,
    String sourceId,
    bool Function() current,
    TtsModelDownloadConsent? confirmModelDownload,
  ) async {
    if (await repo.isInstalled(modelId)) {
      return repo.modelDirectory(modelId);
    }
    if (!current() || confirmModelDownload == null) return null;
    final agreed = await confirmModelDownload(ttsModelByIdOrDefault(modelId));
    if (!agreed || !current()) return null;
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
    _completedSub = player.completedStream.listen((_) async {
      await _onPlaybackFinished();
    });
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

  /// The utterance played to its end: its clip becomes the prepared result
  /// for its key, so the same words, voice and language play again at once —
  /// while the caller's `canPlay` still allows it, asked again now. The clip
  /// goes into the slot before the question, so a discard, anything else
  /// spoken or prepared, and disposal reach it however long the answer takes;
  /// a no takes it out again. An owner that lost access or let go of the
  /// utterance never leaves a clip behind, however its own cleanup and this
  /// completion interleave. A stop deletes a clip still playing.
  Future<void> _onPlaybackFinished() async {
    final file = _file;
    final key = _fileKey;
    final gate = _fileGate;
    _file = null;
    _onPlaybackEnded();
    if (file == null) return;
    if (key == null || !ref.mounted) {
      await _deleteFile(file);
      return;
    }
    discardPrepared();
    final job = _prepared = _PreparedSpeech(key)
      ..file = file
      ..done.complete();
    if (gate == null) return;
    var allowed = false;
    try {
      allowed = await gate();
    } on Object {
      allowed = false;
    }
    // Still in the slot: neither replayed, replaced, discarded nor disposed.
    if (!allowed && identical(_prepared, job)) discardPrepared();
  }

  /// The key of an utterance: on a cloud route, its voice is the route's or
  /// the one chosen for its language, so a different voice never replays the
  /// old one's clip.
  static _SpeechKey _keyFor(
    String sourceId,
    String text,
    String language,
    TtsSettings settings,
    TtsCloudRoute? cloudRoute,
  ) => (
    sourceId: sourceId,
    text: text,
    voice: cloudRoute == null
        ? settings.voiceId
        : cloudRoute.voiceId ??
              settings.cloudVoiceByLanguage[cloudRoute.languageCode] ??
              '',
    model: cloudRoute?.cacheKey ?? settings.modelId,
    language: language,
  );

  void _onPlaybackEnded() {
    _fileKey = null;
    _fileGate = null;
    _cancelPlayerSubscriptions();
    final file = _file;
    _file = null;
    unawaited(_deleteFile(file));
    if (!ref.mounted) return;
    state = state.copyWith(
      status: TtsPlaybackStatus.stopped,
      sourceId: null,
      position: Duration.zero,
      clip: null,
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
