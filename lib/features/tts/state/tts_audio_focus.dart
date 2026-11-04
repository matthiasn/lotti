import 'package:audio_session/audio_session.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart';

/// Holds the phone's audio focus while the voice speaks.
///
/// Without it a phone keeps the app in its default audio session, which
/// falls silent the moment the app leaves the screen: a summary read aloud
/// stopped when its listener switched to another app. Held, the session is
/// spoken audio for playback, so the voice keeps speaking in the background
/// (`UIBackgroundModes` already lists `audio`) and other apps' sound ducks
/// under it; let go, other apps are told they may resume.
abstract interface class TtsAudioFocus {
  /// Takes the focus before the voice starts.
  Future<void> acquire();

  /// Gives it back once the voice has stopped or finished.
  Future<void> release();
}

/// The focus on a desktop, which has no audio session to claim: nothing.
class NoTtsAudioFocus implements TtsAudioFocus {
  const NoTtsAudioFocus();

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}

/// How the voice's session is configured: spoken audio for playback, other
/// apps ducked rather than stopped, and on Android a transient focus — a
/// read-out is short, and what it ducked comes back after it.
final AudioSessionConfiguration ttsAudioSessionConfiguration =
    const AudioSessionConfiguration.speech().copyWith(
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
    );

/// The phone's audio session, through `audio_session`.
///
/// The session is configured afresh on every [acquire], not once: it is
/// shared, and the recorder sets it to play-and-record for each dictation,
/// which would otherwise leave the voice in the earpiece and out of the
/// background.
///
/// Best effort: a session that cannot be configured or activated leaves the
/// voice to play as it did before — in the foreground — and never stops it
/// from speaking. Its failures are logged, not thrown.
class SessionTtsAudioFocus implements TtsAudioFocus {
  SessionTtsAudioFocus({
    Future<AudioSession> Function()? session,
    this.logger,
  }) : _session = session ?? (() => AudioSession.instance);

  final Future<AudioSession> Function() _session;

  /// Where a session that failed is reported.
  final DomainLogger? logger;
  bool _held = false;

  @override
  Future<void> acquire() async {
    try {
      final session = await _session();
      await session.configure(ttsAudioSessionConfiguration);
      _held = await session.setActive(true);
    } on Object catch (error, stackTrace) {
      logger?.error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: 'ttsAudioFocus.acquire',
        message: 'The voice could not claim the audio session',
      );
    }
  }

  @override
  Future<void> release() async {
    if (!_held) return;
    _held = false;
    try {
      final session = await _session();
      await session.setActive(
        false,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
    } on Object catch (error, stackTrace) {
      logger?.error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: 'ttsAudioFocus.release',
        message: 'The voice could not give the audio session back',
      );
    }
  }
}

/// The focus for this platform: the audio session on a phone, its failures
/// logged to [logger], and nothing on a desktop.
TtsAudioFocus platformTtsAudioFocus({DomainLogger? logger}) =>
    isIOS || isAndroid
    ? SessionTtsAudioFocus(logger: logger)
    : const NoTtsAudioFocus();
