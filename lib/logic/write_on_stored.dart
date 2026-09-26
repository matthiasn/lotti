import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic_contract.dart';

/// Writes [updated] under [precondition]; the default is
/// `PersistenceLogicContract.updateDbEntity`.
typedef StoredWrite =
    Future<bool?> Function(
      JournalEntity updated,
      Future<bool> Function() precondition,
    );

/// Writes the version [build] makes of the stored entry [id] — `null` when
/// there is nothing to write — and applies it only while the stored row is
/// still the one it was built on. A version stored meanwhile, by sync or by
/// another writer on this device, is never overwritten: the change is built
/// again on it (ADR 0083, ADR 0089 and `specs/tla/ChecklistMembership.tla`).
///
/// The change is rebuilt for as long as the stored row keeps moving — each
/// refusal means another version was stored, so under any finite contention
/// the write lands. A refusal with the row unchanged is not a race: the
/// write decision refused it for another reason (a concurrent version from
/// another device, which it records as a conflict), and building it again
/// would be refused again, so it stops there.
///
/// [write] replaces the default write (`updateDbEntity`) for a caller whose
/// version carries its own clock; it must apply the version only while
/// `precondition` holds. [beforeNotify] builds the hook `updateDbEntity` runs
/// after an applied write, from the row the version was built on and the
/// version itself.
///
/// Returns whether the change is stored: `true` when [build] had nothing to
/// write, `false` when the entry does not exist, the write was refused with
/// the row unchanged, or it failed.
Future<bool> writeOnStored({
  required JournalDb journalDb,
  required PersistenceLogicContract persistenceLogic,
  required String id,
  required Future<JournalEntity?> Function(JournalEntity stored) build,
  String? linkedId,
  Future<void> Function()? Function(
    JournalEntity stored,
    JournalEntity updated,
  )?
  beforeNotify,
  StoredWrite? write,
}) async {
  JournalEntity? previous;
  while (true) {
    final stored = await journalDb.journalEntityById(id);
    if (stored == null) return false;
    if (previous != null &&
        stored.meta.vectorClock == previous.meta.vectorClock) {
      return false;
    }
    previous = stored;
    final updated = await build(stored);
    if (updated == null) return true;
    Future<bool> precondition() =>
        journalDb.isStoredVersion(id, stored.meta.vectorClock);
    final applied = write != null
        ? await write(updated, precondition)
        : await persistenceLogic.updateDbEntity(
            updated,
            linkedId: linkedId,
            beforeNotify: beforeNotify?.call(stored, updated),
            precondition: precondition,
          );
    if (applied == null) return false;
    if (applied) return true;
  }
}
