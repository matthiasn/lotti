import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_companion.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_words.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/ai_config_factories.dart';
import '../../../tts/test_utils.dart';

/// Her ticker never settles, so these tests pump a fixed run of frames.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  late AppLocalizations m;
  late MockProfileResolver resolver;

  final mistral = testInferenceProvider(
    id: 'mistral',
    inferenceProviderType: InferenceProviderType.mistral,
  );
  final withVoice = ResolvedProfile(
    thinkingModelId: 'thinking',
    thinkingProvider: mistral,
    speechModelId: 'voxtral-mini-tts-3-0',
    speechProvider: mistral,
    speechModel: testAiModel(
      id: 'voice-row',
      providerModelId: 'voxtral-mini-tts-3-0',
    ),
  );
  final withoutVoice = ResolvedProfile(
    thinkingModelId: 'thinking',
    thinkingProvider: mistral,
  );

  setUp(() async {
    m = await AppLocalizations.delegate.load(const Locale('en'));
    resolver = MockProfileResolver();
  });

  Future<void> pumpWords(WidgetTester tester, {String? profileId}) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SizedBox(
          width: 390,
          child: OnboardingFirstWords(profileId: profileId),
        ),
        overrides: [
          profileResolverProvider.overrideWithValue(resolver),
          ttsPlaybackControllerProvider.overrideWith(
            () => TtsPlaybackController(logger: MockDomainLogger()),
          ),
          cloudSpeechSynthesizerProvider.overrideWithValue(
            FakeCloudSpeechSynthesizer(),
          ),
          spokenTrackLoaderProvider.overrideWithValue(
            (clip, text) => Completer<MouthTrack>().future,
          ),
        ],
      ),
    );
    await _frames(tester);
  }

  OnboardingCompanion her(WidgetTester tester) =>
      tester.widget<OnboardingCompanion>(find.byType(OnboardingCompanion));

  OnboardingSpeechBubble bubble(WidgetTester tester) =>
      tester.widget<OnboardingSpeechBubble>(
        find.byType(OnboardingSpeechBubble),
      );

  testWidgets('with a read-aloud voice she says her first words in it, in '
      "the app's language", (tester) async {
    when(
      () => resolver.resolveByProfileId('profile-mistral'),
    ).thenAnswer((_) async => withVoice);

    await pumpWords(tester, profileId: 'profile-mistral');

    expect(her(tester).beat, OnboardingCompanionBeat.firstWords);
    expect(her(tester).framing, CompanionFraming.bust);
    expect(her(tester).line, m.onboardingFirstWordsVoiced);
    final voice = her(tester).cloudVoice!;
    expect(voice.provider, mistral);
    expect(voice.model.providerModelId, 'voxtral-mini-tts-3-0');
    expect(voice.languageCode, 'en');
    expect(bubble(tester).text, m.onboardingFirstWordsVoiced);
    expect(bubble(tester).tail, OnboardingBubbleTail.left);
  });

  testWidgets('a profile without a voice leaves her quiet, her bubble saying '
      'she is ready', (tester) async {
    when(
      () => resolver.resolveByProfileId('profile-gemini'),
    ).thenAnswer((_) async => withoutVoice);

    await pumpWords(tester, profileId: 'profile-gemini');

    expect(her(tester).line, isNull);
    expect(her(tester).cloudVoice, isNull);
    expect(bubble(tester).text, m.onboardingFirstWordsQuiet);
  });

  testWidgets('a provider with no seeded profile asks for none', (
    tester,
  ) async {
    await pumpWords(tester);

    verifyNever(() => resolver.resolveByProfileId(any()));
    expect(her(tester).cloudVoice, isNull);
    expect(bubble(tester).text, m.onboardingFirstWordsQuiet);
  });

  testWidgets('a profile that fails to resolve is the quiet case', (
    tester,
  ) async {
    when(
      () => resolver.resolveByProfileId('broken'),
    ).thenAnswer((_) async => throw StateError('no such profile'));

    await pumpWords(tester, profileId: 'broken');

    expect(her(tester).cloudVoice, isNull);
    expect(bubble(tester).text, m.onboardingFirstWordsQuiet);
  });
}
