import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/onboarding_event.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/daily_os_next/state/day_activity_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_next_root.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_onboarding_spotlight.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_activity_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/repositories/onboarding_metrics_repository.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/utils/device_region.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/service_overrides.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_utils/material_ui_finders.dart';
import '../../../../test_utils/screenshot_harness.dart';
import '../../../../widget_test_utils.dart';
import '../../test_doubles/mock_day_agent.dart';

final StreamProvider<int> _dailyOsRootReloadTickProvider = StreamProvider<int>(
  (ref) => const Stream<int>.empty(),
);

Widget _wrap(
  Widget child, {
  List<TimeBlock> actualBlocks = const [],
  List<Override> overrides = const [],
  DailyOsSetupStatus Function()? setupStatus,
  MediaQueryData mediaQueryData = const MediaQueryData(size: Size(1280, 900)),
}) {
  return ProviderScope(
    overrides: withServiceOverrides([
      dailyOsActualTimeBlocksProvider.overrideWith(
        (ref, _) async => actualBlocks,
      ),
      dayActivityProvider.overrideWith((ref, _) async => const []),
      firstDayOfWeekIndexProvider.overrideWith((ref) async => 1),
      dailyOsSetupStatusProvider.overrideWith(
        (ref) async =>
            setupStatus?.call() ??
            const DailyOsSetupStatus(
              hasInferenceRoute: true,
              hasPreferredName: true,
            ),
      ),
      ...overrides,
    ]),
    child: makeTestableWidget2(child, mediaQueryData: mediaQueryData),
  );
}

const _category = DayAgentCategory(
  id: 'cat',
  name: 'Work',
  colorHex: '5ED4B7',
);

DraftPlan _draftPlan() {
  return DraftPlan(
    dayDate: DateTime(2026, 5, 26),
    blocks: const [],
    bands: const [],
    capacityMinutes: 240,
    scheduledMinutes: 60,
    agendaItems: const [
      AgendaItem(
        id: 'a',
        title: 'Deep work',
        category: _category,
        linkedBlockIds: ['blk_1'],
      ),
    ],
  );
}

/// The week strip's cell for [day].
Finder _weekDay(DateTime day) =>
    find.byKey(ValueKey('daily_os_week_strip_${day.toIso8601String()}'));

/// The day page's masthead — the date as the page title, a button that opens
/// the picker.
final Finder _masthead = find.byKey(const Key('daily_os_day_masthead'));

/// Three frames: the selection, the re-keyed page, its plan.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

/// Recorder stub whose denied permission keeps toggle() a no-op error path,
/// so root-page tests never touch the mic or transcription stack.
/// Keeps the walkthrough's cadence bookkeeping off SettingsDb.
class _InMemoryOnboardingCadence extends DailyOsOnboardingCadence {
  @override
  Future<void> recordShown() async {}

  @override
  Future<void> markCompleted() async {}
}

/// Counts completions so a test can see the walkthrough retire its cadence.
class _CountingOnboardingCadence extends _InMemoryOnboardingCadence {
  _CountingOnboardingCadence(this.onCompleted);

  final void Function() onCompleted;

  @override
  Future<void> markCompleted() async => onCompleted();
}

/// Starts on a captured transcript so the create ritual can run straight
/// through Reconcile and Drafting without the recorder stack.
class _CapturedCaptureController extends CaptureController {
  @override
  CaptureState build() => const CaptureState(
    phase: CapturePhase.captured,
    transcript: 'Count the colony before the sardine delivery',
    amplitudes: [],
  );
}

/// Agent whose submitted check-ins are recorded, answering at once.
class _RecordingSubmitAgent extends MockDayAgent {
  _RecordingSubmitAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

  final submitted =
      <({String transcript, DateTime dayDate, String? audioId})>[];

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    required DateTime dayDate,
    String? audioId,
  }) async {
    submitted.add((transcript: transcript, dayDate: dayDate, audioId: audioId));
    return const CaptureId('cap_composer');
  }
}

/// Agent whose capture submit fails.
class _FailingSubmitAgent extends MockDayAgent {
  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    required DateTime dayDate,
    String? audioId,
  }) => Future.error(StateError('offline'));
}

/// Taps the mic of the empty Day's check-in composer.
Future<void> _tapCheckInMic(WidgetTester tester) => tester.tap(
  find.descendant(
    of: find.byKey(const Key('daily_os_day_check_in_cta')),
    matching: findMaterialTooltip(
      tester.element(find.byType(DayPage)).messages.chatInputRecordVoice,
    ),
  ),
);

/// Types [words] into the empty Day's check-in composer and sends them.
Future<void> _sendCheckInWords(WidgetTester tester, String words) async {
  final composer = find.byKey(const Key('daily_os_day_check_in_cta'));
  await tester.enterText(
    find.descendant(of: composer, matching: find.byType(TextField)),
    words,
  );
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: composer,
      matching: findMaterialTooltip(
        tester.element(find.byType(DayPage)).messages.chatInputSendTooltip,
      ),
    ),
  );
}

MockAudioRecorderRepository _permissionlessRecorder() {
  final recorder = MockAudioRecorderRepository();
  when(recorder.hasPermission).thenAnswer((_) async => false);
  when(recorder.stopRecording).thenAnswer((_) async {});
  return recorder;
}

void main() {
  // Several tests here assert width-driven layout decisions — whether the year
  // survives, whether Today fits. Those depend on real text metrics, so pin the
  // production fonts instead of inheriting whatever the run happened to load:
  // font loading is process-wide and cannot be undone, so an ambient default is
  // not a stable baseline in a bundled run.
  setUpAll(loadAppFonts);

  tearDown(() => nav_service.beamToNamedOverride = null);

  group('DailyOsNextRoot', () {
    testWidgets('keeps day navigation on the no-plan path', (
      tester,
    ) async {
      final requestedDates = <DateTime>[];

      await withClock(Clock.fixed(DateTime(2026, 5, 26, 16, 15)), () async {
        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            overrides: [
              captureControllerProvider.overrideWith(
                () => CaptureController(recorder: _permissionlessRecorder()),
              ),
              currentDraftPlanProvider.overrideWith((ref, date) async {
                requestedDates.add(date);
                return null;
              }),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Today · Tuesday'), findsOneWidget);

        await tester.tap(_weekDay(DateTime(2026, 5, 27)));
        await tester.pump();
        await tester.pump();
        // Third frame: the tracked-time projection resolves before the
        // root chooses between Capture and the empty Day surface.
        await tester.pump();

        expect(find.text('Tomorrow · Wednesday'), findsOneWidget);
        expect(find.text('May 27'), findsOneWidget);
        expect(requestedDates, contains(DateTime(2026, 5, 27)));
      });
    });

    testWidgets(
      'a no-plan day with tracked time lands on the empty Day surface; '
      'words sent from its composer open the planning sheet at Reconcile',
      (tester) async {
        final actualBlock = TimeBlock(
          id: 'actual:entry-1',
          title: 'Client follow-up',
          start: DateTime(2026, 5, 26, 9),
          end: DateTime(2026, 5, 26, 10),
          type: TimeBlockType.manual,
          state: TimeBlockState.completed,
          category: _category,
          taskId: 'task-1',
        );

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              actualBlocks: [actualBlock],
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => null),
                dayAgentProvider.overrideWithValue(_RecordingSubmitAgent()),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          // Recorded time is visible without creating a plan first
          // (handoff v2 item 2): the Day surface mounts in empty mode
          // with the tracked session on the timeline.
          expect(find.byType(DayPage), findsOneWidget);
          expect(find.byType(CapturePage), findsNothing);
          expect(find.text('Client follow-up'), findsOneWidget);
          // Honest "No plan yet" footer CTA instead of Refine/Commit.
          final cta = find.byKey(const Key('daily_os_day_check_in_cta'));
          expect(cta, findsOneWidget);
          expect(
            find.byKey(const Key('daily_os_day_refine_composer')),
            findsNothing,
          );

          // The composer was the capture: the sheet opens at Reconcile, with
          // no Capture step, and the Day surface stays mounted underneath.
          await _sendCheckInWords(tester, 'Finish the launch deck');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(ReconcileModalContent), findsOneWidget);
          expect(find.byType(CaptureModalContent), findsNothing);
          expect(find.byType(DayPage), findsOneWidget);
        });
      },
    );

    testWidgets('a sent check-in is submitted for the shown day', (
      tester,
    ) async {
      final agent = _RecordingSubmitAgent();
      await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            overrides: [
              captureControllerProvider.overrideWith(
                () => CaptureController(recorder: _permissionlessRecorder()),
              ),
              currentDraftPlanProvider.overrideWith((ref, _) async => null),
              dayAgentProvider.overrideWithValue(agent),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        await _sendCheckInWords(tester, '  Finish the launch deck  ');
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }

        expect(agent.submitted, hasLength(1));
        expect(agent.submitted.single.transcript, 'Finish the launch deck');
        expect(agent.submitted.single.dayDate, DateTime(2026, 5, 26));
        // Typed words carry no recording.
        expect(agent.submitted.single.audioId, isNull);
      });
    });

    testWidgets('a check-in that cannot be submitted says so and keeps '
        'the words', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            overrides: [
              captureControllerProvider.overrideWith(
                () => CaptureController(recorder: _permissionlessRecorder()),
              ),
              currentDraftPlanProvider.overrideWith((ref, _) async => null),
              dayAgentProvider.overrideWithValue(_FailingSubmitAgent()),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        await _sendCheckInWords(tester, 'Finish the launch deck');
        await tester.pump();
        await tester.pump();

        final messages = tester.element(find.byType(DayPage)).messages;
        expect(find.text(messages.dailyOsNextGenericError), findsOneWidget);
        expect(find.byType(ReconcileModalContent), findsNothing);
        expect(find.text('Finish the launch deck'), findsOneWidget);
      });
    });

    testWidgets('a check-in sent after setup was lost opens Daily OS '
        'settings instead', (tester) async {
      var hasInferenceRoute = true;
      String? route;
      nav_service.beamToNamedOverride = (path) => route = path;
      final agent = _RecordingSubmitAgent();
      await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            setupStatus: () => DailyOsSetupStatus(
              hasInferenceRoute: hasInferenceRoute,
              hasPreferredName: true,
            ),
            overrides: [
              captureControllerProvider.overrideWith(
                () => CaptureController(recorder: _permissionlessRecorder()),
              ),
              currentDraftPlanProvider.overrideWith((ref, _) async => null),
              dayAgentProvider.overrideWithValue(agent),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        final composer = find.byKey(const Key('daily_os_day_check_in_cta'));
        await tester.enterText(
          find.descendant(of: composer, matching: find.byType(TextField)),
          'Finish the launch deck',
        );
        await tester.pump();
        // The route goes away between rendering and sending.
        hasInferenceRoute = false;
        ProviderScope.containerOf(
          tester.element(find.byType(DailyOsNextRoot)),
        ).invalidate(dailyOsSetupStatusProvider);
        await tester.tap(
          find.descendant(
            of: composer,
            matching: findMaterialTooltip(
              tester
                  .element(find.byType(DayPage))
                  .messages
                  .chatInputSendTooltip,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(route, '/settings/daily-os');
        expect(agent.submitted, isEmpty);
        expect(find.byType(ReconcileModalContent), findsNothing);
      });
    });

    testWidgets('the composer mic records in place, with no sheet', (
      tester,
    ) async {
      final recorder = _permissionlessRecorder();
      await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            overrides: [
              captureControllerProvider.overrideWith(
                () => CaptureController(recorder: recorder),
              ),
              currentDraftPlanProvider.overrideWith((ref, _) async => null),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();
        verifyNever(recorder.hasPermission);

        await _tapCheckInMic(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Recording starts in the composer itself — the permission ask is its
        // first step — and no Capture sheet opens over the day.
        verify(recorder.hasPermission).called(1);
        expect(find.byType(CaptureModalContent), findsNothing);
        // Refused here, so the composer says why, in the Capture words.
        final messages = tester.element(find.byType(DayPage)).messages;
        expect(
          find.text(
            messages.dailyOsNextCaptureErrorMicrophonePermissionDenied,
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('dismissing the check-in modal records the walkthrough '
        'skip and ends the onboarding session', (tester) async {
      final metrics = MockOnboardingMetricsRepository();
      when(
        () => metrics.recordEvent(
          OnboardingEventName.dailyOsWalkthroughSkipped,
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<OnboardingMetricsRepository>(metrics);
      addTearDown(getIt.unregister<OnboardingMetricsRepository>);

      await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            overrides: [
              captureControllerProvider.overrideWith(
                () => CaptureController(recorder: _permissionlessRecorder()),
              ),
              currentDraftPlanProvider.overrideWith((ref, _) async => null),
              dayAgentProvider.overrideWithValue(_RecordingSubmitAgent()),
              dailyOsOnboardingCadenceProvider.overrideWith(
                _InMemoryOnboardingCadence.new,
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DailyOsNextRoot)),
        );
        final session = container
            .read(dailyOsOnboardingSessionControllerProvider.notifier)
            .start(targetDate: DateTime(2026, 5, 26), sessionId: 's-1');

        // The walkthrough's spotlight sits over the composer: a tap on it
        // opens the guided ritual, Capture step and all.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(DailyOsOnboardingSpotlight), findsOneWidget);
        await tester.tap(find.byKey(const Key('daily_os_day_check_in_cta')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(CaptureModalContent), findsOneWidget);
        expect(
          container.read(dailyOsOnboardingSessionControllerProvider),
          same(session),
        );

        // Tap the dim barrier outside the sheet: the modal resolves with no
        // plan, which the root routes to the session's dismissal.
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(CaptureModalContent), findsNothing);
        expect(
          container.read(dailyOsOnboardingSessionControllerProvider),
          isNull,
        );
        verify(
          () => metrics.recordEvent(
            OnboardingEventName.dailyOsWalkthroughSkipped,
            reason: any(named: 'reason'),
            valueBucket: any(named: 'valueBucket'),
          ),
        ).called(1);
      });
    });

    testWidgets('the guided Capture step keeps its own capture while the '
        'composer sits underneath', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            overrides: [
              captureControllerProvider.overrideWith(
                () => CaptureController(recorder: _permissionlessRecorder()),
              ),
              currentDraftPlanProvider.overrideWith((ref, _) async => null),
              dailyOsOnboardingCadenceProvider.overrideWith(
                _InMemoryOnboardingCadence.new,
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DailyOsNextRoot)),
        );
        container
            .read(dailyOsOnboardingSessionControllerProvider.notifier)
            .start(targetDate: DateTime(2026, 5, 26), sessionId: 's-1');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const Key('daily_os_day_check_in_cta')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(CaptureModalContent), findsOneWidget);

        final messages = tester.element(find.byType(DayPage)).messages;
        await tester.tap(
          find.widgetWithText(
            DsGlassPill,
            messages.dailyOsNextCaptureTypeInstead,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Typing opened in the sheet, and the composer below did not take it
        // back to rest.
        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.captured,
        );
      });
    });

    testWidgets('creating a plan through the check-in modal completes the '
        'walkthrough and ends the onboarding session', (tester) async {
      var completed = 0;
      await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            overrides: [
              captureControllerProvider.overrideWith(
                _CapturedCaptureController.new,
              ),
              dayAgentProvider.overrideWithValue(
                MockDayAgent(
                  parseLatency: Duration.zero,
                  pendingLatency: Duration.zero,
                  triageLatency: Duration.zero,
                  draftLatency: Duration.zero,
                  summarizeLatency: Duration.zero,
                ),
              ),
              currentDraftPlanProvider.overrideWith((ref, _) async => null),
              dailyOsOnboardingCadenceProvider.overrideWith(
                () => _CountingOnboardingCadence(() => completed++),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DailyOsNextRoot)),
        );
        container
            .read(dailyOsOnboardingSessionControllerProvider.notifier)
            .start(targetDate: DateTime(2026, 5, 26), sessionId: 's-1');

        // Through the walkthrough spotlight: the guided ritual from Capture.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const Key('daily_os_day_check_in_cta')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final messages = tester.element(find.byType(DayPage)).messages;

        Future<void> tapPill(String label) async {
          await tester.tap(find.widgetWithText(DsGlassPill, label));
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 80));
          }
        }

        await tapPill(messages.dailyOsNextCaptureReconcileCta);
        await tapPill(messages.dailyOsNextReconcileBuildDayCta);

        // Drafting resolved the modal with a created plan: the walkthrough
        // retires its cadence for good and the session ends.
        expect(find.byType(CaptureModalContent), findsNothing);
        expect(completed, 1);
        expect(
          container.read(dailyOsOnboardingSessionControllerProvider),
          isNull,
        );
      });
    });

    testWidgets('a route lost before check-in opens Daily OS settings', (
      tester,
    ) async {
      var hasInferenceRoute = true;
      String? route;
      nav_service.beamToNamedOverride = (path) => route = path;
      final actualBlock = TimeBlock(
        id: 'actual:entry-setup',
        title: 'Setup transition',
        start: DateTime(2026, 5, 26, 9),
        end: DateTime(2026, 5, 26, 10),
        type: TimeBlockType.manual,
        state: TimeBlockState.completed,
        category: _category,
      );

      await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            actualBlocks: [actualBlock],
            setupStatus: () => DailyOsSetupStatus(
              hasInferenceRoute: hasInferenceRoute,
              hasPreferredName: true,
            ),
            overrides: [
              currentDraftPlanProvider.overrideWith((ref, _) async => null),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        final rootContext = tester.element(find.byType(DailyOsNextRoot));
        hasInferenceRoute = false;
        ProviderScope.containerOf(rootContext).invalidate(
          dailyOsSetupStatusProvider,
        );
        await tester.pump();
        await tester.pump();
        // The footer now leads to setup instead of a check-in.
        await tester.tap(find.byKey(const Key('daily_os_day_check_in_cta')));
        await tester.pump();

        expect(route, '/settings/daily-os');
        expect(find.byType(CaptureModalContent), findsNothing);
        expect(find.byType(ReconcileModalContent), findsNothing);
      });
    });

    testWidgets('AsyncLoading shows the loading shell', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DailyOsNextRoot(),
          overrides: [
            captureControllerProvider.overrideWith(
              () => CaptureController(recorder: _permissionlessRecorder()),
            ),
            currentDraftPlanProvider.overrideWith(
              (ref, date) => Completer<DraftPlan?>().future,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CapturePage), findsNothing);
      expect(find.byType(DayPage), findsNothing);
    });

    testWidgets(
      'when a plan exists for the date, DayPage renders with day navigation',
      (tester) async {
        final plan = _draftPlan();

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                capturesForDateProvider.overrideWith(
                  (ref, _) async => const [],
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => plan),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.byType(DayPage), findsOneWidget);
          expect(find.byType(CapturePage), findsNothing);
          // The masthead names the day.
          expect(find.text('Today · Tuesday'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'keeps rendered day content during provider dependency reloads',
      (tester) async {
        final plan = _draftPlan();
        final pendingReload = Completer<DraftPlan?>();
        final reloadTicks = StreamController<int>.broadcast();
        addTearDown(() {
          if (!pendingReload.isCompleted) pendingReload.complete(plan);
          return reloadTicks.close();
        });

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                capturesForDateProvider.overrideWith(
                  (ref, _) async => const [],
                ),
                _dailyOsRootReloadTickProvider.overrideWith(
                  (ref) => reloadTicks.stream,
                ),
                currentDraftPlanProvider.overrideWith((ref, _) {
                  final tick =
                      ref.watch(_dailyOsRootReloadTickProvider).value ?? 0;
                  if (tick == 0) return plan;
                  return pendingReload.future;
                }),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.byType(DayPage), findsOneWidget);
          // The agenda row is the rendered content to keep; the page opens
          // on the Day timeline, so pick Agenda first.
          tester
              .widget<PlanViewToggle>(find.byType(PlanViewToggle))
              .onChanged(PlanView.agenda);
          await tester.pump();
          expect(find.text('Deep work'), findsOneWidget);

          reloadTicks.add(1);
          await tester.idle();
          await tester.pump();

          expect(find.byType(DayPage), findsOneWidget);
          expect(find.text('Deep work'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        });
      },
    );

    testWidgets(
      'keeps rendered day content during explicit provider refreshes',
      (tester) async {
        final plan = _draftPlan();
        final pendingRefresh = Completer<DraftPlan?>();
        var calls = 0;
        addTearDown(() {
          if (!pendingRefresh.isCompleted) pendingRefresh.complete(plan);
        });

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                capturesForDateProvider.overrideWith(
                  (ref, _) async => const [],
                ),
                currentDraftPlanProvider.overrideWith((ref, _) {
                  calls += 1;
                  return calls == 1 ? plan : pendingRefresh.future;
                }),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.byType(DayPage), findsOneWidget);
          tester
              .widget<PlanViewToggle>(find.byType(PlanViewToggle))
              .onChanged(PlanView.agenda);
          await tester.pump();
          expect(find.text('Deep work'), findsOneWidget);

          ProviderScope.containerOf(
            tester.element(find.byType(DailyOsNextRoot)),
          ).invalidate(
            currentDraftPlanProvider(DateTime(2026, 5, 26)),
          );
          await tester.pump();

          expect(calls, 2);
          expect(find.byType(DayPage), findsOneWidget);
          expect(find.text('Deep work'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        });
      },
    );

    testWidgets(
      'a day tapped in the week strip becomes the selected day',
      (tester) async {
        final requestedDates = <DateTime>[];

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                currentDraftPlanProvider.overrideWith((ref, date) async {
                  requestedDates.add(date);
                  return null;
                }),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          await tester.tap(_weekDay(DateTime(2026, 5, 25)));
          await _settle(tester);

          expect(find.text('Yesterday · Monday'), findsOneWidget);
          expect(find.text('May 25'), findsOneWidget);
          expect(requestedDates, contains(DateTime(2026, 5, 25)));
        });
      },
    );

    testWidgets(
      'the masthead opens the design-system picker; dismissing keeps the '
      'selection',
      (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => null),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();
          await tester.tap(_masthead);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(CalendarDatePicker), findsOneWidget);

          Navigator.of(
            tester.element(find.byType(CalendarDatePicker)),
          ).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(CalendarDatePicker), findsNothing);
          expect(find.text('May 26'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'a pick confirmed in the picker becomes the selected day',
      (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => null),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();
          await tester.tap(_masthead);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          tester
              .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
              .onDateChanged(DateTime(2026, 5, 20));
          await tester.pump();
          await tester.tap(find.text('Done'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();

          // Six days back, same year: the overline is the weekday alone.
          expect(find.text('Wednesday'), findsOneWidget);
          expect(find.text('May 20'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'a pick confirmed after the surface was disposed is dropped, not '
      'applied to a dead state',
      (tester) async {
        // The sheet lives on the app navigator, so the root can be torn
        // down (tab switch) while the sheet stays up. Swapping the root for
        // an empty box under a live MaterialApp reproduces exactly that.
        final showRoot = ValueNotifier<bool>(true);
        addTearDown(showRoot.dispose);
        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              ValueListenableBuilder<bool>(
                valueListenable: showRoot,
                builder: (context, show, _) =>
                    show ? const DailyOsNextRoot() : const SizedBox.shrink(),
              ),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => null),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          await tester.tap(_masthead);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(CalendarDatePicker), findsOneWidget);

          showRoot.value = false;
          await tester.pump();
          expect(find.byType(DailyOsNextRoot), findsNothing);
          expect(find.byType(CalendarDatePicker), findsOneWidget);

          // Confirm a pick against the disposed root: the `mounted` guard in
          // `_pickDate` drops it instead of reading a provider through a
          // dead ref.
          tester
              .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
              .onDateChanged(DateTime(2026, 5, 20));
          await tester.pump();
          await tester.tap(find.text('Done'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull);
          expect(find.byType(CalendarDatePicker), findsNothing);
        });
      },
    );

    testWidgets(
      'long-pressing the masthead returns the selection to today',
      (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => null),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();
          await tester.tap(_weekDay(DateTime(2026, 5, 29)));
          await _settle(tester);
          expect(find.text('May 29'), findsOneWidget);

          await tester.longPress(_masthead);
          await _settle(tester);

          expect(find.text('Today · Tuesday'), findsOneWidget);
          expect(find.text('May 26'), findsOneWidget);
          expect(find.text('May 29'), findsNothing);
        });
      },
    );

    testWidgets(
      "the picker's own Today action returns the selection to today",
      (tester) async {
        setTestSurfaceSize(tester, const Size(390, 844));
        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              mediaQueryData: const MediaQueryData(size: Size(390, 844)),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => null),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          await tester.tap(_weekDay(DateTime(2026, 5, 27)));
          await _settle(tester);
          expect(find.text('May 27'), findsOneWidget);

          // A phone has no Today button: the picker's own Today quick action
          // is the way back besides the long press.
          await tester.tap(_masthead);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(CalendarDatePicker), findsOneWidget);

          await tester.tap(find.byKey(designSystemDatePickerTodayKey));
          await tester.pump();
          await tester.tap(find.text('Done'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();

          expect(find.text('Today · Tuesday'), findsOneWidget);
          expect(find.text('May 27'), findsNothing);
        });
      },
    );

    testWidgets(
      "a selection far from today still gets the picker's Today action, and "
      'its masthead names the year',
      (tester) async {
        setTestSurfaceSize(tester, const Size(390, 844));
        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              mediaQueryData: const MediaQueryData(size: Size(390, 844)),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => null),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          // More than a year out. Anchoring the picker window on the
          // selection alone would put today outside it, and the picker
          // disables its own Today action when today is out of range.
          ProviderScope.containerOf(
                tester.element(find.byType(DailyOsNextRoot)),
              )
              .read(dailyOsNextSelectedDateProvider.notifier)
              .select(DateTime(2028, 2, 10));
          await _settle(tester);
          expect(find.text('Thursday · 2028'), findsOneWidget);

          await tester.tap(_masthead);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(CalendarDatePicker), findsOneWidget);

          await tester.tap(find.byKey(designSystemDatePickerTodayKey));
          await tester.pump();
          await tester.tap(find.text('Done'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();

          expect(find.text('Today · Tuesday'), findsOneWidget);
          expect(find.text('Feb 10'), findsNothing);
        });
      },
    );

    testWidgets(
      'the selected plan view survives day navigation and jump-to-today',
      (tester) async {
        final plan = _draftPlan();

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                capturesForDateProvider.overrideWith(
                  (ref, _) async => const [],
                ),
                currentDraftPlanProvider.overrideWith(
                  (ref, date) async => plan.copyWith(dayDate: date),
                ),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          // The default projection is the Day timeline, plan or not.
          expect(find.byType(DayTimeline), findsOneWidget);
          expect(find.byType(AgendaView), findsNothing);

          tester
              .widget<PlanViewToggle>(find.byType(PlanViewToggle))
              .onChanged(PlanView.agenda);
          await tester.pump();
          expect(find.byType(AgendaView), findsOneWidget);
          expect(find.byType(DayTimeline), findsNothing);

          // Day navigation re-keys the page; it must not bounce the user
          // back to the Day default.
          await tester.tap(_weekDay(DateTime(2026, 5, 27)));
          await _settle(tester);
          expect(find.text('May 27'), findsOneWidget);
          expect(find.byType(AgendaView), findsOneWidget);
          expect(find.byType(DayTimeline), findsNothing);
          expect(find.byType(DayActivityView), findsNothing);

          // Neither does the jump back to today.
          await tester.longPress(_masthead);
          await _settle(tester);
          expect(find.text('Today · Tuesday'), findsOneWidget);
          expect(find.byType(AgendaView), findsOneWidget);
          expect(find.byType(DayTimeline), findsNothing);
          expect(find.byType(DayActivityView), findsNothing);
        });
      },
    );

    testWidgets(
      'AsyncError shows the error shell with the error message',
      (tester) async {
        const errorMessage = 'day-agent unavailable';

        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            overrides: [
              currentDraftPlanProvider.overrideWith(
                (ref, date) => Future<DraftPlan?>.error(
                  Exception(errorMessage),
                  StackTrace.empty,
                ),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        // The error shell must be shown and must contain the error text.
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(CapturePage), findsNothing);
        expect(find.byType(DayPage), findsNothing);
        expect(
          find.textContaining(errorMessage),
          findsOneWidget,
          reason: 'error text must be rendered by _ErrorShell',
        );
      },
    );
  });
}
