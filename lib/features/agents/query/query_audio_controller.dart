import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_audio_excerpt.dart';
import 'package:lotti/features/agents/query/query_audio_timing_service.dart';
import 'package:lotti/features/agents/query/query_audio_timing_writer.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:media_kit/media_kit.dart';

typedef QueryAudioChatKey = ({QueryChatKey home, String chatId});

enum QueryAudioStatus {
  idle,
  preparing,
  playing,
  unmatched,
  unavailable,
  stale,
  missingFile,
  tooLarge,
  failed,
}

class _StaleAudioTiming implements Exception {
  const _StaleAudioTiming();
}

class QueryAudioState {
  const QueryAudioState({
    this.actionId,
    this.status = QueryAudioStatus.idle,
    this.excerpt,
  });
  final String? actionId;
  final QueryAudioStatus status;
  final QueryAudioExcerpt? excerpt;
  bool get busy =>
      status == QueryAudioStatus.preparing ||
      status == QueryAudioStatus.playing;
}

final queryAudioFileProvider = Provider<Future<File> Function(JournalAudio)>(
  (ref) =>
      (entry) async => File(await AudioUtils.getFullAudioPath(entry)),
);

/// The selected chat owns playback. Losing the last UI listener cancels even
/// before auto-disposal, so a delayed native or HTTP result cannot start sound
/// after navigation. Visibility settings also cancel synchronously.
final NotifierProviderFamily<
  QueryAudioController,
  QueryAudioState,
  QueryAudioChatKey
>
queryAudioControllerProvider = NotifierProvider.autoDispose
    .family<QueryAudioController, QueryAudioState, QueryAudioChatKey>(
      QueryAudioController.new,
    );

class QueryAudioController extends Notifier<QueryAudioState> {
  QueryAudioController(this.key);
  final QueryAudioChatKey key;
  QueryCancellation? _run;
  QueryEvidence? _activeEvidence;
  Player? _player;
  StreamSubscription<bool>? _completed;
  TtsPlaybackController? _tts;
  String? _ttsSourceId;
  int _intent = 0;

  @override
  QueryAudioState build() {
    _tts = ref.read(ttsPlaybackControllerProvider.notifier);
    ref
      ..listen(configFlagProvider('private'), (previous, next) {
        if (previous?.value == true && next.value != true) unawaited(stop());
      })
      ..listen(lockdownControllerProvider, (_, _) => unawaited(stop()))
      ..listen(chatRecorderControllerProvider.select((s) => s.status), (
        _,
        status,
      ) {
        if (status == ChatRecorderStatus.recording) unawaited(stop());
      })
      ..listen(configFlagProvider(enableAiSummaryTtsFlag), (_, next) {
        if (next.value != true && _ttsSourceId != null) unawaited(stop());
      })
      ..listen(queryChatDataProvider(key.home), (_, next) {
        final data = next.value;
        if (_run != null &&
            (next.hasError || data == null || !_visible(data))) {
          unawaited(stop());
        }
      })
      ..listen(audioPlayerControllerProvider.select((s) => s.status), (
        _,
        status,
      ) {
        if (status == AudioPlayerStatus.playing) unawaited(stop());
      })
      ..listen(ttsPlaybackControllerProvider, (_, next) {
        if (_ttsSourceId == null && _player != null && next.isBusy) {
          unawaited(stop());
        }
        if (_ttsSourceId == null || !ref.mounted) return;
        if (next.sourceId == _ttsSourceId) {
          state = QueryAudioState(
            actionId: state.actionId,
            status: next.status == TtsPlaybackStatus.error
                ? QueryAudioStatus.failed
                : next.status == TtsPlaybackStatus.playing
                ? QueryAudioStatus.playing
                : QueryAudioStatus.preparing,
          );
        } else if (!next.isBusy && state.busy) {
          state = const QueryAudioState();
        }
      })
      ..onCancel(_detach)
      ..onDispose(_detach);
    return const QueryAudioState();
  }

  bool _visible(QueryChatData data) {
    final chat = data.projection.chats
        .where((c) => c.id == key.chatId)
        .firstOrNull;
    if (chat == null || chat.scope != key.home.scope) return false;
    final access = _live(data.access);
    final evidence = _activeEvidence;
    if (evidence != null) {
      final source = access.entries[evidence.source.id];
      if (source is! JournalAudio ||
          !access.allowsEntry(source) ||
          !chat.events.any(
            (e) =>
                e.data is QueryChatAnswer &&
                (e.data as QueryChatAnswer).evidence.contains(evidence),
          )) {
        return false;
      }
    }
    final home = access.entries[key.home.scope.id];
    return (key.home.scope.kind == QueryScopeKind.category
            ? access.allowsCategory(key.home.scope.id)
            : home != null && access.allowsEntry(home)) &&
        (!chat.private || access.showPrivate) &&
        chat.events.every((e) => access.allowsEvent(e.data));
  }

  QueryAccessSnapshot _live(QueryAccessSnapshot snapshot) =>
      QueryAccessSnapshot(
        showPrivate: ref.read(configFlagProvider('private')).value == true,
        categories: snapshot.categories,
        entries: snapshot.entries,
        lockdown: ref.read(lockdownControllerProvider),
      );

  Future<({QueryChatHistory chat, QueryAccessSnapshot access})> _authorize(
    QueryCancellation run,
  ) async {
    run.check();
    if (ref.read(chatRecorderControllerProvider).status ==
        ChatRecorderStatus.recording) {
      throw const QueryCancelled();
    }
    final store = ref.read(queryChatStoreProvider);
    final projection = await store.load(key.home.agentId);
    run.check();
    final chat = projection.chats.where((c) => c.id == key.chatId).firstOrNull;
    if (chat == null) throw const QueryCancelled();
    final snapshot = await ref.read(querySourceAccessProvider).load({
      key.home.scope.id,
      for (final event in chat.events)
        ...queryEventDependencies(event.data).map((s) => s.id),
    });
    run.check();
    final data = QueryChatData(projection: projection, access: snapshot);
    if (!_visible(data)) throw const QueryCancelled();
    return (chat: chat, access: _live(snapshot));
  }

  Future<JournalAudio> _audio(
    QueryEvidence evidence,
    QueryCancellation run,
  ) async {
    final current = await _authorize(run);
    final belongs = current.chat.events.any(
      (e) =>
          e.data is QueryChatAnswer &&
          (e.data as QueryChatAnswer).evidence.contains(evidence),
    );
    final entry = current.access.entries[evidence.source.id];
    if (!belongs ||
        entry is! JournalAudio ||
        !current.access.allowsEntry(entry)) {
      throw const QueryCancelled();
    }
    return entry;
  }

  Future<void> playEvidence({
    required String actionId,
    required QueryEvidence evidence,
    bool generate = false,
  }) async {
    final run = await _start(actionId);
    if (run == null) return;
    _activeEvidence = evidence;
    try {
      var audio = await _audio(evidence, run);
      final file = await ref.read(queryAudioFileProvider)(audio);
      run.check();
      if (!file.existsSync()) {
        throw const FileSystemException('Recording unavailable');
      }
      final hash = (await sha256.bind(file.openRead()).first).toString();
      run.check();
      var timing = audio.data.transcriptTimings[evidence.fingerprint];
      if (timing == null ||
          timing.audioSha256 != hash ||
          timing.sourceFingerprint != evidence.fingerprint) {
        if (!generate) throw const _StaleAudioTiming();
        if (QuerySourceDocument.fromEntry(audio)?.fingerprint !=
                evidence.fingerprint ||
            audio.meta.categoryId != evidence.source.categoryId) {
          state = QueryAudioState(
            actionId: actionId,
            status: QueryAudioStatus.unmatched,
          );
          return;
        }
        final profile = await ref.read(queryProfileProvider(key.home).future);
        run.check();
        if (!QueryAudioTimingService.supports(profile)) {
          throw const QueryAudioTimingUnavailable();
        }
        final bytes = await file.readAsBytes();
        run.check();
        timing = await ref
            .read(queryAudioTimingServiceProvider)
            .generate(
              profile: profile!,
              audioBytes: bytes,
              evidence: evidence,
              cancellation: run,
              authorize: () async {
                await _audio(evidence, run);
              },
              agentId: key.home.agentId,
              chatId: key.chatId,
            );
        audio = await _audio(evidence, run);
        if (timing.audioSha256 != hash ||
            QuerySourceDocument.fromEntry(audio)?.fingerprint !=
                evidence.fingerprint) {
          throw const QueryCancelled();
        }
        if (!await ref
            .read(queryAudioTimingWriterProvider)
            .save(
              expected: audio,
              timing: timing,
              isCancelled: () => run.isCancelled,
            )) {
          throw const QueryCancelled();
        }
      }
      final latest = await _audio(evidence, run);
      final latestFile = await ref.read(queryAudioFileProvider)(latest);
      run.check();
      if (latestFile.path != file.path) throw const QueryCancelled();
      final latestHash = (await sha256.bind(latestFile.openRead()).first)
          .toString();
      run.check();
      if (latestHash != timing.audioSha256) throw const QueryCancelled();
      final excerpt = queryAudioExcerpt(
        evidence: evidence,
        timing: timing,
        duration: latest.data.duration,
      );
      if (excerpt == null) {
        state = QueryAudioState(
          actionId: actionId,
          status: QueryAudioStatus.unmatched,
        );
        return;
      }
      await _pauseRecording();
      await _tts!.stop();
      await _audio(evidence, run);
      run.check();
      final player = _player = ref.read(playerFactoryProvider)();
      _completed = player.stream.completed.listen((done) {
        if (done) unawaited(stop());
      });
      await player.open(
        Media(file.path, start: excerpt.start, end: excerpt.end),
        play: false,
      );
      await _audio(evidence, run);
      run.check();
      state = QueryAudioState(
        actionId: actionId,
        status: QueryAudioStatus.playing,
        excerpt: excerpt,
      );
      await player.play();
    } on QueryCancelled {
      if (identical(_run, run)) await stop();
    } on QueryAudioTimingUnavailable {
      _error(run, actionId, QueryAudioStatus.unavailable);
    } on _StaleAudioTiming {
      _error(run, actionId, QueryAudioStatus.stale);
    } on FileSystemException {
      _error(run, actionId, QueryAudioStatus.missingFile);
    } on Object {
      _error(run, actionId, QueryAudioStatus.failed);
    }
  }

  Future<void> speakAnswer({required String answerId}) async {
    final run = await _start(answerId);
    if (run == null) return;
    try {
      if (ref.read(configFlagProvider(enableAiSummaryTtsFlag)).value != true) {
        throw const QueryCancelled();
      }
      final current = await _authorize(run);
      final row = current.chat.events
          .where((e) => e.id == answerId)
          .firstOrNull;
      if (row?.data case final QueryChatAnswer answer) {
        await _pauseRecording();
        await _tts!.stop();
        await _authorize(run);
        run.check();
        _ttsSourceId = 'query:${key.home.agentId}:${key.chatId}:$answerId';
        await _tts!.speak(
          sourceId: _ttsSourceId!,
          text: answer.text,
          canPlay: () async {
            try {
              await _authorize(run);
              return true;
            } on Object {
              return false;
            }
          },
        );
      } else {
        throw const QueryCancelled();
      }
    } on QueryCancelled {
      if (identical(_run, run)) await stop();
    } on Object {
      _error(run, answerId, QueryAudioStatus.failed);
    }
  }

  void _error(QueryCancellation run, String id, QueryAudioStatus status) {
    if (!ref.mounted || run.isCancelled || !identical(_run, run)) return;
    run.cancel();
    unawaited(_release());
    state = QueryAudioState(actionId: id, status: status);
  }

  Future<void> stop() {
    _intent++;
    return _cancelCurrent();
  }

  Future<QueryCancellation?> _start(String actionId) async {
    final intent = ++_intent;
    await _cancelCurrent();
    if (!ref.mounted || intent != _intent) return null;
    final run = _run = QueryCancellation();
    state = QueryAudioState(
      actionId: actionId,
      status: QueryAudioStatus.preparing,
    );
    return run;
  }

  Future<void> _cancelCurrent() {
    _run?.cancel();
    _run = null;
    _activeEvidence = null;
    if (ref.mounted) state = const QueryAudioState();
    return _release();
  }

  /// Riverpod forbids provider state writes inside lifecycle callbacks. Abort
  /// owned work immediately, then stop shared speech and reset surviving state
  /// outside that callback. A resumed/new request supersedes the reset.
  void _detach() {
    final intent = ++_intent;
    _run?.cancel();
    _run = null;
    _activeEvidence = null;
    unawaited(_release(deferSpeech: true));
    scheduleMicrotask(() {
      if (ref.mounted && intent == _intent) state = const QueryAudioState();
    });
  }

  Future<void> _release({bool deferSpeech = false}) async {
    final player = _player;
    _player = null;
    final cancellation = _completed?.cancel();
    _completed = null;
    final ttsSource = _ttsSourceId;
    _ttsSourceId = null;
    final speech = ttsSource == null
        ? null
        : deferSpeech
        ? Future<void>.microtask(() => _tts?.stop(sourceId: ttsSource))
        : _tts?.stop(sourceId: ttsSource);
    final disposal = player?.dispose();
    await Future.wait<void>([
      ?cancellation,
      ?speech,
      ?disposal,
    ]);
  }

  Future<void> _pauseRecording() async {
    if (ref.read(audioPlayerControllerProvider).status ==
        AudioPlayerStatus.playing) {
      await ref.read(audioPlayerControllerProvider.notifier).pause();
    }
  }
}
