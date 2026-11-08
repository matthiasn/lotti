import 'package:lotti/database/database.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/utils/day_agent_capture_helpers.dart';

/// The time logged in [range] that [categoryIds] lets her see (empty for
/// every category), bucketed per day and category, with the names of the
/// categories she may see and the time entries summed, by entry id. The
/// Insights page's read and bucketing, so her answer and her chart show the
/// numbers that page shows: private entries only while they are shown, a
/// task's time in the task's category, overlapping entries in one category
/// counted once. Time in a private category is left out while private
/// entries are hidden — an entry need not be private itself to sit in one —
/// and time in no category whenever the scope is narrowed.
///
/// With [namedCategoryIds] — the categories the user named — every other
/// category's time, and time in none, is keyed [kInsightsOtherCategoryKey]
/// instead: one unnamed slice, so naming one category never names the rest.
Future<
  ({
    InsightsDayBuckets buckets,
    Map<String, String> names,
    List<({String entryId, InsightsTimeRow row})> entries,
  })
>
readFrontLoggedTime(
  JournalDb journalDb,
  InsightsRange range,
  Set<String> categoryIds, {
  Set<String> namedCategoryIds = const {},
}) async {
  final records = await journalDb.insightsTimeRows(
    start: dayStart(range.startDay),
    end: dayStart(range.endDayExclusive),
  );
  // Private categories are dropped from this read while hidden.
  final names = {
    for (final category in await journalDb.getAllCategories())
      category.id: category.name,
  };
  final hidden = {
    for (final category in await journalDb.getAllCategoriesIncludingPrivate())
      if (!names.containsKey(category.id)) category.id,
  };
  // Folded per entry, so overlapping time across the others counts once.
  String? keyFor(String? id) =>
      namedCategoryIds.isEmpty || namedCategoryIds.contains(id)
      ? id
      : kInsightsOtherCategoryKey;
  final entries = [
    for (final record in records)
      if (categoryAllowed(record.categoryId, categoryIds) &&
          !hidden.contains(record.categoryId))
        (
          entryId: record.entryId,
          row: InsightsTimeRow(
            dateFrom: record.dateFrom,
            dateTo: record.dateTo,
            categoryId: keyFor(record.categoryId),
          ),
        ),
  ];
  final buckets = bucketize(
    [for (final entry in entries) entry.row],
    windowStartDay: range.startDay,
  );
  return (buckets: buckets, names: names, entries: entries);
}
