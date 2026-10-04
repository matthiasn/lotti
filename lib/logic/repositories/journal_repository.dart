import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/blocks_cycle_guard.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/relationship_cascade.dart';
import 'package:lotti/logic/write_on_stored.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// App-facing facade for journal entity reads, writes, links, and deletes.
///
/// A thin coordination layer over the `getIt`-resolved `JournalDb`,
/// `PersistenceLogic`, and sync services (it is a facade, not DI-wired — deps
/// are looked up via `getIt`, not injected). Owns single- and bulk-ID loads,
/// entity create/update, entry-link writes (under a vector-clock scope), and
/// cascading cleanup such as clearing cover-art, avatar and banner references
/// on image delete.
/// What [JournalRepository.createImageEntryTracked] came to: the entry, and
/// whether that call inserted it rather than landing on an existing row.
typedef ImageEntryResult = ({JournalEntity entry, bool created});

class JournalRepository {
  JournalRepository();

  /// The writes to a person that a delete cascades into — the person's own
  /// deletion, and clearing a deleted image off their avatar or banner — over
  /// this repository. The composition root registers the factory, so every
  /// edit of a person stays on the relationship repository's single write
  /// path without this layer importing it.
  /// The journal the link methods read and write.
  JournalDb get _journalDb => getIt<JournalDb>();

  RelationshipCascade _relationships(PersistenceLogic persistenceLogic) =>
      getIt<RelationshipCascadeFactory>()(this, persistenceLogic);

  /// Clears references to a deleted image from the entities that point at it,
  /// so nothing is left rendering an id whose file and entry are gone.
  ///
  /// Covers a task's cover art and a relationship's avatar and banner. The
  /// avatar's crop goes with the avatar: a framing for an image that no longer
  /// exists is not a value worth keeping, and leaving it behind would make a
  /// later photo inherit the old photo's framing.
  Future<void> _clearImageReferences(
    String imageId,
    PersistenceLogic persistenceLogic,
  ) async {
    final db = getIt<JournalDb>();
    // Entities that link TO this image — the ones able to reference it.
    final linkedFromEntities = await db.getLinkedToEntities(imageId);

    for (final dbEntity in linkedFromEntities) {
      final entity = fromDbEntity(dbEntity);
      if (entity is Task && entity.data.coverArtId == imageId) {
        await persistenceLogic.updateTask(
          journalEntityId: entity.id,
          change: (stored) => stored.coverArtId == imageId
              ? stored.copyWith(coverArtId: null)
              : stored,
        );
      }
      if (entity is RelationshipEntry) {
        final data = entity.data;
        final clearsAvatar = data.avatarImageId == imageId;
        final clearsBanner = data.bannerImageId == imageId;
        if (!clearsAvatar && !clearsBanner) continue;
        final cleared = await _relationships(persistenceLogic)
            .updateRelationship(
              entity.copyWith(
                data: data.copyWith(
                  avatarImageId: clearsAvatar ? null : data.avatarImageId,
                  avatarCrop: clearsAvatar ? null : data.avatarCrop,
                  bannerImageId: clearsBanner ? null : data.bannerImageId,
                ),
              ),
            );
        // A refused write leaves the person pointing at an image that is
        // about to be tombstoned. The renderer tolerates that — the avatar's
        // "id known, nothing to show" face, the hero's plain wash — so the
        // deletion the user asked for goes ahead; the miss is recorded so it
        // can be found rather than silently outliving the image.
        if (!cleared) {
          getIt<DomainLogger>().log(
            LogDomain.persistence,
            'Could not clear image $imageId from relationship ${entity.id} '
            'before tombstoning it',
            subDomain: 'deleteJournalEntity',
            level: InsightLevel.warn,
          );
        }
      }
    }
  }

  /// Loads a single entity by id, or null if it does not exist.
  Future<JournalEntity?> getJournalEntityById(String id) async {
    return getIt<JournalDb>().journalEntityById(id);
  }

  /// Bulk-fetch entities by id. Use this whenever the caller has more than
  /// one id at a time — collapses the classic `Future.wait(ids.map(byId))`
  /// fan-out into a single round-trip.
  Future<List<JournalEntity>> getJournalEntitiesByIds(
    Iterable<String> ids,
  ) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return const <JournalEntity>[];
    return getIt<JournalDb>().getJournalEntitiesForIdsUnordered(idSet);
  }

  /// Updates only the `categoryId` on a single entity's metadata (pass null to
  /// clear it). Callers that need cascading propagation to linked entries do
  /// that themselves (see `EntryController.updateCategoryId`).
  ///
  /// Returns whether the write actually landed: false for a missing entity, a
  /// rejected write (`updateDbEntity` answers false when the vector-clock
  /// comparison loses to a concurrent sync, null when it swallowed an
  /// exception), and a logged failure. Callers act on this — `EntryController`
  /// only sweeps project links for entries that really moved, and the
  /// relationship form only reports a save as successful when it did — so
  /// answering true for a write that never happened would report success on a
  /// half-saved entity with nothing left to retry.
  Future<bool> updateCategoryId(
    String journalEntityId, {
    required String? categoryId,
  }) async {
    try {
      // Built on the entry as stored, so a field set since — a task's
      // status, a checklist listed on it — is kept (MetaOnStored).
      return await getIt<PersistenceLogic>().updateEntity(
        journalEntityId,
        (stored) => stored.copyWith(
          meta: stored.meta.copyWith(categoryId: categoryId),
        ),
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateCategoryId',
      );
      return false;
    }
  }

  /// Soft-deletes an entity by stamping `deletedAt` on its metadata, on the
  /// entry as stored ([writeOnStored]): a version stored meanwhile is built
  /// on, not replaced by the copy read first.
  ///
  /// Also handles side effects: when deleting an image used as task cover art
  /// the references are cleared first, a relationship cascades to its
  /// check-ins, and once the deletion is stored the running timer is stopped
  /// if it is this entry, or runs for this task, and the app badge is
  /// refreshed.
  ///
  /// Returns whether the deletion is stored: false when the entity does not
  /// exist, the write was refused, or it failed. Callers act on it — the
  /// checklist membership intents keep an operation whose delete did not
  /// land for the next start (`specs/tla/ChecklistMembership.tla`,
  /// DeleteReportsFailure), and the entry page stays open on an entry that
  /// is still there — so answering true for a write that never happened
  /// would leave a deleted item alive and listed nowhere.
  Future<bool> deleteJournalEntity(String journalEntityId) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();
      final journalDb = getIt<JournalDb>();

      final journalEntity = await journalDb.journalEntityById(
        journalEntityId,
      );

      if (journalEntity == null) {
        return false;
      }

      // ADR 0037 §5: deleting a person cascades to their check-ins, private
      // ones included. The invariant is guarded HERE so it holds on every
      // surface that can reach the generic delete path (a deep link to the
      // journal detail page included), not only on the People pages.
      if (journalEntity is RelationshipEntry) {
        return await _relationships(
          persistenceLogic,
        ).deleteRelationship(journalEntityId);
      }

      // If deleting an image anything uses as cover art, an avatar or a
      // banner, clear the reference before the image is tombstoned.
      if (journalEntity is JournalImage) {
        await _clearImageReferences(journalEntityId, persistenceLogic);
      }

      final written = await writeOnStored(
        journalDb: journalDb,
        persistenceLogic: persistenceLogic,
        id: journalEntityId,
        build: (stored) async => stored.copyWith(
          meta: await persistenceLogic.updateMetadata(
            stored.meta,
            deletedAt: DateTime.now(),
          ),
        ),
      );
      // A write reported as failed can have committed: `updateDbEntity`
      // answers null too when work after the commit throws (the search
      // index, the badge). The stored row decides.
      final deleted =
          written ||
          (await journalDb.journalEntityByIdIncludingDeleted(
                journalEntityId,
              ))?.meta.deletedAt !=
              null;
      if (!deleted) return false;

      // Stop the timer when the deleted entry is the one running — a
      // deleted entry has no end left to write — or the task it runs for:
      // its entry stays, and keeps the time tracked until now.
      final timeService = getIt<TimeService>();
      final running = timeService.getCurrent();
      if (running?.id == journalEntityId) {
        await timeService.stop(persistEnd: false);
      } else if (running != null &&
          timeService.linkedFrom?.id == journalEntityId) {
        await timeService.stop();
      }

      await getIt<NotificationService>().updateBadge();
      return true;
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'deleteJournalEntity',
      );
      return false;
    }
  }

  /// Persists `updated` (including its metadata) through `PersistenceLogic`.
  ///
  /// A task keeps the checklist list it has stored: `updated` is the
  /// caller's copy, read before its change, and
  /// `ChecklistRepository.updateTaskChecklistIds` owns that list. The list
  /// is taken from the stored row and the write applies only while that row
  /// is still the one read ([writeOnStored]), so a checklist listed in
  /// between is never dropped (`specs/tla/ChecklistMembership.tla`,
  /// agTaskEdit). Its record of applied agent changes is kept the same way,
  /// joined with any `updated` adds ([TaskDataOnStored.onStored], ADR 0098).
  ///
  /// [onlyIfUnchanged] applies any other entity only while the stored row is
  /// still the version `updated` was built on — the one whose vector clock
  /// `updated.meta` carries — so a version stored meanwhile, by sync or by a
  /// local edit, is never overwritten; the write is refused instead, and the
  /// caller builds it again on a fresh read.
  ///
  /// Returns false when the write was refused, and on a logged failure.
  Future<bool> updateJournalEntity(
    JournalEntity updated, {
    bool onlyIfUnchanged = false,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();
      final journalDb = getIt<JournalDb>();
      if (updated is Task &&
          await journalDb.journalEntityById(updated.id) is Task) {
        return await writeOnStored(
          journalDb: journalDb,
          persistenceLogic: persistenceLogic,
          id: updated.id,
          build: (stored) async => stored is Task
              ? updated.copyWith(data: updated.data.onStored(stored.data))
              : null,
          write: (entity, precondition) => persistenceLogic.updateJournalEntity(
            entity,
            entity.meta,
            precondition: precondition,
          ),
        );
      }
      return await persistenceLogic.updateJournalEntity(
        updated,
        updated.meta,
        precondition: onlyIfUnchanged
            ? () => journalDb.isStoredVersion(
                updated.id,
                updated.meta.vectorClock,
              )
            : null,
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateJournalEntity',
      );
      return false;
    }
  }

  /// Applies [change] to the data of the stored task [taskId] and writes the
  /// result on that row (`PersistenceLogic.updateTask`): the agent's field
  /// tools and the day agent's triage set a field this way, so a field set
  /// since their tool call read the task is kept
  /// (`specs/tla/TaskFieldWrites.tla`). [onlyIf] is asked of the stored
  /// task inside the write, and nothing is written when it answers false.
  /// Returns the task as stored afterwards, or `null` when it does not exist
  /// or the write failed.
  Future<Task?> updateTask(
    String taskId,
    TaskData Function(TaskData stored) change, {
    bool Function(Task stored)? onlyIf,
  }) => getIt<PersistenceLogic>().updateTask(
    journalEntityId: taskId,
    change: change,
    onlyIf: onlyIf,
  );

  /// Updates an entity's `dateFrom`/`dateTo` on the entry as stored, so a
  /// field set since is kept (MetaOnStored), and, if it is the running
  /// timer, pushes the new range into the time service so the live duration
  /// stays in sync. Returns whether the range is stored: false when the
  /// entity does not exist, the write was refused, or it failed.
  Future<bool> updateJournalEntityDate(
    String journalEntityId, {
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      JournalEntity? updated;
      final stored = await getIt<PersistenceLogic>().updateEntity(
        journalEntityId,
        (stored) => updated = stored.copyWith(
          meta: stored.meta.copyWith(dateFrom: dateFrom, dateTo: dateTo),
        ),
      );
      if (stored) getIt<TimeService>().updateCurrent(updated);
      return stored;
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateJournalEntityDate',
      );
      return false;
    }
  }

  /// Creates a new text journal entry from `entryText`, optionally linked to
  /// `linkedId` and tagged with `categoryId`. Returns the created entity, or
  /// null on a logged failure.
  ///
  /// The entry's id is minted with its metadata, where its vector clock is
  /// reserved naming that id; callers read it from the returned entity.
  static Future<JournalEntity?> createTextEntry(
    EntryText entryText, {
    required DateTime started,
    String? linkedId,
    String? categoryId,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity = JournalEntity.journalEntry(
        entryText: entryText,
        meta: await persistenceLogic.createMetadata(
          dateFrom: started,
          categoryId: categoryId,
        ),
      );

      await persistenceLogic.createDbEntity(journalEntity, linkedId: linkedId);

      return journalEntity;
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createTextEntry',
      );
      return null;
    }
  }

  /// Creates a new image entry in the journal.
  ///
  /// Parameters:
  /// - [imageData]: The image data to create an entry for
  /// - [linkedId]: Optional ID of an entry to link this image to (e.g., a task)
  /// - [categoryId]: Optional category ID for the image
  /// - [onCreated]: Optional callback invoked after the image entry is created
  ///   (used for automatic image analysis triggering)
  /// - [linkCollapsed]: Whether the created link to [linkedId] starts collapsed
  static Future<JournalEntity?> createImageEntry(
    ImageData imageData, {
    String? linkedId,
    String? categoryId,
    void Function(JournalEntity)? onCreated,
    bool linkCollapsed = false,
  }) async => (await createImageEntryTracked(
    imageData,
    linkedId: linkedId,
    categoryId: categoryId,
    onCreated: onCreated,
    linkCollapsed: linkCollapsed,
  ))?.entry;

  /// [createImageEntry], also saying whether this call *inserted* the entry.
  ///
  /// An image entry's id is a v5 uuid of its `ImageData`, and a gallery
  /// asset's data is the same on every import, so importing a photo a second
  /// time lands on the row that already exists: `createDbEntity` declines the
  /// write and `created` is false. A caller that imported the picture for one
  /// purpose — a person's photo, say — may take it back out of the journal on
  /// cancel only when it created it; the existing row is somebody's already.
  static Future<ImageEntryResult?> createImageEntryTracked(
    ImageData imageData, {
    String? linkedId,
    String? categoryId,
    void Function(JournalEntity)? onCreated,
    bool linkCollapsed = false,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity = JournalEntity.journalImage(
        data: imageData,
        meta: await persistenceLogic.createMetadata(
          dateFrom: imageData.capturedAt,
          dateTo: imageData.capturedAt,
          uuidV5Input: json.encode(imageData),
          flag: EntryFlag.import,
          categoryId: categoryId,
        ),
        geolocation: imageData.geolocation,
      );
      final applied = await persistenceLogic.createDbEntity(
        journalEntity,
        linkedId: linkedId,
        shouldAddGeolocation: false,
        linkCollapsed: linkCollapsed,
      );

      final created = applied ?? false;
      // Only a row this call inserted is "created": an existing image must
      // not have its analysis re-triggered because it was picked again.
      if (created) onCreated?.call(journalEntity);

      return (entry: journalEntity, created: created);
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createImageEntry',
      );
    }

    return null;
  }

  /// Upserts an entry link, but only when a meaningful field actually changed;
  /// an unchanged link returns false on a fast path
  /// without reserving a vector clock.
  ///
  /// A real change runs inside a vector-clock scope so the bump, the local
  /// notification, and the outbox sync message stay consistent; the VC is only
  /// committed when the upsert wrote a row. Returns true when a row was written.
  ///
  /// The edit succeeds the stored version on every device: its clock extends
  /// that version's, and its `updatedAt` is never older than that version's
  /// (see [linkEditTimestamp]), so a late copy of the replaced version — a
  /// peer's journal-entity message embeds its links — cannot undo it.
  ///
  /// [precondition], when given, runs inside the transaction that writes the
  /// link, and the link is written only when it holds: a check made before
  /// the call can have been overtaken by another write on this device.
  Future<bool> updateLink(
    EntryLink link, {
    Future<bool> Function()? precondition,
  }) async {
    final journalDb = _journalDb;
    final existing = await journalDb.entryLinkById(link.id);

    if (existing != null && !_hasChange(existing, link)) {
      // No VC reserved yet — fast path.
      return false;
    }

    // Wrap in VC scope: if upsertEntryLink returns 0 (identical row already
    // exists), release the reservation and let the burn handler broadcast
    // an unresolvable hint so peers skip the gap instead of round-tripping
    // via backfill.
    return getIt<VectorClockService>().withVcScope<bool>(() async {
      final updated = link.copyWith(
        updatedAt: linkEditTimestamp(existing, DateTime.now()),
        // An update carries every counter of the version it replaces, so it
        // dominates that version on every device: `upsertEntryLink` refuses
        // a link whose stored clock dominates it, and a clock of this host's
        // counter alone would merely be concurrent with the stored one.
        vectorClock: await getIt<VectorClockService>().getNextVectorClock(
          previous: VectorClock.merge(existing?.vectorClock, link.vectorClock),
          payload: (id: link.id, type: SyncSequencePayloadType.entryLink),
        ),
      );

      final res = precondition == null
          ? await journalDb.upsertEntryLink(updated)
          : await journalDb.transaction(
              () async =>
                  await precondition() ? journalDb.upsertEntryLink(updated) : 0,
            );
      if (res == 0) return false;
      getIt<UpdateNotifications>().notify({
        link.fromId,
        link.toId,
        linkNotification,
      });
      try {
        await getIt<OutboxService>().enqueueMessage(
          SyncMessage.entryLink(
            entryLink: updated,
            status: SyncEntryStatus.update,
          ),
        );
      } catch (error, stackTrace) {
        getIt<DomainLogger>().error(
          LogDomain.sync,
          error,
          message:
              'outbox enqueue failed after updateLink; VC already committed',
          stackTrace: stackTrace,
          subDomain: 'updateLink.enqueue',
        );
      }
      return true;
    }, commitWhen: (ok) => ok);
  }

  bool _hasChange(EntryLink existing, EntryLink incoming) {
    final existingHidden = existing.hidden ?? false;
    final incomingHidden = incoming.hidden ?? false;
    final existingCollapsed = existing.collapsed ?? false;
    final incomingCollapsed = incoming.collapsed ?? false;

    return existing.fromId != incoming.fromId ||
        existing.toId != incoming.toId ||
        existing.createdAt != incoming.createdAt ||
        existing.deletedAt != incoming.deletedAt ||
        existingHidden != incomingHidden ||
        existingCollapsed != incomingCollapsed ||
        entryLinkTypeName(existing) != entryLinkTypeName(incoming);
  }

  /// Removes every link from `fromId` to `toId`, whatever its type, and
  /// returns how many were removed.
  ///
  /// See [removeTypedLink] for how a removal reaches the other devices.
  Future<int> removeLink({required String fromId, required String toId}) =>
      _removeLinks(fromId: fromId, toId: toId);

  /// Removes only the link of [linkType] between `fromId` and `toId`, leaving
  /// any other type coexisting between the same pair intact (ADR 0042 allows
  /// e.g. a `BasicLink` and a `BlocksLink` between the same two tasks
  /// simultaneously — unlike [removeLink], this never touches the other one).
  /// Returns how many links were removed: 1, or 0 when none was live.
  ///
  /// A removal is a synced tombstone, not a local delete: the link's next
  /// version, with `deletedAt` set and `hidden` true, written through
  /// [updateLink]. So it extends the removed version's clock, is never
  /// stamped earlier than it, and is sent to the other devices — where it
  /// outranks every copy of the live link, including the snapshot a peer's
  /// journal-entity message embeds. Creating the same link again revives the
  /// tombstone (`PersistenceLogic.createLink`).
  Future<int> removeTypedLink({
    required String fromId,
    required String toId,
    required String linkType,
  }) => _removeLinks(fromId: fromId, toId: toId, type: linkType);

  Future<int> _removeLinks({
    required String fromId,
    required String toId,
    String? type,
  }) async {
    final links = await _journalDb.linksBetween(
      fromId,
      toId,
      type: type,
    );
    var removed = 0;
    for (final link in links) {
      if (link.deletedAt != null) continue;
      final tombstone = link.copyWith(deletedAt: DateTime.now(), hidden: true);
      if (await updateLink(tombstone)) removed++;
    }
    return removed;
  }

  /// Applies [change] to the stored link [linkId] — a flag such as `hidden`
  /// or `collapsed` — and writes the result ([updateLink]) only while the
  /// link is still stored as it was read; one stored meanwhile is built on
  /// again, for as long as the row keeps moving.
  ///
  /// A card's copy of a link can predate its removal, here or on another
  /// device: written as it was, the edit would be the newest version of the
  /// link and bring it back everywhere. A link that is removed, or gone, is
  /// therefore left alone (`specs/tla/EntryLinkIdentity.tla`, EditOnStored).
  ///
  /// Returns whether the change is stored: `true` when [change] leaves the
  /// link as it is, `false` when the link is removed or gone, or the write
  /// was refused with the row unchanged.
  Future<bool> changeLink(
    String linkId,
    EntryLink Function(EntryLink stored) change,
  ) async {
    final db = _journalDb;
    EntryLink? previous;
    while (true) {
      final stored = await db.entryLinkById(linkId);
      if (stored == null || stored.deletedAt != null) return false;
      if (stored == previous) return false;
      previous = stored;
      final changed = change(stored);
      if (changed == stored) return true;
      if (await updateLink(
        changed,
        precondition: () async => await db.entryLinkById(linkId) == stored,
      )) {
        return true;
      }
    }
  }

  /// Retypes and/or flips the direction of an existing typed relationship
  /// link, preserving its `id` (and therefore its identity across the
  /// notification stream and any future edits) rather than deleting and
  /// recreating it.
  ///
  /// Returns `false` when [linkId] no longer resolves to a link, when another
  /// live link already is the new relationship, or when [newType] is
  /// `blocks` and the retype would close a cycle (ADR 0042 §5) — the existing
  /// link's own row is excluded from that check so a same-edge direction flip
  /// is never rejected against its own stale state.
  ///
  /// A link is its `(fromId, toId, type)`, and the receive keeps one version
  /// per triple whatever its id (ADR 0096), so moving this link onto a triple
  /// another live link holds would replace that link rather than sit beside
  /// it. That is refused here, as the duplicate rule refused it before.
  ///
  /// Both refusals are checked before a clock is reserved and again inside
  /// the transaction that writes the link, which also requires the link to
  /// be stored as it was read: another writer on this device can have
  /// changed it, or stored a link that closes the cycle, in between
  /// (ADR 0106).
  Future<bool> updateLinkType({
    required String linkId,
    required EntryLinkType newType,
    required bool swapDirection,
  }) async {
    final db = _journalDb;
    final existing = await db.entryLinkById(linkId);
    if (existing == null) return false;

    final newFromId = swapDirection ? existing.toId : existing.fromId;
    final newToId = swapDirection ? existing.fromId : existing.toId;

    Future<bool> allowed() async {
      final occupant = (await db.linksBetween(
        newFromId,
        newToId,
        type: entryLinkTypeDbName(newType),
      )).where((link) => link.id != linkId).firstOrNull;
      if (occupant != null &&
          occupant.deletedAt == null &&
          occupant.hidden != true) {
        return false;
      }
      return !(newType == EntryLinkType.blocks &&
          await wouldCreateBlocksCycle(
            fromId: newFromId,
            toId: newToId,
            excludeLinkId: linkId,
          ));
    }

    if (!await allowed()) return false;

    return updateLink(
      newType.buildLink(
        id: existing.id,
        fromId: newFromId,
        toId: newToId,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        vectorClock: existing.vectorClock,
        hidden: existing.hidden,
        collapsed: existing.collapsed,
        deletedAt: existing.deletedAt,
      ),
      precondition: () async =>
          await db.entryLinkById(linkId) == existing && await allowed(),
    );
  }

  /// Returns the entities that link *to* `linkedTo` (incoming / "linked from"
  /// direction). Contrast with [getLinkedEntities], which returns the outgoing
  /// targets.
  Future<List<JournalEntity>> getLinkedToEntities({
    required String linkedTo,
  }) async {
    final db = _journalDb;
    final items = await db.getLinkedToEntities(linkedTo);
    return items.map(fromDbEntity).toList();
  }

  /// Returns the entities that `linkedTo` links *to* (outgoing direction).
  /// Contrast with [getLinkedToEntities], which returns the incoming sources.
  Future<List<JournalEntity>> getLinkedEntities({
    required String linkedTo,
  }) async {
    return _journalDb.getLinkedEntities(linkedTo);
  }

  /// Returns all JournalImage entries linked to the given task.
  ///
  /// This is a convenience method that filters the linked entities
  /// to only include images, useful for reference image selection.
  Future<List<JournalImage>> getLinkedImagesForTask(String taskId) async {
    final linkedEntities = await getLinkedEntities(linkedTo: taskId);
    return linkedEntities.whereType<JournalImage>().toList();
  }

  /// Returns the outgoing [EntryLink]s from `linkedFrom`, deduplicated by
  /// target id and ordered by the target entity's (editable) `dateFrom`
  /// descending — so re-dating a linked entry reorders the list. Hidden links
  /// are excluded unless `includeHidden` is set.
  Future<List<EntryLink>> getLinksFromId(
    String linkedFrom, {
    bool includeHidden = false,
  }) async {
    final linksByToId = <String, EntryLink>{};

    final res = await _journalDb
        .linksFromId(linkedFrom, includeHidden ? [false, true] : [false])
        .get();

    for (final link in res.map(entryLinkFromLinkedDbEntry)) {
      linksByToId[link.toId] = link;
    }

    if (linksByToId.isEmpty) {
      // Avoid the follow-up `id IN ()` ordering query when there are no links.
      return const <EntryLink>[];
    }

    // sort by the (editable) date from, descending, to allow for changing the
    // start date of the linked entries and get the list reordered accordingly
    final sortedToIds = await _journalDb
        .getJournalEntityIdsSortedByDateFromDesc(
          linksByToId.keys.toList(growable: false),
        );

    return sortedToIds.map((id) => linksByToId[id]).nonNulls.toList();
  }

  /// Returns typed links (e.g. `blocks`, `followsUp`) touching any of [ids] in
  /// either direction, restricted to [linkTypes] (the `linked_entries.type`
  /// column values, e.g. `'BlocksLink'`). Thin pass-through to
  /// [JournalDb.typedLinksForTaskIds].
  Future<List<EntryLink>> getTypedLinksForTaskIds(
    Set<String> ids, {
    required Set<String> linkTypes,
  }) {
    return _journalDb.typedLinksForTaskIds(ids, types: linkTypes);
  }

  /// Bulk-fetch entities by id, including tombstoned (soft-deleted) ones.
  ///
  /// Unlike [getJournalEntitiesByIds], this does not filter `deleted = false`
  /// — it's the one lookup that can tell "tombstoned" apart from "never
  /// resolved" (needed by `TaskBlockersController` to release a dependent when
  /// its blocker was deliberately closed/deleted vs. keep it blocked when the
  /// blocker simply hasn't synced yet).
  Future<List<JournalEntity>> getJournalEntitiesByIdsIncludingDeleted(
    Iterable<String> ids,
  ) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return const <JournalEntity>[];
    final rows = await getIt<JournalDb>().entriesForIds(idSet.toList()).get();
    return rows.map(fromDbEntity).toList();
  }
}

final Provider<JournalRepository> journalRepositoryProvider =
    Provider.autoDispose<JournalRepository>(
      journalRepository,
      name: 'journalRepositoryProvider',
    );
JournalRepository journalRepository(Ref ref) => JournalRepository();
