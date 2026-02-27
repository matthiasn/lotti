import 'package:meta/meta.dart';

/// Aggregated outbox volume for a single day.
/// Used to visualize daily sync volume (bytes sent per day).
@immutable
class OutboxDailyVolume {
  const OutboxDailyVolume({
    required this.date,
    required this.totalBytes,
    required this.itemCount,
  });

  /// The date (time portion is midnight UTC).
  final DateTime date;

  /// Total payload bytes sent on this day.
  final int totalBytes;

  /// Number of outbox items sent on this day.
  final int itemCount;

  /// Convenience getter for megabytes.
  double get totalMegabytes => totalBytes / (1024 * 1024);

  @override
  String toString() =>
      'OutboxDailyVolume(date: $date, totalBytes: $totalBytes, '
      'itemCount: $itemCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutboxDailyVolume &&
          date == other.date &&
          totalBytes == other.totalBytes &&
          itemCount == other.itemCount;

  @override
  int get hashCode => Object.hash(date, totalBytes, itemCount);
}
