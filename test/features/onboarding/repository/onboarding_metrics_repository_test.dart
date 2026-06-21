// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';

void main() {
  late OnboardingMetricsDb db;
  var idSeq = 0;

  OnboardingMetricsRepository makeRepo({
    DateTime Function()? clock,
    Future<bool> Function()? hasExistingUserData,
  }) {
    return OnboardingMetricsRepository(
      db: db,
      clock: clock ?? () => DateTime.utc(2026, 7, 1, 12),
      idGenerator: () => 'id-${idSeq++}',
      currentPlatform: () => 'testos',
      hasExistingUserData: hasExistingUserData ?? () async => false,
    );
  }

  setUp(() {
    idSeq = 0;
    db = OnboardingMetricsDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
  });

  test('recordEvent writes a content-free row with derived bucket', () async {
    final at = DateTime.utc(2026, 7, 1, 12);
    await makeRepo(
      clock: () => at,
    ).recordEvent(OnboardingEventName.providerConnected, provider: 'gemini');

    final row = (await db.getAllEvents()).single;
    expect(row.eventName, OnboardingEventName.providerConnected.wireName);
    expect(row.provider, 'gemini');
    expect(row.platform, 'testos');
    expect(row.dayBucket, onboardingDayBucket(at));
    expect(row.createdAt.isAtSameMomentAs(at), isTrue);
  });

  test('recordAppFirstSeenIfAbsent records exactly once', () async {
    final repo = makeRepo();
    await repo.recordAppFirstSeenIfAbsent();
    await repo.recordAppFirstSeenIfAbsent();

    final firstSeenRows = (await db.getAllEvents()).where(
      (e) => e.eventName == OnboardingEventName.appFirstSeen.wireName,
    );
    expect(firstSeenRows, hasLength(1));
  });

  test('appFirstSeen tags a brand-new install', () async {
    await makeRepo(
      hasExistingUserData: () async => false,
    ).recordAppFirstSeenIfAbsent();
    expect((await db.getAllEvents()).single.reason, onboardingNewInstallReason);
  });

  test('appFirstSeen tags a pre-existing user', () async {
    await makeRepo(
      hasExistingUserData: () async => true,
    ).recordAppFirstSeenIfAbsent();
    expect(
      (await db.getAllEvents()).single.reason,
      onboardingExistingUserReason,
    );
  });

  test(
    'funnelState derives install date, active days, counts, flags',
    () async {
      final day0 = DateTime.utc(2026, 7, 1, 9);
      final day1 = DateTime.utc(2026, 7, 2, 9);
      final r0 = makeRepo(clock: () => day0);
      await r0.recordAppFirstSeenIfAbsent();
      await r0.recordEvent(OnboardingEventName.firstAudioCaptured);
      await r0.recordEvent(OnboardingEventName.realAha);
      await makeRepo(
        clock: () => day1,
      ).recordEvent(OnboardingEventName.returnSession);

      final state = await makeRepo().funnelState();
      expect(state.installFirstSeen, isNotNull);
      expect(state.installFirstSeen!.isAtSameMomentAs(day0), isTrue);
      expect(state.activeDaysCount, 2);
      expect(state.activeDaysInFirst7, 2);
      expect(state.capturedAudio, isTrue);
      expect(state.reachedRealAha, isTrue);
      expect(state.countOf(OnboardingEventName.realAha), 1);
      // Installed after the FTUE release and not pre-existing → not baseline.
      expect(state.isBaselineCohort, isFalse);
    },
  );

  test('funnelState marks pre-existing users as baseline cohort', () async {
    await makeRepo(
      hasExistingUserData: () async => true,
    ).recordAppFirstSeenIfAbsent();
    expect((await makeRepo().funnelState()).isBaselineCohort, isTrue);
  });

  test(
    'funnelState marks installs predating the FTUE release as baseline',
    () async {
      await makeRepo(
        clock: () => DateTime.utc(2026, 6, 1),
      ).recordAppFirstSeenIfAbsent();
      expect((await makeRepo().funnelState()).isBaselineCohort, isTrue);
    },
  );

  test('funnelState is empty before any events', () async {
    final state = await makeRepo().funnelState();
    expect(state.installFirstSeen, isNull);
    expect(state.activeDaysCount, 0);
    expect(state.activeDaysInFirst7, 0);
    expect(state.isBaselineCohort, isFalse);
    expect(state.reachedRealAha, isFalse);
  });
}
