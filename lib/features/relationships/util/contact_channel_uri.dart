import 'package:lotti/classes/relationship_data.dart';

/// A quick action the user can fire against one of a relationship's contact
/// channels (plan v2 phase 7 item 4).
///
/// Each action maps to exactly one URI scheme, and every scheme produced here
/// is declared to both platforms — iOS `LSApplicationQueriesSchemes` and the
/// Android `<queries>` block. `contact_channel_uri_test.dart` pins that
/// correspondence against the real manifests, so adding an action without the
/// matching declaration fails the suite rather than shipping a dead button.
enum ContactAction {
  /// `tel:` — hand the number to the dialer.
  call,

  /// `sms:` — open a message composer addressed to the number.
  message,

  /// `mailto:` — open a mail composer addressed to the address.
  email,
}

/// The URI scheme [action] launches. Kept as a single source of truth so the
/// manifest cross-check reads the same values [contactChannelUri] emits.
String schemeForContactAction(ContactAction action) => switch (action) {
  ContactAction.call => 'tel',
  ContactAction.message => 'sms',
  ContactAction.email => 'mailto',
};

/// The actions a channel of [type] can drive, in the order they should be
/// offered.
///
/// The distinctions are deliberate rather than permissive:
///
/// - [ContactChannelType.phone] is a landline in this vocabulary, so it dials
///   but does not offer a message the recipient may never receive.
/// - [ContactChannelType.mobile] offers both.
/// - [ContactChannelType.messaging] offers nothing. A handle like `@anna` or a
///   Signal username has no universal scheme to launch, and guessing one app's
///   deep link would silently open the wrong messenger. The channel stays
///   visible and copyable; it simply has no button.
Set<ContactAction> contactActionsFor(ContactChannelType type) => switch (type) {
  ContactChannelType.phone => const {ContactAction.call},
  ContactChannelType.mobile => const {
    ContactAction.call,
    ContactAction.message,
  },
  ContactChannelType.email => const {ContactAction.email},
  ContactChannelType.messaging => const <ContactAction>{},
};

/// Characters that carry meaning in a dialable number: digits, and the `+`
/// that marks an E.164 country prefix.
final _dialableCharacters = RegExp('[^0-9+]');

/// A minimally plausible email address — a non-empty local part, one `@`, and
/// a domain containing a dot. Deliberately not RFC 5322: the job here is to
/// refuse a value that would open an empty composer, not to adjudicate
/// address syntax the user's mail client will validate anyway.
final _plausibleEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// The URI that fires [action] against [channel], or `null` when the pair
/// cannot produce a working launch.
///
/// Returns `null` — rather than throwing or emitting a broken URI — when:
///
/// - [action] is not among [contactActionsFor] the channel's type (emailing a
///   phone number, messaging a landline),
/// - the channel's value is empty or whitespace only,
/// - a phone number holds no digits at all (`"n/a"`, `"ask Bob"`), or
/// - an email address is not plausibly addressable.
///
/// Callers treat `null` as "no button for this pair"; nothing about a
/// half-filled contact channel should surface an action that dead-ends.
Uri? contactChannelUri(ContactChannel channel, ContactAction action) {
  if (!contactActionsFor(channel.type).contains(action)) return null;

  final value = channel.value.trim();
  if (value.isEmpty) return null;

  return switch (action) {
    ContactAction.call || ContactAction.message => _telephonyUri(
      value,
      schemeForContactAction(action),
    ),
    ContactAction.email => _mailtoUri(value),
  };
}

/// Builds a `tel:`/`sms:` URI from a human-formatted number.
///
/// Spaces, parentheses, dashes and dots are how people write numbers and are
/// not part of the dialable string, so they are stripped. A leading `+` is
/// preserved because it is what makes the number reachable from abroad; a `+`
/// anywhere else is a typo and is dropped rather than passed to the dialer.
Uri? _telephonyUri(String value, String scheme) {
  final hasCountryPrefix = value.startsWith('+');
  final digits = value.replaceAll(_dialableCharacters, '').replaceAll('+', '');
  if (digits.isEmpty) return null;
  return Uri(scheme: scheme, path: hasCountryPrefix ? '+$digits' : digits);
}

/// Builds a `mailto:` URI, refusing values a mail client could not address.
///
/// Uses [Uri.parse] on an encoded address rather than `Uri(scheme:, path:)`
/// because the latter escapes `@` into `%40`, which several desktop mail
/// clients hand to the user verbatim as a malformed recipient.
Uri? _mailtoUri(String value) {
  if (!_plausibleEmail.hasMatch(value)) return null;
  return Uri.parse('mailto:${Uri.encodeFull(value)}');
}
