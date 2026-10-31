import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:rxdart/rxdart.dart';

/// The ids of every source a journal answer in [thread] depends on.
Set<String> frontJournalSourceIds(FrontChatThread? thread) => {
  for (final doors
      in thread?.doorsByMessageId.values ?? const <List<FrontDoorEntry>>[])
    for (final door in doors)
      if (door.record.outcome case FrontDoorAnswer(
        fromJournal: true,
        :final dependencies,
      ))
        for (final source in dependencies) source.id,
};

/// The live visibility of the sources the front agent's journal answers
/// cite: reread whenever an entry, a category, a config flag (private mode
/// among them) or lockdown changes, so an answer resting on something that
/// has since become private or been deleted is hidden at once, as query
/// chat hides it. Null while the thread holds no journal answer.
final StreamProvider<QueryAccessSnapshot?> frontJournalAccessProvider =
    StreamProvider.autoDispose<QueryAccessSnapshot?>((ref) async* {
      final ids = frontJournalSourceIds(
        ref.watch(frontChatThreadProvider).value,
      );
      if (ids.isEmpty) {
        yield null;
        return;
      }
      final access = ref.watch(querySourceAccessProvider);
      final journal = ref.watch(journalDbProvider);
      // A lockdown change rebuilds the provider, which rereads.
      ref.watch(lockdownControllerProvider);
      final changes = journal.tableUpdates(
        TableUpdateQuery.onAllTables([
          journal.journal,
          journal.categoryDefinitions,
          journal.configFlags,
        ]),
      );
      // Subscribed before the first read, so a change that lands while a
      // read runs is held and read again, never lost.
      await for (final _ in changes.startWith(const {})) {
        // A failed read is reported, and the next change tries again.
        try {
          yield await access.load(ids);
        } on Exception catch (error, stack) {
          yield* Stream<QueryAccessSnapshot?>.error(error, stack);
        }
      }
    }, name: 'frontJournalAccessProvider');
