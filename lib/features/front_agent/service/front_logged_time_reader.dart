import 'package:lotti/database/database.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/repository/insights_repository.dart';
import 'package:lotti/utils/day_agent_capture_helpers.dart';

/// The time logged in [range] that [categoryIds] lets her see (empty for
/// every category), bucketed per day and category, with the names of the
/// categories she may see. The Insights page's read and bucketing, so her
/// answer and her chart show the numbers that page shows: private entries
/// only while they are shown, a task's time in the task's category,
/// overlapping entries in one category counted once. Time in a private
/// category is left out while private entries are hidden — an entry need
/// not be private itself to sit in one — and time in no category whenever
/// the scope is narrowed.
Future<({InsightsDayBuckets buckets, Map<String, String> names})>
readFrontLoggedTime(
  JournalDb journalDb,
  InsightsRange range,
  Set<String> categoryIds,
) async {
  final rows = await InsightsRepository(journalDb).fetchTimeRows(
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
  final buckets = bucketize(
    [
      for (final row in rows)
        if (categoryAllowed(row.categoryId, categoryIds) &&
            !hidden.contains(row.categoryId))
          row,
    ],
    windowStartDay: range.startDay,
  );
  return (buckets: buckets, names: names);
}
