import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    as agent_providers;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/day_activity_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_activity_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';
import '../../../categories/test_utils.dart';
import '../../test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat_focus',
  name: 'Focus',
  colorHex: '0080FF',
);

DraftPlan _drafted({
  DayState state = DayState.drafted,
  String title = 'Deep work',
}) => DraftPlan(
  dayDate: DateTime(2026, 5, 26),
  blocks: const [],
  bands: const [],
  capacityMinutes: 240,
  scheduledMinutes: 120,
  state: state,
  agendaItems: [
    AgendaItem(
      id: 'item_1',
      title: title,
      category: _category,
      linkedBlockIds: const ['blk_1'],
    ),
  ],
);

DraftPlan _draftedWithReasons() => DraftPlan(
  dayDate: DateTime(2026, 5, 26),
  blocks: [
    TimeBlock(
      id: 'blk_reason_1',
      title: 'Deep work',
      start: DateTime(2026, 5, 26, 9),
      end: DateTime(2026, 5, 26, 10),
      type: TimeBlockType.ai,
      state: TimeBlockState.drafted,
      category: _category,
      taskId: 'task_1',
      reason: 'Morning is the strongest focus window.',
    ),
    TimeBlock(
      id: 'blk_reason_2',
      title: 'Admin',
      start: DateTime(2026, 5, 26, 11),
      end: DateTime(2026, 5, 26, 12),
      type: TimeBlockType.ai,
      state: TimeBlockState.drafted,
      category: _category,
      taskId: 'task_2',
      reason: 'Keeps shallow work away from deep work.',
    ),
  ],
  bands: const [],
  capacityMinutes: 240,
  scheduledMinutes: 120,
  agendaItems: const [
    AgendaItem(
      id: 'item_1',
      title: 'Deep work',
      category: _category,
      linkedBlockIds: ['blk_reason_1'],
    ),
  ],
);

/// Stub the realtime service so CaptureController (built by RefinePage
/// when DayPage pushes it) can dispose cleanly without touching the AI
/// providers during teardown.
CaptureController _stubCapture() {
  final recorder = MockAudioRecorderRepository();
  final transcriber = MockAudioTranscriptionService();
  when(recorder.stopRecording).thenAnswer((_) async {});
  return CaptureController(
    recorder: recorder,
    transcriber: transcriber,
    docDir: Directory.systemTemp.createTempSync,
    persistAudio: (_) async => null,
    now: () => DateTime(2026, 5, 26, 9),
  );
}

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  List<TimeBlock> actualBlocks = const [],
  List<DayActivityEntry> activityEntries = const [],
  Size size = const Size(1400, 1200),
  MediaQueryData? mediaQueryData,
  ThemeData? theme,
  DailyOsSetupStatus setupStatus = const DailyOsSetupStatus(
    hasInferenceRoute: true,
    hasPreferredName: true,
  ),
}) {
  return makeTestableWidgetNoScroll(
    child,
    overrides: [
      capturesForDateProvider.overrideWith((ref, date) async => const []),
      dayActivityProvider.overrideWith((ref, date) async => activityEntries),
      dailyOsActualTimeBlocksProvider.overrideWith(
        (ref, date) async => actualBlocks,
      ),
      // RefinePage builds a CaptureController; stub so it doesn't read
      // the realtime service providers during dispose.
      captureControllerProvider.overrideWith(_stubCapture),
      dailyOsSetupStatusProvider.overrideWith(
        (ref) async => setupStatus,
      ),
      ...overrides,
    ],
    mediaQueryData: mediaQueryData ?? MediaQueryData(size: size),
    theme: theme,
  );
}

ThemeData _themeWithHeaderSpacing(double step2) {
  final theme = resolveTestTheme();
  final tokens = theme.extension<DsTokens>()!;
  return theme.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      tokens.copyWith(
        spacing: tokens.spacing.copyWith(step2: step2),
      ),
    ],
  );
}

Widget _dateStripLike(String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.chevron_left_rounded),
        onPressed: () {},
      ),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.chevron_right_rounded),
        onPressed: () {},
      ),
    ],
  );
}

void _setSurfaceSize(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void _setSurface(WidgetTester tester) {
  _setSurfaceSize(tester, const Size(1400, 1200));
}

/// Sets the standard surface, pumps a [DayPage] for [draft] with [agent]
/// wired through `dayAgentProvider`, and runs one frame so the page
/// settles. Covers the common "RecordingDayAgent override + initial pump"
/// boilerplate shared by the menu / footer / refine tests.
Future<void> _pumpDayPage(
  WidgetTester tester, {
  required DraftPlan draft,
  required RecordingDayAgent agent,
}) async {
  _setSurface(tester);
  await tester.pumpWidget(
    _wrap(
      DayPage(draft: draft),
      overrides: [dayAgentProvider.overrideWithValue(agent)],
    ),
  );
  await tester.pump();
}

void main() {
  tearDown(() {
    nav_service.beamToNamedOverride = null;
  });

  group('DayPage', () {
    testWidgets('default title and AgendaView render, DayTimeline absent', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.text(messages.dailyOsNextDayTitle), findsOneWidget);
      expect(find.byType(AgendaView), findsOneWidget);
      expect(find.byType(DayTimeline), findsNothing);
    });

    testWidgets(
      'empty mode (no plan) lands on Activity with the check-in CTA '
      'instead of Refine/Commit, and hides the delete-plan menu entry',
      (tester) async {
        _setSurface(tester);
        var checkIns = 0;
        final tracked = TimeBlock(
          id: 'tr1',
          title: 'Recorded session',
          start: DateTime(2026, 5, 26, 9),
          end: DateTime(2026, 5, 26, 10),
          type: TimeBlockType.manual,
          state: TimeBlockState.completed,
          category: _category,
        );
        await tester.pumpWidget(
          _wrap(
            DayPage(
              draft: DraftPlan.emptyForDay(DateTime(2026, 5, 26)),
              hasPlan: false,
              onCheckIn: () => checkIns++,
            ),
            actualBlocks: [tracked],
          ),
        );
        await tester.pump();
        await tester.pump();

        // Failed or pending recordings are the primary no-plan recovery path,
        // while already-tracked time remains visible on the same surface.
        expect(find.byType(DayActivityView), findsOneWidget);
        expect(find.byType(DayTimeline), findsNothing);
        expect(find.byType(AgendaView), findsNothing);
        expect(find.text('Recorded session'), findsOneWidget);

        // Footer carries the single check-in CTA, not Refine/Commit.
        final messages = tester.element(find.byType(DayPage)).messages;
        expect(find.text(messages.dailyOsNextDayRefineCta), findsNothing);
        expect(find.text(messages.dailyOsNextDayLockInCta), findsNothing);
        final cta = find.byKey(const Key('daily_os_day_check_in_cta'));
        expect(cta, findsOneWidget);
        await tester.tap(cta);
        expect(checkIns, 1);

        // The overflow menu offers no delete-plan entry without a plan.
        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pump();
        expect(
          find.text(messages.dailyOsNextDayMenuDeletePlan),
          findsNothing,
        );
        expect(
          find.text(messages.dailyOsNextDayMenuInspectAgent),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'missing inference replaces check-in with a discoverable setup action',
      (tester) async {
        _setSurface(tester);
        final routes = <String>[];
        nav_service.beamToNamedOverride = routes.add;
        await tester.pumpWidget(
          _wrap(
            DayPage(
              draft: DraftPlan.emptyForDay(DateTime(2026, 5, 26)),
              hasPlan: false,
              onCheckIn: () => fail('check-in must stay blocked'),
            ),
            setupStatus: const DailyOsSetupStatus(
              hasInferenceRoute: false,
              hasPreferredName: false,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final messages = tester.element(find.byType(DayPage)).messages;
        expect(
          find.text(messages.dailyOsSettingsSetupRequiredTitle),
          findsOneWidget,
        );
        expect(
          find.textContaining(messages.dailyOsSettingsNameNudgeBody),
          findsOneWidget,
        );
        expect(
          find.text(messages.dailyOsSettingsSetupAction),
          findsNWidgets(2),
        );
        expect(find.text(messages.dailyOsNextDayCheckInCta), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text(messages.dailyOsNextDayMenuSettings));
        await tester.pump();
        final setupActions = find.text(messages.dailyOsSettingsSetupAction);
        await tester.tap(setupActions.at(0));
        await tester.pump();
        await tester.tap(setupActions.at(1));
        await tester.pump();

        expect(routes, [
          '/settings/daily-os',
          '/settings/daily-os',
          '/settings/daily-os',
        ]);
      },
    );

    testWidgets(
      'using a retained recording targets the selected day workspace',
      (tester) async {
        _setSurface(tester);
        final agent = RecordingDayAgent();
        final sourceCapturedAt = DateTime(2026, 7, 18, 8, 15);
        final selectedDay = DateTime(2026, 5, 26);
        final job = DayProcessingJob(
          id: 'job-retained',
          kind: DayProcessingJobKind.transcribeAudio,
          status: DayProcessingJobStatus.succeeded,
          dayId: 'dayplan-2026-05-26',
          activityEntryId: 'activity-retained',
          recordingSessionId: 'session-retained',
          audioId: 'audio-retained',
          audioPath: '/tmp/audio-retained.wav',
          createdAt: sourceCapturedAt,
          updatedAt: sourceCapturedAt,
          nextAttemptAt: sourceCapturedAt,
          attempts: 1,
          generation: 1,
          resultTranscript: 'Use this check-in for the selected day.',
          completedAt: sourceCapturedAt,
        );
        final entry = DayActivityEntry(
          id: 'activity-retained',
          kind: DayActivityEntryKind.recording,
          createdAt: sourceCapturedAt,
          activityEntryId: 'activity-retained',
          processingJob: job,
        );

        await tester.pumpWidget(
          _wrap(
            DayPage(
              draft: DraftPlan.emptyForDay(selectedDay),
              hasPlan: false,
            ),
            activityEntries: [entry],
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextActivityUseToPlan));
        await tester.pump();

        expect(agent.capturedAt, sourceCapturedAt);
        expect(agent.capturedDayDate, selectedDay);
        // The journal row hasn't landed for this entry, so the outbox job's
        // audio reference keeps the capture correlated to its recording.
        expect(agent.capturedAudioId, 'audio-retained');
      },
    );

    testWidgets('a submitted check-in retries its existing capture', (
      tester,
    ) async {
      _setSurface(tester);
      final captureService = MockDayAgentCaptureService();
      when(
        () => captureService.retryCapture('capture-activity'),
      ).thenAnswer((_) async => true);
      final capture = makeTestCapture(
        id: 'capture-activity',
        transcript: 'Retry this submitted check-in.',
        capturedAt: DateTime(2026, 5, 26, 8),
        dayId: 'dayplan-2026-05-26',
      );
      final entry = DayActivityEntry(
        id: capture.id,
        kind: DayActivityEntryKind.checkIn,
        createdAt: capture.capturedAt,
        activityEntryId: capture.id,
        capture: capture,
      );

      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: DraftPlan.emptyForDay(DateTime(2026, 5, 26)),
            hasPlan: false,
          ),
          activityEntries: [entry],
          overrides: [
            agent_providers.dayAgentCaptureServiceProvider.overrideWithValue(
              captureService,
            ),
          ],
        ),
      );
      await tester.pump();
      final messages = tester.element(find.byType(DayPage)).messages;

      await tester.tap(find.text(messages.dailyOsNextActivityUseToPlan));
      await tester.pump();

      verify(() => captureService.retryCapture('capture-activity')).called(1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a retained recording seeds refinement for an existing plan', (
      tester,
    ) async {
      _setSurface(tester);
      final agent = RecordingDayAgent(
        diff: PlanDiff(
          id: 'activity-refine-diff',
          transcript: 'Make the afternoon lighter.',
          changes: const [],
          updatedPlan: _drafted(),
        ),
      );
      final capturedAt = DateTime(2026, 5, 26, 8);
      final job = DayProcessingJob(
        id: 'activity-refine-job',
        kind: DayProcessingJobKind.transcribeAudio,
        status: DayProcessingJobStatus.succeeded,
        dayId: 'dayplan-2026-05-26',
        activityEntryId: 'activity-refine',
        recordingSessionId: 'activity-refine-session',
        audioId: 'activity-refine-audio',
        audioPath: '/tmp/activity-refine.wav',
        createdAt: capturedAt,
        updatedAt: capturedAt,
        nextAttemptAt: capturedAt,
        attempts: 1,
        generation: 1,
        resultTranscript: 'Make the afternoon lighter.',
        completedAt: capturedAt,
      );

      await tester.pumpWidget(
        _wrap(
          DayPage(draft: _drafted()),
          activityEntries: [
            DayActivityEntry(
              id: 'activity-refine',
              kind: DayActivityEntryKind.recording,
              createdAt: capturedAt,
              activityEntryId: 'activity-refine',
              processingJob: job,
            ),
          ],
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump();
      tester
          .widget<PlanViewToggle>(find.byType(PlanViewToggle))
          .onChanged(PlanView.activity);
      await tester.pump();
      await tester.pump();
      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.byType(DayActivityView), findsOneWidget);
      expect(find.text('Make the afternoon lighter.'), findsOneWidget);

      await tester.tap(find.text(messages.dailyOsNextActivityUseToRefine));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(find.byType(RefineModalContent), findsOneWidget);
      expect(agent.proposeCount, 1);
      expect(agent.proposedTranscript, 'Make the afternoon lighter.');
    });

    testWidgets('missing name stays discoverable without blocking check-in', (
      tester,
    ) async {
      _setSurface(tester);
      var checkIns = 0;
      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: DraftPlan.emptyForDay(DateTime(2026, 5, 26)),
            hasPlan: false,
            onCheckIn: () => checkIns++,
          ),
          setupStatus: const DailyOsSetupStatus(
            hasInferenceRoute: true,
            hasPreferredName: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(
        find.text(messages.dailyOsSettingsNameNudgeTitle),
        findsOneWidget,
      );
      expect(find.text(messages.dailyOsNextDayCheckInCta), findsOneWidget);

      await tester.tap(find.byKey(const Key('daily_os_day_check_in_cta')));
      expect(checkIns, 1);
    });

    testWidgets(
      'a failing inline rename surfaces the error toast instead of an '
      'unhandled exception',
      (tester) async {
        final agent = RecordingDayAgent(renameError: StateError('db down'));
        // One standalone agenda item (no taskId) -> editable title.
        final draft = DraftPlan(
          dayDate: DateTime(2026, 5, 26),
          blocks: const [],
          bands: const [],
          capacityMinutes: 240,
          scheduledMinutes: 120,
          agendaItems: const [
            AgendaItem(
              id: 'item_1',
              title: 'Standalone block',
              category: _category,
              linkedBlockIds: ['blk_1'],
            ),
          ],
        );
        await _pumpDayPage(tester, draft: draft, agent: agent);

        await tester.tap(find.text('Standalone block'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('daily_os_editable_title_field')),
          'Renamed',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.pump();

        final messages = tester.element(find.byType(DayPage)).messages;
        expect(find.text(messages.dailyOsNextRenameFailed), findsOneWidget);
      },
    );

    testWidgets(
      'inline block rename on the Day view persists via the agent; a '
      'failure surfaces the toast',
      (tester) async {
        _setSurface(tester);
        DraftPlan draftWithStandaloneBlock() => DraftPlan(
          dayDate: DateTime(2026, 5, 26),
          blocks: [
            TimeBlock(
              id: 'blk_1',
              title: 'Standalone block',
              start: DateTime(2026, 5, 26, 9),
              end: DateTime(2026, 5, 26, 10, 30),
              type: TimeBlockType.manual,
              state: TimeBlockState.drafted,
              category: _category,
            ),
          ],
          bands: const [],
          capacityMinutes: 240,
          scheduledMinutes: 90,
        );

        Future<void> renameOnDayView(RecordingDayAgent agent) async {
          await tester.pumpWidget(
            _wrap(
              DayPage(draft: draftWithStandaloneBlock()),
              overrides: [dayAgentProvider.overrideWithValue(agent)],
            ),
          );
          await tester.pump();

          // Switch to the Day projection. `.last` skips the toggle's
          // invisible width-reserving ghost label.
          final messages = tester.element(find.byType(DayPage)).messages;
          await tester.tap(find.text(messages.dailyOsNextPlanViewDay).last);
          await tester.pump();
          await tester.pump();

          await tester.tap(find.text('Standalone block'));
          await tester.pump();
          await tester.enterText(
            find.byKey(const Key('daily_os_editable_title_field')),
            'Renamed block',
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pump();
          await tester.pump();
        }

        // Success path: the agent receives the rename, no toast.
        final agent = RecordingDayAgent();
        await renameOnDayView(agent);
        expect(agent.renamedBlocks, [('blk_1', 'Renamed block')]);
        final messages = tester.element(find.byType(DayPage)).messages;
        expect(find.text(messages.dailyOsNextRenameFailed), findsNothing);

        // Failure path: the error toast appears.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final failingAgent = RecordingDayAgent(
          renameError: StateError('db down'),
        );
        await renameOnDayView(failingAgent);
        expect(find.text(messages.dailyOsNextRenameFailed), findsOneWidget);
      },
    );

    testWidgets(
      'block editor persists one atomic edit and offers a working undo',
      (tester) async {
        final block = TimeBlock(
          id: 'blk_modal',
          title: 'Brief the emergency penguin council',
          start: DateTime(2026, 5, 26, 9),
          end: DateTime(2026, 5, 26, 10, 30),
          type: TimeBlockType.manual,
          state: TimeBlockState.drafted,
          category: _category,
          reason: 'They vote before the fish market opens.',
        );
        final draft = DraftPlan(
          dayDate: DateTime(2026, 5, 26),
          blocks: [block],
          bands: const [],
          capacityMinutes: 240,
          scheduledMinutes: 90,
        );
        final agent = RecordingDayAgent();
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextPlanViewDay).last);
        await tester.pump();
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('daily_os_edit_block_blk_modal')),
        );
        await tester.pumpAndSettle();

        expect(find.text(messages.dailyOsNextBlockEditTitle), findsOneWidget);
        await tester.enterText(
          find.byType(TextField),
          'Move penguin diplomacy forward',
        );
        await tester.pump();
        final saveButton = tester.widget<DesignSystemButton>(
          find.widgetWithText(
            DesignSystemButton,
            messages.dailyOsNextBlockEditSave,
          ),
        );
        expect(saveButton.onPressed, isNotNull);
        saveButton.onPressed!();
        await tester.pumpAndSettle();

        expect(agent.editedBlocks, hasLength(1));
        expect(agent.editedBlocks.single.blockId, block.id);
        expect(
          agent.editedBlocks.single.title,
          'Move penguin diplomacy forward',
        );
        expect(agent.editedBlocks.single.category, _category);
        expect(agent.editedBlocks.single.start, block.start);
        expect(agent.editedBlocks.single.end, block.end);
        expect(find.text(messages.dailyOsNextBlockEditSaved), findsOneWidget);

        final toast = tester.widget<DesignSystemToast>(
          find.byType(DesignSystemToast),
        );
        expect(toast.action?.label, messages.designSystemUndoLabel);
        toast.action!.onPressed();
        await tester.pump();
        await tester.pump();

        expect(agent.editedBlocks, hasLength(2));
        expect(agent.editedBlocks.last.title, block.title);
        expect(agent.editedBlocks.last.category, block.category);
        expect(agent.editedBlocks.last.start, block.start);
        expect(agent.editedBlocks.last.end, block.end);
      },
    );

    testWidgets(
      'block editor failure keeps the page stable and shows a toast',
      (
        tester,
      ) async {
        final block = TimeBlock(
          id: 'blk_failure',
          title: 'Count backup sardines',
          start: DateTime(2026, 5, 26, 9),
          end: DateTime(2026, 5, 26, 10, 30),
          type: TimeBlockType.manual,
          state: TimeBlockState.drafted,
          category: _category,
        );
        final draft = DraftPlan(
          dayDate: DateTime(2026, 5, 26),
          blocks: [block],
          bands: const [],
          capacityMinutes: 240,
          scheduledMinutes: 90,
        );
        final agent = RecordingDayAgent(editError: StateError('db down'));
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextPlanViewDay).last);
        await tester.pump();
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('daily_os_edit_block_blk_failure')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Count all sardines');
        await tester.pump();
        tester
            .widget<DesignSystemButton>(
              find.widgetWithText(
                DesignSystemButton,
                messages.dailyOsNextBlockEditSave,
              ),
            )
            .onPressed!();
        await tester.pumpAndSettle();

        expect(agent.editedBlocks, hasLength(1));
        expect(find.text(messages.dailyOsNextBlockEditFailed), findsOneWidget);
        expect(find.byType(DayPage), findsOneWidget);
      },
    );

    testWidgets('timeline rescheduling uses the same atomic persistence path', (
      tester,
    ) async {
      final block = TimeBlock(
        id: 'blk_drag',
        title: 'Schedule orbital sardine transfer',
        start: DateTime(2026, 5, 26, 9),
        end: DateTime(2026, 5, 26, 10),
        type: TimeBlockType.manual,
        state: TimeBlockState.drafted,
        category: _category,
      );
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: [block],
        bands: const [],
        capacityMinutes: 240,
        scheduledMinutes: 60,
      );
      final agent = RecordingDayAgent();
      await _pumpDayPage(tester, draft: draft, agent: agent);

      final messages = tester.element(find.byType(DayPage)).messages;
      await tester.tap(find.text(messages.dailyOsNextPlanViewDay).last);
      await tester.pump();
      await tester.pump();
      final timeline = tester.widget<DayTimeline>(find.byType(DayTimeline));

      final saved = await timeline.onRescheduleBlock!(
        block,
        DateTime(2026, 5, 26, 10, 15),
        DateTime(2026, 5, 26, 11, 45),
      );
      await tester.pump();

      expect(saved, isTrue);
      expect(agent.editedBlocks, hasLength(1));
      expect(agent.editedBlocks.single.title, block.title);
      expect(agent.editedBlocks.single.category, block.category);
      expect(agent.editedBlocks.single.start, DateTime(2026, 5, 26, 10, 15));
      expect(agent.editedBlocks.single.end, DateTime(2026, 5, 26, 11, 45));
      expect(
        agent.lastEditedPlan?.scheduledMinutes,
        90,
      );
      expect(find.text(messages.dailyOsNextBlockEditSaved), findsOneWidget);
    });

    testWidgets(
      'task-linked time edits never write projected task identity fields',
      (tester) async {
        final block = TimeBlock(
          id: 'blk_linked_drag',
          title: 'Persisted title snapshot',
          start: DateTime(2026, 5, 26, 9),
          end: DateTime(2026, 5, 26, 10),
          type: TimeBlockType.ai,
          state: TimeBlockState.drafted,
          category: _category,
          taskId: 'task-penguins',
        );
        const liveCategory = DayAgentCategory(
          id: 'cat_live',
          name: 'Live Penguin Operations',
          colorHex: '8B5CF6',
        );
        final projectedBlock = block.copyWith(
          title: 'Renamed on the linked task',
          category: liveCategory,
        );
        final draft = DraftPlan(
          dayDate: DateTime(2026, 5, 26),
          blocks: [block],
          bands: const [],
          capacityMinutes: 240,
          scheduledMinutes: 60,
        );
        final agent = RecordingDayAgent();
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextPlanViewDay).last);
        await tester.pump();
        await tester.pump();
        final timeline = tester.widget<DayTimeline>(find.byType(DayTimeline));

        final saved = await timeline.onRescheduleBlock!(
          projectedBlock,
          DateTime(2026, 5, 26, 10, 15),
          DateTime(2026, 5, 26, 11, 15),
        );
        await tester.pump();

        expect(saved, isTrue);
        expect(agent.editedBlocks, hasLength(1));
        expect(agent.editedBlocks.single.title, isNull);
        expect(agent.editedBlocks.single.category, isNull);
        expect(agent.editedBlocks.single.start, DateTime(2026, 5, 26, 10, 15));
        expect(agent.editedBlocks.single.end, DateTime(2026, 5, 26, 11, 15));

        final toast = tester.widget<DesignSystemToast>(
          find.byType(DesignSystemToast),
        );
        expect(toast.action?.label, messages.designSystemUndoLabel);
        toast.action!.onPressed();
        await tester.pump();
        await tester.pump();

        expect(agent.editedBlocks, hasLength(2));
        expect(agent.editedBlocks.last.title, isNull);
        expect(agent.editedBlocks.last.category, isNull);
        expect(agent.editedBlocks.last.start, block.start);
        expect(agent.editedBlocks.last.end, block.end);
      },
    );

    testWidgets('undo failure reports the error without losing the page', (
      tester,
    ) async {
      final block = TimeBlock(
        id: 'blk_undo_failure',
        title: 'Inventory diplomatic herring',
        start: DateTime(2026, 5, 26, 9),
        end: DateTime(2026, 5, 26, 10),
        type: TimeBlockType.manual,
        state: TimeBlockState.drafted,
        category: _category,
      );
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: [block],
        bands: const [],
        capacityMinutes: 240,
        scheduledMinutes: 60,
      );
      final agent = RecordingDayAgent(
        editError: StateError('undo persistence failed'),
        editErrorOnCall: 2,
      );
      await _pumpDayPage(tester, draft: draft, agent: agent);

      final messages = tester.element(find.byType(DayPage)).messages;
      await tester.tap(find.text(messages.dailyOsNextPlanViewDay).last);
      await tester.pump();
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('daily_os_edit_block_blk_undo_failure')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Count every herring');
      await tester.pump();
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(
              DesignSystemButton,
              messages.dailyOsNextBlockEditSave,
            ),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.text(messages.designSystemUndoLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(agent.editCalls, 2);
      expect(find.text(messages.dailyOsNextBlockEditFailed), findsOneWidget);
      expect(find.byType(DayPage), findsOneWidget);
    });

    testWidgets('task-linked editor can leave for the task without saving', (
      tester,
    ) async {
      final routes = <String>[];
      nav_service.beamToNamedOverride = routes.add;
      final block = TimeBlock(
        id: 'blk_task',
        title: 'Brief the penguin task force',
        start: DateTime(2026, 5, 26, 9),
        end: DateTime(2026, 5, 26, 10, 30),
        type: TimeBlockType.ai,
        state: TimeBlockState.drafted,
        category: _category,
        taskId: 'task-penguins',
      );
      final draft = DraftPlan(
        dayDate: DateTime(2026, 5, 26),
        blocks: [block],
        bands: const [],
        capacityMinutes: 240,
        scheduledMinutes: 90,
      );
      final agent = RecordingDayAgent();
      await _pumpDayPage(tester, draft: draft, agent: agent);

      final messages = tester.element(find.byType(DayPage)).messages;
      await tester.tap(find.text(messages.dailyOsNextPlanViewDay).last);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('daily_os_edit_block_blk_task')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(messages.dailyOsNextBlockEditOpenTask));
      await tester.pumpAndSettle();

      expect(routes, ['/tasks/task-penguins']);
      expect(agent.editedBlocks, isEmpty);
      expect(find.text(messages.dailyOsNextBlockEditTitle), findsNothing);
    });

    testWidgets(
      'block editor offers only categories enabled for day planning',
      (
        tester,
      ) async {
        final available = CategoryTestUtils.createTestCategory(
          id: 'cat-available',
          name: 'Penguin Operations',
          isAvailableForDayPlan: true,
        );
        final excluded = CategoryTestUtils.createTestCategory(
          id: 'cat-excluded',
          name: 'Secret Walrus Committee',
          isAvailableForDayPlan: false,
        );
        final cache = MockEntitiesCacheService();
        when(
          () => cache.sortedCategories,
        ).thenReturn([available, excluded]);
        await setUpTestGetIt(
          additionalSetup: () {
            getIt.registerSingleton<EntitiesCacheService>(cache);
          },
        );
        addTearDown(tearDownTestGetIt);

        final block = TimeBlock(
          id: 'blk_category_filter',
          title: 'Schedule the penguin committee',
          start: DateTime(2026, 5, 26, 9),
          end: DateTime(2026, 5, 26, 10),
          type: TimeBlockType.manual,
          state: TimeBlockState.drafted,
          category: _category,
        );
        final draft = DraftPlan(
          dayDate: DateTime(2026, 5, 26),
          blocks: [block],
          bands: const [],
          capacityMinutes: 240,
          scheduledMinutes: 60,
        );
        await _pumpDayPage(
          tester,
          draft: draft,
          agent: RecordingDayAgent(),
        );

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextPlanViewDay).last);
        await tester.pump();
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('daily_os_edit_block_blk_category_filter')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(_category.name));
        await tester.pumpAndSettle();

        final picker = tester.widget<CategoryPickerSheet>(
          find.byType(CategoryPickerSheet),
        );
        expect(picker.options, [available]);
        expect(picker.allowCreate, isFalse);
      },
    );

    testWidgets(
      'inspect-agent menu action beams to the agent instance when the '
      'day-agent identity resolves',
      (tester) async {
        _setSurface(tester);
        final mockNav = MockNavService();
        final settingsDelegate = RecordingBeamerDelegate();
        when(() => mockNav.index).thenReturn(0);
        when(() => mockNav.settingsIndex).thenReturn(6);
        when(() => mockNav.setIndex(any())).thenReturn(null);
        when(() => mockNav.settingsDelegate).thenReturn(settingsDelegate);
        when(() => mockNav.persistNamedRoute(any())).thenAnswer((_) async {});
        if (getIt.isRegistered<nav_service.NavService>()) {
          getIt.unregister<nav_service.NavService>();
        }
        getIt.registerSingleton<nav_service.NavService>(mockNav);
        addTearDown(() => getIt.unregister<nav_service.NavService>());

        await tester.pumpWidget(
          _wrap(
            DayPage(draft: _drafted()),
            overrides: [
              agent_providers.dayAgentProvider.overrideWith(
                (ref, date) async => makeTestIdentity(
                  id: 'day-agent-001',
                  agentId: 'day-agent-001',
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pump();
        // Let the popup menu's open animation finish before tapping.
        await tester.pump(const Duration(milliseconds: 200));
        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextDayMenuInspectAgent));
        await tester.pump();
        await tester.pump();

        expect(settingsDelegate.beamed, [
          '/settings/agents/instances/day-agent-001',
        ]);
      },
    );

    testWidgets('dateStrip widget replaces the default title', (tester) async {
      _setSurface(tester);
      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: _drafted(),
            dateStrip: const Text('2026-05-26'),
          ),
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.text(messages.dailyOsNextDayTitle), findsNothing);
      expect(find.text('2026-05-26'), findsOneWidget);
    });

    testWidgets('header stacks the three-view toggle when it needs room', (
      tester,
    ) async {
      _setSurfaceSize(tester, const Size(640, 844));
      const label = 'May 31, 2026';
      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: _drafted(),
            dateStrip: _dateStripLike(label),
          ),
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(640, 844),
          ),
        ),
      );
      await tester.pump();

      final dateBottom = tester.getBottomLeft(find.text(label)).dy;
      final toggleTop = tester.getTopLeft(find.byType(PlanViewToggle)).dy;

      expect(toggleTop, greaterThan(dateBottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('header moves the plan toggle below only when it cannot fit', (
      tester,
    ) async {
      _setSurfaceSize(tester, phoneMediaQueryData.size);
      const label = 'May 31, 2026';
      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: _drafted(),
            dateStrip: _dateStripLike(label),
          ),
          mediaQueryData: phoneMediaQueryData,
        ),
      );
      await tester.pump();

      final dateBottom = tester.getBottomLeft(find.text(label)).dy;
      final toggleTop = tester.getTopLeft(find.byType(PlanViewToggle)).dy;

      expect(find.text(label), findsOneWidget);
      expect(toggleTop, greaterThan(dateBottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('header relayouts when design-system spacing changes', (
      tester,
    ) async {
      _setSurfaceSize(tester, const Size(640, 844));
      const label = 'May 31, 2026';
      final mediaQueryData = phoneMediaQueryData.copyWith(
        size: const Size(640, 844),
      );
      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: _drafted(),
            dateStrip: _dateStripLike(label),
          ),
          mediaQueryData: mediaQueryData,
          theme: _themeWithHeaderSpacing(20),
        ),
      );
      await tester.pump();
      final firstTop = tester.getTopLeft(find.text(label)).dy;

      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: _drafted(),
            dateStrip: _dateStripLike(label),
          ),
          mediaQueryData: mediaQueryData,
          theme: _themeWithHeaderSpacing(32),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final secondTop = tester.getTopLeft(find.text(label)).dy;

      expect(secondTop, greaterThan(firstTop));
      expect(tester.takeException(), isNull);
    });

    testWidgets('toggling the plan view switches Agenda → DayTimeline', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      expect(find.byType(AgendaView), findsOneWidget);
      expect(find.byType(DayTimeline), findsNothing);

      // Drive the toggle directly; chip tap behavior is covered by
      // PlanViewToggle's focused widget tests.
      final toggle = tester.widget<PlanViewToggle>(find.byType(PlanViewToggle));
      toggle.onChanged(PlanView.day);
      await tester.pump();

      expect(find.byType(AgendaView), findsNothing);
      expect(find.byType(DayTimeline), findsOneWidget);
    });

    testWidgets('drafted footer keeps Refine and commits via Looks good', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      expect(find.text(messages.dailyOsNextDayRefineCta), findsOneWidget);
      expect(find.text(messages.dailyOsNextReviewLooksGood), findsOneWidget);
      expect(find.text(messages.dailyOsNextDayLockInCta), findsNothing);
      expect(find.text(messages.dailyOsNextDayWrapUpCta), findsNothing);
    });

    testWidgets(
      'drafted footer explains why items made it in and shows quick review',
      (tester) async {
        _setSurface(tester);
        await tester.pumpWidget(_wrap(DayPage(draft: _draftedWithReasons())));
        await tester.pump();

        final messages = tester.element(find.byType(DayPage)).messages;
        expect(find.text(messages.dailyOsNextReviewWhyTitle), findsOneWidget);
        expect(
          find.text('Morning is the strongest focus window.'),
          findsOneWidget,
        );
        expect(
          find.text('Keeps shallow work away from deep work.'),
          findsOneWidget,
        );
        expect(find.text(messages.dailyOsNextReviewLooksGood), findsOneWidget);
        expect(find.text(messages.dailyOsNextReviewTooMuch), findsOneWidget);
        expect(
          find.text(messages.dailyOsNextReviewMoveLighter),
          findsOneWidget,
        );
        expect(find.text(messages.dailyOsNextReviewAddBuffer), findsOneWidget);
      },
    );

    testWidgets('committed footer swaps Lock In for Wrap up', (tester) async {
      _setSurface(tester);
      await tester.pumpWidget(
        _wrap(DayPage(draft: _drafted(state: DayState.committed))),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.text(messages.dailyOsNextDayLockInCta), findsNothing);
      expect(find.text(messages.dailyOsNextDayWrapUpCta), findsOneWidget);
      expect(find.text(messages.dailyOsNextDayRefineCta), findsOneWidget);
    });

    testWidgets(
      'mobile committed footer stacks the coaching hint above actions',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            DayPage(draft: _drafted(state: DayState.committed)),
            mediaQueryData: phoneMediaQueryData,
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(DayPage)).messages;
        expect(
          find.text(messages.dailyOsNextDayRefineFooterHint),
          findsOneWidget,
        );
        expect(find.text(messages.dailyOsNextDayRefineCta), findsOneWidget);
        expect(find.text(messages.dailyOsNextDayWrapUpCta), findsOneWidget);
        expect(
          tester
              .getBottomLeft(
                find.text(messages.dailyOsNextDayRefineFooterHint),
              )
              .dy,
          lessThan(
            tester.getTopLeft(find.text(messages.dailyOsNextDayRefineCta)).dy,
          ),
        );
      },
    );

    testWidgets('syncs displayed agenda when the draft prop changes', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Evening meeting'), findsNothing);

      await tester.pumpWidget(
        _wrap(DayPage(draft: _drafted(title: 'Evening meeting'))),
      );
      await tester.pump();

      expect(find.text('Deep work'), findsNothing);
      expect(find.text('Evening meeting'), findsOneWidget);
    });

    testWidgets('mobile footer clears the bottom navigation hit area', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DayPage(draft: _drafted()),
          mediaQueryData: phoneMediaQueryData,
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(DayPage));
      final bottomNavHeight = DesignSystemBottomNavigationBar.occupiedHeight(
        context,
      );
      final messages = context.messages;
      final looksGoodBottom = tester
          .getBottomLeft(find.text(messages.dailyOsNextReviewLooksGood))
          .dy;

      expect(
        looksGoodBottom,
        lessThan(phoneMediaQueryData.size.height - bottomNavHeight),
      );
      expect(
        tester.getCenter(find.text(messages.dailyOsNextDayRefineCta)),
        isA<Offset>(),
      );
    });

    testWidgets('popup menu exposes Inspect agent + Delete plan items', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(
        find.text(messages.dailyOsNextDayMenuInspectAgent),
        findsOneWidget,
      );
      expect(find.text(messages.dailyOsNextDayMenuDeletePlan), findsOneWidget);
    });

    testWidgets('Inspect agent menu item resolves day-agent internals', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(
        _wrap(
          DayPage(draft: _drafted()),
          overrides: [
            agent_providers.dayAgentProvider.overrideWith(
              (ref, date) async => null,
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final messages = tester.element(find.byType(DayPage)).messages;
      await tester.tap(find.text(messages.dailyOsNextDayMenuInspectAgent));
      await tester.pump();
      await tester.pump();

      expect(find.byType(DayPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Delete plan flow: confirm dialog → confirm calls agent with day date',
      (tester) async {
        final agent = RecordingDayAgent();
        final draft = _drafted();
        await _pumpDayPage(tester, draft: draft, agent: agent);

        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextDayMenuDeletePlan));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.text(messages.dailyOsNextDayDeleteDialogTitle),
          findsOneWidget,
        );
        await tester.tap(
          find.text(messages.dailyOsNextDayDeleteDialogConfirm),
        );
        await tester.pump();
        await tester.pump();

        expect(agent.deleteCount, 1);
        expect(agent.deletedFor, draft.dayDate);
      },
    );

    testWidgets(
      'header back IconButton pops the navigator (no dateStrip)',
      (tester) async {
        _setSurface(tester);
        final agent = RecordingDayAgent();
        var popped = false;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => DayPage(draft: _drafted()),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 200));

        // The header shows a back button only when there's no dateStrip;
        // the popup-menu's more_vert icon stays in place.
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(popped, isTrue);
        expect(find.byType(DayPage), findsNothing);
      },
    );

    testWidgets(
      'tapping Refine opens the modal over the current day page',
      (tester) async {
        final agent = RecordingDayAgent();
        final draft = _drafted();
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextDayRefineCta));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(DayPage), findsOneWidget);
        expect(find.byType(RefineModalContent), findsOneWidget);
        expect(
          find.text(messages.dailyOsNextRefineHeadlineIdle),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'quick review action opens refine modal and submits its seeded prompt',
      (tester) async {
        final agent = RecordingDayAgent(
          diff: PlanDiff(
            id: 'quick_diff',
            transcript: 'quick',
            changes: const [],
            updatedPlan: _draftedWithReasons(),
          ),
        );
        final draft = _draftedWithReasons();
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextReviewTooMuch));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        expect(find.byType(DayPage), findsOneWidget);
        expect(find.byType(RefineModalContent), findsOneWidget);
        expect(agent.proposeCount, 1);
        expect(
          agent.proposedTranscript,
          messages.dailyOsNextReviewTooMuchPrompt,
        );
      },
    );

    for (final scenario in ['move lighter', 'add buffer']) {
      testWidgets('quick review $scenario submits its seeded prompt', (
        tester,
      ) async {
        final agent = RecordingDayAgent(
          diff: PlanDiff(
            id: 'quick_${scenario.replaceAll(' ', '_')}_diff',
            transcript: scenario,
            changes: const [],
            updatedPlan: _draftedWithReasons(),
          ),
        );
        final draft = _draftedWithReasons();
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        final (label, prompt) = switch (scenario) {
          'move lighter' => (
            messages.dailyOsNextReviewMoveLighter,
            messages.dailyOsNextReviewMoveLighterPrompt,
          ),
          'add buffer' => (
            messages.dailyOsNextReviewAddBuffer,
            messages.dailyOsNextReviewAddBufferPrompt,
          ),
          _ => throw StateError('unknown quick review scenario: $scenario'),
        };

        await tester.tap(find.text(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        expect(find.byType(DayPage), findsOneWidget);
        expect(find.byType(RefineModalContent), findsOneWidget);
        expect(agent.proposeCount, 1);
        expect(agent.proposedTranscript, prompt);
      });
    }

    testWidgets('large text folds quick refinements into an Adjust menu', (
      tester,
    ) async {
      final agent = RecordingDayAgent(
        diff: PlanDiff(
          id: 'compact_diff',
          transcript: 'compact',
          changes: const [],
          updatedPlan: _draftedWithReasons(),
        ),
      );
      final mediaQueryData = phoneMediaQueryData.copyWith(
        textScaler: const TextScaler.linear(2),
      );
      _setSurfaceSize(tester, mediaQueryData.size);
      await tester.pumpWidget(
        _wrap(
          DayPage(draft: _draftedWithReasons()),
          mediaQueryData: mediaQueryData,
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.text(messages.dailyOsNextReviewAdjust), findsOneWidget);
      expect(find.text(messages.dailyOsNextReviewTooMuch), findsNothing);

      await tester.tap(find.text(messages.dailyOsNextReviewAdjust));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.tap(find.text(messages.dailyOsNextReviewTooMuch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(agent.proposeCount, 1);
      expect(
        agent.proposedTranscript,
        messages.dailyOsNextReviewTooMuchPrompt,
      );
    });

    testWidgets(
      'accepted refine modal invalidates the current draft and keeps day page',
      (tester) async {
        _setSurface(tester);
        final draft = _drafted();
        final acceptedPlan = draft.copyWith(scheduledMinutes: 210);
        final diff = PlanDiff(
          id: 'diff_day',
          transcript: 'move one thing',
          changes: const [
            PlanDiffChange(
              id: 'chg_day',
              kind: PlanDiffChangeKind.moved,
              title: 'Move focus',
              category: _category,
              reason: 'one change resolves the modal',
              affectedBlockId: 'blk_1',
            ),
          ],
          updatedPlan: acceptedPlan,
        );
        final agent = RecordingDayAgent(diff: diff, acceptedPlan: acceptedPlan);
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextDayRefineCta));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        final element = tester.element(find.byType(RefineModalContent));
        final container = ProviderScope.containerOf(element);
        final notifier = container.read(
          refineControllerProvider(draft).notifier,
        );
        await notifier.finishWithTranscript('move one thing');
        await tester.pump();

        await tester.tap(find.text(messages.dailyOsNextRefineAccept));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(DayPage), findsOneWidget);
        expect(find.byType(RefineModalContent), findsNothing);
      },
    );

    testWidgets(
      'tapping Looks good beams to the DailyOS commit route',
      (tester) async {
        final agent = RecordingDayAgent();
        String? route;
        nav_service.beamToNamedOverride = (path) => route = path;
        final draft = _drafted();
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextReviewLooksGood));
        await tester.pump();

        expect(
          route,
          dailyOsNextRoutePath(DailyOsNextRouteTarget.commit, draft.dayDate),
        );
      },
    );

    testWidgets(
      'tapping Wrap up beams to the DailyOS shutdown route',
      (tester) async {
        final agent = RecordingDayAgent();
        String? route;
        nav_service.beamToNamedOverride = (path) => route = path;
        final draft = _drafted(state: DayState.committed);
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextDayWrapUpCta));
        await tester.pump();

        expect(
          route,
          dailyOsNextRoutePath(DailyOsNextRouteTarget.shutdown, draft.dayDate),
        );
        expect(find.byType(DayPage), findsOneWidget);
      },
    );

    testWidgets('Delete plan dialog Cancel does not call the agent', (
      tester,
    ) async {
      final agent = RecordingDayAgent();
      await _pumpDayPage(tester, draft: _drafted(), agent: agent);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final messages = tester.element(find.byType(DayPage)).messages;
      await tester.tap(find.text(messages.dailyOsNextDayMenuDeletePlan));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text(messages.dailyOsNextDayDeleteDialogCancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(agent.deleteCount, 0);
      expect(
        find.text(messages.dailyOsNextDayDeleteDialogTitle),
        findsNothing,
      );
    });
  });
}
