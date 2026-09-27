import 'package:collection/collection.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:uuid/uuid.dart';

/// The id a link from [fromId] to [toId] of [type] (the `linked_entries.type`
/// column value, see `entryLinkTypeDbName`) takes when it is created for the
/// first time: derived from that natural key, so it is the same on every
/// device.
///
/// Two devices that create the same link offline then write two versions of
/// one link rather than two links, and `JournalDb.upsertEntryLink` orders
/// them like any other versions (ADR 0078). A removal on either device
/// succeeds the version it saw and outranks the other wherever it arrives
/// (ADR 0096).
String entryLinkId({
  required String fromId,
  required String toId,
  required String type,
}) => MetadataService.deterministicId('entry-link|$type|$fromId|$toId');

/// What a new link is written over: the `id` it takes, and the stored
/// `predecessor` it succeeds, if any.
typedef LinkCreationBase = ({String id, EntryLink? predecessor});

/// How to create the link from [fromId] to [toId] of [type] on this device,
/// or null when that link is already live and visible here, so creating it
/// again would change nothing.
///
/// `linked_entries` holds one row per `(from_id, to_id, type)`. When one is
/// stored — removed by a tombstone, or hidden — the new link is its next
/// version: it takes the row's id, and the caller reserves its clock with the
/// row's as `previous` and stamps it with [linkEditTimestamp]. A tombstone is
/// therefore revived rather than joined by a second id for the same link.
///
/// Otherwise the link takes [entryLinkId]. That id can already belong to
/// another row only when a link created under it was retyped or turned
/// around since (`JournalRepository.updateLinkType` keeps the id); the new
/// link then takes a random id, and the receive orders it against the other
/// versions of its natural key whatever their ids (ADR 0096).
Future<LinkCreationBase?> linkCreationBase(
  JournalDb db, {
  required String fromId,
  required String toId,
  required String type,
}) async {
  final stored = (await db.linksBetween(fromId, toId, type: type)).firstOrNull;
  if (stored != null) {
    final live = stored.deletedAt == null && stored.hidden != true;
    return live ? null : (id: stored.id, predecessor: stored);
  }
  final derived = entryLinkId(fromId: fromId, toId: toId, type: type);
  final taken = await db.entryLinkById(derived) != null;
  return (id: taken ? const Uuid().v1() : derived, predecessor: null);
}
