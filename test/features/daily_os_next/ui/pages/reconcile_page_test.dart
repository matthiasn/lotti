import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/parsed_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/pending_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
    ),
  );
}

void _setWideSurface(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1400, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

MockDayAgent _fastAgent() => MockDayAgent(
  parseLatency: Duration.zero,
  pendingLatency: Duration.zero,
  triageLatency: Duration.zero,
  clock: () => DateTime(2026, 5, 25, 9),
);

class _EmptyParsedAgent extends MockDayAgent {
  _EmptyParsedAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => const [];
}

void main() {
  group('ReconcilePage', () {
    testWidgets('renders parsed and pending cards from the day agent', (
      tester,
    ) async {
      _setWideSurface(tester);
      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          const ReconcilePage(captureId: CaptureId('cap_x')),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pumpAndSettle();

      // Scripted mock returns 4 parsed + 3 pending items.
      expect(find.byType(ParsedCard), findsNWidgets(4));
      expect(find.byType(PendingCard), findsNWidgets(3));
    });

    testWidgets('shows both column headers with their item counts', (
      tester,
    ) async {
      _setWideSurface(tester);
      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          const ReconcilePage(captureId: CaptureId('cap_x')),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ReconcilePage));
      final messages = context.messages;
      expect(
        find.text(messages.dailyOsNextReconcileHeardOverline),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextReconcileDecideOverline),
        findsOneWidget,
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('explains the empty heard column while parsing catches up', (
      tester,
    ) async {
      _setWideSurface(tester);
      final agent = _EmptyParsedAgent();
      await tester.pumpWidget(
        _wrap(
          const ReconcilePage(captureId: CaptureId('cap_x')),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ReconcilePage));
      expect(
        find.text(context.messages.dailyOsNextReconcileHeardEmpty),
        findsOneWidget,
      );
      expect(find.byType(ParsedCard), findsNothing);
      expect(find.byType(PendingCard), findsNWidgets(3));
    });

    testWidgets(
      'triaging a pending card replaces the action row with a confirmation '
      'pill and dims the card',
      (tester) async {
        _setWideSurface(tester);
        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            const ReconcilePage(captureId: CaptureId('cap_x')),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ReconcilePage));
        final messages = context.messages;
        final todayButton = find
            .descendant(
              of: find.byType(PendingCard).first,
              matching: find.text(messages.dailyOsNextTriageToday),
            )
            .first;
        await tester.tap(todayButton);
        await tester.pumpAndSettle();

        expect(
          find.text(messages.dailyOsNextTriageConfirmToday),
          findsOneWidget,
        );
        // The triage row for the first card collapsed — there are
        // fewer Today buttons across the surface now.
        expect(
          find.text(messages.dailyOsNextTriageToday),
          findsNWidgets(2),
        );
      },
    );
  });
}
