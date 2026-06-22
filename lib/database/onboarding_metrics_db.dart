import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';

part 'onboarding_metrics_db.g.dart';

const onboardingMetricsDbFileName = 'onboarding_metrics.sqlite';

/// Dedicated, append-only store for the first-time-user-experience (FTUE)
/// funnel.
///
/// It is intentionally separate from the heavily-shared SettingsDb k/v store:
/// onboarding metrics need indexed, grouped queries and their own migration
/// lifecycle. The event log is the single source of truth; derived funnel
/// state (install date, active days, per-step booleans) is computed from it
/// via the query helpers below rather than persisted in a second table.
///
/// The table is content-free by construction — it only ever records event
/// names, a coarse UTC day bucket, and a small fixed set of low-cardinality
/// dimensions. No transcript, audio, or thought text is ever written here.
@DriftDatabase(include: {'onboarding_metrics_db.drift'})
class OnboardingMetricsDb extends _$OnboardingMetricsDb {
  OnboardingMetricsDb({
    this.inMemoryDatabase = false,
    // Onboarding writes are infrequent and never on a latency-sensitive path,
    // so the default background isolate is fine.
    bool background = true,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
         openDbConnection(
           onboardingMetricsDbFileName,
           inMemoryDatabase: inMemoryDatabase,
           background: background,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  final bool inMemoryDatabase;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(onCreate: (m) => m.createAll());
  }

  /// Appends one content-free event. Caller supplies the id, clock-derived
  /// timestamp, and day bucket so the write stays deterministic and testable.
  Future<void> insertOnboardingEvent({
    required String id,
    required String eventName,
    required DateTime createdAt,
    required int dayBucket,
    String? platform,
    String? provider,
    String? reason,
    int? valueBucket,
  }) async {
    await into(onboardingEvents).insert(
      OnboardingEventRow(
        id: id,
        eventName: eventName,
        createdAt: createdAt,
        dayBucket: dayBucket,
        platform: platform,
        provider: provider,
        reason: reason,
        valueBucket: valueBucket,
      ),
    );
  }

  /// All events in chronological order — used by the debug funnel surface and
  /// for Dart-side derivation of funnel state.
  Future<List<OnboardingEventRow>> getAllEvents() =>
      allOnboardingEvents().get();

  /// Count of events per event name, keyed by name.
  Future<Map<String, int>> eventCounts() async {
    final rows = await countOnboardingEventsByName().get();
    return {for (final row in rows) row.eventName: row.cnt};
  }

  /// Earliest timestamp for [eventName], or null if it never occurred.
  Future<DateTime?> firstSeen(String eventName) =>
      firstOnboardingEventTime(eventName).getSingleOrNull();

  /// Sorted set of distinct UTC day buckets on which any event occurred.
  Future<List<int>> activeDayBuckets() => distinctActiveDayBuckets().get();

  /// Removes every event. Used by the debug "reset" action and test teardown.
  Future<int> clearAll() => delete(onboardingEvents).go();
}
