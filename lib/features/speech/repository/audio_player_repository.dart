import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:media_kit/media_kit.dart';

class AudioPlayerRepository {
  AudioPlayerRepository() : _audioPlayer = Player();

  final Player _audioPlayer;
  final LoggingService _loggingService = getIt<LoggingService>();

  Stream<Duration> get positionStream => _audioPlayer.stream.position;

  AudioPlayerStatus? get currentStatus {
    if (_audioPlayer.state.playing) {
      return AudioPlayerStatus.playing;
    } else if (_audioPlayer.state.completed) {
      return AudioPlayerStatus.stopped;
    } else {
      return AudioPlayerStatus.paused;
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'audio_player_repository',
        subDomain: 'pause',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> play() async {
    try {
      await _audioPlayer.play();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'audio_player_repository',
        subDomain: 'play',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'audio_player_repository',
        subDomain: 'stop',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> setAudioNote(JournalAudio audioNote) async {
    try {
      final localPath = await AudioUtils.getFullAudioPath(audioNote);
      await _audioPlayer.open(Media(localPath), play: false);
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'audio_player_repository',
        subDomain: 'setAudioNote',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'audio_player_repository',
        subDomain: 'dispose',
        stackTrace: stackTrace,
      );
    }
  }
}
