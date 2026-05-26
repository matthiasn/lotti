import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_page.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: const MediaQueryData(size: Size(1280, 1100)),
    ),
  );
}

MockDayAgent _fastAgent() => MockDayAgent(
  parseLatency: Duration.zero,
  pendingLatency: Duration.zero,
  triageLatency: Duration.zero,
  draftLatency: Duration.zero,
  summarizeLatency: Duration.zero,
  clock: () => DateTime(2026, 5, 25, 9),
);

void main() {
  group('ShutdownPage', () {
    testWidgets('renders completed + carryover + tomorrow content', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 1100)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Mock returns 2 completed items + 2 carryover items.
      expect(find.text('Deck review — Q2 leadership update'), findsOneWidget);
      expect(find.text('Morning run · 5km'), findsOneWidget);
      expect(find.text('Finish the Onboarding doc'), findsOneWidget);
      // For-tomorrow note body — the mock generates a paragraph.
      expect(find.textContaining('Onboarding doc'), findsWidgets);
    });

    testWidgets(
      'tapping a carryover suggested chip collapses the row to a confirmation',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 1100)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            ShutdownPage(forDate: DateTime(2026, 5, 25)),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Mock surfaces "→ tomorrow morning" / "→ tomorrow afternoon"
        // as primary chips.
        final morning = find.text('→ tomorrow morning');
        expect(morning, findsOneWidget);

        await tester.ensureVisible(morning);
        await tester.tap(morning);
        await tester.pump(const Duration(milliseconds: 200));

        // After the decision the label reappears inside the
        // confirmation pill; the original button is gone.
        expect(find.text('→ tomorrow morning'), findsOneWidget);
        // The Pick-a-date secondary button still exists for the
        // second carryover row that wasn't decided.
        expect(find.text('Pick a date'), findsOneWidget);
      },
    );
  });
}
