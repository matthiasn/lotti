import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

/// What the card still says about freshness now that the schedule, the
/// automatic-updates switch and the model identity live in the agent
/// internals panel: a word and a trigger, and only while the summary is
/// behind. Everything the band used to carry is covered by
/// `test/features/agents/ui/agent_maintenance_section_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The manual trigger while a run is in flight — scoped to the button so a
  /// "Thinking…" elsewhere on the card could never satisfy it.
  Finder thinkingTrigger() => find.descendant(
    of: find.byKey(const ValueKey('taskAgentWakeButton')),
    matching: find.text('Thinking…'),
  );

  /// A report that has been overtaken by a task change.
  AgentStateEntity staleState() => makeTestState().copyWith(
    reportStaleAt: DateTime(2026, 5, 4, 12),
    reportFreshAt: DateTime(2026, 5, 4, 11),
  );

  group('AiSummaryCard – freshness strip', () {
    testWidgets(
      'a current summary shows its age and the trigger, and none of the '
      'settings',
      (tester) async {
        final writtenAt = DateTime(2026, 5, 4, 12);
        await withClock(
          Clock.fixed(writtenAt.add(const Duration(minutes: 20))),
          () async {
            final bench = AgentTestBench(
              report: makeTestReport(tldr: 'Tldr line.', createdAt: writtenAt),
              state: makeTestState(),
            );

            await tester.pumpWidget(bench.build());
            await tester.pumpAndSettle();
          },
        );

        expect(find.text('Tldr line.'), findsOneWidget);
        // The age says more than "Up to date" could: a summary from this
        // morning and one from last month are not equally current.
        expect(find.text('20 min ago'), findsOneWidget);
        expect(find.text('Up to date'), findsNothing);
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.byKey(const ValueKey('taskAgentFreshGlyph')),
            matching: find.byType(Tooltip),
          ),
        );
        expect(tooltip.message, 'Summary is up to date');
        // The trigger is always where the reader looks for it.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('taskAgentWakeButton')),
            matching: find.text('Update now'),
          ),
          findsOneWidget,
        );
        // And none of the settings that moved to the internals panel.
        expect(find.text('Automatic updates'), findsNothing);
        expect(find.text('Updates on changes'), findsNothing);
        expect(find.text('test-model · via Test Provider'), findsNothing);
      },
    );

    testWidgets('the age advances in place and becomes a date after a week', (
      tester,
    ) async {
      final writtenAt = DateTime(2026, 5, 4, 12);
      var current = writtenAt.add(const Duration(minutes: 59, seconds: 30));
      await withClock(Clock(() => current), () async {
        await tester.pumpWidget(
          AgentTestBench(
            report: makeTestReport(tldr: 'Tldr line.', createdAt: writtenAt),
            state: makeTestState(),
          ).build(),
        );
        await tester.pumpAndSettle();
        expect(find.text('59 min ago'), findsOneWidget);

        // One timer for the next bucket, not a tick per second.
        current = current.add(const Duration(seconds: 31));
        await tester.pump(const Duration(seconds: 31));
        expect(find.text('1 h ago'), findsOneWidget);

        current = writtenAt.add(const Duration(days: 6, hours: 23));
        await tester.pump(const Duration(hours: 1));
        await tester.pump(const Duration(days: 1));
        current = writtenAt.add(const Duration(days: 7, minutes: 1));
        await tester.pump(const Duration(days: 1));
        expect(find.text('May 4'), findsOneWidget);
      });
    });

    testWidgets('a stale summary says so, with the trigger beside it', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      when(() => taskAgentService.triggerReanalysis(any())).thenAnswer((_) {});
      final bench = AgentTestBench(
        identity: makeTestIdentity().copyWith(
          config: const AgentConfig(automaticUpdatesEnabled: false),
        ),
        state: staleState(),
        taskAgentService: taskAgentService,
        report: makeTestReport(tldr: 'Old summary.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('Out of date'), findsOneWidget);
      // The glyph carries the full sentence in its tooltip; the word beside
      // it stays quiet ink.
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(const ValueKey('taskAgentStaleGlyph')),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, 'This summary is out of date');

      await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));
      verify(() => taskAgentService.triggerReanalysis(any())).called(1);
    });

    testWidgets(
      'a change waiting out its countdown reads Out of date, with the time '
      'to the next update',
      (tester) async {
        // A task change arms the throttle deadline without moving the stale
        // watermark, so before the fix the card stayed silent — looking
        // current — for the whole countdown. Once the deadline is behind
        // `now` (fired or cleared), the countdown alone claims nothing.
        final now = DateTime(2026, 5, 4, 12);
        for (final (deadline, behind) in [
          (now.add(const Duration(seconds: 90)), true),
          (now.subtract(const Duration(seconds: 1)), false),
        ]) {
          final taskAgentService = MockTaskAgentService();
          when(
            () => taskAgentService.triggerReanalysis(any()),
          ).thenAnswer((_) {});
          // A fresh tree per case: re-pumping the same host would keep the
          // row's State and its collapse animation from the previous case.
          await tester.pumpWidget(const SizedBox.shrink());
          await withClock(Clock.fixed(now), () async {
            final bench = AgentTestBench(
              identity: makeTestIdentity().copyWith(
                config: const AgentConfig(automaticUpdatesEnabled: true),
              ),
              state: makeTestState(
                nextWakeAt: deadline,
              ).copyWith(reportFreshAt: DateTime(2026, 5, 4, 11)),
              taskAgentService: taskAgentService,
              report: makeTestReport(tldr: 'Old summary.'),
            );

            await tester.pumpWidget(bench.build());
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          });

          final reason = 'behind=$behind';
          expect(
            find.text('Out of date'),
            behind ? findsOneWidget : findsNothing,
            reason: reason,
          );
          expect(
            find.byKey(const ValueKey('taskAgentStaleGlyph')),
            behind ? findsOneWidget : findsNothing,
            reason: reason,
          );
          // Out of date says when it will fix itself; a deadline already
          // behind `now` promises nothing.
          expect(
            find.text('Update now · 1:30'),
            behind ? findsOneWidget : findsNothing,
            reason: reason,
          );
          if (behind) {
            // The reader can act on it straight away instead of waiting.
            await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));
            verify(() => taskAgentService.triggerReanalysis(any())).called(1);
          } else {
            // Current again: the trigger stays, without a time.
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('taskAgentWakeButton')),
                matching: find.text('Update now'),
              ),
              findsOneWidget,
              reason: reason,
            );
          }
        }
      },
    );

    testWidgets('a card with no report offers only the trigger', (
      tester,
    ) async {
      // Nothing on screen is out of date, so there is no state to report —
      // but the trigger is how the first summary gets written.
      final bench = AgentTestBench(
        identity: makeTestIdentity().copyWith(
          config: const AgentConfig(automaticUpdatesEnabled: false),
        ),
        state: makeTestState().copyWith(
          reportStaleAt: DateTime(2026, 5, 4, 12),
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('taskAgentStaleGlyph')), findsNothing);
      expect(find.byKey(const ValueKey('taskAgentFreshGlyph')), findsNothing);
      expect(find.byKey(const ValueKey('taskAgentWakeButton')), findsOneWidget);
    });

    testWidgets(
      'a running wake reads Out of date, whichever way it was started',
      (tester) async {
        // The summary on screen is the one the run is replacing, and the
        // fresh watermark is written only once the wake succeeds — so a
        // state that is not (yet) stale must still not read as current
        // beside "Thinking…". Both ways a run starts: a scheduled wake
        // firing, and Update now on a report the card already had.
        for (final scheduled in [true, false]) {
          await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
            final bench = AgentTestBench(
              identity: makeTestIdentity().copyWith(
                config: AgentConfig(automaticUpdatesEnabled: scheduled),
              ),
              state: makeTestState(
                nextWakeAt: scheduled ? DateTime(2026, 5, 4, 12, 0, 30) : null,
              ).copyWith(reportFreshAt: DateTime(2026, 5, 4, 11)),
              isRunning: true,
              report: makeTestReport(tldr: 'Old summary.'),
            );

            await tester.pumpWidget(bench.build());
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          });

          final reason = 'scheduled=$scheduled';
          expect(thinkingTrigger(), findsOneWidget, reason: reason);
          expect(find.text('Out of date'), findsOneWidget, reason: reason);
          expect(find.text('Up to date'), findsNothing, reason: reason);
          expect(
            find.byKey(const ValueKey('taskAgentStaleGlyph')),
            findsOneWidget,
            reason: reason,
          );
          // The countdown is the panel's business; the card never shows it.
          expect(find.textContaining('0:30'), findsNothing, reason: reason);
        }
      },
    );

    testWidgets('Out of date lasts until the run has ended', (
      tester,
    ) async {
      final runningController = StreamController<bool>.broadcast();
      addTearDown(runningController.close);

      final bench = AgentTestBench(
        identity: makeTestIdentity().copyWith(
          config: const AgentConfig(automaticUpdatesEnabled: true),
        ),
        state: makeTestState().copyWith(
          reportFreshAt: DateTime(2026, 5, 4, 11),
        ),
        report: makeTestReport(tldr: 'Old summary.'),
        isRunningOverride: (ref, agentId) async* {
          yield false;
          yield* runningController.stream;
        },
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      // Not stale, not running: current.
      expect(find.text('Out of date'), findsNothing);
      expect(find.byKey(const ValueKey('taskAgentFreshGlyph')), findsOneWidget);
      expect(thinkingTrigger(), findsNothing);

      // A run starts: the card admits the summary on screen is being
      // replaced. This is the frame that used to read "Up to date".
      runningController.add(true);
      await tester.pump();
      await tester.pump();
      expect(thinkingTrigger(), findsOneWidget);
      expect(find.text('Out of date'), findsOneWidget);

      // The run ends with a state that is not stale: current again, told by
      // the summary's age rather than a bare confirmation.
      runningController.add(false);
      await tester.pump();
      await tester.pump();
      expect(thinkingTrigger(), findsNothing);
      expect(find.text('Out of date'), findsNothing);
      expect(find.text('Up to date'), findsNothing);
      expect(find.byKey(const ValueKey('taskAgentFreshGlyph')), findsOneWidget);
    });

    testWidgets('without a setup the trigger is dead rather than absent', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      final bench = AgentTestBench(
        taskAgentService: taskAgentService,
        state: staleState(),
        resolvedSetup: const ResolvedAgentSetup(
          status: AgentSetupResolutionStatus.disabled,
        ),
        report: makeTestReport(tldr: 'Existing report.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('Out of date'), findsOneWidget);
      final wakeButton = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('taskAgentWakeButton')),
      );
      expect(wakeButton.onPressed, isNull);
      verifyNever(() => taskAgentService.triggerReanalysis(any()));
      // The explanation lives with the setup row, in the internals panel.
      expect(find.byIcon(LottiIcons.info), findsNothing);
    });
  });
}
