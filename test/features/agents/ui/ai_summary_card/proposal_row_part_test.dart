import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../test_data/change_set_factories.dart';
import 'test_bench.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(makeTestChangeSet());
    registerFallbackValue(<String>{});
  });
  group('AiSummaryCard – Proposal row error branches', () {
    testWidgets(
      'confirmItem returning success: false surfaces an error toast',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final service = MockChangeSetConfirmationService();
        // Distinct from the existing "throws" test: this hits the
        // `!result.success` branch inside the try body, not the catch.
        when(() => service.confirmItem(any(), any())).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: false,
            output: 'failed',
          ),
        );
        final notifier = MockUpdateNotifications();
        final bench = AgentTestBench(
          confirmationService: service,
          updateNotifications: notifier,
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(() => service.confirmItem(any(), any())).called(1);
        verify(() => notifier.notify(any())).called(1);
        expect(find.text('Failed to apply change'), findsWidgets);
      },
    );

    testWidgets(
      'rejectItem throwing surfaces an error toast via the catch arm',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final service = MockChangeSetConfirmationService();
        when(
          () => service.rejectItem(any(), any()),
        ).thenAnswer((_) async => Future.error(Exception('reject boom')));
        final notifier = MockUpdateNotifications();
        final bench = AgentTestBench(
          confirmationService: service,
          updateNotifications: notifier,
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.close_rounded).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(() => service.rejectItem(any(), any())).called(1);
        expect(find.text('Failed to apply change'), findsWidgets);
      },
    );
  });
  group('AiSummaryCard – swipe intent label & affordances', () {
    // A desktop-width viewport with animations disabled. Disabling
    // animations both (a) drives the reduce-motion branch in
    // didChangeDependencies that schedules nothing, and (b) keeps the
    // wiggle hint from adding its own offset on top of the drag, so the
    // mid-gesture `_dx` is exactly what we move by.
    const reducedMotionDesktop = MediaQueryData(
      size: Size(900, 800),
      disableAnimations: true,
    );

    testWidgets(
      'reduce-motion skips scheduling the wiggle hint on the first row',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final bench = AgentTestBench(
          mediaQueryData: reducedMotionDesktop,
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // No animation controller is created, so the row never peeks:
        // the swipe-intent labels stay hidden until the user drags.
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);

        // The row renders normally with its action buttons. If a wiggle
        // Timer had been scheduled, an un-awaited timer would make the
        // test fail at tear-down — reaching here clean proves the
        // reduce-motion early return fired.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a partial left swipe surfaces the Reject intent label and close icon',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final service = MockChangeSetConfirmationService();
        final notifier = MockUpdateNotifications();
        final bench = AgentTestBench(
          mediaQueryData: reducedMotionDesktop,
          confirmationService: service,
          updateNotifications: notifier,
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Before any drag the reject backdrop is not shown.
        expect(find.byIcon(Icons.close), findsNothing);

        // Hold a left drag at -50px: past the -30 intent threshold but
        // short of the -70 reject trigger, so the row stays in the
        // "Reject" affordance state without firing the service.
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Status')),
        );
        await gesture.moveBy(const Offset(-50, 0));
        await tester.pump();

        // The reject intent label + the backdrop close icon are now
        // rendered by the gradient layer.
        expect(find.text('Reject'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Releasing below the trigger must not call the service.
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        verifyNever(() => service.rejectItem(any(), any()));
        verifyNever(() => service.confirmItem(any(), any()));
      },
    );
  });
  group('AiSummaryCard – proposal row busy spinner', () {
    testWidgets(
      'while confirmItem is in flight the row actions show a spinner',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );

        // Hold the confirm response open so the row stays busy across
        // the assertion window.
        final completer = Completer<ToolExecutionResult>();
        final service = MockChangeSetConfirmationService();
        when(
          () => service.confirmItem(any(), any()),
        ).thenAnswer((_) => completer.future);
        final notifier = MockUpdateNotifications();

        final bench = AgentTestBench(
          confirmationService: service,
          updateNotifications: notifier,
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap confirm and rebuild only (no settle) so we observe the
        // in-flight busy layout.
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pump();

        // The confirm/reject chips collapse to a single 48×48 spinner
        // slot — the icons are gone and a spinner is shown in their
        // place inside the proposal row (not the confirm-all button,
        // which isn't present with a single item).
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Release the future so tear-down doesn't hang, and confirm the
        // busy state clears back to the action buttons.
        completer.complete(
          const ToolExecutionResult(success: true, output: 'ok'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      },
    );
  });
}
