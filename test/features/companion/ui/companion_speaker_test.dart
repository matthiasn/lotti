import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../companion_overrides.dart';

const _clip = '/tmp/clip.wav';

/// The app-wide playback state, set by the test instead of a real voice.
class _Playback extends TtsPlaybackController {
  _Playback([this.initial = const TtsPlaybackState()]);

  /// The state the voice is in before she appears.
  final TtsPlaybackState initial;

  @override
  TtsPlaybackState build() => initial;

  TtsPlaybackState get current => state;
  set current(TtsPlaybackState next) => state = next;
}

class _Settings extends TtsSettingsController {
  _Settings(this.settings);

  final TtsSettings settings;

  @override
  TtsSettings build() => settings;
}

/// Records each load and answers it when the test says so.
class _Loader {
  final calls = <({String clip, String text})>[];
  final pending = <Completer<MouthTrack>>[];

  Future<MouthTrack> call(String clip, String text) {
    calls.add((clip: clip, text: text));
    final load = Completer<MouthTrack>();
    pending.add(load);
    return load.future;
  }
}

TtsPlaybackState _playing(
  String sourceId, {
  String text = 'Four things today.',
  Duration position = Duration.zero,
}) => TtsPlaybackState(
  status: TtsPlaybackStatus.playing,
  sourceId: sourceId,
  clip: (path: _clip, text: text),
  position: position,
);

void main() {
  late _Playback playback;
  late _Loader loader;
  late MockDomainLogger logger;

  Future<void> pumpSpeaker(
    WidgetTester tester, {
    String sourceId = 'task-1',
    double speed = 1,
    TtsPlaybackState startWith = const TtsPlaybackState(),
    TtsPlaybackState? initial,
    CompanionController? controller,
    GestureName? holding,
    bool stage = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SizedBox(
          width: 96,
          height: 96,
          child: CompanionSpeaker(
            sourceId: sourceId,
            mood: CompanionMood.bright,
            controller: controller,
            holding: holding,
            stage: stage,
          ),
        ),
        overrides: [
          ttsPlaybackControllerProvider.overrideWith(
            () => playback = _Playback(startWith),
          ),
          ttsSettingsControllerProvider.overrideWith(
            () => _Settings(TtsSettings(speed: speed)),
          ),
          spokenTrackLoaderProvider.overrideWithValue(loader.call),
          ...companionLookOverrides(outfit: CompanionLook.grandmaWinter),
          domainLoggerProvider.overrideWithValue(logger),
        ],
      ),
    );
    if (initial != null) {
      playback.current = initial;
      await tester.pump();
    }
  }

  CompanionView view(WidgetTester tester) =>
      tester.widget<CompanionView>(find.byType(CompanionView));

  /// Answers the latest load with a track of its words.
  Future<MouthTrack> answerLoad(WidgetTester tester) async {
    final track = TextLipSync(loader.calls.last.text);
    loader.pending.last.complete(track);
    await tester.pump();
    return track;
  }

  setUp(() {
    loader = _Loader();
    logger = MockDomainLogger();
  });

  testWidgets('shows her in the look, mood and full framing', (tester) async {
    await pumpSpeaker(tester);

    final shown = view(tester);
    expect(shown.look.id, CompanionLook.grandmaWinter.id);
    expect(shown.mood, CompanionMood.bright);
    expect(shown.framing, CompanionFraming.full);
    expect(shown.stage, isFalse);
  });

  testWidgets('wears the session outfit, and changes when it does', (
    tester,
  ) async {
    await pumpSpeaker(tester);
    ProviderScope.containerOf(
      tester.element(find.byType(CompanionSpeaker)),
    ).read(companionOutfitProvider.notifier).next();
    await tester.pump();

    final winter = companionOutfits.indexOf(CompanionLook.grandmaWinter);
    expect(
      view(tester).look.id,
      companionOutfits[(winter + 1) % companionOutfits.length].id,
    );
  });

  testWidgets('wears her customization: a new hairstyle shows at once', (
    tester,
  ) async {
    await pumpSpeaker(tester);
    expect(view(tester).look.hairStyle, CompanionHairStyle.bun);

    ProviderScope.containerOf(
          tester.element(find.byType(CompanionSpeaker)),
        )
        .read(companionCustomizationProvider.notifier)
        .set(
          const CompanionCustomization(
            hairStyle: CompanionHairStyle.locs,
            skinTone: CompanionSkinTone.tone5,
          ),
        );
    await tester.pump();

    expect(view(tester).look.hairStyle, CompanionHairStyle.locs);
    expect(view(tester).look.palette.skin, CompanionSkinTone.tone5.skin);
    // Still the winter outfit, in her new skin and hair.
    expect(
      view(tester).look.palette.dress,
      CompanionLook.grandmaWinter.palette.dress,
    );
  });

  testWidgets('stands her on the stage when the host asks', (tester) async {
    await pumpSpeaker(tester, stage: true);

    expect(view(tester).stage, isTrue);
  });

  testWidgets('hands her view the controller and the held gesture', (
    tester,
  ) async {
    final controller = CompanionController();
    await pumpSpeaker(
      tester,
      controller: controller,
      holding: GestureName.think,
    );

    expect(view(tester).controller, same(controller));
    expect(view(tester).holding, GestureName.think);
    expect(controller.isAttached, isTrue);
  });

  testWidgets('is silent while nothing plays', (tester) async {
    await pumpSpeaker(tester);

    expect(view(tester).track, isNull);
    expect(view(tester).playhead!(), isNull);
    expect(loader.calls, isEmpty);
  });

  testWidgets('stays silent while another source plays', (tester) async {
    await pumpSpeaker(tester, initial: _playing('task-2'));

    expect(loader.calls, isEmpty);
    expect(view(tester).track, isNull);
    expect(view(tester).playhead!(), isNull);
  });

  testWidgets('stays silent while her source is only being prepared', (
    tester,
  ) async {
    await pumpSpeaker(
      tester,
      initial: const TtsPlaybackState(
        status: TtsPlaybackStatus.synthesizing,
        sourceId: 'task-1',
      ),
    );

    expect(loader.calls, isEmpty);
  });

  testWidgets('loads the clip with its words when her source plays', (
    tester,
  ) async {
    await pumpSpeaker(tester);
    playback.current = _playing('task-1', text: 'Good morning');
    await tester.pump();

    expect(loader.calls, [(clip: _clip, text: 'Good morning')]);
    final track = await answerLoad(tester);
    expect(view(tester).track, same(track));
  });

  testWidgets("reads the tone of the clip's own words, timed by its mouth", (
    tester,
  ) async {
    const words = 'Four things today. The review is overdue.';
    await pumpSpeaker(tester);
    playback.current = _playing('task-1', text: words);
    await tester.pump();
    expect(view(tester).tone, isNull);

    final track = await answerLoad(tester);
    final tone = view(tester).tone!;
    expect(tone.cues, hasLength(2));
    expect(tone.cues.last.start, track.timeOf(words.indexOf(' The review')));
    expect(tone.cues.last.approval, lessThan(0));
  });

  testWidgets('speaks a clip that was already playing when she appeared', (
    tester,
  ) async {
    await pumpSpeaker(tester, startWith: _playing('task-1'));

    expect(loader.calls, hasLength(1));
    final track = await answerLoad(tester);
    expect(view(tester).track, same(track));
  });

  testWidgets('her playhead follows the player, carried between reports', (
    tester,
  ) async {
    await pumpSpeaker(
      tester,
      initial: _playing('task-1', position: const Duration(seconds: 2)),
    );
    await answerLoad(tester);
    final playhead = view(tester).playhead!;

    expect(playhead(), const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(playhead(), const Duration(milliseconds: 2100));
  });

  testWidgets('her playhead runs at the playback speed', (tester) async {
    await pumpSpeaker(
      tester,
      speed: 1.5,
      initial: _playing('task-1', position: const Duration(seconds: 2)),
    );
    await answerLoad(tester);
    final playhead = view(tester).playhead!;

    expect(playhead(), const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(playhead(), const Duration(milliseconds: 2150));
  });

  testWidgets('a new utterance starts her mouth at its own start', (
    tester,
  ) async {
    await pumpSpeaker(tester, initial: _playing('task-1'));
    await answerLoad(tester);
    expect(view(tester).playhead!(), Duration.zero);

    // The first clip ends without a later report, so both open at zero.
    await tester.pump(const Duration(seconds: 1));
    playback.current = const TtsPlaybackState(
      status: TtsPlaybackStatus.stopped,
    );
    await tester.pump();
    playback.current = _playing('task-1', text: 'Again');
    await tester.pump();
    await answerLoad(tester);

    expect(view(tester).playhead!(), Duration.zero);
  });

  testWidgets('falls silent when her utterance ends', (tester) async {
    await pumpSpeaker(tester, initial: _playing('task-1'));
    await answerLoad(tester);

    playback.current = const TtsPlaybackState(
      status: TtsPlaybackStatus.stopped,
    );
    await tester.pump();

    expect(view(tester).track, isNull);
    expect(view(tester).tone, isNull);
    expect(view(tester).playhead!(), isNull);
  });

  testWidgets('a load that lands after its utterance ended is dropped', (
    tester,
  ) async {
    await pumpSpeaker(tester, initial: _playing('task-1'));
    playback.current = const TtsPlaybackState(
      status: TtsPlaybackStatus.stopped,
    );
    await tester.pump();

    await answerLoad(tester);

    expect(view(tester).track, isNull);
  });

  testWidgets('a load that lands after she is gone changes nothing', (
    tester,
  ) async {
    await pumpSpeaker(tester, initial: _playing('task-1'));
    await tester.pumpWidget(const SizedBox());

    loader.pending.single.complete(TextLipSync('late'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CompanionSpeaker), findsNothing);
  });

  testWidgets('follows a new source when the host gives her one', (
    tester,
  ) async {
    await pumpSpeaker(tester);
    playback.current = _playing('task-2', text: 'Second task');
    await tester.pump();
    expect(loader.calls, isEmpty);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const SizedBox(
          width: 96,
          height: 96,
          child: CompanionSpeaker(sourceId: 'task-2'),
        ),
        overrides: [
          ttsPlaybackControllerProvider.overrideWith(() => playback),
          ttsSettingsControllerProvider.overrideWith(
            () => _Settings(const TtsSettings()),
          ),
          spokenTrackLoaderProvider.overrideWithValue(loader.call),
          ...companionLookOverrides(outfit: CompanionLook.grandmaWinter),
          domainLoggerProvider.overrideWithValue(logger),
        ],
      ),
    );

    expect(loader.calls, [(clip: _clip, text: 'Second task')]);
    final track = await answerLoad(tester);
    expect(view(tester).track, same(track));
  });

  testWidgets('a load that fails is logged, and leaves her silent', (
    tester,
  ) async {
    await pumpSpeaker(tester, initial: _playing('task-1'));

    final failure = StateError('envelope failed');
    loader.pending.single.completeError(failure);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(view(tester).track, isNull);
    verify(
      () => logger.error(
        LogDomain.speech,
        failure,
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'companionSpeaker',
        message: any(named: 'message'),
      ),
    ).called(1);
  });
}
