import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/query/query_chat_store.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

/// Real agent persistence and sync wrapper, with the shared fake journal
/// corpus and centrally maintained infrastructure mocks at the boundaries.
class QueryPersistenceBench extends QueryTestBench {
  QueryPersistenceBench() {
    repository = AgentRepository(agentDb);
    final vc = MockVectorClockService();
    when(vc.getHost).thenAnswer((_) async => 'device');
    when(
      () => vc.getNextVectorClock(previous: any(named: 'previous')),
    ).thenAnswer((_) async => const VectorClock({'device': 1}));
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    store = QueryChatStore(
      sync: AgentSyncService(
        repository: repository,
        outboxService: outbox,
        vectorClockService: vc,
      ),
      access: crawler.access,
    );
  }
  final agentDb = AgentDatabase(inMemoryDatabase: true, background: false);
  final outbox = MockOutboxService();
  late final AgentRepository repository;
  late final QueryChatStore store;
  Future<void> close() => agentDb.close();
}

class QueryTestBench {
  QueryTestBench() {
    when(() => db.getTaskIdsForProjects(any())).thenAnswer((call) async {
      final projects = call.positionalArguments.first as Set<String>;
      return taskProjects.entries
          .where((entry) => projects.contains(entry.value))
          .map((entry) => entry.key)
          .toSet();
    });
    when(() => db.getProjectIdMapForTasks(any())).thenAnswer(
      (call) async => {
        for (final id in call.positionalArguments.first as Set<String>)
          if (taskProjects.containsKey(id)) id: taskProjects[id]!,
      },
    );
    when(
      () => db.getConfigFlag('private'),
    ).thenAnswer((_) async => showPrivate);
    when(db.getAllCategories).thenAnswer((_) async => categories);
    when(() => db.journalEntityMapForIdsIncludingDeleted(any())).thenAnswer((
      call,
    ) async {
      final ids = call.positionalArguments.first as Iterable<String>;
      return {
        for (final id in ids) id: ?entries[id],
      };
    });
    when(() => db.linksForEntryIdsBidirectional(any())).thenAnswer((
      call,
    ) async {
      final ids = call.positionalArguments.first as Set<String>;
      return links
          .where((l) => ids.contains(l.fromId) || ids.contains(l.toId))
          .toList();
    });
    when(
      () => db.getJournalEntities(
        types: any(named: 'types'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        ids: any(named: 'ids'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((call) async {
      categoryReads++;
      final categories = call.namedArguments[#categoryIds] as Set<String>;
      final ids = call.namedArguments[#ids] as List<String>?;
      return entries.values
          .where(
            (e) =>
                categories.contains(e.meta.categoryId) &&
                (ids == null || ids.contains(e.meta.id)),
          )
          .take(call.namedArguments[#limit] as int)
          .toList();
    });
  }

  final db = MockJournalDb();
  final entries = <String, JournalEntity>{};
  final links = <EntryLink>[];
  final taskProjects = <String, String>{};
  final categories = <CategoryDefinition>[categoryMindfulness];
  final searches = <String>[];
  bool showPrivate = false;
  int categoryReads = 0;

  QueryJournalCrawler get crawler => QueryJournalCrawler(
    journal: db,
    access: QuerySourceAccess(
      journal: db,
      readLockdown: () => LockdownState.inactive,
    ),
    search: (query) async {
      searches.add(query);
      return entries.keys.toList();
    },
  );

  void add(String id, {String? category, bool private = false}) {
    entries[id] = testTextEntry.copyWith(
      meta: testTextEntry.meta.copyWith(
        id: id,
        categoryId: category,
        private: private,
      ),
      entryText: EntryText(plainText: 'Feeder decision in $id.'),
    );
  }

  void link(String from, String to, {bool hidden = false}) {
    links.add(
      EntryLink.basic(
        id: '$from-$to',
        fromId: from,
        toId: to,
        createdAt: DateTime(2026, 7, 17),
        updatedAt: DateTime(2026, 7, 17),
        vectorClock: null,
        hidden: hidden,
      ),
    );
  }
}
