import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';

/// One current visibility view shared by retrieval, recall and presentation.
/// Entries include deletion tombstones so retaining a quote never loses the
/// source's most recent privacy metadata.
class QueryAccessSnapshot {
  const QueryAccessSnapshot({
    required this.showPrivate,
    required this.categories,
    required this.entries,
    this.lockdown = LockdownState.inactive,
  });

  final bool showPrivate;
  final Map<String, CategoryDefinition> categories;
  final Map<String, JournalEntity> entries;
  final LockdownState lockdown;

  bool allowsCategory(String? id) =>
      lockdown.allows(id) &&
      (id == null ||
          (categories.containsKey(id) &&
              (showPrivate || !categories[id]!.private)));

  bool allowsEntry(JournalEntity entry, {bool allowDeleted = false}) =>
      (allowDeleted || entry.meta.deletedAt == null) &&
      (showPrivate || entry.meta.private != true) &&
      allowsCategory(entry.meta.categoryId);

  /// Unknown sources fail closed. A category move alone does not hide an
  /// otherwise visible historical quote; it only changes its status label.
  bool allowsReference(QuerySourceRef source) {
    final current = entries[source.id];
    return current != null && allowsEntry(current, allowDeleted: true);
  }

  bool allowsContent(
    Iterable<QuerySourceRef> dependencies, {
    required bool private,
  }) => (!private || showPrivate) && dependencies.every(allowsReference);

  bool allowsEvent(QueryChatEventData data) => switch (data) {
    QueryChatCreated(:final private) => !private || showPrivate,
    QueryChatRenamed(:final private) => !private || showPrivate,
    QueryChatQuestion(:final private, :final dependencies) => allowsContent(
      dependencies,
      private: private,
    ),
    QueryChatAnswer(:final private, :final dependencies) => allowsContent(
      dependencies,
      private: private,
    ),
    QueryChatMemory(:final private, :final dependencies) => allowsContent(
      dependencies,
      private: private,
    ),
    _ => true,
  };

  QuerySourceRef reference(JournalEntity entry) => QuerySourceRef(
    id: entry.meta.id,
    categoryId: entry.meta.categoryId,
    private: entry.meta.private ?? false,
    categoryPrivate:
        entry.meta.categoryId != null &&
        categories[entry.meta.categoryId]?.private != false,
  );
}

class QuerySourceAccess {
  const QuerySourceAccess({
    required this.journal,
    required this.readLockdown,
  });

  final JournalDb journal;
  final LockdownState Function() readLockdown;

  /// Refresh immediately before each model call and before publishing a reply.
  /// No prompt, source text or user content is written to diagnostic logs.
  Future<QueryAccessSnapshot> load(Iterable<String> sourceIds) async {
    final categories = await journal.getAllCategories();
    final entries = await journal.journalEntityMapForIdsIncludingDeleted(
      sourceIds,
    );
    return QueryAccessSnapshot(
      showPrivate: await journal.getConfigFlag('private'),
      categories: {for (final category in categories) category.id: category},
      entries: entries,
      lockdown: readLockdown(),
    );
  }
}
