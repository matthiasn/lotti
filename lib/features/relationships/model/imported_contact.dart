import 'package:lotti/classes/relationship_data.dart';

/// One address-book entry the user picked, reduced to what a relationship
/// actually needs (ADR 0041).
///
/// Deliberately plugin-free: nothing outside
/// `service/contact_import_mapper.dart` imports `flutter_contacts`, so the
/// import UI, the repository and their tests stay buildable — and testable —
/// on desktop and in the pure-Dart test VM, where the plugin's platform
/// channel does not exist.
///
/// Carries only identity and channels. Photos, addresses, organizations,
/// notes and birthdays are read from the OS but discarded here: the person's
/// record is what the *user* authors, and the less of the address book Lotti
/// holds, the less there is to leak (ADR 0037).
typedef ImportedContact = ({
  /// The OS contact identifier, stored in `RelationshipData.contactRefs` so an
  /// explicit "Update from contact" can find this entry again on this device.
  String id,
  String displayName,
  List<ContactChannel> channels,
});

/// Builds the [RelationshipData] a freshly imported contact starts life with.
///
/// [important] and [checkInCadenceDays] come from the import review screen,
/// where the user sets them per row — importing is curation, so nothing is
/// marked important by default and no agent is created behind the user's back
/// (ADR 0041: dormant entities destroy the nudge signal).
///
/// The OS id is recorded under [platformKey] ('ios' / 'android'), matching the
/// per-platform shape of `contactRefs`: the same person's contact has
/// different identifiers on different devices, so a ref is only meaningful on
/// the device that wrote it.
RelationshipData relationshipDataFromContact(
  ImportedContact contact, {
  required String platformKey,
  required RelationshipStatus status,
  bool important = false,
  int? checkInCadenceDays,
}) {
  return RelationshipData(
    title: contact.displayName,
    status: status,
    important: important,
    checkInCadenceDays: checkInCadenceDays,
    contactChannels: contact.channels,
    contactRefs: {platformKey: contact.id},
  );
}

/// Merges freshly read [incoming] channels into the [existing] ones, keeping
/// what the user typed themselves.
///
/// Linking a contact to a person who already has channels must not silently
/// discard manual entry — someone may have typed a number the address book
/// does not hold. So this is a union, not a replacement: existing channels
/// keep their position and their label, and only genuinely new values are
/// appended.
///
/// Sameness is judged on type plus a normalized value (case-folded, with the
/// punctuation people write numbers with removed), so `+1 (555) 010-9999` does
/// not land beside `+15550109999`, and `Anna@Example.com` does not land beside
/// `anna@example.com`.
List<ContactChannel> mergeContactChannels({
  required List<ContactChannel> existing,
  required List<ContactChannel> incoming,
}) {
  final seen = existing.map(contactChannelIdentity).toSet();
  return [
    ...existing,
    for (final channel in incoming)
      if (seen.add(contactChannelIdentity(channel))) channel,
  ];
}

/// The identity two channels are compared on for de-duplication: the type
/// plus the value stripped of formatting and case.
///
/// Punctuation is removed for every type, not just phone numbers: an address
/// book that stores `anna@example.com` and a user who typed `anna@example.com`
/// differ only in case, while two renderings of one phone number differ only
/// in punctuation, and one rule covers both without needing to branch.
String contactChannelIdentity(ContactChannel channel) {
  final normalized = channel.value.toLowerCase().replaceAll(
    RegExp(r'[\s()\-.]'),
    '',
  );
  return '${channel.type.name}:$normalized';
}
