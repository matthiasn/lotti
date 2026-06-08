import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    as agent_providers;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';
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

/// Stub the realtime service so CaptureController (built by RefinePage
/// when DayPage pushes it) can dispose cleanly without touching the AI
/// providers during teardown.
CaptureController _stubCapture() {
  final recorder = MockAudioRecorderRepository();
  final transcriber = MockAudioTranscriptionService();
  final realtime = MockRealtimeTranscriptionService();
  when(realtime.dispose).thenAnswer((_) async {});
  when(realtime.resolveRealtimeConfig).thenAnswer((_) async => null);
  when(recorder.stopRecording).thenAnswer((_) async {});
  return CaptureController(
    recorder: recorder,
    transcriber: transcriber,
    realtimeService: realtime,
    docDir: Directory.systemTemp.createTempSync,
    persistAudio: (_) async => null,
    now: () => DateTime(2026, 5, 26, 9),
  );
}

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  List<TimeBlock> actualBlocks = const [],
  Size size = const Size(1400, 1200),
  MediaQueryData? mediaQueryData,
  ThemeData? theme,
}) {
  return makeTestableWidgetNoScroll(
    child,
    overrides: [
      // CapturesPanel watches this; stub to empty so the panel collapses
      // to SizedBox.shrink instead of touching the DB.
      capturesForDateProvider.overrideWith((ref, date) async => const []),
      dailyOsActualTimeBlocksProvider.overrideWith(
        (ref, date) async => actualBlocks,
      ),
      // RefinePage builds a CaptureController; stub so it doesn't read
      // the realtime service providers during dispose.
      captureControllerProvider.overrideWith(_stubCapture),
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
      'empty mode (no plan) lands on the Day view with the check-in CTA '
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

        // Lands on the Day projection so recorded time is visible.
        expect(find.byType(DayTimeline), findsOneWidget);
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

          // Switch to the Day projection.
          final messages = tester.element(find.byType(DayPage)).messages;
          await tester.tap(find.text(messages.dailyOsNextPlanViewDay));
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

    testWidgets('header keeps the plan toggle inline when it fits', (
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

      final dateTop = tester.getTopLeft(find.text(label)).dy;
      final dateBottom = tester.getBottomLeft(find.text(label)).dy;
      final toggleTop = tester.getTopLeft(find.byType(PlanViewToggle)).dy;
      final toggleBottom = tester.getBottomLeft(find.byType(PlanViewToggle)).dy;

      expect(toggleTop, lessThan(dateBottom));
      expect(toggleBottom, greaterThan(dateTop));
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

    testWidgets('drafted footer shows Refine + Lock In CTAs (no Wrap up)', (
      tester,
    ) async {
      _setSurface(tester);
      await tester.pumpWidget(_wrap(DayPage(draft: _drafted())));
      await tester.pump();

      final messages = tester.element(find.byType(DayPage)).messages;
      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      expect(find.text(messages.dailyOsNextDayRefineCta), findsOneWidget);
      expect(find.text(messages.dailyOsNextDayLockInCta), findsOneWidget);
      expect(find.text(messages.dailyOsNextDayWrapUpCta), findsNothing);
    });

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
      final lockInBottom = tester
          .getBottomLeft(find.text(messages.dailyOsNextDayLockInCta))
          .dy;

      expect(
        lockInBottom,
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
        expect(find.text(messages.dailyOsNextRefineTitle), findsOneWidget);
      },
    );

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
      'tapping Lock In beams to the DailyOS commit route',
      (tester) async {
        final agent = RecordingDayAgent();
        String? route;
        nav_service.beamToNamedOverride = (path) => route = path;
        final draft = _drafted();
        await _pumpDayPage(tester, draft: draft, agent: agent);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(find.text(messages.dailyOsNextDayLockInCta));
        await tester.pump();

        expect(
          route,
          dailyOsNextRoutePath(DailyOsNextRouteTarget.commit, draft.dayDate),
        );
        expect(find.byType(DayPage), findsOneWidget);
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
