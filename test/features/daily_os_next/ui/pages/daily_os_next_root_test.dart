import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_next_root.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
}) {
  return ProviderScope(
    overrides: [
      dailyOsActualTimeBlocksProvider.overrideWith(
        (ref, _) async => actualBlocks,
      ),
      ...overrides,
    ],
    child: makeTestableWidget2(
      child,
      mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
    ),
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

void main() {
  group('DailyOsNextRoot', () {
    testWidgets('keeps the date strip visible on the capture path', (
      tester,
    ) async {
      final requestedDates = <DateTime>[];
      final realtimeService = MockRealtimeTranscriptionService();
      when(realtimeService.resolveRealtimeConfig).thenAnswer((_) async => null);
      when(realtimeService.dispose).thenAnswer((_) async {});

      await withClock(Clock.fixed(DateTime(2026, 5, 26, 16, 15)), () async {
        await tester.pumpWidget(
          _wrap(
            const DailyOsNextRoot(),
            overrides: [
              captureControllerProvider.overrideWith(
                () => CaptureController(realtimeService: realtimeService),
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

        expect(find.text('May 27, 2026'), findsOneWidget);
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
        final realtimeService = MockRealtimeTranscriptionService();
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenAnswer((_) async => null);
        when(realtimeService.dispose).thenAnswer((_) async {});

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              actualBlocks: [actualBlock],
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(realtimeService: realtimeService),
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
        });
      },
    );

    testWidgets('AsyncLoading shows the loading shell', (tester) async {
      final realtimeService = MockRealtimeTranscriptionService();
      when(realtimeService.resolveRealtimeConfig).thenAnswer((_) async => null);
      when(realtimeService.dispose).thenAnswer((_) async {});

      await tester.pumpWidget(
        _wrap(
          const DailyOsNextRoot(),
          overrides: [
            captureControllerProvider.overrideWith(
              () => CaptureController(realtimeService: realtimeService),
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
        final realtimeService = MockRealtimeTranscriptionService();
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenAnswer((_) async => null);
        when(realtimeService.dispose).thenAnswer((_) async {});

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(realtimeService: realtimeService),
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
        final realtimeService = MockRealtimeTranscriptionService();
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenAnswer((_) async => null);
        when(realtimeService.dispose).thenAnswer((_) async {});

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(realtimeService: realtimeService),
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
        final realtimeService = MockRealtimeTranscriptionService();
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenAnswer((_) async => null);
        when(realtimeService.dispose).thenAnswer((_) async {});

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(realtimeService: realtimeService),
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
        final realtimeService = MockRealtimeTranscriptionService();
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenAnswer((_) async => null);
        when(realtimeService.dispose).thenAnswer((_) async {});

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(realtimeService: realtimeService),
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

          expect(find.text('May 25, 2026'), findsOneWidget);
          expect(requestedDates, contains(DateTime(2026, 5, 25)));
        });
      },
    );

    testWidgets(
      'tapping the date label opens showDatePicker; cancelling keeps selection',
      (tester) async {
        final realtimeService = MockRealtimeTranscriptionService();
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenAnswer((_) async => null);
        when(realtimeService.dispose).thenAnswer((_) async {});

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(realtimeService: realtimeService),
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => null),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          await tester.tap(find.text('Today'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 200));

          final material = MaterialLocalizations.of(
            tester.element(find.byType(DailyOsNextRoot)),
          );
          await tester.tap(find.text(material.cancelButtonLabel));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(find.text('Today'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'long-pressing the date label returns selection to today',
      (tester) async {
        final realtimeService = MockRealtimeTranscriptionService();
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenAnswer((_) async => null);
        when(realtimeService.dispose).thenAnswer((_) async {});

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(realtimeService: realtimeService),
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
          expect(find.text('May 27, 2026'), findsOneWidget);

          // Long-press the date label → snaps back to "Today".
          await tester.longPress(find.text('May 27, 2026'));
          await tester.pump();
          await tester.pump();
          await tester.pump();

          expect(find.text('Today'), findsOneWidget);
          expect(find.text('May 27, 2026'), findsNothing);
        });
      },
    );

    testWidgets(
      'confirming a date in the picker updates the selected date',
      (tester) async {
        final realtimeService = MockRealtimeTranscriptionService();
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenAnswer((_) async => null);
        when(realtimeService.dispose).thenAnswer((_) async {});

        await withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () async {
          await tester.pumpWidget(
            _wrap(
              const DailyOsNextRoot(),
              overrides: [
                captureControllerProvider.overrideWith(
                  () => CaptureController(realtimeService: realtimeService),
                ),
                currentDraftPlanProvider.overrideWith((ref, _) async => null),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          // Open the date picker by tapping "Today".
          await tester.tap(find.text('Today'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 200));

          // Confirm the currently selected date (May 26 2026) using the OK
          // button — this exercises the `if (picked != null)` branch.
          final material = MaterialLocalizations.of(
            tester.element(find.byType(DailyOsNextRoot)),
          );
          await tester.tap(find.text(material.okButtonLabel));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 200));

          // The widget stayed on today (same date confirmed).
          expect(find.text('Today'), findsOneWidget);
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
