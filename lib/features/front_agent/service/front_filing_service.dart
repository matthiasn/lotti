import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:uuid/uuid.dart';

/// Writes the user's words as a text entry under [id]: linked under
/// [linkedId] when given, on their own otherwise. Writing the same id twice
/// lands on the same entry. Returns the entry — the one written, or the one
/// already there — or null when nothing is stored.
typedef FrontTextEntryWriter =
    Future<JournalEntity?> Function(
      String text, {
      required String id,
      String? linkedId,
      String? categoryId,
    });

/// Makes a task titled with the user's words under [id]. Returns it — the
/// one created, or the one already there — or null when nothing is stored.
typedef FrontTaskMaker =
    Future<Task?> Function(String title, {required String id});

/// Deletes an entry; true when it existed and is gone.
typedef FrontEntryDeleter = Future<bool> Function(String entryId);

/// Thrown when a door is not in the state an action needs — it was already
/// acted on, from another device or an earlier tap.
class FrontDoorStateException implements Exception {
  const FrontDoorStateException(this.doorId);

  final String doorId;

  @override
  String toString() => 'Door $doorId is not waiting for this action.';
}

/// What happens on the user's tap under a door: the one place the front
/// agent's surface changes the record, and only ever with the user's own
/// words, verbatim (decision 1 — nothing is filed without the tap).
///
/// Every action rewrites the door record's outcome under the same ids, so
/// the dispatch keeps its pointer to what was written — the audit trail the
/// plan asks for — and the inbox count follows from the records alone.
///
/// Every write is idempotent per door: the entry or task gets a
/// deterministic id derived from the door (and, for a proposal, its filing
/// generation), so a tap retried after the write landed but the record did
/// not — the process died in between — reuses what it wrote instead of
/// writing it twice.
class FrontFilingService {
  const FrontFilingService({
    required AgentRepository repository,
    required AgentSyncService syncService,
    required JournalDb journalDb,
    required UpdateNotifications notifications,
    required FrontTextEntryWriter writeTextEntry,
    required FrontTaskMaker makeTask,
    required FrontEntryDeleter deleteEntry,
  }) : this._(
         repository,
         syncService,
         journalDb,
         notifications,
         writeTextEntry,
         makeTask,
         deleteEntry,
       );

  const FrontFilingService._(
    this._repository,
    this._syncService,
    this._journalDb,
    this._notifications,
    this._writeTextEntry,
    this._makeTask,
    this._deleteEntry,
  );

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final JournalDb _journalDb;
  final UpdateNotifications _notifications;
  final FrontTextEntryWriter _writeTextEntry;
  final FrontTaskMaker _makeTask;
  final FrontEntryDeleter _deleteEntry;

  /// Files the proposed segment under its task: a text entry with the
  /// user's words, linked to the task and in the task's category, so the
  /// task agent's subscription wake takes it from there.
  Future<void> fileUnderTask(String doorId) async {
    final (record, payload) = await _waiting<FrontDoorProposal>(doorId);
    final proposal = record.outcome! as FrontDoorProposal;
    final task = await _journalDb.journalEntityById(proposal.ownerId);
    final entry = await _writeTextEntry(
      record.text,
      id: frontDoorEntryId(doorId, generation: proposal.generation),
      linkedId: proposal.ownerId,
      categoryId: task?.meta.categoryId,
    );
    if (entry == null) throw StateError('The entry was not written.');
    await _rewrite(
      payload,
      record.done(
        FrontDoorFiled(
          entryId: entry.meta.id,
          ownerId: proposal.ownerId,
          generation: proposal.generation,
        ),
      ),
    );
  }

  /// The user said no to what a waiting door offers. Nothing is written.
  /// A proposal is not refused outright: the words go to the inbox, where
  /// they can still be made something, or left — a wrong guess costs one
  /// more tap, not a retype. An inbox item left where it is settles, and
  /// what it was is kept on the record so [undoDecline] can bring it back.
  Future<void> decline(String doorId) async {
    final (record, payload) = await _waiting<FrontDoorOutcome>(doorId);
    final next = switch (record.outcome) {
      FrontDoorProposal(:final ownerId, :final generation) => FrontDoorInbox(
        ownerId: ownerId,
        generation: generation,
      ),
      FrontDoorInbox(:final ownerId, :final newKind, :final generation) =>
        FrontDoorDeclined(
          ownerId: ownerId,
          newKind: newKind,
          generation: generation,
        ),
      _ => throw FrontDoorStateException(doorId),
    };
    await _rewrite(payload, record.done(next));
  }

  /// A left item waits again as what it was — the proposal, when it came
  /// from one, else the inbox item — the same generation: nothing was
  /// written in between. A record from before the proposal was kept on the
  /// refusal falls back on the door's destination.
  Future<void> undoDecline(String doorId) async {
    final (record, payload) = await _waiting<FrontDoorDeclined>(doorId);
    final declined = record.outcome! as FrontDoorDeclined;
    final ownerId =
        declined.ownerId ??
        (record.kind == FrontDestinationKind.task
            ? record.destinationId
            : null);
    await _rewrite(
      payload,
      record.done(
        ownerId != null
            ? FrontDoorProposal(
                ownerId: ownerId,
                generation: declined.generation,
              )
            : FrontDoorInbox(
                newKind: declined.newKind,
                generation: declined.generation,
              ),
      ),
    );
  }

  /// Takes back what a door wrote: the entry or task is deleted and the
  /// door waits again, one generation on — a filed entry's door is a
  /// proposal again, a note's or a task's is an inbox item again, leading
  /// with the same chip. A delete that did not happen — the thing still
  /// there, undeleted — leaves the door as it was; one already gone
  /// (deleted from the journal itself) counts as taken back.
  Future<void> takeBack(String doorId) async {
    final (record, payload) = await _waiting<FrontDoorOutcome>(doorId);
    final FrontDoorOutcome waiting;
    switch (record.outcome) {
      case FrontDoorFiled(:final entryId, :final ownerId?, :final generation):
        await _takeOut(entryId);
        waiting = FrontDoorProposal(
          ownerId: ownerId,
          generation: generation + 1,
        );
      case FrontDoorFiled(:final entryId, :final newKind, :final generation):
        await _takeOut(entryId);
        waiting = FrontDoorInbox(newKind: newKind, generation: generation + 1);
      case FrontDoorTaskCreated(
        :final taskId,
        :final newKind,
        :final generation,
      ):
        await _takeOut(taskId);
        waiting = FrontDoorInbox(newKind: newKind, generation: generation + 1);
      case _:
        throw FrontDoorStateException(doorId);
    }
    await _rewrite(payload, record.done(waiting));
  }

  /// Saves an inbox segment as a note: a text entry with the user's words,
  /// owned by nothing.
  Future<void> saveAsNote(String doorId) async {
    final (record, payload) = await _waiting<FrontDoorInbox>(doorId);
    final inbox = record.outcome! as FrontDoorInbox;
    final entry = await _writeTextEntry(
      record.text,
      id: frontDoorNoteId(doorId, generation: inbox.generation),
    );
    if (entry == null) throw StateError('The note was not written.');
    await _rewrite(
      payload,
      record.done(
        FrontDoorFiled(
          entryId: entry.meta.id,
          newKind: inbox.newKind,
          generation: inbox.generation,
        ),
      ),
    );
  }

  /// Makes a task of an inbox segment, titled with the user's words. The
  /// tap is the approval.
  Future<void> makeTask(String doorId) async {
    final (record, payload) = await _waiting<FrontDoorInbox>(doorId);
    final inbox = record.outcome! as FrontDoorInbox;
    final task = await _makeTask(
      record.text.trim(),
      id: frontDoorTaskId(doorId, generation: inbox.generation),
    );
    if (task == null) throw StateError('The task was not created.');
    await _rewrite(
      payload,
      record.done(
        FrontDoorTaskCreated(
          taskId: task.meta.id,
          newKind: inbox.newKind,
          generation: inbox.generation,
        ),
      ),
    );
  }

  /// Deletes what a door wrote, or verifies it is gone already.
  Future<void> _takeOut(String id) async {
    if (await _deleteEntry(id)) return;
    final entity = await _journalDb.journalEntityById(id);
    if (entity != null && entity.meta.deletedAt == null) {
      throw StateError('The entry was not deleted.');
    }
  }

  /// The door's record and payload, when its outcome is a [T]; throws
  /// [FrontDoorStateException] otherwise — the action no longer applies.
  Future<(FrontDoorRecord, AgentMessagePayloadEntity)>
  _waiting<T extends FrontDoorOutcome>(String doorId) async {
    final payload = await _repository.getEntity('$doorId:payload');
    final record = payload is AgentMessagePayloadEntity
        ? FrontDoorRecord.fromJson(payload.content)
        : null;
    if (record == null || record.outcome is! T) {
      throw FrontDoorStateException(doorId);
    }
    return (record, payload! as AgentMessagePayloadEntity);
  }

  Future<void> _rewrite(
    AgentMessagePayloadEntity payload,
    FrontDoorRecord record,
  ) async {
    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payload.id,
        agentId: payload.agentId,
        content: record.toJson(),
        createdAt: payload.createdAt,
        vectorClock: payload.vectorClock,
      ),
    );
    // The sync service pings nobody; the thread watches the front agent.
    _notifications.notifyUiOnly({frontAgentId, agentNotification});
  }
}

/// The id of the entry a proposal files under its task: the door and the
/// filing generation, so a retry reuses the entry and a re-file after a
/// take-back gets a new one.
String frontDoorEntryId(String doorId, {required int generation}) =>
    _writtenId('$doorId/entry/$generation');

/// The id of the note an inbox item is saved as; the first generation keeps
/// the id notes were saved under before generations were counted.
String frontDoorNoteId(String doorId, {int generation = 0}) =>
    _writtenId(generation == 0 ? '$doorId/note' : '$doorId/note/$generation');

/// The id of the task an inbox item is made into; the first generation
/// keeps the id tasks were made under before generations were counted.
String frontDoorTaskId(String doorId, {int generation = 0}) =>
    _writtenId(generation == 0 ? '$doorId/task' : '$doorId/task/$generation');

String _writtenId(String path) =>
    const Uuid().v5(Namespace.url.value, 'lotti://front-door/$path');
