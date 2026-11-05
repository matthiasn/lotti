import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_companion.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_voices_step.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_bundled_clip.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../tts/test_utils.dart';

/// Her ticker never settles, so these tests pump a fixed run of frames.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Finder _control(OnboardingVoiceSample sample) =>
    find.byKey(ValueKey('onboarding-voice-${sample.name}'));

void main() {
  late AppLocalizations m;

  setUp(() async {
    m = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('every sample is a bundled WAV of its own', () {
    final assets = OnboardingVoiceSample.values.map((s) => s.asset).toList();
    expect(assets.toSet(), hasLength(assets.length));
    for (final asset in assets) {
      expect(asset, startsWith('assets/onboarding/voice_samples/'));
      expect(asset, endsWith('.wav'));
    }
  });

  test('the on-device sample is bundled and is 16-bit PCM WAV', () {
    final bytes = File(OnboardingVoiceSample.onDevice.asset).readAsBytesSync();
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    // fmt chunk: PCM (1), 16 bits per sample.
    expect(bytes[20] | bytes[21] << 8, 1);
    expect(bytes[34] | bytes[35] << 8, 16);
  });

  group('OnboardingVoicesView', () {
    late List<(OnboardingVoiceSample, bool)> toggled;
    late List<String> pressed;

    setUp(() {
      toggled = [];
      pressed = [];
    });

    Future<void> pumpView(
      WidgetTester tester, {
      OnboardingVoiceSample? playing,
    }) async {
      setTestSurfaceSize(tester, const Size(480, 1200));
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SingleChildScrollView(
            child: OnboardingVoicesView(
              title: 'Hear me',
              line: 'Tap one.',
              companion: const ColoredBox(
                key: ValueKey('her'),
                color: Color(0xFF000000),
              ),
              playing: playing,
              onToggle: (sample, {required playing}) =>
                  toggled.add((sample, playing)),
              onContinue: () => pressed.add('continue'),
              onBack: () => pressed.add('back'),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('her bust stands beside her bubble under the title', (
      tester,
    ) async {
      await pumpView(tester);

      final her = find.byKey(const ValueKey('her'));
      expect(tester.getSize(her), const Size.square(ControlSizes.avatarHero));
      final bubble = tester.widget<OnboardingSpeechBubble>(
        find.byType(OnboardingSpeechBubble),
      );
      expect(bubble.text, 'Tap one.');
      expect(bubble.tail, OnboardingBubbleTail.left);
      expect(
        tester.getBottomLeft(find.text('Hear me')).dy,
        lessThanOrEqualTo(tester.getTopLeft(her).dy),
      );
    });

    testWidgets('a card per voice, named and costed, in order, then the '
        'English note', (tester) async {
      await pumpView(tester);

      var previousTop = 0.0;
      for (final sample in OnboardingVoiceSample.values) {
        final name = find.text(sample.label(m));
        expect(name, findsOneWidget);
        expect(find.text(sample.description(m)), findsOneWidget);
        final top = tester.getTopLeft(name).dy;
        expect(top, greaterThan(previousTop));
        previousTop = top;
      }
      expect(
        tester.getTopLeft(find.text(m.onboardingVoicesEnglishNote)).dy,
        greaterThan(previousTop),
      );
    });

    testWidgets('nothing playing: every control offers to play its voice', (
      tester,
    ) async {
      await pumpView(tester);

      for (final sample in OnboardingVoiceSample.values) {
        final control = tester.widget<IconButton>(_control(sample));
        expect(control.tooltip, m.onboardingVoicePlay(sample.label(m)));
        expect((control.icon as Icon).icon, LottiIcons.play);
      }
    });

    testWidgets('the playing voice offers to stop, the others to play', (
      tester,
    ) async {
      await pumpView(tester, playing: OnboardingVoiceSample.voxtral);

      final voxtral = tester.widget<IconButton>(
        _control(OnboardingVoiceSample.voxtral),
      );
      expect(
        voxtral.tooltip,
        m.onboardingVoiceStop(m.onboardingVoiceVoxtralName),
      );
      expect((voxtral.icon as Icon).icon, LottiIcons.stop);
      final onDevice = tester.widget<IconButton>(
        _control(OnboardingVoiceSample.onDevice),
      );
      expect((onDevice.icon as Icon).icon, LottiIcons.play);
    });

    testWidgets('a control reports its voice and whether it is playing', (
      tester,
    ) async {
      await pumpView(tester, playing: OnboardingVoiceSample.elevenLabs);

      await tester.tap(_control(OnboardingVoiceSample.onDevice));
      await tester.tap(_control(OnboardingVoiceSample.elevenLabs));

      expect(toggled, [
        (OnboardingVoiceSample.onDevice, false),
        (OnboardingVoiceSample.elevenLabs, true),
      ]);
    });

    testWidgets('the way on and the way back', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text(m.onboardingVoicesContinue));
      await tester.tap(find.byIcon(LottiIcons.back));

      expect(pressed, ['continue', 'back']);
    });
  });

  group('OnboardingVoicesStep', () {
    late FakeTtsAudioPlayer player;
    late List<String> copiedAssets;
    late List<OnboardingVoiceSample> played;

    setUp(() async {
      player = FakeTtsAudioPlayer();
      copiedAssets = [];
      played = [];
    });
    tearDown(() async {
      await player.dispose();
    });

    Future<ProviderContainer> pumpStep(WidgetTester tester) async {
      setTestSurfaceSize(tester, const Size(480, 1200));
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SingleChildScrollView(
            child: OnboardingVoicesStep(
              onContinue: () {},
              onBack: () {},
              onPlayed: played.add,
            ),
          ),
          overrides: [
            ttsPlaybackControllerProvider.overrideWith(
              () => TtsPlaybackController(logger: MockDomainLogger()),
            ),
            ttsAudioPlayerProvider.overrideWithValue(player),
            ttsBundledClipCopierProvider.overrideWithValue((asset) async {
              copiedAssets.add(asset);
              final file = MockIoFile();
              when(
                () => file.path,
              ).thenReturn('/tmp/${copiedAssets.length}.wav');
              when(file.existsSync).thenReturn(false);
              return file;
            }),
            spokenTrackLoaderProvider.overrideWithValue(
              (clip, text) => Completer<MouthTrack>().future,
            ),
          ],
        ),
      );
      await _frames(tester);
      return ProviderScope.containerOf(
        tester.element(find.byType(OnboardingVoicesView)),
      );
    }

    Future<void> tap(WidgetTester tester, OnboardingVoiceSample sample) async {
      await tester.tap(_control(sample));
      await _frames(tester);
    }

    testWidgets('she is there as a bust, saying what the cards are for', (
      tester,
    ) async {
      await pumpStep(tester);

      final her = tester.widget<OnboardingCompanion>(
        find.byType(OnboardingCompanion),
      );
      expect(her.beat, OnboardingCompanionBeat.voices);
      expect(her.framing, CompanionFraming.bust);
      expect(her.line, m.onboardingVoicesLine);
    });

    testWidgets('playing a voice plays its sample under her source, the '
        'words she lip-syncs to its own', (tester) async {
      final container = await pumpStep(tester);

      await tap(tester, OnboardingVoiceSample.voxtral);

      expect(played, [OnboardingVoiceSample.voxtral]);
      expect(copiedAssets, [OnboardingVoiceSample.voxtral.asset]);
      final state = container.read(ttsPlaybackControllerProvider);
      expect(state.status, TtsPlaybackStatus.playing);
      expect(state.sourceId, OnboardingCompanionBeat.voices.sourceId);
      expect(state.clip?.text, onboardingVoiceSampleText);
      expect(
        (tester.widget<IconButton>(_control(OnboardingVoiceSample.voxtral)).icon
                as Icon)
            .icon,
        LottiIcons.stop,
      );
    });

    testWidgets('tapping the playing voice stops it', (tester) async {
      final container = await pumpStep(tester);
      await tap(tester, OnboardingVoiceSample.onDevice);

      await tester.tap(_control(OnboardingVoiceSample.onDevice));
      await _frames(tester);

      expect(
        container.read(ttsPlaybackControllerProvider).status,
        TtsPlaybackStatus.stopped,
      );
      expect(played, [OnboardingVoiceSample.onDevice]);
      expect(
        (tester
                    .widget<IconButton>(
                      _control(OnboardingVoiceSample.onDevice),
                    )
                    .icon
                as Icon)
            .icon,
        LottiIcons.play,
      );
    });

    testWidgets('another voice takes over from the one playing', (
      tester,
    ) async {
      final container = await pumpStep(tester);
      await tap(tester, OnboardingVoiceSample.onDevice);
      copiedAssets.clear();

      await tap(tester, OnboardingVoiceSample.elevenLabs);

      expect(copiedAssets, [OnboardingVoiceSample.elevenLabs.asset]);
      expect(played, [
        OnboardingVoiceSample.onDevice,
        OnboardingVoiceSample.elevenLabs,
      ]);
      expect(player.stopCount, greaterThanOrEqualTo(1));
      expect(
        container.read(ttsPlaybackControllerProvider).status,
        TtsPlaybackStatus.playing,
      );
    });

    testWidgets('when the sample ends the control offers to play again', (
      tester,
    ) async {
      await pumpStep(tester);
      await tap(tester, OnboardingVoiceSample.voxtral);

      player.complete();
      await _frames(tester);

      expect(
        (tester.widget<IconButton>(_control(OnboardingVoiceSample.voxtral)).icon
                as Icon)
            .icon,
        LottiIcons.play,
      );
    });
  });
}
