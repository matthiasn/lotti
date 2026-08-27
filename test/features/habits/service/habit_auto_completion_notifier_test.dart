import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/service/habit_auto_completion_notifier.dart';
import 'package:lotti/features/habits/service/habit_auto_completion_service.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../logic/signals/signal_test_fixtures.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockHabitAutoCompletionService service;
  late MockNotificationRepository notifications;
  late MockDomainLogger logger;
  late StreamController<HabitAutoCompletion> completions;
  late HabitAutoCompletionNotifier notifier;

  // Saturday 2026-08-08.
  final now = DateTime(2026, 8, 8, 14, 30);
  final todayKey = DateTime.utc(2026, 8, 8);
  final yesterdayKey = DateTime.utc(2026, 8, 7);

  HabitAutoCompletion completion({
    required String id,
    required String name,
    String reason = 'Steps · 7412',
    DateTime? day,
    bool notify = true,
  }) {
    final habit = habitFlossing.copyWith(
      id: id,
      name: name,
      autoCompleteNotify: notify,
    );
    final data = HabitCompletionData(
      dateFrom: now,
      dateTo: now,
      habitId: id,
      completionType: HabitCompletionType.success,
      source: HabitCompletionSource.auto,
      autoCompleteReason: reason,
    );
    return HabitAutoCompletion(
      habit: habit,
      entry:
          JournalEntity.habitCompletion(
                meta: signalMeta(now, id: 'entry-$id'),
                data: data,
              )
              as HabitCompletionEntry,
      day: day ?? todayKey,
      verdict: const HabitRuleVerdict(satisfied: true, leaves: []),
    );
  }

  setUp(() {
    service = MockHabitAutoCompletionService();
    notifications = MockNotificationRepository();
    logger = MockDomainLogger();
    completions = StreamController<HabitAutoCompletion>.broadcast();
    when(() => service.completions).thenAnswer((_) => completions.stream);
    when(
      () => notifications.createHabitAutoCompletion(
        linkedHabitIds: any(named: 'linkedHabitIds'),
        dayKey: any(named: 'dayKey'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => null);
    notifier = HabitAutoCompletionNotifier(
      service: service,
      notifications: notifications,
      logger: logger,
      messages: AppLocalizationsEn.new,
    );
  });

  tearDown(() async {
    notifier.dispose();
    await completions.close();
  });

  void run(void Function(FakeAsync async) body) {
    withClock(Clock.fixed(now), () {
      fakeAsync((async) {
        notifier.start();
        body(async);
        async.flushMicrotasks();
      }, initialTime: now);
    });
  }

  /// Every row written so far, in write order. Captures once: mocktail's
  /// `verify` consumes matched calls, so reading twice would see nothing.
  List<({List<String> habitIds, String dayKey, String title, String body})>
  rows() {
    final captured = verify(
      () => notifications.createHabitAutoCompletion(
        linkedHabitIds: captureAny(named: 'linkedHabitIds'),
        dayKey: captureAny(named: 'dayKey'),
        title: captureAny(named: 'title'),
        body: captureAny(named: 'body'),
      ),
    ).captured;
    return [
      for (var i = 0; i < captured.length; i += 4)
        (
          habitIds: captured[i] as List<String>,
          dayKey: captured[i + 1] as String,
          title: captured[i + 2] as String,
          body: captured[i + 3] as String,
        ),
    ];
  }

  test('one completion becomes one row naming the habit and the signal', () {
    run((async) {
      completions.add(completion(id: 'walk', name: 'Walk'));
      async.elapse(const Duration(seconds: 4));
    });
    final row = rows().single;
    expect(row.habitIds, ['walk']);
    expect(row.dayKey, '2026-08-08');
    expect(row.title, '✓ Walk done');
    expect(row.body, 'Checked off automatically from Steps · 7412.');
  });

  test('completions inside the grouping window share one row', () {
    run((async) {
      completions.add(completion(id: 'walk', name: 'Walk'));
      async.elapse(const Duration(seconds: 1));
      completions.add(completion(id: 'water', name: 'Drink water'));
      async.elapse(const Duration(seconds: 1));
      completions.add(completion(id: 'meds', name: 'Take medication'));
      async.elapse(const Duration(seconds: 4));
    });
    final row = rows().single;
    expect(row.habitIds, ['walk', 'water', 'meds']);
    expect(row.title, '3 habits checked off automatically');
    expect(row.body, 'Walk, Drink water, Take medication');
  });

  test('the window is measured from the first completion, not the last', () {
    run((async) {
      completions.add(completion(id: 'walk', name: 'Walk'));
      async.elapse(const Duration(milliseconds: 2500));
      completions.add(completion(id: 'water', name: 'Drink water'));
      async.elapse(const Duration(milliseconds: 600));
      // 3.1 s after the first: flushed as one row of two.
      expect(rows().single.habitIds, ['walk', 'water']);
      completions.add(completion(id: 'meds', name: 'Take medication'));
      async.elapse(const Duration(seconds: 4));
    });
    expect(rows().single.habitIds, ['meds']);
  });

  test('a habit with notifications off is not announced', () {
    run((async) {
      completions
        ..add(completion(id: 'quiet', name: 'Quiet', notify: false))
        ..add(completion(id: 'walk', name: 'Walk'));
      async.elapse(const Duration(seconds: 4));
    });
    expect(rows().single.habitIds, ['walk']);
  });

  test('a late completion for yesterday says which day it counted for', () {
    run((async) {
      completions.add(
        completion(id: 'walk', name: 'Walk', day: yesterdayKey),
      );
      async.elapse(const Duration(seconds: 4));
    });
    final row = rows().single;
    expect(row.dayKey, '2026-08-07');
    expect(row.title, '✓ Walk done');
    expect(row.body, 'Steps · 7412 imported late; counted for Friday.');
  });

  test('completions for different days become separate rows', () {
    run((async) {
      completions
        ..add(completion(id: 'walk', name: 'Walk', day: yesterdayKey))
        ..add(completion(id: 'water', name: 'Drink water'));
      async.elapse(const Duration(seconds: 4));
    });
    final all = rows();
    expect(all, hasLength(2));
    expect(all.map((row) => row.dayKey).toSet(), {'2026-08-07', '2026-08-08'});
    expect(all.map((row) => row.habitIds.single).toSet(), {'walk', 'water'});
  });

  test('a batch whose write failed is retried, not lost', () {
    var calls = 0;
    when(
      () => notifications.createHabitAutoCompletion(
        linkedHabitIds: any(named: 'linkedHabitIds'),
        dayKey: any(named: 'dayKey'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw StateError('inbox busy');
      return null;
    });
    run((async) {
      completions.add(completion(id: 'walk', name: 'Walk'));
      async.elapse(const Duration(seconds: 8));
    });
    final all = rows();
    expect(all, hasLength(2));
    expect(all.last.habitIds, ['walk']);
  });

  test('a batch that keeps failing is dropped after the attempt cap', () {
    when(
      () => notifications.createHabitAutoCompletion(
        linkedHabitIds: any(named: 'linkedHabitIds'),
        dayKey: any(named: 'dayKey'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenThrow(StateError('inbox gone'));
    run((async) {
      completions.add(completion(id: 'walk', name: 'Walk'));
      async.elapse(const Duration(minutes: 5));
    });
    expect(rows(), hasLength(HabitAutoCompletionNotifier.maxWriteAttempts));
  });

  test('a failing write is logged and does not block the next batch', () {
    when(
      () => notifications.createHabitAutoCompletion(
        linkedHabitIds: any(named: 'linkedHabitIds'),
        dayKey: any(named: 'dayKey'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenThrow(StateError('inbox closed'));
    run((async) {
      completions.add(completion(id: 'walk', name: 'Walk'));
      async.elapse(const Duration(seconds: 4));
      verify(
        () => logger.error(
          any(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'autoCompletion.notify',
        ),
      ).called(1);
      when(
        () => notifications.createHabitAutoCompletion(
          linkedHabitIds: any(named: 'linkedHabitIds'),
          dayKey: any(named: 'dayKey'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => null);
      completions.add(completion(id: 'water', name: 'Drink water'));
      async.elapse(const Duration(seconds: 4));
    });
    // The throwing call is recorded; the retried walk completion then rides
    // along with the water batch, so nothing is lost.
    expect(rows().expand((row) => row.habitIds).toSet(), {'walk', 'water'});
  });

  test('nothing pending is written after dispose', () {
    run((async) {
      completions.add(completion(id: 'walk', name: 'Walk'));
      notifier.dispose();
      async.elapse(const Duration(seconds: 4));
    });
    verifyNever(
      () => notifications.createHabitAutoCompletion(
        linkedHabitIds: any(named: 'linkedHabitIds'),
        dayKey: any(named: 'dayKey'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    );
  });
}
