import 'package:flutter/foundation.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/file_utils.dart';

/// Records content-free FTUE funnel events and derives the funnel state from
/// the append-only [OnboardingMetricsDb].
///
/// All time-dependent inputs (clock, id generator, platform) are injected so
/// recording is deterministic and unit-testable without `DateTime.now()`.
class OnboardingMetricsRepository {
  OnboardingMetricsRepository({
    required this._db,
    DateTime Function()? clock,
    String Function()? idGenerator,
    String Function()? currentPlatform,
    Future<bool> Function()? hasExistingUserData,
    this._logger,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? (() => uuid.v1()),
       _currentPlatform = currentPlatform ?? _defaultPlatformName,
       _hasExistingUserData = hasExistingUserData ?? (() async => false);

  final OnboardingMetricsDb _db;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final String Function() _currentPlatform;
  final Future<bool> Function() _hasExistingUserData;
  final DomainLogger? _logger;

  static String _defaultPlatformName() => defaultTargetPlatform.name;

  /// Appends one content-free funnel event.
  ///
  /// [provider], [reason], and [valueBucket] are the only payload, and must be
  /// low-cardinality, already-bucketed, non-user-text values.
  Future<void> recordEvent(
    OnboardingEventName name, {
    String? provider,
    String? reason,
    int? valueBucket,
  }) async {
    final now = _clock().toUtc();
    await _db.insertOnboardingEvent(
      id: _idGenerator(),
      eventName: name.wireName,
      createdAt: now,
      dayBucket: onboardingDayBucket(now),
      platform: _currentPlatform(),
      provider: provider,
      reason: reason,
      valueBucket: valueBucket,
    );
    _logger?.log(
      LogDomain.onboarding,
      [
        name.wireName,
        if (provider != null) 'provider=$provider',
        if (reason != null) 'reason=$reason',
        if (valueBucket != null) 'bucket=$valueBucket',
      ].join(' '),
      subDomain: 'funnel',
    );
  }

  /// Records [OnboardingEventName.appFirstSeen] exactly once, ever.
  ///
  /// Pre-existing users upgrading into the FTUE build are tagged so they can be
  /// excluded from the activated cohort and treated as the pre-FTUE baseline.
  Future<void> recordAppFirstSeenIfAbsent() async {
    final existing = await _db.firstSeen(
      OnboardingEventName.appFirstSeen.wireName,
    );
    if (existing != null) return;
    final hadData = await _hasExistingUserData();
    await recordEvent(
      OnboardingEventName.appFirstSeen,
      reason: hadData
          ? onboardingExistingUserReason
          : onboardingNewInstallReason,
    );
  }

  /// Computes the derived general FTUE funnel state from the event log.
  ///
  /// Only events belonging to the general FTUE vocabulary contribute: Daily OS
  /// onboarding events (and any unknown/future names) are partitioned out so
  /// they never shift the FTUE active-day or activation metrics. See
  /// [dailyOsOnboardingFunnelState] for the Daily OS projection.
  Future<OnboardingFunnelState> funnelState() async {
    final events = await _db.getAllEvents();
    if (events.isEmpty) return const OnboardingFunnelState.empty();

    final counts = <String, int>{};
    final days = <int>{};
    DateTime? installFirstSeen;
    var existingUser = false;

    for (final event in events) {
      final name = OnboardingEventName.fromWireName(event.eventName);
      // Skip Daily OS onboarding events and unknown/future names: neither is
      // part of the general FTUE funnel.
      if (name == null || name.isDailyOsOnboarding) continue;
      counts.update(event.eventName, (v) => v + 1, ifAbsent: () => 1);
      days.add(event.dayBucket);
      if (name == OnboardingEventName.appFirstSeen) {
        if (installFirstSeen == null ||
            event.createdAt.isBefore(installFirstSeen)) {
          installFirstSeen = event.createdAt;
        }
        if (event.reason == onboardingExistingUserReason) existingUser = true;
      }
    }

    final isBaseline =
        existingUser ||
        (installFirstSeen != null &&
            onboardingDayBucket(installFirstSeen) < kFtueReleaseDayBucketUtc);

    return OnboardingFunnelState(
      installFirstSeen: installFirstSeen,
      activeDayBuckets: days.toList()..sort(),
      isBaselineCohort: isBaseline,
      eventCounts: counts,
    );
  }

  /// Computes the derived Daily OS onboarding funnel state from the same event
  /// log, partitioned to the Daily OS onboarding vocabulary. Events from the
  /// general FTUE (and unknown names) do not contribute.
  Future<DailyOsOnboardingFunnelState> dailyOsOnboardingFunnelState() async {
    final events = await _db.getAllEvents();
    if (events.isEmpty) return const DailyOsOnboardingFunnelState.empty();

    final counts = <String, int>{};
    final days = <int>{};

    for (final event in events) {
      final name = OnboardingEventName.fromWireName(event.eventName);
      if (name == null || !name.isDailyOsOnboarding) continue;
      counts.update(event.eventName, (v) => v + 1, ifAbsent: () => 1);
      days.add(event.dayBucket);
    }

    return DailyOsOnboardingFunnelState(
      activeDayBuckets: days.toList()..sort(),
      eventCounts: counts,
    );
  }
}
