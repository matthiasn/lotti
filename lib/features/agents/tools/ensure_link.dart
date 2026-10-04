import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic.dart';

/// Writes a link of [linkType] from [fromId] to [toId] where none is live,
/// and answers whether one is live afterwards.
///
/// `PersistenceLogic.createLink` answers false both when its write failed and
/// when it wrote nothing because the link was already there, so a false
/// answer is checked against the stored links. A tool that repairs what an
/// interrupted application left (`specs/tla/ChangeDispatchRecovery.tla`,
/// TailOnRerun) must not report the repair done on a link that is missing.
Future<bool> ensureLink({
  required PersistenceLogic persistenceLogic,
  required JournalDb journalDb,
  required String fromId,
  required String toId,
  EntryLinkType linkType = EntryLinkType.basic,
}) async =>
    await persistenceLogic.createLink(
      fromId: fromId,
      toId: toId,
      linkType: linkType,
    ) ||
    (await journalDb.linksBetween(
      fromId,
      toId,
      type: entryLinkTypeDbName(linkType),
    )).any((link) => link.deletedAt == null);
