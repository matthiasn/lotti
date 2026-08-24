import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';

/// What came of linking (or re-reading) an OS contact.
enum ContactLinkOutcome {
  /// Channels were copied and the person was saved.
  linked,

  /// The contact was read, but held nothing the person did not already have.
  /// Distinguished from [linked] so the UI can say "nothing new" rather than
  /// claiming an update that changed nothing.
  noChanges,

  /// The user backed out of the picker.
  cancelled,

  /// The stored ref points at a contact this device no longer has — deleted,
  /// or the person is on a different device from the one that linked them.
  contactMissing,

  /// The write was rejected.
  saveFailed,

  /// No address book on this platform.
  unsupported,
}

/// Links a relationship to an OS contact and copies its channels across
/// (plan v2 phase 7 item 2, ADR 0041).
///
/// Copying is one-way and explicit, always: Lotti reads the address book
/// when the user asks and never writes back to it, and there is no
/// background re-sync — a contact that changes on the device does not change
/// the person here until the user asks for it again.
class ContactLinkController {
  ContactLinkController(this._ref);

  final Ref _ref;

  /// Opens the picker and copies the chosen contact's channels onto
  /// [relationship], recording its OS id for later refreshes.
  Future<ContactLinkOutcome> linkContact(RelationshipEntry relationship) async {
    final service = _ref.read(contactsServiceProvider);
    if (!service.isSupported) return ContactLinkOutcome.unsupported;

    final picked = await service.pickSingle();
    if (picked == null) return ContactLinkOutcome.cancelled;

    return _applyContact(relationship, picked);
  }

  /// Re-reads the contact this person is already linked to and copies over
  /// anything new. Returns [ContactLinkOutcome.contactMissing] when the ref
  /// resolves to nothing, which is the normal case on a second device: refs
  /// are per-device, so a person linked on one phone carries a ref that
  /// means nothing anywhere else — including on a second phone running the
  /// same OS.
  Future<ContactLinkOutcome> refreshFromContact(
    RelationshipEntry relationship,
  ) async {
    final service = _ref.read(contactsServiceProvider);
    if (!service.isSupported) return ContactLinkOutcome.unsupported;

    final refKey = await _ref.read(contactRefKeyProvider.future);
    final ref = refKey == null ? null : relationship.data.contactRefs[refKey];
    if (ref == null || ref.isEmpty) return ContactLinkOutcome.contactMissing;

    final contact = await service.readById(ref);
    if (contact == null) return ContactLinkOutcome.contactMissing;

    return _applyContact(relationship, contact);
  }

  /// Merges [contact]'s channels into [relationship] and saves.
  ///
  /// The person's own title is deliberately left alone: they may have been
  /// renamed here on purpose ("Mum" rather than "Margaret Schmidt"), and a
  /// contact refresh silently overwriting that would be a bad surprise.
  /// Only channels and the ref are copied — and the ref only into this
  /// device's slot, leaving every other device's entry untouched.
  Future<ContactLinkOutcome> _applyContact(
    RelationshipEntry relationship,
    ImportedContact contact,
  ) async {
    final merged = mergeContactChannels(
      existing: relationship.data.contactChannels,
      incoming: contact.channels,
    );

    final refs = Map<String, String>.from(relationship.data.contactRefs);
    final refKey = await _ref.read(contactRefKeyProvider.future);
    final refUnchanged = refKey == null || refs[refKey] == contact.id;
    if (refKey != null) refs[refKey] = contact.id;

    final channelsUnchanged =
        merged.length == relationship.data.contactChannels.length;
    if (channelsUnchanged && refUnchanged) return ContactLinkOutcome.noChanges;

    final saved = await _ref
        .read(relationshipRepositoryProvider)
        .updateRelationship(
          relationship.copyWith(
            data: relationship.data.copyWith(
              contactChannels: merged,
              contactRefs: refs,
            ),
          ),
        );

    return saved ? ContactLinkOutcome.linked : ContactLinkOutcome.saveFailed;
  }
}

final contactLinkControllerProvider = Provider<ContactLinkController>(
  ContactLinkController.new,
  name: 'contactLinkControllerProvider',
);
