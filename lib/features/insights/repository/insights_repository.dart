import 'package:lotti/database/database.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

/// Data access for the Insights time-analysis dashboard.
///
/// Thin mapping layer over [JournalDb.insightsTimeRows] — all aggregation
/// happens in the pure bucketing logic so it stays property-testable.
class InsightsRepository {
  const InsightsRepository(this._db);

  final JournalDb _db;

  /// Fetches slim time rows overlapping `[start, end)`, mapped to the
  /// feature model. Rows arrive with local `DateTime`s (Drift converts
  /// from the epoch-seconds storage).
  Future<List<InsightsTimeRow>> fetchTimeRows({
    required DateTime start,
    required DateTime end,
  }) async {
    final records = await _db.insightsTimeRows(start: start, end: end);
    return [
      for (final record in records)
        InsightsTimeRow(
          dateFrom: record.dateFrom,
          dateTo: record.dateTo,
          categoryId: record.categoryId,
        ),
    ];
  }
}
