import 'dart:io' show Platform;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';

/// Where the import flow currently stands.
enum ContactImportStatus {
  /// Nothing asked for yet — the screen has just opened.
  idle,

  /// Asking the OS for access, or reading the address book.
  loading,

  /// Contacts are readable and listed.
  ready,

  /// Access refused, but askable again.
  denied,

  /// Refused permanently or blocked by policy; only system settings helps.
  permanentlyDenied,

  /// No address book on this platform — desktop enters channels by hand.
  unsupported,

  /// Access granted, but there was nothing importable to show.
  empty,
}

/// One selected contact plus the two decisions the review step asks for.
typedef ContactImportDraft = ({
  ImportedContact contact,
  bool important,
  int? cadenceDays,
});

/// The import screen's whole state.
typedef ContactImportState = ({
  ContactImportStatus status,
  List<ImportedContact> contacts,

  /// Selected contacts by OS id, in selection order — insertion-ordered so
  /// the review step lists them the way the user picked them.
  Map<String, ContactImportDraft> drafts,
  String query,
});

const ContactImportState _emptyState = (
  status: ContactImportStatus.idle,
  contacts: <ImportedContact>[],
  drafts: <String, ContactImportDraft>{},
  query: '',
);

/// Drives the multi-select contact import (plan v2 phase 7 item 3, ADR 0041
/// D5).
///
/// The address book is read once, on an explicit user action, and held only
/// for the life of this screen — nothing is persisted until [importSelected]
/// runs, and only the chosen contacts become entities. That is the whole
/// point of the curation model: dormant entities the user never picked would
/// destroy the nudge signal.
class ContactImportController extends Notifier<ContactImportState> {
  @override
  ContactImportState build() => _emptyState;

  /// Asks for access and loads the address book. Safe to call again — a
  /// user who granted access from settings after a refusal can retry without
  /// leaving the screen.
  Future<void> load() async {
    final service = ref.read(contactsServiceProvider);

    if (!service.isSupported) {
      state = (
        status: ContactImportStatus.unsupported,
        contacts: const [],
        drafts: const {},
        query: '',
      );
      return;
    }

    state = (
      status: ContactImportStatus.loading,
      contacts: const [],
      // Selections are dropped on reload: they refer to a list that is about
      // to be replaced, and a draft whose contact is no longer readable
      // would import a person from stale data.
      drafts: const {},
      query: state.query,
    );

    final access = await service.requestReadAccess();
    final refused = switch (access) {
      ContactsAccess.denied => ContactImportStatus.denied,
      ContactsAccess.permanentlyDenied => ContactImportStatus.permanentlyDenied,
      ContactsAccess.unsupported => ContactImportStatus.unsupported,
      ContactsAccess.granted || ContactsAccess.limited => null,
    };

    if (refused != null) {
      state = (
        status: refused,
        contacts: const [],
        drafts: const {},
        query: state.query,
      );
      return;
    }

    final contacts = await service.readAll();
    state = (
      status: contacts.isEmpty
          ? ContactImportStatus.empty
          : ContactImportStatus.ready,
      contacts: contacts,
      drafts: const {},
      query: state.query,
    );
  }

  /// The contacts matching the current query, matched on name and on channel
  /// values so a number can be searched for as readily as a name.
  List<ImportedContact> get visibleContacts {
    final query = state.query.trim().toLowerCase();
    if (query.isEmpty) return state.contacts;

    return state.contacts
        .where(
          (contact) =>
              contact.displayName.toLowerCase().contains(query) ||
              contact.channels.any(
                (channel) => channel.value.toLowerCase().contains(query),
              ),
        )
        .toList();
  }

  void setQuery(String query) {
    state = (
      status: state.status,
      contacts: state.contacts,
      drafts: state.drafts,
      query: query,
    );
  }

  /// Selects or deselects [contact]. A newly selected contact starts
  /// unimportant with no cadence — importing is not consent to be nudged
  /// (ADR 0041), and the review step is where that is chosen.
  void toggleSelection(ImportedContact contact) {
    final drafts = Map<String, ContactImportDraft>.from(state.drafts);
    if (drafts.remove(contact.id) == null) {
      drafts[contact.id] = (
        contact: contact,
        important: false,
        cadenceDays: null,
      );
    }
    _withDrafts(drafts);
  }

  bool isSelected(String contactId) => state.drafts.containsKey(contactId);

  /// Marks a selected contact important, which is what creates their agent
  /// once they exist. Clearing it also clears the cadence, since a cadence
  /// on an unimportant person is never evaluated and would only be
  /// misleading if it reappeared later.
  void setImportant({required String contactId, required bool important}) {
    final draft = state.drafts[contactId];
    if (draft == null) return;

    final drafts = Map<String, ContactImportDraft>.from(state.drafts);
    drafts[contactId] = (
      contact: draft.contact,
      important: important,
      cadenceDays: important ? draft.cadenceDays : null,
    );
    _withDrafts(drafts);
  }

  /// Sets the desired check-in interval for a selected contact. Ignored for
  /// a contact who is not marked important, for the same reason as above.
  void setCadence({required String contactId, required int? cadenceDays}) {
    final draft = state.drafts[contactId];
    if (draft == null || !draft.important) return;

    final drafts = Map<String, ContactImportDraft>.from(state.drafts);
    drafts[contactId] = (
      contact: draft.contact,
      important: draft.important,
      cadenceDays: cadenceDays,
    );
    _withDrafts(drafts);
  }

  void clearSelection() => _withDrafts(const {});

  /// Creates one relationship per selected contact, in selection order.
  ///
  /// Returns the ids of the people actually created. A contact whose write
  /// is rejected is skipped rather than aborting the batch: importing eight
  /// people and failing on the third must not leave the user wondering which
  /// five are missing, and the ones that did land are real.
  Future<List<String>> importSelected() async {
    final repository = ref.read(relationshipRepositoryProvider);
    final refKey = await ref.read(contactRefKeyProvider.future);
    final created = <String>[];

    for (final draft in state.drafts.values) {
      final data = relationshipDataFromContact(
        draft.contact,
        refKey: refKey,
        status: RelationshipStatus.active(
          id: uuid.v1(),
          createdAt: clock.now(),
          utcOffset: clock.now().timeZoneOffset.inMinutes,
        ),
        important: draft.important,
        checkInCadenceDays: draft.cadenceDays,
      );

      final relationship = await repository.createRelationship(data: data);
      if (relationship != null) created.add(relationship.id);
    }

    if (created.isNotEmpty) clearSelection();
    return created;
  }

  void _withDrafts(Map<String, ContactImportDraft> drafts) {
    state = (
      status: state.status,
      contacts: state.contacts,
      drafts: drafts,
      query: state.query,
    );
  }
}

/// The key [host]'s contact ref is stored under in
/// `RelationshipData.contactRefs`.
///
/// Refs are per-device, not merely per-platform: every address book assigns
/// its own identifiers, so two phones on the same OS still hold unrelated
/// ids for the same person. Scoping the key by the sync host id gives each
/// device its own slot — a link written on one device can never overwrite,
/// or be resolved against, another device's address book (ADR 0041 §2). The
/// platform prefix adds no uniqueness beyond the host; it makes the stored
/// map read as "which kind of device wrote this".
String contactRefKeyForHost(String host) =>
    '${Platform.isIOS ? 'ios' : 'android'}:$host';

/// This device's contact-ref key, or `null` while the sync host id is still
/// unknown (it is provisioned during startup, before any contact UI runs).
///
/// Callers treat `null` as "this device has no ref and cannot store one":
/// linking still copies channels, refreshing reports the contact missing,
/// and nothing is written under a key another device could collide with.
final contactRefKeyProvider = FutureProvider<String?>((ref) async {
  final vectorClockService = getIt<VectorClockService>();
  await vectorClockService.initialized;
  final host = await vectorClockService.getHost();
  return host == null ? null : contactRefKeyForHost(host);
}, name: 'contactRefKeyProvider');

final contactImportControllerProvider =
    NotifierProvider<ContactImportController, ContactImportState>(
      ContactImportController.new,
      name: 'contactImportControllerProvider',
    );
