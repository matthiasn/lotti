import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The profile seeded for the provider just connected, resolved: its
/// read-aloud slot is the voice of her first words.
///
/// A failed lookup is final, not retried: she speaks once it has settled, and
/// a retry landing a voice after she had begun would have her start over.
final FutureProviderFamily<ResolvedProfile?, String>
onboardingConnectedProfileProvider = FutureProvider.autoDispose
    .family<ResolvedProfile?, String>(
      (ref, profileId) =>
          ref.watch(profileResolverProvider).resolveByProfileId(profileId),
      name: 'onboardingConnectedProfileProvider',
      retry: (_, _) => null,
    );

/// What she says the moment the key works, and the voice she says it in.
///
/// Where the profile seeded for the connected provider ([profileId]) names a
/// read-aloud voice, as Mistral's does, the line says she can now be heard
/// and the voice is that cloud voice, in the app's language. Without one
/// (another provider, no seeded profile, or one that does not resolve, or
/// has not yet) the line says she is ready and the voice is null.
///
/// `settled` is false while the profile is still being resolved. Until then
/// the line is only a caption: spoken that early, it would start in whatever
/// voice is on hand and start over in the cloud voice a moment later.
({String line, TtsCloudRoute? voice, bool settled}) onboardingFirstWords(
  BuildContext context,
  WidgetRef ref, {
  required String? profileId,
}) {
  final resolving = profileId == null
      ? null
      : ref.watch(onboardingConnectedProfileProvider(profileId));
  final voice = TtsCloudRoute.fromProfile(
    resolving?.value,
    languageCode: Localizations.localeOf(context).languageCode,
  );
  final messages = context.messages;
  return (
    line: voice == null
        ? messages.onboardingFirstWordsQuiet
        : messages.onboardingFirstWordsVoiced,
    voice: voice,
    settled: resolving == null || !resolving.isLoading,
  );
}
