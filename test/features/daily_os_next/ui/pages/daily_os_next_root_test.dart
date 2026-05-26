import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_next_root.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
    ),
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

        expect(find.text('May 27, 2026'), findsOneWidget);
        expect(requestedDates, contains(DateTime(2026, 5, 27)));
      });
    });

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
        const category = DayAgentCategory(
          id: 'cat',
          name: 'Work',
          colorHex: '5ED4B7',
        );
        final plan = DraftPlan(
          dayDate: DateTime(2026, 5, 26),
          blocks: const [],
          bands: const [],
          capacityMinutes: 240,
          scheduledMinutes: 60,
          agendaItems: const [
            AgendaItem(
              id: 'a',
              title: 'Deep work',
              category: category,
              linkedBlockIds: ['blk_1'],
            ),
          ],
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
          expect(find.text('May 27, 2026'), findsOneWidget);

          // Long-press the date label → snaps back to "Today".
          await tester.longPress(find.text('May 27, 2026'));
          await tester.pump();
          await tester.pump();

          expect(find.text('Today'), findsOneWidget);
          expect(find.text('May 27, 2026'), findsNothing);
        });
      },
    );
  });
}
