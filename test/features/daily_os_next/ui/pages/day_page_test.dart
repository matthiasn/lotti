import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    as agent_providers;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page_header.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_activity_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_block_task_picker.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_composer.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_week_strip.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_utils/material_ui_finders.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';
import '../../../categories/test_utils.dart';
import '../../test_utils.dart';
import 'day_page_test_helpers.dart';

// The fixtures live in day_page_test_helpers.dart, shared with the
// header-layout suite; these aliases keep this file's call sites unchanged.
const DayAgentCategory _category = dayPageCategory;
const DraftPlan Function({DayState state, String title}) _drafted = draftedPlan;
const Widget Function(
  Widget, {
  List<TimeBlock> actualBlocks,
  List<DayActivityEntry> activityEntries,
  MediaQueryData? mediaQueryData,
  List<Override> overrides,
  DailyOsSetupStatus? setupStatus,
  Size size,
  ThemeData? theme,
})
_wrap = wrapDayPage;

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

/// Types [words] into a planned Day's composer and sends them to Refine.
Future<void> _sendRefineWords(WidgetTester tester, String words) async {
  final composer = find.byKey(const Key('daily_os_day_refine_composer'));
  await tester.enterText(
    find.descendant(of: composer, matching: find.byType(TextField)),
    words,
  );
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: composer,
      matching: findMaterialTooltip(
        tester.element(composer).messages.chatInputSendTooltip,
      ),
    ),
  );
}

/// Types [words] into the empty Day's check-in composer and sends them.
Future<void> _sendCheckIn(WidgetTester tester, String words) async {
  final composer = find.byType(DayComposer);
  await tester.enterText(
    find.descendant(of: composer, matching: find.byType(TextField)),
    words,
  );
  await tester.pump();
  await tester.tap(
    findMaterialTooltip(
      tester.element(composer).messages.chatInputSendTooltip,
    ),
  );
  await tester.pump();
}

void _setSurface(WidgetTester tester) {
  setTestSurfaceSize(tester, const Size(1400, 1200));
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
    testWidgets('lands on the Day timeline by default, under its date, '
        'with Agenda a tap away', (tester) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      expect(find.text('May 26'), findsOneWidget);
      expect(find.byType(DayTimeline), findsOneWidget);
      expect(find.byType(AgendaView), findsNothing);
      expect(find.byType(DayActivityView), findsNothing);
      expect(
        tester.widget<PlanViewToggle>(find.byType(PlanViewToggle)).selected,
        PlanView.day,
      );

      tester
          .widget<PlanViewToggle>(find.byType(PlanViewToggle))
          .onChanged(PlanView.agenda);
      await tester.pump();

      expect(find.byType(AgendaView), findsOneWidget);
      expect(find.byType(DayTimeline), findsNothing);
    });

    testWidgets(
      'empty mode (no plan) lands on the Day timeline with the check-in CTA '
      'instead of Refine/Commit, and hides the delete-plan menu entry',
      (tester) async {
        _setSurface(tester);
        final checkIns = <String>[];
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
              onSubmitCheckIn: (words, {audioId}) async => checkIns.add(words),
            ),
            actualBlocks: [tracked],
          ),
        );
        await tester.pump();
        await tester.pump();

        // Already-tracked time is visible on the timeline without a plan;
        // failed or pending recordings — the no-plan recovery path — stay one
        // tap away on Activity.
        expect(find.byType(DayTimeline), findsOneWidget);
        expect(find.byType(DayActivityView), findsNothing);
        expect(find.byType(AgendaView), findsNothing);
        expect(find.text('Recorded session'), findsOneWidget);
        tester
            .widget<PlanViewToggle>(find.byType(PlanViewToggle))
            .onChanged(PlanView.activity);
        await tester.pump();
        await tester.pump();
        expect(find.byType(DayActivityView), findsOneWidget);
        expect(find.byType(DayTimeline), findsNothing);
        expect(find.text('Recorded session'), findsOneWidget);

        // Footer is the check-in composer, not Refine/Commit.
        final messages = tester.element(find.byType(DayPage)).messages;
        expect(
          find.byKey(const Key('daily_os_day_refine_composer')),
          findsNothing,
        );
        expect(find.text(messages.dailyOsNextDayLockInCta), findsNothing);
        final cta = find.byKey(const Key('daily_os_day_check_in_cta'));
        expect(cta, findsOneWidget);
        expect(find.byType(DayComposer), findsOneWidget);
        await _sendCheckIn(tester, 'Finish the deck');
        expect(checkIns, ['Finish the deck']);

        // The overflow menu offers no delete-plan entry without a plan.
        await tester.tap(find.byIcon(LottiIcons.moreVertical));
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
              onSubmitCheckIn: (words, {audioId}) async =>
                  fail('check-in must stay blocked'),
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
        expect(find.byType(DayComposer), findsNothing);

        // A plain row in warning ink, not a card of its own.
        final tokens = tester.element(find.byType(DayPage)).designTokens;
        final nudge = find.byKey(const Key('daily_os_setup_nudge'));
        expect(
          tester
              .widget<Icon>(
                find.descendant(
                  of: nudge,
                  matching: find.byIcon(LottiIcons.warning),
                ),
              )
              .color,
          tokens.colors.alert.warning.ink,
        );
        expect(
          tester
              .widget<Text>(
                find.text(messages.dailyOsSettingsSetupRequiredTitle),
              )
              .style
              ?.color,
          tokens.colors.alert.warning.ink,
        );
        expect(
          find.descendant(of: nudge, matching: find.byType(DecoratedBox)),
          findsNothing,
        );

        await tester.tap(find.byIcon(LottiIcons.moreVertical));
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
          status: DayProcessingJobStatus.succeeded,
          dayId: 'dayplan-2026-05-26',
          payload: const TranscribeAudioPayload(
            activityEntryId: 'activity-retained',
            recordingSessionId: 'session-retained',
            audioId: 'audio-retained',
            audioPath: '/tmp/audio-retained.wav',
          ),
          createdAt: sourceCapturedAt,
          updatedAt: sourceCapturedAt,
          requestedAt: sourceCapturedAt,
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
        // The surface opens on the Day timeline; the recovery row lives on
        // Activity.
        tester
            .widget<PlanViewToggle>(find.byType(PlanViewToggle))
            .onChanged(PlanView.activity);
        await tester.pump();
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

      // The surface opens on the Day timeline; the recovery row lives on
      // Activity.
      tester
          .widget<PlanViewToggle>(find.byType(PlanViewToggle))
          .onChanged(PlanView.activity);
      await tester.pump();
      await tester.pump();
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
          changes: const [],
          updatedPlan: _drafted(),
        ),
      );
      final capturedAt = DateTime(2026, 5, 26, 8);
      final job = DayProcessingJob(
        id: 'activity-refine-job',
        status: DayProcessingJobStatus.succeeded,
        dayId: 'dayplan-2026-05-26',
        payload: const TranscribeAudioPayload(
          activityEntryId: 'activity-refine',
          recordingSessionId: 'activity-refine-session',
          audioId: 'activity-refine-audio',
          audioPath: '/tmp/activity-refine.wav',
        ),
        createdAt: capturedAt,
        updatedAt: capturedAt,
        requestedAt: capturedAt,
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
      final checkIns = <String>[];
      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: DraftPlan.emptyForDay(DateTime(2026, 5, 26)),
            hasPlan: false,
            onSubmitCheckIn: (words, {audioId}) async => checkIns.add(words),
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
      expect(find.byType(DayComposer), findsOneWidget);

      await _sendCheckIn(tester, 'Finish the deck');
      expect(checkIns, ['Finish the deck']);
    });

    testWidgets('the composer stays closed until setup status is known', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(
        _wrap(
          DayPage(
            draft: DraftPlan.emptyForDay(DateTime(2026, 5, 26)),
            hasPlan: false,
            onSubmitCheckIn: (words, {audioId}) async =>
                fail('no check-in before setup status is known'),
          ),
          setupStatus: null,
        ),
      );
      await tester.pump();
      await tester.pump();

      // The composer holds its place, so the footer does not jump, but takes
      // no words: they would be lost if setup turns out to be missing.
      expect(find.byType(DayComposer), findsOneWidget);
      final field = find.descendant(
        of: find.byType(DayComposer),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).enabled, isFalse);
      // The mic stays in its place too, but cannot open a take.
      expect(
        tester
            .widget<DesignSystemChatInputDisc>(
              find.byKey(DesignSystemChatInputKeys.mic),
            )
            .onPressed,
        isNull,
      );
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
        // Agenda rows are the inline-rename surface; the page opens on Day.
        tester
            .widget<PlanViewToggle>(find.byType(PlanViewToggle))
            .onChanged(PlanView.agenda);
        await tester.pump();

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
          find.widgetWithText(TextField, block.title),
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

    group('block actions', () {
      TimeBlock blockFor({String? taskId}) => TimeBlock(
        id: 'blk_act',
        title: 'Sort the sardine shipment',
        start: DateTime(2026, 5, 26, 9),
        end: DateTime(2026, 5, 26, 10),
        type: TimeBlockType.manual,
        state: TimeBlockState.drafted,
        category: _category,
        taskId: taskId,
      );

      Future<AppLocalizations> openEditor(
        WidgetTester tester, {
        required RecordingDayAgent agent,
        TimeBlock? block,
        Task? picked,
      }) async {
        final shown = block ?? blockFor();
        _setSurface(tester);
        await tester.pumpWidget(
          _wrap(
            DayPage(
              draft: DraftPlan(
                dayDate: DateTime(2026, 5, 26),
                blocks: [shown],
                bands: const [],
                capacityMinutes: 240,
                scheduledMinutes: 60,
              ),
            ),
            overrides: [
              dayAgentProvider.overrideWithValue(agent),
              dayBlockTaskPickerProvider.overrideWithValue(
                (_) async => picked,
              ),
            ],
          ),
        );
        await tester.pump();
        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextPlanViewDay).last);
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byKey(Key('daily_os_edit_block_${shown.id}')));
        await tester.pumpAndSettle();
        return messages;
      }

      Future<void> tapText(WidgetTester tester, String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }

      DesignSystemToast toast(WidgetTester tester) =>
          tester.widget<DesignSystemToast>(find.byType(DesignSystemToast));

      testWidgets('remove takes the block off, and Undo puts it back', (
        tester,
      ) async {
        final agent = RecordingDayAgent();
        final messages = await openEditor(tester, agent: agent);

        await tapText(tester, messages.dailyOsNextBlockRemove);

        expect(agent.blockActions.single.action, 'remove');
        expect(agent.blockActions.single.blockId, 'blk_act');
        expect(find.text(messages.dailyOsNextBlockRemoved), findsOneWidget);
        expect(toast(tester).action?.label, messages.designSystemUndoLabel);

        toast(tester).action!.onPressed();
        await tester.pump();
        await tester.pump();

        expect(agent.blockActions.map((call) => call.action), [
          'remove',
          'restore',
        ]);
      });

      testWidgets('link picks a task and ties the block to it', (
        tester,
      ) async {
        final agent = RecordingDayAgent();
        final messages = await openEditor(
          tester,
          agent: agent,
          picked: testTask,
        );

        await tapText(tester, messages.dailyOsNextBlockLinkTask);

        expect(agent.blockActions.single.action, 'link');
        expect(agent.blockActions.single.taskId, testTask.meta.id);
        expect(find.text(messages.dailyOsNextBlockLinked), findsOneWidget);
      });

      testWidgets('closing the picker links nothing', (tester) async {
        final agent = RecordingDayAgent();
        final messages = await openEditor(tester, agent: agent);

        await tapText(tester, messages.dailyOsNextBlockLinkTask);

        expect(agent.blockActions, isEmpty);
        expect(find.byType(DesignSystemToast), findsNothing);
      });

      testWidgets('create makes a task and offers to open it', (tester) async {
        final routes = <String>[];
        nav_service.beamToNamedOverride = routes.add;
        final agent = RecordingDayAgent();
        final messages = await openEditor(tester, agent: agent);

        await tapText(tester, messages.dailyOsNextBlockCreateTask);

        expect(agent.blockActions.single.action, 'create');
        expect(
          find.text(messages.dailyOsNextBlockTaskCreated),
          findsOneWidget,
        );
        expect(
          toast(tester).action?.label,
          messages.dailyOsNextBlockEditOpenTask,
        );
        toast(tester).action!.onPressed();
        expect(routes, ['/tasks/task-for-blk_act']);
      });

      testWidgets('a task made but not linked says so and still opens', (
        tester,
      ) async {
        final routes = <String>[];
        nav_service.beamToNamedOverride = routes.add;
        final agent = RecordingDayAgent(createdTaskNotLinked: true);
        final messages = await openEditor(tester, agent: agent);

        await tapText(tester, messages.dailyOsNextBlockCreateTask);

        expect(
          find.text(messages.dailyOsNextBlockTaskCreatedNotLinked),
          findsOneWidget,
        );
        expect(find.text(messages.dailyOsNextBlockEditFailed), findsNothing);
        expect(toast(tester).tone, DesignSystemToastTone.warning);
        toast(tester).action!.onPressed();
        expect(routes, ['/tasks/task-for-blk_act']);
      });

      testWidgets('a task-linked block unlinks from its task', (tester) async {
        final agent = RecordingDayAgent();
        final messages = await openEditor(
          tester,
          agent: agent,
          block: blockFor(taskId: 'task-1'),
        );

        await tapText(tester, messages.dailyOsNextBlockUnlinkTask);

        expect(agent.blockActions.single.action, 'unlink');
        expect(find.text(messages.dailyOsNextBlockUnlinked), findsOneWidget);
      });

      testWidgets('a failing action says so', (tester) async {
        final agent = RecordingDayAgent(
          blockActionError: StateError('offline'),
        );
        final messages = await openEditor(tester, agent: agent);

        await tapText(tester, messages.dailyOsNextBlockRemove);

        expect(find.text(messages.dailyOsNextBlockEditFailed), findsOneWidget);
        expect(find.text(messages.dailyOsNextBlockRemoved), findsNothing);
      });
    });

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
        await tester.enterText(
          find.widgetWithText(TextField, block.title),
          'Count all sardines',
        );
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
      await tester.enterText(
        find.widgetWithText(TextField, block.title),
        'Count every herring',
      );
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

        await tester.tap(find.byIcon(LottiIcons.moreVertical));
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

    testWidgets(
      'day navigation brings the week strip and drops the back chevron',
      (tester) async {
        _setSurface(tester);
        await tester.pumpWidget(
          _wrap(
            DayPage(
              draft: _drafted(),
              navigation: DayNavigation(
                today: DateTime(2026, 5, 26),
                onSelect: (_) {},
                onPick: () {},
                onToday: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(DayWeekStrip), findsOneWidget);
        expect(find.byIcon(LottiIcons.back), findsNothing);
        expect(find.text('Today · Tuesday'), findsOneWidget);
      },
    );

    testWidgets('toggling the plan view switches DayTimeline → Agenda → '
        'DayTimeline', (tester) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      expect(find.byType(DayTimeline), findsOneWidget);
      expect(find.byType(AgendaView), findsNothing);

      // Drive the toggle directly; chip tap behavior is covered by
      // PlanViewToggle's focused widget tests.
      final toggle = tester.widget<PlanViewToggle>(find.byType(PlanViewToggle));
      toggle.onChanged(PlanView.agenda);
      await tester.pump();

      expect(find.byType(AgendaView), findsOneWidget);
      expect(find.byType(DayTimeline), findsNothing);

      tester
          .widget<PlanViewToggle>(find.byType(PlanViewToggle))
          .onChanged(PlanView.day);
      await tester.pump();

      expect(find.byType(AgendaView), findsNothing);
      expect(find.byType(DayTimeline), findsOneWidget);
    });

    testWidgets('a drafted day: Looks good beside the composer, quick '
        'refinements over it', (tester) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _draftedWithReasons())));
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      final composer = find.byKey(const Key('daily_os_day_refine_composer'));
      // The day's next step sits in the footer, in thumb reach — never in
      // the header.
      expect(
        find.descendant(
          of: composer,
          matching: find.text(messages.dailyOsNextReviewLooksGood),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DayHeader),
          matching: find.text(messages.dailyOsNextReviewLooksGood),
        ),
        findsNothing,
      );
      expect(find.text(messages.dailyOsNextDayWrapUpCta), findsNothing);
      expect(composer, findsOneWidget);
      expect(
        find.descendant(
          of: composer,
          matching: find.text(messages.dailyOsNextRefineHeadlineIdle),
        ),
        findsOneWidget,
      );
      for (final chip in [
        messages.dailyOsNextReviewTooMuch,
        messages.dailyOsNextReviewMoveLighter,
        messages.dailyOsNextReviewAddBuffer,
      ]) {
        expect(
          find.descendant(of: composer, matching: find.text(chip)),
          findsOneWidget,
        );
      }
      // The block reasons stay on the blocks, not repeated in the footer.
      expect(
        find.descendant(
          of: find.byType(DesignSystemGlassStrip),
          matching: find.text('Morning is the strongest focus window.'),
        ),
        findsNothing,
      );
    });

    testWidgets('a committed day: Wrap up beside the composer, no chips', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(
        _wrap(DayPage(draft: _drafted(state: DayState.committed))),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(
        find.descendant(
          of: find.byKey(const Key('daily_os_day_refine_composer')),
          matching: find.text(messages.dailyOsNextDayWrapUpCta),
        ),
        findsOneWidget,
      );
      expect(find.text(messages.dailyOsNextReviewLooksGood), findsNothing);
      expect(
        find.byKey(const Key('daily_os_day_refine_composer')),
        findsOneWidget,
      );
      expect(find.text(messages.dailyOsNextReviewTooMuch), findsNothing);
    });

    testWidgets('Wrap up opens the shutdown for the day', (tester) async {
      String? route;
      nav_service.beamToNamedOverride = (path) => route = path;
      _setSurface(tester);
      await tester.pumpWidget(
        _wrap(DayPage(draft: _drafted(state: DayState.committed))),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      await tester.tap(find.text(messages.dailyOsNextDayWrapUpCta));
      await tester.pump();

      expect(route, contains('shutdown'));
    });

    for (final (name, size, scale) in [
      ('an iPhone SE viewport', const Size(320, 568), 1.0),
      ('an iPhone SE viewport at large text', const Size(320, 568), 2.0),
    ]) {
      testWidgets('the drafted footer and header fit $name', (tester) async {
        final mediaQueryData = phoneMediaQueryData.copyWith(
          size: size,
          textScaler: TextScaler.linear(scale),
        );
        setTestSurfaceSize(tester, size);
        await tester.pumpWidget(
          _wrap(
            DayPage(draft: _draftedWithReasons()),
            mediaQueryData: mediaQueryData,
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(DayPage)).messages;
        expect(find.text(messages.dailyOsNextReviewLooksGood), findsOneWidget);
        // Large text gives the chips' room back to the day.
        expect(
          find.text(messages.dailyOsNextReviewTooMuch),
          scale < 1.5 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const Key('daily_os_day_refine_composer')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('syncs displayed agenda when the draft prop changes', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();
      tester
          .widget<PlanViewToggle>(find.byType(PlanViewToggle))
          .onChanged(PlanView.agenda);
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
      final composerBottom = tester
          .getBottomLeft(
            find.byKey(const Key('daily_os_day_refine_composer')),
          )
          .dy;

      expect(
        composerBottom,
        lessThanOrEqualTo(phoneMediaQueryData.size.height - bottomNavHeight),
      );
    });

    testWidgets('popup menu exposes Inspect agent + Delete plan items', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      await tester.tap(find.byIcon(LottiIcons.moreVertical));
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

      await tester.tap(find.byIcon(LottiIcons.moreVertical));
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

        await tester.tap(find.byIcon(LottiIcons.moreVertical));
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
      'header back IconButton pops the navigator (no day navigation)',
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

        // The header shows a back button only without day navigation;
        // the popup-menu's more_vert icon stays in place.
        await tester.tap(find.byIcon(LottiIcons.back));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(popped, isTrue);
        expect(find.byType(DayPage), findsNothing);
      },
    );

    testWidgets(
      'words sent from the composer go straight into Refine over the day',
      (tester) async {
        final agent = RecordingDayAgent();
        await _pumpDayPage(tester, draft: _drafted(), agent: agent);

        await _sendRefineWords(tester, 'Move the run to the evening');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        expect(find.byType(DayPage), findsOneWidget);
        expect(find.byType(RefineModalContent), findsOneWidget);
        expect(agent.proposeCount, 1);
        expect(agent.proposedTranscript, 'Move the run to the evening');
      },
    );

    testWidgets('the composer empties once the Refine it opened is done', (
      tester,
    ) async {
      final agent = RecordingDayAgent();
      await _pumpDayPage(tester, draft: _drafted(), agent: agent);

      await _sendRefineWords(tester, 'Lighter afternoon');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      Navigator.of(tester.element(find.byType(RefineModalContent))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('daily_os_day_refine_composer')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets(
      'quick review action opens refine modal and submits its seeded prompt',
      (tester) async {
        final agent = RecordingDayAgent(
          diff: PlanDiff(
            id: 'quick_diff',
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

    testWidgets(
      'accepted refine modal invalidates the current draft and keeps day page',
      (tester) async {
        _setSurface(tester);
        final draft = _drafted();
        final acceptedPlan = draft.copyWith(scheduledMinutes: 210);
        final diff = PlanDiff(
          id: 'diff_day',
          changes: const [
            PlanDiffChange(
              id: 'chg_day',
              kind: PlanDiffChangeKind.moved,
              title: 'Move focus',
              category: _category,
              reason: 'one change resolves the modal',
            ),
          ],
          updatedPlan: acceptedPlan,
        );
        final agent = RecordingDayAgent(diff: diff, acceptedPlan: acceptedPlan);
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await _sendRefineWords(tester, 'Move focus');
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
      'Looks good commits the day in place, and Undo takes it back',
      (tester) async {
        final agent = RecordingDayAgent();
        String? route;
        nav_service.beamToNamedOverride = (path) => route = path;
        final draft = _drafted();
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextReviewLooksGood));
        await tester.pump();
        await tester.pump();

        // No sign-off page in between: the tap is the commit.
        expect(route, isNull);
        expect(agent.commitCount, 1);
        expect(agent.capturedPlan, draft);
        expect(find.text(messages.dailyOsNextCommitDone), findsOneWidget);

        final toast = tester.widget<DesignSystemToast>(
          find.byType(DesignSystemToast),
        );
        expect(toast.action?.label, messages.designSystemUndoLabel);
        toast.action!.onPressed();
        await tester.pump();
        await tester.pump();

        expect(agent.uncommitCount, 1);
        expect(find.text(messages.dailyOsNextUncommitFailed), findsNothing);
      },
    );

    testWidgets('a failed commit says so and offers no undo', (tester) async {
      final agent = RecordingDayAgent(commitError: StateError('offline'));
      await _pumpDayPage(tester, draft: _drafted(), agent: agent);

      final messages = tester.element(find.byType(DayPage)).messages;
      await tester.tap(find.text(messages.dailyOsNextReviewLooksGood));
      await tester.pump();
      await tester.pump();

      expect(agent.commitCount, 1);
      expect(find.text(messages.dailyOsNextCommitFailed), findsOneWidget);
      expect(find.text(messages.dailyOsNextCommitDone), findsNothing);
      expect(find.text(messages.designSystemUndoLabel), findsNothing);
      expect(agent.uncommitCount, 0);
    });

    testWidgets('a failed undo says the plan stays committed', (tester) async {
      final agent = RecordingDayAgent(uncommitError: StateError('offline'));
      await _pumpDayPage(tester, draft: _drafted(), agent: agent);

      final messages = tester.element(find.byType(DayPage)).messages;
      await tester.tap(find.text(messages.dailyOsNextReviewLooksGood));
      await tester.pump();
      await tester.pump();
      tester
          .widget<DesignSystemToast>(find.byType(DesignSystemToast))
          .action!
          .onPressed();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(agent.uncommitCount, 1);
      expect(find.text(messages.dailyOsNextUncommitFailed), findsOneWidget);
    });

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

      await tester.tap(find.byIcon(LottiIcons.moreVertical));
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
