import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/write_on_stored.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/time_service.dart';

/// Builds the app's [TimeService], wired to persist the running timer's end
/// time: when a new timer replaces it, and on the autosave cadence while it
/// runs. Its collaborators are resolved from [getIt] at write time, not at
/// construction.
TimeService buildPersistingTimeService() {
  Future<void> persist(JournalEntity entry) => persistRunningTimerEnd(
    entry,
    persistenceLogic: getIt<PersistenceLogic>(),
    journalDb: getIt<JournalDb>(),
    editorStateService: getIt<EditorStateService>(),
  );

  return TimeService(persistTimerStop: persist, autosave: persist);
}

/// Moves the end time of the running timer's [entry] to now.
///
/// Only the end time is written, on the entry as stored — never on [entry],
/// the copy the timer was started with — and only while the stored row is
/// still the one it was built on ([writeOnStored]). A save of the text that
/// lands in between is therefore built on, not put back.
///
/// An unsaved editor draft is neither read nor persisted: it stays the
/// user's to save or discard, and is not synced to other devices before they
/// do. It is moved onto the version this write stores
/// ([EditorStateService.rebaseDraft]), so it is still restored after a
/// restart even when no editor for the entry is open to follow the write.
///
/// The write lets a long session show up in the calendar — here and,
/// through sync, on every other device — while it runs, rather than as a gap
/// until the timer is stopped; and it gives a replaced timer its real stop
/// time.
Future<void> persistRunningTimerEnd(
  JournalEntity entry, {
  required PersistenceLogic persistenceLogic,
  required JournalDb journalDb,
  required EditorStateService editorStateService,
}) async {
  JournalEntity? builtOn;
  JournalEntity? written;
  final stored = await writeOnStored(
    journalDb: journalDb,
    persistenceLogic: persistenceLogic,
    id: entry.meta.id,
    build: (stored) async {
      builtOn = stored;
      return written = stored is JournalEntry
          ? stored.copyWith(
              meta: await persistenceLogic.updateMetadata(
                stored.meta,
                dateTo: clock.now(),
              ),
            )
          : null;
    },
  );

  final from = builtOn?.meta.updatedAt;
  final to = written?.meta.updatedAt;
  if (stored && from != null && to != null) {
    await editorStateService.rebaseDraft(
      id: entry.meta.id,
      from: from,
      to: to,
    );
  }
}
