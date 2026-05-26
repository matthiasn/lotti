import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_next_root.dart';
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
  });
}
