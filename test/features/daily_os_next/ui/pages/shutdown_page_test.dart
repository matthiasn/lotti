import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/shutdown_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_page.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../mocks/mocks.dart';
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
      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      // For-tomorrow note body — the mock generates a paragraph.
      expect(find.textContaining('Onboarding doc'), findsWidgets);
    });

    testWidgets('keeps shutdown content during provider refreshes', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 1100)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final agent = RefreshBlockingShutdownAgent();
      addTearDown(() {
        if (!agent.pendingShutdownRefresh.isCompleted) {
          agent.pendingShutdownRefresh.complete(
            const (
              completed: <CompletedItem>[],
              carryover: <CarryoverItem>[],
              metrics: ShutdownMetrics(
                focusMinutes: 0,
                flowSessions: 0,
                contextSwitches: 0,
                contextSwitchesWeekAvg: 0,
                energyScore: 0,
                energyDeltaVsWeek: 0,
              ),
            ),
          );
        }
      });
      final date = DateTime(2026, 5, 25);
      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: date),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Deck review — Q2 leadership update'), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(ShutdownPage)),
      ).invalidate(shutdownControllerProvider(date));
      await tester.pump();

      expect(find.text('Deck review — Q2 leadership update'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders a localized error when shutdown loading fails', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 1100)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [
            dayAgentProvider.overrideWithValue(ThrowingShutdownAgent()),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final messages = tester.element(find.byType(ShutdownPage)).messages;
      expect(find.text(messages.dailyOsNextGenericError), findsOneWidget);
      expect(find.textContaining('shutdown unavailable'), findsNothing);
    });

    testWidgets('footer actions all pop the shutdown route', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 1100)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cases = <Finder Function(AppLocalizations)>[
        (messages) => find.widgetWithText(
          TextButton,
          messages.dailyOsNextDayBack,
        ),
        (messages) => find.widgetWithText(
          TextButton,
          messages.dailyOsNextShutdownSaveAndClose,
        ),
        (messages) => find.widgetWithText(
          FilledButton,
          messages.dailyOsNextShutdownCloseDay,
        ),
      ];

      for (final finderFor in cases) {
        final agent = _fastAgent();
        var popped = false;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ShutdownPage(
                          forDate: DateTime(2026, 5, 25),
                        ),
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

        final messages = tester.element(find.byType(ShutdownPage)).messages;
        final control = finderFor(messages);
        await tester.ensureVisible(control);
        await tester.tap(control);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(popped, isTrue);
        expect(find.byType(ShutdownPage), findsNothing);
      }
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
