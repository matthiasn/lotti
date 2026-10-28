import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/database/history_db.dart';
import 'package:lotti/features/history/domain/history_entry.dart';
import 'package:lotti/features/history/domain/history_filter.dart';
import 'package:lotti/features/history/state/history_title_resolver.dart';

/// One page of history, newest first, and where the next one starts.
@immutable
class HistoryPage {
  const HistoryPage({required this.items, required this.nextBeforeId});

  final List<ResolvedHistoryEntry> items;

  /// The row id the next page reads below, or null once the log (as the
  /// filter sees it) is exhausted.
  final int? nextBeforeId;

  bool get hasMore => nextBeforeId != null;
}

/// Records visits and reads them back a page at a time.
///
/// The log is append-only: [record] adds a row, [delete] removes one for
/// good, nothing rewrites one.
class HistoryService {
  HistoryService({
    required this._db,
    required HistoryTitleResolver titleResolver,
  }) : _titles = titleResolver;

  /// Rows per page of the history page's infinite scroll.
  static const pageSize = 20;

  /// Rows read per round while a search query is set. A query matches on
  /// current titles, which live in the journal, so matching rows are found by
  /// reading the log in batches and filtering each one.
  @visibleForTesting
  static const searchBatchSize = 100;

  final HistoryDb _db;
  final HistoryTitleResolver _titles;

  /// The record most recently queued, so two visits reported in the same
  /// frame — the route and the desktop selection both moving — compare
  /// against each other instead of both against the same older row.
  Future<bool> _recordTail = Future<bool>.value(false);

  /// Appends a visit to [target], stamped now, unless the newest row already
  /// is a visit to the same entity: re-opening what is on screen, or
  /// reaching it through a second route, is not a new visit. Returns whether
  /// a row was written.
  Future<bool> record(HistoryTarget target) {
    final next = _recordTail.then((_) async {
      final latest = await _db.latestEntry();
      if (latest != null &&
          latest.kind == target.kind.name &&
          latest.entityId == target.entityId) {
        return false;
      }
      await _db.appendEntry(
        kind: target.kind.name,
        entityId: target.entityId,
        route: target.route,
        visitedAt: clock.now(),
      );
      return true;
    });
    // A failed write must not wedge every later one behind it.
    _recordTail = next.catchError((_) => false);
    return next;
  }

  /// Up to [limit] visits matching [filter], newest first, below the row
  /// [beforeId] when given.
  ///
  /// Without a query, one read of the window does. With one, the log is read
  /// in [searchBatchSize] batches until [limit] titles match or it runs out;
  /// a visit to an entity that no longer exists has no title, so it matches
  /// no query.
  Future<HistoryPage> page(
    HistoryFilter filter, {
    int? beforeId,
    int limit = pageSize,
  }) async {
    final bounds = filter.bounds(clock.now());
    final batchSize = filter.hasQuery ? searchBatchSize : limit;
    final items = <ResolvedHistoryEntry>[];
    var cursor = beforeId;

    while (true) {
      final rows = await _db.entriesPage(
        limit: batchSize,
        beforeId: cursor,
        from: bounds.from,
        to: bounds.to,
      );
      final entries = rows.map(HistoryEntry.fromRow).nonNulls.toList();
      final titles = await _titles.currentTitles(
        entries.map((entry) => entry.target),
      );
      for (final row in rows) {
        cursor = row.id;
        final entry = HistoryEntry.fromRow(row);
        if (entry == null) continue;
        final title = titles[historyEntityKeyOf(entry.target)];
        if (filter.hasQuery && (title == null || !filter.matchesTitle(title))) {
          continue;
        }
        items.add(ResolvedHistoryEntry(entry: entry, title: title));
        if (items.length == limit) {
          return HistoryPage(items: items, nextBeforeId: row.id);
        }
      }
      if (rows.length < batchSize) {
        return HistoryPage(items: items, nextBeforeId: null);
      }
    }
  }

  /// Removes the visit [id] permanently.
  Future<void> delete(int id) async {
    await _db.deleteEntry(id);
  }
}
