import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/state/tts_audio_focus.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockAudioSession session;

  setUpAll(() {
    registerFallbackValue(const AudioSessionConfiguration.music());
  });

  setUp(() {
    session = MockAudioSession();
    when(() => session.configure(any())).thenAnswer((_) async {});
    when(
      () => session.setActive(
        any(),
        avAudioSessionSetActiveOptions: any(
          named: 'avAudioSessionSetActiveOptions',
        ),
      ),
    ).thenAnswer((_) async => true);
  });

  SessionTtsAudioFocus focus() =>
      SessionTtsAudioFocus(session: () async => session);

  void verifyDeactivated(int times) => verify(
    () => session.setActive(
      false,
      avAudioSessionSetActiveOptions:
          AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
    ),
  ).called(times);

  group('the configuration', () {
    test('is spoken audio for playback, which iOS keeps in the background', () {
      final c = ttsAudioSessionConfiguration;
      expect(c.avAudioSessionCategory, AVAudioSessionCategory.playback);
      expect(c.avAudioSessionMode, AVAudioSessionMode.spokenAudio);
    });

    test('ducks other apps instead of stopping them', () {
      final c = ttsAudioSessionConfiguration;
      expect(
        c.avAudioSessionCategoryOptions,
        AVAudioSessionCategoryOptions.duckOthers,
      );
      expect(
        c.androidAudioFocusGainType,
        AndroidAudioFocusGainType.gainTransientMayDuck,
      );
      expect(
        c.androidAudioAttributes?.contentType,
        AndroidAudioContentType.speech,
      );
    });
  });

  group('SessionTtsAudioFocus', () {
    test(
      'acquire configures the session for speech, then activates it',
      () async {
        await focus().acquire();
        final configured =
            verify(() => session.configure(captureAny())).captured.single
                as AudioSessionConfiguration;
        expect(configured.avAudioSessionMode, AVAudioSessionMode.spokenAudio);
        verify(() => session.setActive(true)).called(1);
      },
    );

    // The regression: configured once, the session stayed in whatever the
    // recorder last set it to — play-and-record, in the earpiece.
    test('configures the session afresh on every claim', () async {
      final f = focus();
      await f.acquire();
      await f.release();
      await f.acquire();
      verify(() => session.configure(any())).called(2);
      verify(() => session.setActive(true)).called(2);
    });

    test('release deactivates and lets other apps resume', () async {
      final f = focus();
      await f.acquire();
      await f.release();
      verifyDeactivated(1);
    });

    test('release gives back only what it holds', () async {
      final f = focus();
      await f.release();
      verifyNever(
        () => session.setActive(
          false,
          avAudioSessionSetActiveOptions: any(
            named: 'avAudioSessionSetActiveOptions',
          ),
        ),
      );
      await f.acquire();
      await f.release();
      await f.release();
      verifyDeactivated(1);
    });

    test('a session the platform would not activate is not released', () async {
      when(() => session.setActive(true)).thenAnswer((_) async => false);
      final f = focus();
      await f.acquire();
      await f.release();
      verifyNever(
        () => session.setActive(
          false,
          avAudioSessionSetActiveOptions: any(
            named: 'avAudioSessionSetActiveOptions',
          ),
        ),
      );
    });

    test(
      'a failing session never stops the voice: acquire absorbs it',
      () async {
        when(
          () => session.configure(any()),
        ).thenThrow(StateError('no session'));
        final f = focus();
        await expectLater(f.acquire(), completes);
        await expectLater(f.release(), completes);
        verifyNever(() => session.setActive(true));
      },
    );

    test('a failed claim is logged, with its trace', () async {
      final logger = MockDomainLogger();
      final error = StateError('no session');
      when(() => session.configure(any())).thenThrow(error);
      await SessionTtsAudioFocus(
        session: () async => session,
        logger: logger,
      ).acquire();
      verify(
        () => logger.error(
          LogDomain.speech,
          error,
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'ttsAudioFocus.acquire',
          message: any(named: 'message'),
        ),
      ).called(1);
    });

    test('a failed release is logged, with its trace', () async {
      final logger = MockDomainLogger();
      final error = StateError('gone');
      final f = SessionTtsAudioFocus(
        session: () async => session,
        logger: logger,
      );
      await f.acquire();
      when(
        () => session.setActive(
          false,
          avAudioSessionSetActiveOptions: any(
            named: 'avAudioSessionSetActiveOptions',
          ),
        ),
      ).thenThrow(error);
      await f.release();
      verify(
        () => logger.error(
          LogDomain.speech,
          error,
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'ttsAudioFocus.release',
          message: any(named: 'message'),
        ),
      ).called(1);
    });

    test('a failing release is absorbed too', () async {
      final f = focus();
      await f.acquire();
      when(
        () => session.setActive(
          false,
          avAudioSessionSetActiveOptions: any(
            named: 'avAudioSessionSetActiveOptions',
          ),
        ),
      ).thenThrow(StateError('gone'));
      await expectLater(f.release(), completes);
    });
  });

  test('the real session, where the platform has none, never stops the '
      'voice', () async {
    final real = SessionTtsAudioFocus();
    await expectLater(real.acquire(), completes);
    await expectLater(real.release(), completes);
  });

  group('platformTtsAudioFocus', () {
    tearDown(() {
      platform.isIOS = false;
      platform.isAndroid = false;
    });

    test(
      'claims the audio session on a phone, logging to the given logger',
      () {
        platform.isIOS = true;
        final logger = MockDomainLogger();
        final f = platformTtsAudioFocus(logger: logger);
        expect(f, isA<SessionTtsAudioFocus>());
        expect((f as SessionTtsAudioFocus).logger, same(logger));
        platform.isIOS = false;
        platform.isAndroid = true;
        expect(platformTtsAudioFocus(), isA<SessionTtsAudioFocus>());
      },
    );

    test('claims nothing on a desktop, and its no-op completes', () async {
      final f = platformTtsAudioFocus();
      expect(f, isA<NoTtsAudioFocus>());
      await expectLater(f.acquire(), completes);
      await expectLater(f.release(), completes);
    });
  });
}
