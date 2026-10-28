import 'package:flutter/foundation.dart';

/// The time window the history page shows.
enum HistoryTimeRange { last7Days, last30Days, last90Days, allTime, custom }

/// What the history page filters by: a title query and a time window.
///
/// Pure, so the paging logic and the page can share it and tests can pin it
/// without a database.
@immutable
class HistoryFilter {
  const HistoryFilter({
    this.query = '',
    this.range = HistoryTimeRange.allTime,
    this.customStart,
    this.customEnd,
  });

  /// The raw text in the search field.
  final String query;
  final HistoryTimeRange range;

  /// The first and last calendar day of a [HistoryTimeRange.custom] window,
  /// both included. Ignored by every other range.
  final DateTime? customStart;
  final DateTime? customEnd;

  /// The lower-cased terms of [query]. Every one must occur in a title for it
  /// to match, in any order — "fix bug" finds "Bug fix for login".
  List<String> get terms => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);

  bool get hasQuery => terms.isNotEmpty;

  /// Whether [title] — the entity's current title — passes the query.
  bool matchesTitle(String title) {
    final queryTerms = terms;
    if (queryTerms.isEmpty) return true;
    final folded = title.toLowerCase();
    return queryTerms.every(folded.contains);
  }

  /// The window as `[from, to)` against [now], either end open (null).
  ///
  /// The "last N days" windows count today as one of the N and start at a
  /// local midnight, built from date components so a DST change in between
  /// moves neither end.
  ({DateTime? from, DateTime? to}) bounds(DateTime now) {
    DateTime daysBack(int days) =>
        DateTime(now.year, now.month, now.day - (days - 1));

    return switch (range) {
      HistoryTimeRange.last7Days => (from: daysBack(7), to: null),
      HistoryTimeRange.last30Days => (from: daysBack(30), to: null),
      HistoryTimeRange.last90Days => (from: daysBack(90), to: null),
      HistoryTimeRange.allTime => (from: null, to: null),
      HistoryTimeRange.custom => (
        from: switch (customStart) {
          final start? => DateTime(start.year, start.month, start.day),
          null => null,
        },
        to: switch (customEnd) {
          final end? => DateTime(end.year, end.month, end.day + 1),
          null => null,
        },
      ),
    };
  }

  HistoryFilter copyWith({
    String? query,
    HistoryTimeRange? range,
    DateTime? customStart,
    DateTime? customEnd,
  }) => HistoryFilter(
    query: query ?? this.query,
    range: range ?? this.range,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
  );

  @override
  bool operator ==(Object other) =>
      other is HistoryFilter &&
      other.query == query &&
      other.range == range &&
      other.customStart == customStart &&
      other.customEnd == customEnd;

  @override
  int get hashCode => Object.hash(query, range, customStart, customEnd);
}
