import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/cloud/growing_speech_clip.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_bundled_clip.dart';
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

/// Stops the read-aloud voice before a microphone opens, so a recording never
/// captures Lotti reading a summary, an answer or the Day briefing aloud. The
/// voice has no pause — its control only plays and stops — so it stops.
///
/// Leaves the voice alone when it is not downloading, synthesizing or playing,
/// and never builds it just to silence it. Either way it waits for the
/// player to let go of the phone's audio session — a clip that just ended may
/// still be releasing it — so the recorder's session is never deactivated
/// under it. A failure to stop is logged and swallowed: the recording must
/// start regardless.
Future<void> stopReadAloudForRecording(Ref ref) async {
  if (!ref.exists(ttsPlaybackControllerProvider)) return;
  try {
    if (ref.read(ttsPlaybackControllerProvider).isBusy) {
      await ref.read(ttsPlaybackControllerProvider.notifier).stop();
    }
    if (ref.exists(ttsAudioPlayerProvider)) {
      await ref.read(ttsAudioPlayerProvider).settled;
    }
  } catch (error) {
    ref
        .read(domainLoggerProvider)
        .log(
          LogDomain.speech,
          'Read-aloud voice could not be stopped, recording anyway: $error',
          subDomain: 'stopReadAloudForRecording',
        );
  }
}

class TtsPlaybackController extends Notifier<TtsPlaybackState> {
  TtsPlaybackController({DomainLogger? logger}) : _injectedLogger = logger;

  StreamSubscription<void>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  int _generation = 0;
  Future<void> _preparation = Future<void>.value();
  _PreparedSpeech? _prepared;

  /// The clip playing while its cloud voice is still writing it; null for
  /// one that was whole before it played.
  GrowingSpeechClip? _growing;

  /// The clip being played, with the key it was made under and the caller's
  /// gate — one record, so a playing file never lacks either.
  ({File file, _SpeechKey key, Future<bool> Function()? canPlay})? _playing;
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
      final file = _playing?.file;
      _playing = null;
      final growing = _growing;
      _growing = null;
      unawaited(_stopAndDelete(_player, file, growing));
    });
    // A new speed reaches the clip that is speaking, not only the next one.
    // A bundled sample keeps its natural speed ([playClip]).
    ref.listen(ttsSettingsControllerProvider.select((s) => s.speed), (
      _,
      speed,
    ) {
      final playing = _playing;
      if (state.status != TtsPlaybackStatus.playing ||
          playing == null ||
          playing.key.model == _bundledClipModel) {
        return;
      }
      // A rate the player refuses leaves the clip at its old speed; the next
      // one opens at the new speed regardless.
      _player?.setSpeed(speed).ignore();
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
    var key = _keyFor(sourceId, text, language, settings, cloudRoute);
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
      GrowingSpeechClip? growing;
      if (file == null && cloudRoute != null) {
        try {
          final cloud = ref.read(cloudSpeechSynthesizerProvider);
          // Checked again right before the text is uploaded: a stop, or the
          // caller withdrawing permission, while the voice catalog loads —
          // or while the caller is still being asked — must keep the text
          // on the device.
          Future<bool> canSend() async =>
              current() && (canPlay == null || await canPlay()) && current();
          var sent = true;
          if (cloud.canStream(cloudRoute)) {
            // One synthesis, played while it is still arriving: her first
            // words are heard a fraction of a second in, in one voice.
            final clip = await cloud.synthesizeToGrowingFile(
              route: cloudRoute,
              text: text,
              chosenVoices: settings.cloudVoiceByLanguage,
              canSend: canSend,
            );
            sent = clip != null;
            if (clip != null) {
              if (!current()) {
                await _discard(clip);
                return;
              }
              _growing = clip;
              await clip.playable;
              // A stop meanwhile took the clip and deleted it.
              if (!current()) return;
              final failure = clip.failure;
              if (failure != null || !clip.hasAudio) {
                _growing = null;
                await _discard(clip);
                if (failure != null) {
                  Error.throwWithStackTrace(failure.error, failure.stackTrace);
                }
                // No audio that way, for a word or two: asked for whole.
              } else {
                growing = clip;
                file = clip.file;
              }
            }
          }
          if (file == null && sent) {
            file = await cloud.synthesizeToFile(
              route: cloudRoute,
              text: text,
              chosenVoices: settings.cloudVoiceByLanguage,
              canSend: canSend,
            );
          }
          if (file == null) {
            if (current()) _onPlaybackEnded();
            return;
          }
        } on CloudTtsException catch (error) {
          // The cloud voice has no voice for the language, and nothing was
          // sent; or the provider cannot be reached at all. Either way the
          // on-device voice, which infers the language from the text, speaks
          // it instead of a failure — but offline only when it is installed:
          // its download needs the network that just failed.
          final unreachable =
              error.failure == CloudTtsFailure.network ||
              error.failure == CloudTtsFailure.timeout;
          final fallBack =
              engine.isSupported &&
              (error.failure == CloudTtsFailure.noVoice ||
                  unreachable && await repo.isInstalled(settings.modelId));
          if (!fallBack) rethrow;
          if (!current()) return;
          // Its clip is kept under the on-device key: replayed for the cloud
          // route it would skip asking the cloud again, and outlive a change
          // of the on-device voice.
          key = _keyFor(sourceId, text, language, settings, null);
          _logger.log(
            LogDomain.speech,
            unreachable
                ? 'Cloud voice unreachable (${error.failure.name}); '
                      'the on-device voice speaks'
                : 'No cloud voice for ${cloudRoute.languageCode}; '
                      'the on-device voice speaks',
            subDomain: 'ttsPlayback.speak',
          );
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
        // A stop took a clip still being written; any other is deleted here.
        if (growing == null) await _deleteFile(file);
        return;
      }
      _playing = (file: file, key: key, canPlay: canPlay);
      final allowed = canPlay == null || await canPlay();
      if (!current() || !allowed) {
        if (identical(_playing?.file, file)) _playing = null;
        if (identical(_growing, growing)) _growing = null;
        if (growing != null) {
          await _discard(growing);
        } else if (!identical(_prepared?.file, file)) {
          // A stop meanwhile kept the clip for a replay: it is the slot's
          // now.
          await _deleteFile(file);
        }
        if (current()) _onPlaybackEnded();
        return;
      }

      final player = ref.read(ttsAudioPlayerProvider);
      _player = player;
      _listenToPlayer(player);
      state = state.copyWith(
        status: TtsPlaybackStatus.playing,
        sourceId: sourceId,
        // A clip still being written has no audio to read a mouth from yet:
        // without a path she goes by the words, and gets the path — and
        // with it the sound — once the file is whole ([_followGrowing]).
        clip: (path: growing == null ? file.path : '', text: text),
      );
      if (growing != null) {
        // Nothing waits for it, and it handles its own outcome.
        _followGrowing(growing, generation, text).ignore();
      }
      // The speed now, not when synthesis began: it may have changed since.
      final speed = ref.read(ttsSettingsControllerProvider).speed;
      await player.play(file, speed: speed);
      // A change while the player was opening was applied and then
      // overwritten by the rate `play` sets: put the latest one back.
      final latest = ref.read(ttsSettingsControllerProvider).speed;
      if (current() && latest != speed) await player.setSpeed(latest);
    } catch (error, stackTrace) {
      if (!current()) return;
      // The cloud clients log their own request failures with their detail;
      // everything else — the on-device engine, the player, a language with
      // no cloud voice — would otherwise surface only as the generic toast.
      if (error is! CloudTtsException ||
          error.failure == CloudTtsFailure.noVoice) {
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
      await _onSpeechFailed(error, sourceId, current);
    } finally {
      finished.complete();
    }
  }

  /// An utterance of [sourceId] that could not be made or played, already
  /// logged: its clip is deleted and the state says so.
  Future<void> _onSpeechFailed(
    Object error,
    String sourceId,
    bool Function() current,
  ) async {
    _cancelPlayerSubscriptions();
    final file = _playing?.file;
    _playing = null;
    final growing = _growing;
    _growing = null;
    await _stopAndDelete(_player, file, growing);
    if (!current()) return;
    state = state.copyWith(
      status: TtsPlaybackStatus.error,
      sourceId: sourceId,
      clip: null,
      errorMessage: error.toString(),
    );
  }

  /// Stops writing [clip] and deletes what was written of it.
  Future<void> _discard(GrowingSpeechClip clip) async {
    await clip.cancel();
    await _deleteFile(clip.file);
  }

  /// Once [growing] is whole while it still plays, the state names its
  /// file, so whoever shapes a mouth to the clip reads its sound from then
  /// on. A stream that failed is dealt with when the player reaches the end
  /// of what it wrote ([_resumeGrowing]): what is there is still spoken.
  Future<void> _followGrowing(
    GrowingSpeechClip growing,
    int generation,
    String text,
  ) async {
    await growing.done;
    if (!ref.mounted ||
        generation != _generation ||
        !identical(_growing, growing) ||
        !growing.isComplete ||
        state.status != TtsPlaybackStatus.playing) {
      return;
    }
    state = state.copyWith(clip: (path: growing.file.path, text: text));
  }

  /// The player reached the end of what was written of [growing] before
  /// the voice had finished — the network stalled for longer than the lead
  /// it started with. Once the rest is there, the clip is opened again
  /// where it stopped; if the stream failed instead, so does the utterance.
  Future<void> _resumeGrowing(GrowingSpeechClip growing) async {
    final generation = _generation;
    final sourceId = state.sourceId;
    final at = state.position;
    bool sameUtterance() => ref.mounted && generation == _generation;
    bool current() => sameUtterance() && identical(_growing, growing);
    try {
      await growing.done;
      if (!current() || sourceId == null) return;
      if (growing.failure case (:final error, :final stackTrace)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      _logger.log(
        LogDomain.speech,
        'Speech played faster than it arrived; resumed at '
        '${at.inMilliseconds} ms',
        subDomain: 'ttsPlayback.speak',
      );
      await _player?.play(
        growing.file,
        speed: ref.read(ttsSettingsControllerProvider).speed,
        from: at,
      );
    } catch (error, stackTrace) {
      if (!current() || sourceId == null) return;
      if (error is! CloudTtsException) {
        _logger.error(
          LogDomain.speech,
          error,
          stackTrace: stackTrace,
          subDomain: 'ttsPlayback.speak',
          message: 'Cloud speech failed while it was arriving',
        );
      }
      // The failure lets go of the clip, so only the utterance is asked
      // about afterwards.
      await _onSpeechFailed(error, sourceId, sameUtterance);
    }
  }

  /// Plays the bundled clip [asset], which speaks [text], attributing it to
  /// [sourceId] — through the same player and state as synthesized speech, so
  /// the companion lip-syncs to it. A no-op while another utterance is being
  /// prepared or playing.
  ///
  /// Needs neither the on-device model nor the network: onboarding plays the
  /// voices it offers this way before any of them is set up. The clip plays at
  /// its natural speed, since it is a sample of how the voice sounds.
  Future<void> playClip({
    required String sourceId,
    required String asset,
    required String text,
  }) async {
    if (state.isBusy) return;
    final generation = ++_generation;
    discardPrepared();
    bool current() => ref.mounted && generation == _generation;
    state = TtsPlaybackState(
      status: TtsPlaybackStatus.synthesizing,
      sourceId: sourceId,
    );
    File? file;
    try {
      file = await ref.read(ttsBundledClipCopierProvider)(asset);
      if (!current()) {
        await _deleteFile(file);
        return;
      }
      _playing = (
        file: file,
        key: (
          sourceId: sourceId,
          text: text,
          voice: asset,
          model: _bundledClipModel,
          language: kDefaultTtsLanguage,
        ),
        canPlay: null,
      );
      final player = ref.read(ttsAudioPlayerProvider);
      _player = player;
      _listenToPlayer(player);
      state = state.copyWith(
        status: TtsPlaybackStatus.playing,
        sourceId: sourceId,
        clip: (path: file.path, text: text),
      );
      await player.play(file, speed: 1);
    } catch (error, stackTrace) {
      if (!current()) return;
      _logger.error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: 'ttsPlayback.playClip',
        message: 'Bundled clip failed ($asset)',
      );
      _cancelPlayerSubscriptions();
      final owned = _playing?.file ?? file;
      _playing = null;
      await _stopAndDelete(_player, owned);
      if (!current()) return;
      state = state.copyWith(
        status: TtsPlaybackStatus.error,
        sourceId: sourceId,
        clip: null,
        errorMessage: error.toString(),
      );
    }
  }

  /// The model slot of a bundled clip's key: never one a synthesized
  /// utterance has, so a sample is never replayed in place of real speech.
  static const _bundledClipModel = 'bundled-clip';

  /// Stops the current utterance. When [sourceId] is supplied, another
  /// surface's utterance is left playing. Preparation is invalidated before
  /// awaiting native work.
  ///
  /// A clip already made is kept for a replay, as one played to its end is
  /// ([_keepForReplay]): stopping her and asking for the answer again plays
  /// it at once, in the voice it was made in, rather than making it again.
  Future<void> stop({String? sourceId}) async {
    if (!ref.mounted || (sourceId != null && state.sourceId != sourceId)) {
      return;
    }
    _generation++;
    final growing = _growing;
    _growing = null;
    // A clip still being written is not all of the utterance: it is not
    // kept for a replay, which would play it as if it were.
    final partial = growing != null && !growing.isComplete;
    final played = partial ? null : _playing;
    _playing = null;
    final player = _player;
    // Invalidate preparation and presentation before the native await.
    _onPlaybackEnded();
    final kept = _keepForReplay(played);
    await _stopAndDelete(player, null, partial ? growing : null);
    await kept;
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

  /// The utterance played to its end: its clip is kept for a replay. A
  /// clip still being written has not ended, only run out ([_resumeGrowing]).
  Future<void> _onPlaybackFinished() async {
    final growing = _growing;
    if (growing != null && !growing.isComplete) return _resumeGrowing(growing);
    _growing = null;
    final played = _playing;
    _playing = null;
    _onPlaybackEnded();
    await _keepForReplay(played);
  }

  /// [played]'s clip — finished or stopped — becomes the prepared result
  /// for its key, so the same words, voice and language play again at once —
  /// while the caller's `canPlay` still allows it, asked again now. The clip
  /// goes into the slot before the question, so a discard, anything else
  /// spoken or prepared, and disposal reach it however long the answer takes;
  /// a no takes it out again. An owner that lost access or let go of the
  /// utterance never leaves a clip behind, however its own cleanup and this
  /// interleave.
  Future<void> _keepForReplay(
    ({File file, _SpeechKey key, Future<bool> Function()? canPlay})? played,
  ) async {
    if (played == null) return;
    discardPrepared();
    final job = _prepared = _PreparedSpeech(played.key)
      ..file = played.file
      ..done.complete();
    final canPlay = played.canPlay;
    if (canPlay == null) return;
    var allowed = false;
    try {
      allowed = await canPlay();
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
              settings.cloudVoiceFor(
                cloudRoute.provider,
                cloudRoute.languageCode,
              ) ??
              '',
    model: cloudRoute?.cacheKey ?? settings.modelId,
    language: language,
  );

  void _onPlaybackEnded() {
    _cancelPlayerSubscriptions();
    final file = _playing?.file;
    _playing = null;
    unawaited(_deleteFile(file));
    if (!ref.mounted) return;
    state = state.copyWith(
      status: TtsPlaybackStatus.stopped,
      sourceId: null,
      position: Duration.zero,
      clip: null,
    );
  }

  /// Stops [player] and deletes [file] — and stops writing [growing] and
  /// deletes what there is of it — whether or not the player stops cleanly.
  Future<void> _stopAndDelete(
    TtsAudioPlayer? player,
    File? file, [
    GrowingSpeechClip? growing,
  ]) async {
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
      if (growing != null) await _discard(growing);
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
