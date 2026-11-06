import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_companion.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The profile seeded for the provider just connected, resolved: its
/// read-aloud slot is the voice of her first words.
final FutureProviderFamily<ResolvedProfile?, String>
onboardingConnectedProfileProvider = FutureProvider.autoDispose
    .family<ResolvedProfile?, String>(
      (ref, profileId) =>
          ref.watch(profileResolverProvider).resolveByProfileId(profileId),
      name: 'onboardingConnectedProfileProvider',
    );

/// The moment the key works: she celebrates beside her bubble, and — where
/// the connected provider's seeded profile names a read-aloud voice, as
/// Mistral's does — says her first words aloud in it, in the app's language.
///
/// Without such a voice (another provider, no seeded profile, or one that
/// does not resolve) her bubble says she is ready instead, and she is silent.
class OnboardingFirstWords extends ConsumerWidget {
  const OnboardingFirstWords({required this.profileId, super.key});

  /// The connected provider's seeded profile; null when it has none.
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = profileId;
    final profile = id == null
        ? null
        : ref.watch(onboardingConnectedProfileProvider(id)).value;
    final voice = TtsCloudRoute.fromProfile(
      profile,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    final messages = context.messages;
    final line = voice == null
        ? messages.onboardingFirstWordsQuiet
        : messages.onboardingFirstWordsVoiced;
    return Row(
      children: [
        ExcludeSemantics(
          child: SizedBox.square(
            dimension: ControlSizes.avatarHero,
            child: OnboardingCompanion(
              beat: OnboardingCompanionBeat.firstWords,
              line: voice == null ? null : line,
              framing: CompanionFraming.bust,
              cloudVoice: voice,
            ),
          ),
        ),
        SizedBox(width: context.designTokens.spacing.step2),
        Expanded(
          child: OnboardingSpeechBubble(
            text: line,
            tail: OnboardingBubbleTail.left,
          ),
        ),
      ],
    );
  }
}
