import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/services/db_notification.dart';

/// Writes the user's words as a text entry: under [linkedId] when given,
/// on their own otherwise. Returns the entry, or null when nothing was
/// written.
typedef FrontTextEntryWriter =
    Future<JournalEntity?> Function(
      String text, {
      String? linkedId,
      String? categoryId,
    });

/// Makes a task titled with the user's words. Returns it, or null when
/// nothing was created.
typedef FrontTaskMaker = Future<Task?> Function(String title);

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
      linkedId: proposal.ownerId,
      categoryId: task?.meta.categoryId,
    );
    if (entry == null) throw StateError('The entry was not written.');
    await _rewrite(
      payload,
      record.done(
        FrontDoorFiled(entryId: entry.meta.id, ownerId: proposal.ownerId),
      ),
    );
  }

  /// The user said not to file the proposal. Nothing is written.
  Future<void> decline(String doorId) async {
    final (record, payload) = await _waiting<FrontDoorProposal>(doorId);
    await _rewrite(payload, record.done(const FrontDoorDeclined()));
  }

  /// Takes a filed entry back out: the entry is deleted and the door is a
  /// proposal again, marked as unfiled.
  Future<void> unfile(String doorId) async {
    final (record, payload) = await _waiting<FrontDoorFiled>(doorId);
    final filed = record.outcome! as FrontDoorFiled;
    final ownerId = filed.ownerId;
    if (ownerId == null) throw FrontDoorStateException(doorId);
    await _deleteEntry(filed.entryId);
    await _rewrite(
      payload,
      record.done(FrontDoorProposal(ownerId: ownerId, unfiled: true)),
    );
  }

  /// Saves an inbox segment as a note: a text entry with the user's words,
  /// owned by nothing.
  Future<void> saveAsNote(String doorId) async {
    final (record, payload) = await _waiting<FrontDoorInbox>(doorId);
    final entry = await _writeTextEntry(record.text);
    if (entry == null) throw StateError('The note was not written.');
    await _rewrite(
      payload,
      record.done(FrontDoorFiled(entryId: entry.meta.id)),
    );
  }

  /// Makes a task of an inbox segment, titled with the user's words. The
  /// tap is the approval.
  Future<void> makeTask(String doorId) async {
    final (record, payload) = await _waiting<FrontDoorInbox>(doorId);
    final task = await _makeTask(record.text.trim());
    if (task == null) throw StateError('The task was not created.');
    await _rewrite(
      payload,
      record.done(FrontDoorTaskCreated(taskId: task.meta.id)),
    );
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
