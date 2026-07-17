import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/ui/pending_wakes/wake_countdown_ticker.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/misc/sidebar_activity_summary.dart';
import 'package:lotti/widgets/misc/sidebar_timer_section.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/agents/test_utils.dart';
import '../../helpers/stub_audio_recorder_controller.dart';
import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTimeService timeService;

  setUp(() async {
    timeService = MockTimeService();
    when(() => timeService.getCurrent()).thenReturn(null);
    when(() => timeService.getStream()).thenAnswer((_) => const Stream.empty());
    when(() => timeService.linkedFrom).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<TimeService>(timeService),
    );
  });

  tearDown(tearDownTestGetIt);

  AudioRecorderState recorderState({
    AudioRecorderStatus status = AudioRecorderStatus.stopped,
    Duration progress = Duration.zero,
  }) {
    return AudioRecorderState(
      status: status,
      progress: progress,
      vu: -20,
      dBFS: -40,
      showIndicator: status == AudioRecorderStatus.recording,
      modalVisible: false,
    );
  }

  JournalEntity timerEntry(Duration elapsed) {
    final start = DateTime(2026, 7, 17, 9);
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: 'timer-entry',
        createdAt: start,
        updatedAt: start.add(elapsed),
        dateFrom: start,
        dateTo: start.add(elapsed),
      ),
    );
  }

  Widget subject({
    required AudioRecorderState recorder,
    bool showAudio = true,
    List<PendingWakeRecord> pending = const [],
    List<OngoingWakeRecord> ongoing = const [],
    Stream<DateTime>? wakeTicks,
    MediaQueryData? mediaQueryData,
    double width = 320,
  }) {
    return makeTestableWidgetWithScaffold(
      SizedBox(
        width: width,
        child: SidebarActivitySummary(
          showAudio: showAudio,
        ),
      ),
      overrides: [
        audioRecorderControllerProvider.overrideWith(
          () => StubAudioRecorderController(recorder),
        ),
        pendingWakeRecordsProvider.overrideWith((ref) async => pending),
        ongoingWakeRecordsProvider.overrideWith((ref) async => ongoing),
        if (wakeTicks != null)
          wakeCountdownTickerProvider.overrideWith((ref) => wakeTicks),
      ],
      mediaQueryData: mediaQueryData,
    );
  }

  test('compacts sub-hour durations without losing hours', () {
    expect(
      compactSidebarActivityDuration(const Duration(seconds: 8)),
      '00:08',
    );
    expect(
      compactSidebarActivityDuration(
        const Duration(hours: 1, minutes: 2, seconds: 3),
      ),
      '01:02:03',
    );
  });

  testWidgets('collapses completely when no activity exists', (tester) async {
    await tester.pumpWidget(subject(recorder: recorderState()));
    await tester.pump();

    expect(find.byKey(SidebarActivitySummaryKeys.root), findsNothing);
    expect(find.text('Activity'), findsNothing);
  });

  testWidgets('puts the Activity label above the live metrics', (
    tester,
  ) async {
    when(
      () => timeService.getCurrent(),
    ).thenReturn(timerEntry(const Duration(seconds: 13)));

    await tester.pumpWidget(
      subject(
        recorder: recorderState(
          status: AudioRecorderStatus.recording,
          progress: const Duration(seconds: 8),
        ),
        ongoing: [
          OngoingWakeRecord(
            agentId: 'agent-1',
            title: 'Create a proper manual',
            startedAt: DateTime(2026, 7, 17, 9),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('00:08'), findsOneWidget);
    expect(find.text('00:13'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(SidebarActivitySummaryKeys.agents),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(
              of: find.byKey(SidebarActivitySummaryKeys.audio),
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      'Audio recording in progress',
    );
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(
              of: find.byKey(SidebarActivitySummaryKeys.agents),
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      'Agents',
    );

    final labelRect = tester.getRect(find.text('Activity'));
    for (final key in [
      SidebarActivitySummaryKeys.audio,
      SidebarActivitySummaryKeys.timer,
      SidebarActivitySummaryKeys.agents,
    ]) {
      expect(
        tester.getRect(find.byKey(key)).top,
        greaterThan(labelRect.bottom),
        reason: 'metrics belong on a line below the Activity heading',
      );
    }

    final summaryHeight = tester
        .getSize(find.byKey(SidebarActivitySummaryKeys.root))
        .height;
    expect(summaryHeight, greaterThanOrEqualTo(48));
  });

  testWidgets('does not announce the recording duration on every tick', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      subject(
        recorder: recorderState(
          status: AudioRecorderStatus.recording,
          progress: const Duration(seconds: 8),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .getSemantics(find.byKey(SidebarActivitySummaryKeys.root))
          .flagsCollection
          .isLiveRegion,
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets('large text keeps three long-running metrics overflow-free', (
    tester,
  ) async {
    when(
      () => timeService.getCurrent(),
    ).thenReturn(timerEntry(const Duration(hours: 12, minutes: 34)));

    await tester.pumpWidget(
      subject(
        recorder: recorderState(
          status: AudioRecorderStatus.recording,
          progress: const Duration(hours: 9, minutes: 8, seconds: 7),
        ),
        ongoing: [
          OngoingWakeRecord(
            agentId: 'agent-1',
            title: 'Create a proper manual',
            startedAt: DateTime(2026, 7, 17, 9),
          ),
        ],
        mediaQueryData: const MediaQueryData(
          size: Size(320, 800),
          textScaler: TextScaler.linear(1.6),
        ),
        width: 224,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final labelBottom = tester.getRect(find.text('Activity')).bottom;
    expect(find.byKey(SidebarActivitySummaryKeys.audio), findsOneWidget);
    expect(find.byKey(SidebarActivitySummaryKeys.timer), findsOneWidget);
    expect(find.byKey(SidebarActivitySummaryKeys.agents), findsOneWidget);
    expect(
      tester.getRect(find.byKey(SidebarActivitySummaryKeys.audio)).top,
      greaterThan(labelBottom),
    );
  });

  testWidgets('counts only agent work inside the sidebar lookahead', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 17, 9);
    PendingWakeRecord wake(String id, Duration eta) {
      return PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: id,
          id: id,
          displayName: id,
        ),
        state: makeTestState(agentId: id),
        type: PendingWakeType.pending,
        dueAt: now.add(eta),
      );
    }

    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        subject(
          recorder: recorderState(),
          pending: [
            wake('inside', const Duration(minutes: 30)),
            wake('outside', const Duration(hours: 2)),
          ],
        ),
      );
      await tester.pump();
    });

    expect(
      find.descendant(
        of: find.byKey(SidebarActivitySummaryKeys.agents),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('refreshes when scheduled work enters the lookahead', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 17, 9);
    final ticks = StreamController<DateTime>();
    addTearDown(ticks.close);
    final wake = PendingWakeRecord(
      agent: makeTestIdentity(
        agentId: 'entering-lookahead',
        id: 'entering-lookahead',
        displayName: 'Entering lookahead',
      ),
      state: makeTestState(agentId: 'entering-lookahead'),
      type: PendingWakeType.pending,
      dueAt: now.add(const Duration(minutes: 61)),
    );

    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        subject(
          recorder: recorderState(),
          pending: [wake],
          wakeTicks: ticks.stream,
        ),
      );
      await tester.pump();
      expect(find.byKey(SidebarActivitySummaryKeys.root), findsNothing);

      ticks.add(now.add(const Duration(minutes: 2)));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(SidebarActivitySummaryKeys.agents), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(SidebarActivitySummaryKeys.agents),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('expands and collapses detailed controls in place', (
    tester,
  ) async {
    when(
      () => timeService.getCurrent(),
    ).thenReturn(timerEntry(const Duration(minutes: 2, seconds: 5)));

    await tester.pumpWidget(
      subject(recorder: recorderState(), showAudio: false),
    );
    await tester.pump();

    expect(find.byKey(SidebarActivitySummaryKeys.details), findsNothing);
    expect(find.byType(SidebarTimerSection), findsNothing);

    await tester.tap(find.byKey(SidebarActivitySummaryKeys.root));
    await tester.pump(SidebarTimerSection.animationDuration);

    expect(find.byKey(SidebarActivitySummaryKeys.details), findsOneWidget);
    expect(find.byType(SidebarTimerSection), findsOneWidget);
    expect(find.text('00:02:05'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.byKey(SidebarActivitySummaryKeys.root));
    await tester.pump(SidebarTimerSection.animationDuration);

    expect(find.byKey(SidebarActivitySummaryKeys.details), findsNothing);
    expect(find.byType(SidebarTimerSection), findsNothing);
  });
}
