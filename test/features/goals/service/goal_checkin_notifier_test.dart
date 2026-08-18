import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/service/goal_checkin_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockGoalRepository goals;
  late MockAgentService agents;
  late StreamController<Set<String>> updates;
  late MockUpdateNotifications notifications;
  late GoalCheckInNotifier notifier;

  setUp(() {
    goals = MockGoalRepository();
    agents = MockAgentService();
    updates = StreamController<Set<String>>.broadcast();
    notifications = MockUpdateNotifications();

    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    when(() => goals.goalIdForAgent('agent-1')).thenReturn('goal-1');
    when(() => goals.goalIdForAgent('agent-2')).thenReturn('goal-2');
    when(() => agents.markReportStale(any())).thenAnswer((_) async {});

    notifier = GoalCheckInNotifier(
      goalRepository: goals,
      agentService: agents,
      updateNotifications: notifications,
    );
  });

  tearDown(() {
    notifier.stop();
    updates.close();
  });

  Future<void> emit(Set<String> ids) async {
    updates.add(ids);
    await Future<void>.delayed(Duration.zero);
  }

  test('a check-in marks its goal stale, not the others', () async {
    notifier.start(['agent-1', 'agent-2']);

    await emit({'goal-1'});

    // Stale, never a wake: three check-ins in a morning would otherwise be
    // three inference runs.
    verify(() => agents.markReportStale('agent-1')).called(1);
    verifyNever(() => agents.markReportStale('agent-2'));
  });

  test('an unrelated journal write wakes nothing', () async {
    notifier.start(['agent-1']);

    await emit({'some-other-entry', 'TASK'});

    verifyNever(() => agents.markReportStale(any()));
  });

  test('several goals touched at once are each marked', () async {
    notifier.start(['agent-1', 'agent-2']);

    await emit({'goal-1', 'goal-2'});

    verify(() => agents.markReportStale('agent-1')).called(1);
    verify(() => agents.markReportStale('agent-2')).called(1);
  });

  test('one goal failing to be marked does not silence the others', () async {
    when(
      () => agents.markReportStale('agent-1'),
    ).thenThrow(Exception('agent store is unavailable'));
    notifier.start(['agent-1', 'agent-2']);

    await emit({'goal-1', 'goal-2'});

    // A missed mark is recovered by the next check-in or the cadence; taking
    // the other goals down with it is not.
    verify(() => agents.markReportStale('agent-2')).called(1);
  });

  test('watching no goals subscribes to nothing', () async {
    notifier.start(const []);

    await emit({'goal-1'});

    verifyNever(() => agents.markReportStale(any()));
  });

  test('restarting replaces the previous watch rather than stacking', () async {
    notifier
      ..start(['agent-1'])
      ..start(['agent-1']);

    await emit({'goal-1'});

    // Two live subscriptions would mark the report stale twice per check-in.
    verify(() => agents.markReportStale('agent-1')).called(1);
  });

  test(
    'a goal created mid-session is watched from its first check-in',
    () async {
      // Without this the watch was a startup snapshot: a goal created while
      // the app stayed open produced check-ins that marked nothing until
      // relaunch.
      notifier
        ..start(['agent-1'])
        ..watch('agent-2');
      await emit({'goal-2'});

      verify(() => agents.markReportStale('agent-2')).called(1);
    },
  );

  test('watching before any start still listens', () async {
    notifier.watch('agent-1');

    await emit({'goal-1'});

    verify(() => agents.markReportStale('agent-1')).called(1);
  });

  test('a goal that goes dormant stops being watched', () async {
    notifier
      ..start(['agent-1', 'agent-2'])
      ..unwatch('agent-1');

    await emit({'goal-1', 'goal-2'});

    verifyNever(() => agents.markReportStale('agent-1'));
    verify(() => agents.markReportStale('agent-2')).called(1);
  });

  test('stopping ends the watch', () async {
    notifier
      ..start(['agent-1'])
      ..stop();

    await emit({'goal-1'});

    verifyNever(() => agents.markReportStale(any()));
  });
}
