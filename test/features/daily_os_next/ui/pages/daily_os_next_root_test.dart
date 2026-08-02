import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/day_activity_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_next_root.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_activity_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/utils/device_region.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

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
    overrides: [
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
    ],
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

/// Recorder stub whose denied permission keeps toggle() a no-op error path,
/// so root-page tests never touch the mic or transcription stack.
/// Sizes the test view so a "phone" test really lays out at phone width —
/// a MediaQuery override alone leaves the render tree on the 800x600
/// default surface, where a squeezed header would still have room.
void _setSurfaceSize(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size * tester.view.devicePixelRatio
    ..devicePixelRatio = tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
}

MockAudioRecorderRepository _permissionlessRecorder() {
  final recorder = MockAudioRecorderRepository();
  when(recorder.hasPermission).thenAnswer((_) async => false);
  when(recorder.stopRecording).thenAnswer((_) async {});
  return recorder;
}

void main() {
  tearDown(() => nav_service.beamToNamedOverride = null);

  group('DailyOsNextRoot', () {
    testWidgets('keeps the date strip visible on the capture path', (
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

        expect(find.text('Today'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pump();
        await tester.pump();
        // Third frame: the tracked-time projection resolves before the
        // root chooses between Capture and the empty Day surface.
        await tester.pump();

        expect(find.text('Wed, May 27, 2026'), findsOneWidget);
        expect(requestedDates, contains(DateTime(2026, 5, 27)));
      });
    });

    testWidgets(
      'a no-plan day with tracked time lands on the empty Day surface; '
      'the check-in CTA opens the day-planning modal over it',
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
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          // Recorded time is visible without creating a plan first
          // (handoff v2 item 2): the Day surface mounts in empty mode
          // with the tracked session on the timeline.
          final messages = tester.element(find.byType(DayPage)).messages;
          expect(find.byType(DayPage), findsOneWidget);
          expect(find.byType(CapturePage), findsNothing);
          expect(find.text('Client follow-up'), findsOneWidget);
          // Honest "No plan yet" footer CTA instead of Refine/Commit.
          final cta = find.byKey(const Key('daily_os_day_check_in_cta'));
          expect(cta, findsOneWidget);
          expect(find.text(messages.dailyOsNextDayRefineCta), findsNothing);

          // The CTA opens the day-planning modal (Capture step) as a
          // full-cover layer; the Day surface stays mounted underneath.
          await tester.tap(cta);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(CaptureModalContent), findsOneWidget);
          expect(find.byType(DayPage), findsOneWidget);
          // The tracked-time the user saw on the Day surface now also rides
          // the top of the modal's capture step (handoff v2 item 1): the
          // session title appears both on the timeline and in the card.
          expect(find.text('Client follow-up'), findsNWidgets(2));
        });
      },
    );

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
        await tester.tap(find.byKey(const Key('daily_os_day_check_in_cta')));
        await tester.pump();

        expect(route, '/settings/daily-os');
        expect(find.byType(CaptureModalContent), findsNothing);
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
      'when a plan exists for the date, DayPage renders with the date strip',
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
          expect(find.text('Today'), findsOneWidget); // date strip label.
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
      'prev chevron shifts the selected date back by one day',
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

          await tester.tap(find.byIcon(Icons.chevron_left_rounded));
          await tester.pump();
          await tester.pump();
          await tester.pump();

          expect(find.text('Mon, May 25, 2026'), findsOneWidget);
          expect(requestedDates, contains(DateTime(2026, 5, 25)));
        });
      },
    );

    testWidgets(
      'the date label opens the design-system picker; dismissing keeps '
      'the selection',
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

          await tester.tap(find.text('Today'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(CalendarDatePicker), findsOneWidget);

          Navigator.of(
            tester.element(find.byType(CalendarDatePicker)),
          ).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(CalendarDatePicker), findsNothing);
          expect(find.text('Today'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'long-pressing the date label returns selection to today',
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

          // Shift forward one day so we have a non-today selection.
          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pump();
          await tester.pump();
          await tester.pump();
          expect(find.text('Wed, May 27, 2026'), findsOneWidget);

          // Long-press the date label → snaps back to "Today".
          await tester.longPress(find.text('Wed, May 27, 2026'));
          await tester.pump();
          await tester.pump();
          await tester.pump();

          expect(find.text('Today'), findsOneWidget);
          expect(find.text('Wed, May 27, 2026'), findsNothing);
        });
      },
    );

    testWidgets(
      "the picker's own Today action is the phone's way back to today",
      (tester) async {
        _setSurfaceSize(tester, const Size(390, 844));
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

          // Step off today. The phone header carries no Today button — the
          // date is the one thing that must stay readable at this width.
          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pump();
          await tester.pump();
          await tester.pump();
          expect(find.text('Wed, May 27'), findsOneWidget);
          expect(
            find.byKey(const Key('daily_os_date_strip_today')),
            findsNothing,
          );

          // Tapping the date opens the design-system picker, whose header
          // carries the Today quick action that replaces it.
          await tester.tap(find.text('Wed, May 27'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(CalendarDatePicker), findsOneWidget);

          await tester.tap(find.text('Today'));
          await tester.pump();
          await tester.tap(find.text('Done'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();

          expect(find.text('Today'), findsOneWidget);
          expect(find.text('Wed, May 27'), findsNothing);
        });
      },
    );

    testWidgets(
      'the phone header gives day navigation a row of its own, unsqueezed',
      (tester) async {
        _setSurfaceSize(tester, const Size(390, 844));
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

          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pump();
          await tester.pump();
          await tester.pump();

          final label = find.text('Wed, May 27');
          expect(label, findsOneWidget);

          // The label got the full width it reserved: nothing on the
          // navigation row squeezed it into an ellipsis.
          final reserved = tester
              .widget<ConstrainedBox>(
                find
                    .ancestor(of: label, matching: find.byType(ConstrainedBox))
                    .first,
              )
              .constraints
              .minWidth;
          expect(
            tester.getSize(label).width,
            greaterThanOrEqualTo(reserved),
            reason: 'the date must not be truncated on a phone',
          );

          // Navigation owns its row: the view toggle and the trailing
          // actions sit strictly below the chevrons.
          final navBottom = tester
              .getBottomLeft(find.byIcon(Icons.chevron_right_rounded))
              .dy;
          expect(
            tester.getTopLeft(find.byType(PlanViewToggle)).dy,
            greaterThanOrEqualTo(navBottom),
          );
          expect(
            tester.getTopLeft(find.byType(ProcessingCategoryFilterButton)).dy,
            greaterThanOrEqualTo(navBottom),
          );
        });
      },
    );

    testWidgets(
      'the chevrons hold their position across dates of different label width',
      (tester) async {
        // May 3 2026 ("Sun, May 3, 2026") vs. September 30 2026
        // ("Wed, Sep 30, 2026") — different character counts, and the
        // strip crosses "Today" in between.
        await withClock(Clock.fixed(DateTime(2026, 5, 3, 9)), () async {
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

          Offset nextChevron() =>
              tester.getTopLeft(find.byIcon(Icons.chevron_right_rounded));
          Offset prevChevron() =>
              tester.getTopLeft(find.byIcon(Icons.chevron_left_rounded));

          final anchorNext = nextChevron();
          final anchorPrev = prevChevron();
          final seenLabels = <String>{};

          for (var step = 0; step < 5; step++) {
            await tester.tap(find.byIcon(Icons.chevron_right_rounded));
            await tester.pump();
            await tester.pump();
            await tester.pump();

            seenLabels.add(
              tester
                  .widgetList<Text>(find.byType(Text))
                  .map((text) => text.data ?? '')
                  .firstWhere(
                    (data) => data.contains('2026'),
                    orElse: () => '',
                  ),
            );
            expect(
              nextChevron(),
              anchorNext,
              reason: 'next chevron must not move between dates',
            );
            expect(prevChevron(), anchorPrev);
          }

          // The dates really did differ in rendered width, so the
          // assertion above is not vacuous.
          expect(seenLabels.length, 5);
        });
      },
    );

    testWidgets(
      'the reserved date width grows with the text scale instead of clipping',
      (tester) async {
        Future<double> labelWidthAt(double scale) async {
          await tester.pumpWidget(
            ProviderScope(
              // A fresh scope per scale: without it the second pump reuses
              // the first scope's container and its already-shifted date.
              key: ValueKey(scale),
              overrides: [
                dailyOsActualTimeBlocksProvider.overrideWith(
                  (ref, _) async => const [],
                ),
                dayActivityProvider.overrideWith((ref, _) async => const []),
                firstDayOfWeekIndexProvider.overrideWith((ref) async => 1),
                dailyOsSetupStatusProvider.overrideWith(
                  (ref) async => const DailyOsSetupStatus(
                    hasInferenceRoute: true,
                    hasPreferredName: true,
                  ),
                ),
                captureControllerProvider.overrideWith(
                  () => CaptureController(recorder: _permissionlessRecorder()),
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => null),
              ],
              child: makeTestableWidget2(
                const DailyOsNextRoot(),
                mediaQueryData: MediaQueryData(
                  size: const Size(1280, 900),
                  textScaler: TextScaler.linear(scale),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          // Step off today so a real date string is rendered.
          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pump();
          await tester.pump();
          await tester.pump();

          final label = find.text('Wed, Sep 30, 2026');
          expect(label, findsOneWidget);
          final labelWidth = tester.getSize(label).width;
          final reserved = tester
              .widget<ConstrainedBox>(
                find
                    .ancestor(
                      of: label,
                      matching: find.byType(ConstrainedBox),
                    )
                    .first,
              )
              .constraints
              .minWidth;
          // Nothing is clipped: the reserved box is wide enough for the
          // string it holds at this scale.
          expect(reserved, greaterThanOrEqualTo(labelWidth));
          return reserved;
        }

        await withClock(Clock.fixed(DateTime(2026, 9, 29, 9)), () async {
          final normal = await labelWidthAt(1);
          final large = await labelWidthAt(1.8);
          expect(
            large,
            greaterThan(normal),
            reason: 'the reservation must follow the user font size',
          );
        });
      },
    );

    testWidgets(
      'the Today button appears off-today and returns the selection',
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

          final todayButton = find.byKey(
            const Key('daily_os_date_strip_today'),
          );
          // On today the control has nothing to do and is not rendered.
          expect(todayButton, findsNothing);

          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pump();
          await tester.pump();
          await tester.pump();
          expect(find.text('Wed, May 27, 2026'), findsOneWidget);
          expect(todayButton, findsOneWidget);

          await tester.tap(todayButton);
          await tester.pump();
          await tester.pump();
          await tester.pump();

          expect(find.text('Today'), findsOneWidget);
          expect(find.text('Wed, May 27, 2026'), findsNothing);
          expect(todayButton, findsNothing);
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

          // Default projection for a day with a plan.
          expect(find.byType(AgendaView), findsOneWidget);

          tester
              .widget<PlanViewToggle>(find.byType(PlanViewToggle))
              .onChanged(PlanView.day);
          await tester.pump();
          expect(find.byType(DayTimeline), findsOneWidget);
          expect(find.byType(AgendaView), findsNothing);

          // Chevron navigation must not bounce the user back to Activity.
          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pump();
          await tester.pump();
          await tester.pump();
          expect(find.text('Wed, May 27, 2026'), findsOneWidget);
          expect(find.byType(DayTimeline), findsOneWidget);
          expect(find.byType(DayActivityView), findsNothing);

          // Neither does the jump-to-today control.
          await tester.tap(find.byKey(const Key('daily_os_date_strip_today')));
          await tester.pump();
          await tester.pump();
          await tester.pump();
          expect(find.text('Today'), findsOneWidget);
          expect(find.byType(DayTimeline), findsOneWidget);
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
