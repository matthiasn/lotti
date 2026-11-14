import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_words.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/ai_config_factories.dart';

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

  /// Builds a host that asks for her first words for [profileId] on every
  /// build, and returns a reader of the latest answer.
  Future<({String line, TtsCloudRoute? voice, bool settled}) Function()>
  pumpWords(
    WidgetTester tester, {
    String? profileId,
    Locale? locale,
  }) async {
    late ({String line, TtsCloudRoute? voice, bool settled}) latest;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Consumer(
          builder: (context, ref, _) {
            latest = onboardingFirstWords(context, ref, profileId: profileId);
            return Text(latest.line);
          },
        ),
        locale: locale,
        overrides: [profileResolverProvider.overrideWithValue(resolver)],
      ),
    );
    // The profile resolves a frame after the first build.
    await tester.pump();
    await tester.pump();
    return () => latest;
  }

  testWidgets('a profile with a read-aloud voice gives the line that says '
      "she can be heard, and that voice in the app's language", (
    tester,
  ) async {
    when(
      () => resolver.resolveByProfileId('profile-mistral'),
    ).thenAnswer((_) async => withVoice);

    final words = await pumpWords(tester, profileId: 'profile-mistral');

    expect(words().line, m.onboardingFirstWordsVoiced);
    final voice = words().voice!;
    expect(voice.provider, mistral);
    expect(voice.model.providerModelId, 'voxtral-mini-tts-3-0');
    expect(voice.languageCode, 'en');
    expect(words().settled, isTrue);
    // The line is rebuilt into the tree once the profile arrives.
    expect(find.text(m.onboardingFirstWordsVoiced), findsOneWidget);
  });

  testWidgets('the voice follows the app language, not English', (
    tester,
  ) async {
    when(
      () => resolver.resolveByProfileId('profile-mistral'),
    ).thenAnswer((_) async => withVoice);

    final words = await pumpWords(
      tester,
      profileId: 'profile-mistral',
      locale: const Locale('de'),
    );

    expect(words().voice?.languageCode, 'de');
    final german = await AppLocalizations.delegate.load(const Locale('de'));
    expect(words().line, german.onboardingFirstWordsVoiced);
    expect(words().line, isNot(m.onboardingFirstWordsVoiced));
  });

  testWidgets('while the profile is still resolving she is ready, without a '
      'voice, and the voiced line replaces it once it lands', (tester) async {
    when(
      () => resolver.resolveByProfileId('profile-mistral'),
    ).thenAnswer((_) async => withVoice);
    late ({String line, TtsCloudRoute? voice, bool settled}) latest;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Consumer(
          builder: (context, ref, _) {
            latest = onboardingFirstWords(
              context,
              ref,
              profileId: 'profile-mistral',
            );
            return Text(latest.line);
          },
        ),
        overrides: [profileResolverProvider.overrideWithValue(resolver)],
      ),
    );

    expect(latest.line, m.onboardingFirstWordsQuiet);
    expect(latest.voice, isNull);
    // Not to be spoken yet: the voice it belongs to is not known.
    expect(latest.settled, isFalse);

    await tester.pump();
    await tester.pump();

    expect(latest.line, m.onboardingFirstWordsVoiced);
    expect(latest.voice, isNotNull);
    expect(latest.settled, isTrue);
  });

  testWidgets('a profile without a voice gives the line that says she is '
      'ready, and no voice', (tester) async {
    when(
      () => resolver.resolveByProfileId('profile-gemini'),
    ).thenAnswer((_) async => withoutVoice);

    final words = await pumpWords(tester, profileId: 'profile-gemini');

    expect(words().line, m.onboardingFirstWordsQuiet);
    expect(words().voice, isNull);
    expect(words().settled, isTrue);
    verify(() => resolver.resolveByProfileId('profile-gemini')).called(1);
  });

  testWidgets('a provider with no seeded profile asks for none', (
    tester,
  ) async {
    final words = await pumpWords(tester);

    verifyNever(() => resolver.resolveByProfileId(any()));
    expect(words().line, m.onboardingFirstWordsQuiet);
    expect(words().voice, isNull);
    // Nothing to wait for.
    expect(words().settled, isTrue);
  });

  testWidgets('a profile that does not resolve is the quiet case', (
    tester,
  ) async {
    when(
      () => resolver.resolveByProfileId('gone'),
    ).thenAnswer((_) async => null);

    final words = await pumpWords(tester, profileId: 'gone');

    expect(words().line, m.onboardingFirstWordsQuiet);
    expect(words().voice, isNull);
    expect(words().settled, isTrue);
  });

  testWidgets('a profile that fails to resolve is the quiet case', (
    tester,
  ) async {
    when(
      () => resolver.resolveByProfileId('broken'),
      // An Exception, the kind Riverpod retries by default (an Error it never
      // does): a database or network hiccup, not a bug.
    ).thenAnswer((_) async => throw Exception('lookup failed'));

    final words = await pumpWords(tester, profileId: 'broken');

    expect(words().line, m.onboardingFirstWordsQuiet);
    expect(words().voice, isNull);
    expect(words().settled, isTrue);

    // The failure is final: no retry is pending that could land a voice
    // after she has begun the quiet line, and have her start over.
    await tester.pump(const Duration(seconds: 30));
    verify(() => resolver.resolveByProfileId('broken')).called(1);
    expect(words().settled, isTrue);
    expect(words().voice, isNull);
  });
}
