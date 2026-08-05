/// The external destinations behind the app's Contact Us footer.
///
/// Kept apart from the widgets that render them so the addresses have one
/// definition and can be asserted on without pumping a widget tree. The
/// Manual is deliberately absent: its URL is locale-aware and already owned
/// by `manualUriFor` in `manual_language_controller.dart`.
library;

/// Where "Contact Us" writes to.
const lottiContactEmail = 'lotti@matthiasn.com';

/// The project's source repository — the destination behind the GitHub mark.
///
/// The repository root rather than `/issues`: the footer is a way in to the
/// project, and a reader who wants the tracker is one click from it, whereas
/// someone who wanted the README would have to climb back out.
const lottiGithubUrl = 'https://github.com/matthiasn/lotti';

/// The community invite, matching the `contact` URL the Flatpak metainfo
/// advertises.
const lottiDiscordInviteUrl = 'https://discord.gg/uuSaa8NpY';

/// Builds the `mailto:` URI behind the Contact Us affordance.
///
/// [subject] arrives already localized and is percent-encoded, not form-encoded
/// — a `+` in a `mailto` query is a literal plus to most mail clients, so
/// `Uri(queryParameters:)` would put a row of them where the spaces were. An
/// empty [subject] yields a bare address instead of a dangling `?subject=`.
Uri contactEmailUri({required String subject}) {
  if (subject.isEmpty) return Uri.parse('mailto:$lottiContactEmail');
  return Uri.parse(
    'mailto:$lottiContactEmail?subject=${Uri.encodeComponent(subject)}',
  );
}
