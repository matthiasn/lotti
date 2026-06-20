import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/design_system/theme/motion_tokens.dart';
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

  group('AiSummaryCard – action button separation (motor safety)', () {
    testWidgets(
      'reject and accept hit zones are separated by a dead band',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final bench = AgentTestBench(
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final rejectZone = tester.getRect(
          find
              .ancestor(
                of: find.byIcon(Icons.close_rounded),
                matching: find.byType(InkWell),
              )
              .first,
        );
        final acceptZone = tester.getRect(
          find
              .ancestor(
                of: find.byIcon(Icons.check_rounded),
                matching: find.byType(InkWell),
              )
              .first,
        );

        // The two 48x48 hit zones must NOT abut: a deliberate dead band sits
        // between the destructive reject and accept so a near-miss can't land
        // on the wrong control. (Adjacent zones would give a gap of 0.)
        expect(acceptZone.left - rejectZone.right, greaterThan(4));
      },
    );
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

        // A failed write must NOT collapse the row away: the resolve beat
        // rewinds and the proposal stays put so the user can retry.
        await tester.pump(ProposalMotion.total);
        await tester.pump(ProposalMotion.collapse);
        expect(find.byType(ProposalRow), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'reduced motion prunes the confirmed row instantly, with no collapse',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final service = MockChangeSetConfirmationService();
        when(() => service.confirmItem(any(), any())).thenAnswer(
          (_) async => const ToolExecutionResult(success: true, output: 'ok'),
        );
        final bench = AgentTestBench(
          mediaQueryData: const MediaQueryData(
            size: Size(900, 800),
            disableAnimations: true,
          ),
          confirmationService: service,
          updateNotifications: MockUpdateNotifications(),
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.check_rounded));
        // A couple of frames is enough — no resolve/collapse animation runs
        // under reduced motion, so the row is pruned without a timed window.
        await tester.pump();
        await tester.pump();
        expect(find.byType(ProposalRow), findsNothing);
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

    // The nudge runs on the first row regardless of layout; reduced motion is
    // the only opt-out. The bench's default viewport is 900x800.
    const reducedMotionStandard = reducedMotionDesktop;

    Matrix4? rowTransform(WidgetTester tester) {
      for (final c in tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      )) {
        if (c.transform != null) return c.transform;
      }
      return null;
    }

    testWidgets(
      'reduce-motion skips scheduling the swipe nudge on the first row',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final bench = AgentTestBench(
          mediaQueryData: reducedMotionStandard,
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // Past the nudge's 350ms start delay + its full duration: with
        // reduce-motion no controller was created, so the row never peeks
        // and no un-awaited Timer survives to fail tear-down.
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(ProposalMotion.nudge);

        expect(find.text('Status'), findsOneWidget);
        expect(rowTransform(tester)!.getTranslation().x, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the swipe nudge plays once, one-directional, and settles back',
      (tester) async {
        // Compact bench → animations enabled → the nudge is scheduled in
        // didChangeDependencies. After the 350ms start delay the controller
        // forwards a single peek toward confirm (right), then settles back.
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final bench = AgentTestBench(
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Status'), findsOneWidget);
        // At rest before the start delay.
        expect(rowTransform(tester)!.getTranslation().x, 0);

        // Fire the 350ms start Timer, then advance partway into the peek.
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 180));
        final peekX = rowTransform(tester)!.getTranslation().x;
        // One-directional: the peek is toward confirm (positive) only, never
        // the old left peek, and never beyond the 10px amplitude.
        expect(peekX, greaterThan(0));
        expect(peekX, lessThanOrEqualTo(10));

        // Sample several frames across the rest of the nudge: the offset must
        // never go negative (no left peek) and must settle back to 0.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 60));
          expect(
            rowTransform(tester)!.getTranslation().x,
            greaterThanOrEqualTo(0),
          );
        }
        await tester.pump(ProposalMotion.nudge);
        expect(rowTransform(tester)!.getTranslation().x, 0);
      },
    );

    testWidgets(
      'the swipe nudge does not re-fire once it has played this session',
      (tester) async {
        // Seed the session flag as already-shown: a freshly-mounted first row
        // must not peek, proving the guard lives in session scope (not per
        // row) so promoting a new row to first never replays it.
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final bench = AgentTestBench(
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
          extraOverrides: [
            proposalSwipeNudgePlayedProvider.overrideWith(
              _AlreadyPlayedNudge.new,
            ),
          ],
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(ProposalMotion.nudge);

        // The row never peeked — the nudge was suppressed by the session flag.
        expect(find.text('Status'), findsOneWidget);
        expect(rowTransform(tester)!.getTranslation().x, 0);
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
  group('AiSummaryCard – compact-width proposal row', () {
    // A phone-width viewport (< _proposalRowCompactWidth = 600) where the
    // row drops its explicit confirm/reject buttons and relies on swipe
    // alone. Animations stay disabled so the wiggle hint doesn't add its
    // own offset on top of the drag.
    const compactPhone = MediaQueryData(
      size: Size(420, 800),
      disableAnimations: true,
    );

    testWidgets(
      'shows the action buttons and still confirms via a right swipe',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final service = MockChangeSetConfirmationService();
        when(() => service.confirmItem(any(), any())).thenAnswer(
          (_) async => const ToolExecutionResult(success: true, output: 'ok'),
        );
        final notifier = MockUpdateNotifications();
        final bench = AgentTestBench(
          mediaQueryData: compactPhone,
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

        // The compact branch now shows the confirm/reject buttons as a
        // visible affordance (in addition to swipe).
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Swiping the row right past the trigger still confirms too — the
        // gesture remains available alongside the buttons.
        await tester.drag(find.text('Status'), const Offset(150, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(() => service.confirmItem(pending.changeSet, 0)).called(1);
        verify(() => notifier.notify(any())).called(1);
      },
    );

    testWidgets(
      'rejects via a left swipe on the compact layout',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final service = MockChangeSetConfirmationService();
        when(
          () => service.rejectItem(any(), any()),
        ).thenAnswer((_) async => true);
        final notifier = MockUpdateNotifications();
        final bench = AgentTestBench(
          mediaQueryData: compactPhone,
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

        await tester.drag(find.text('Status'), const Offset(-150, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(() => service.rejectItem(pending.changeSet, 0)).called(1);
        verify(() => notifier.notify(any())).called(1);
      },
    );
  });
  group('AiSummaryCard – proposal row adaptive layout', () {
    PendingSuggestion addPending() => makePending(
      id: 'p1',
      toolName: 'add_checklist_item',
      humanSummary: 'Add checklist item: Write integration tests',
    );

    const chipLabel = 'Add';
    const bodyText = 'checklist item: Write integration tests';

    testWidgets(
      'stacks the kind chip above full-width text on a narrow viewport',
      (tester) async {
        final bench = AgentTestBench(
          mediaQueryData: const MediaQueryData(
            size: Size(420, 800),
            disableAnimations: true,
          ),
          suggestions: UnifiedSuggestionList(
            open: [addPending()],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final chip = find.text(chipLabel);
        final body = find.text(bodyText);
        expect(chip, findsOneWidget);
        expect(body, findsOneWidget);

        // Column layout: the body text sits clearly below the chip and is
        // NOT indented to the right of it — a clean full-width block
        // starting at the row's left edge, not text squished into a ragged
        // column beside the chip.
        expect(
          tester.getTopLeft(body).dy,
          greaterThan(tester.getTopLeft(chip).dy + 10),
        );
        expect(
          tester.getTopLeft(body).dx,
          lessThanOrEqualTo(tester.getTopLeft(chip).dx),
        );
      },
    );

    testWidgets(
      'keeps the chip inline with the text and shows actions when wide',
      (tester) async {
        final bench = AgentTestBench(
          mediaQueryData: const MediaQueryData(
            size: Size(900, 800),
            disableAnimations: true,
          ),
          suggestions: UnifiedSuggestionList(
            open: [addPending()],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final chip = find.text(chipLabel);
        final body = find.text(bodyText);
        expect(chip, findsOneWidget);
        expect(body, findsOneWidget);

        // Row layout: chip and first text line share roughly the same top,
        // and the text sits to the right of the chip rather than below it.
        expect(
          tester.getTopLeft(body).dy,
          moreOrLessEquals(tester.getTopLeft(chip).dy, epsilon: 6),
        );
        expect(
          tester.getTopLeft(body).dx,
          greaterThan(tester.getTopLeft(chip).dx),
        );

        // Explicit confirm/reject actions are present on the comfortable
        // layout (hidden on the narrow swipe-only layout).
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      },
    );
  });
  group('AiSummaryCard – proposal row resolve badge', () {
    testWidgets(
      'while confirmItem is in flight the resolve badge shows (no buttons)',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );

        // Hold the confirm response open so the row stays acknowledging
        // across the assertion window.
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

        // Tap confirm and let the resolve badge firm in.
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The in-flight indicator is the resolve badge — a plain-language
        // "Confirmed" word — not a spinner; the ✕ button is hidden, and the
        // only check glyph on screen is the badge's.
        expect(find.text('Confirmed'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        // Release the future: on success the row acknowledges in place, then
        // collapses away (the confirm button does not return — the row leaves).
        completer.complete(
          const ToolExecutionResult(success: true, output: 'ok'),
        );
        // Resume the confirm continuation, drive the resolve beat past its
        // collapse threshold, run the collapse, then let the shell prune.
        await tester.pump();
        await tester.pump(ProposalMotion.resolveHold);
        await tester.pump(ProposalMotion.collapse);
        await tester.pump(ProposalMotion.collapse);
        await tester.pump();
        expect(find.byType(ProposalRow), findsNothing);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
      },
    );
  });
}

/// Seeds [proposalSwipeNudgePlayedProvider] as already-played so the swipe
/// nudge is treated as shown for this session.
class _AlreadyPlayedNudge extends ProposalSwipeNudgePlayed {
  @override
  bool build() => true;
}
