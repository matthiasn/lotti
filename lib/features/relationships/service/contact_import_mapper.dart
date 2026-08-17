import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';

/// Translates `flutter_contacts` models into the app's own
/// [ImportedContact] (ADR 0041).
///
/// This is the single file in the app that knows the plugin's types. Keeping
/// the boundary here means the import UI, the review screen and the
/// repository are all testable without a platform channel, and swapping the
/// plugin later touches one file.

/// Phone labels that mean "this number can receive a text message".
///
/// Everything else — home, work, main, fax, pager — maps to
/// [ContactChannelType.phone], which offers a call but no message, so Lotti
/// never opens a composer addressed to a landline or a fax machine.
const Set<PhoneLabel> _messageableLabels = {
  PhoneLabel.mobile,
  PhoneLabel.iPhone,
  PhoneLabel.appleWatch,
  PhoneLabel.mms,
};

/// Converts [contact] into an [ImportedContact], or null when it carries no
/// usable name.
///
/// A nameless contact is skipped rather than imported as an empty row: the
/// relationship's title is the person, and the app has no other identity to
/// fall back on. Contacts with a name but no channels *are* kept — the user
/// may want to track someone they only ever see in person, and channels can
/// be added by hand afterwards.
ImportedContact? importedContactFrom(Contact contact) {
  final id = contact.id?.trim() ?? '';
  if (id.isEmpty) return null;

  final name = _displayNameOf(contact);
  if (name == null) return null;

  return (id: id, displayName: name, channels: contactChannelsFrom(contact));
}

/// Maps every list the plugin returns, dropping the entries that cannot
/// become a relationship.
List<ImportedContact> importedContactsFrom(Iterable<Contact> contacts) =>
    contacts.map(importedContactFrom).nonNulls.toList();

/// The name to show, preferring the platform's own [Contact.displayName] and
/// falling back to the structured parts when it is absent — which happens on
/// Android for contacts synced without a formatted name.
String? _displayNameOf(Contact contact) {
  final display = contact.displayName?.trim() ?? '';
  if (display.isNotEmpty) return display;

  final name = contact.name;
  if (name == null) return null;

  final composed = [
    name.first?.trim() ?? '',
    name.middle?.trim() ?? '',
    name.last?.trim() ?? '',
  ].where((part) => part.isNotEmpty).join(' ');

  return composed.isEmpty ? null : composed;
}

/// Extracts the phone and email channels, in the order the OS returned them,
/// with duplicates and blanks removed.
///
/// Phones come before emails regardless of the OS ordering, so the call and
/// message actions sit first on the detail page — the actions the post-call
/// loop is built around.
List<ContactChannel> contactChannelsFrom(Contact contact) {
  final channels = <ContactChannel>[
    for (final phone in contact.phones)
      if (phone.number.trim().isNotEmpty)
        ContactChannel(
          type: _messageableLabels.contains(phone.label.label)
              ? ContactChannelType.mobile
              : ContactChannelType.phone,
          value: phone.number.trim(),
          label: _labelTextOf(phone.label),
        ),
    for (final email in contact.emails)
      if (email.address.trim().isNotEmpty)
        ContactChannel(
          type: ContactChannelType.email,
          value: email.address.trim(),
          label: _labelTextOf(email.label),
        ),
  ];

  // An address book routinely holds the same number twice — once from the SIM
  // and once from an account sync — and importing both would show the person
  // two identical call buttons.
  final seen = <String>{};
  return [
    for (final channel in channels)
      if (seen.add(contactChannelIdentity(channel))) channel,
  ];
}

/// The label text stored alongside the value.
///
/// A user-defined label ("Weekend phone") wins over the enum, because it is
/// what the user chose to call it. Otherwise the enum's own name is used;
/// `custom` with no custom text and `other` carry no information worth
/// showing, so they store nothing.
String? _labelTextOf<T extends Enum>(Label<T> label) {
  final custom = label.customLabel?.trim() ?? '';
  if (custom.isNotEmpty) return custom;

  final name = label.label.name;
  if (name == 'custom' || name == 'other') return null;
  return name;
}
