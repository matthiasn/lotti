import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
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
    bool showWakeQueue = true,
    List<PendingWakeRecord> pending = const [],
    List<OngoingWakeRecord> ongoing = const [],
    MediaQueryData? mediaQueryData,
    double width = 320,
  }) {
    return makeTestableWidgetWithScaffold(
      SizedBox(
        width: width,
        child: SidebarActivitySummary(
          showAudio: showAudio,
          showWakeQueue: showWakeQueue,
        ),
      ),
      overrides: [
        audioRecorderControllerProvider.overrideWith(
          () => StubAudioRecorderController(recorder),
        ),
        pendingWakeRecordsProvider.overrideWith((ref) async => pending),
        ongoingWakeRecordsProvider.overrideWith((ref) async => ongoing),
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
    expect(find.text('Active'), findsNothing);
  });

  testWidgets('summarizes recording, timer, and agents in one row', (
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

    final summaryHeight = tester
        .getSize(find.byKey(SidebarActivitySummaryKeys.root))
        .height;
    expect(summaryHeight, lessThan(64));
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
        width: 272,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(SidebarActivitySummaryKeys.audio), findsOneWidget);
    expect(find.byKey(SidebarActivitySummaryKeys.timer), findsOneWidget);
    expect(find.byKey(SidebarActivitySummaryKeys.agents), findsOneWidget);
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

  testWidgets('opens the detailed activity controls from the summary', (
    tester,
  ) async {
    when(
      () => timeService.getCurrent(),
    ).thenReturn(timerEntry(const Duration(minutes: 2, seconds: 5)));

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SizedBox(
          width: 320,
          child: SidebarActivitySummary(
            showAudio: false,
            showWakeQueue: false,
          ),
        ),
        overrides: [
          audioRecorderControllerProvider.overrideWith(
            () => StubAudioRecorderController(recorderState()),
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(SidebarActivitySummaryKeys.root));
    await tester.pump();

    expect(find.byKey(SidebarActivitySummaryKeys.dialog), findsOneWidget);
    expect(find.byType(SidebarTimerSection), findsOneWidget);
    expect(find.text('00:02:05'), findsOneWidget);
  });
}
