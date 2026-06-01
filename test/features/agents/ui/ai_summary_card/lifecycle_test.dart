import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

/// Wraps [AiSummaryCard] with the full provider set so the
/// `_AiSummaryShell` subtree mounts. The identity, agent-state and
/// suggestion sources are injected from the caller so individual tests
/// can drive lifecycle transitions (identity swap, agent-state
/// re-emit, synchronous first suggestion value).
Widget _buildShell({
  required AgentDomainEntity? Function(Ref ref) identity,
  AgentDomainEntity? Function(Ref ref)? agentState,
  UnifiedSuggestionList Function(Ref ref)? suggestionsSync,
  MockTaskAgentService? taskAgentService,
  bool enableSummaryTts = false,
  MediaQueryData mediaQueryData = desktopMediaQueryData,
}) {
  return RiverpodWidgetTestBench(
    mediaQueryData: mediaQueryData,
    overrides: [
      configFlagProvider.overrideWith(
        (ref, flagName) => Stream.value(
          flagName != enableAiSummaryTtsFlag || enableSummaryTts,
        ),
      ),
      taskAgentProvider.overrideWith((ref, id) => identity(ref)),
      agentReportProvider.overrideWith(
        (ref, agentId) async => makeTestReport(tldr: 'Tldr line.'),
      ),
      templateForAgentProvider.overrideWith((ref, agentId) async => null),
      agentIsRunningProvider.overrideWith(
        (ref, agentId) => Stream.value(false),
      ),
      agentStateProvider.overrideWith(
        (ref, agentId) => agentState?.call(ref),
      ),
      if (taskAgentService != null)
        taskAgentServiceProvider.overrideWith((ref) => taskAgentService),
      if (suggestionsSync != null)
        unifiedSuggestionListProvider.overrideWith(
          (ref, taskId) => suggestionsSync(ref),
        )
      else
        unifiedSuggestionListProvider.overrideWith(
          (ref, taskId) async => const UnifiedSuggestionList.empty(),
        ),
    ],
    child: const SingleChildScrollView(
      child: AiSummaryCard(taskId: AgentTestBench.taskId),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiSummaryCard – error gating', () {
    testWidgets(
      'renders nothing when the task agent provider errors',
      (tester) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              taskAgentProvider.overrideWith(
                (ref, id) => Future<AgentDomainEntity?>.error(
                  StateError('boom'),
                ),
              ),
            ],
            child: const AiSummaryCard(taskId: AgentTestBench.taskId),
          ),
        );
        await tester.pumpAndSettle();

        // The `.when(error: …)` branch collapses to SizedBox.shrink — no
        // CTA, no card chrome.
        expect(find.text('Assign Agent'), findsNothing);
        expect(find.text('AI summary'), findsNothing);
        expect(find.byType(AiSummaryCard), findsOneWidget);
      },
    );
  });

  group('AiSummaryCard – didUpdateWidget identity swap', () {
    testWidgets(
      're-emitting a new identity (different agentId) rebuilds the shell '
      'and re-resolves its subtitle and report',
      (tester) async {
        // Two distinct identities for the SAME task. Swapping the value
        // of the backing StateProvider makes taskAgentProvider recompute
        // synchronously; skipLoadingOnReload keeps the shell mounted so
        // _AiSummaryShell.didUpdateWidget fires with a changed agentId.
        final first = makeTestIdentity(
          id: 'agent-A',
          agentId: 'agent-A',
          displayName: 'Agent Alpha',
        );
        final second = makeTestIdentity(
          id: 'agent-B',
          agentId: 'agent-B',
          displayName: 'Agent Beta',
        );
        var current = first;

        await tester.pumpWidget(
          _buildShell(
            // Synchronous FutureOr return so an invalidate re-resolves in
            // place; skipLoadingOnReload keeps the shell mounted.
            identity: (ref) => current,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Agent Alpha'), findsOneWidget);
        expect(find.text('Agent Beta'), findsNothing);

        // Swap the identity for the same task → didUpdateWidget path.
        final element = tester.element(find.byType(AiSummaryCard));
        final container = ProviderScope.containerOf(element);
        current = second;
        container.invalidate(taskAgentProvider(AgentTestBench.taskId));
        await tester.pumpAndSettle();

        // The subtitle now reflects the new agent, proving the shell was
        // rebuilt in place (not torn down) and re-read its identity.
        expect(find.text('Agent Beta'), findsOneWidget);
        expect(find.text('Agent Alpha'), findsNothing);
      },
    );
  });

  group('AiSummaryCard – synchronous first suggestion value', () {
    testWidgets(
      'a suggestion list available synchronously is shown on first frame '
      'without a setState (the notify:false sync path)',
      (tester) async {
        // A synchronously-resolving suggestion override makes the value
        // present already inside initState → _startSuggestionSubscriptions
        // → _syncVisibleSuggestions(notify:false) takes the early
        // assignment branch instead of calling setState.
        final pending = makePending(
          id: 'sync-1',
          toolName: 'set_task_status',
          humanSummary: 'Synchronous proposal body',
        );
        final list = UnifiedSuggestionList(
          open: [pending],
          activity: const [],
        );

        await tester.pumpWidget(
          _buildShell(
            identity: (ref) => makeTestIdentity(),
            suggestionsSync: (ref) => list,
          ),
        );
        await tester.pumpAndSettle();

        // The open proposal's humanSummary is rendered straight away,
        // confirming the synchronous list became _lastVisibleSuggestions.
        expect(find.text('Proposed changes'), findsOneWidget);
        expect(
          find.textContaining('Synchronous proposal body'),
          findsOneWidget,
        );
        expect(find.textContaining('No open proposals'), findsNothing);
      },
    );
  });

  group('AiSummaryCard – agentState re-emit clears manual cancel', () {
    testWidgets(
      'a rescheduled wake (new nextWakeAt) re-shows the countdown after the '
      'user cancelled the previous one',
      (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
          final initialWake = DateTime(2026, 5, 4, 12, 0, 30);
          final rescheduledWake = DateTime(2026, 5, 4, 12, 1, 30);
          AgentDomainEntity? currentState = makeTestState(
            nextWakeAt: initialWake,
          );
          final taskAgentService = MockTaskAgentService();
          when(
            () => taskAgentService.cancelScheduledWake(any()),
          ).thenAnswer((_) {});

          await tester.pumpWidget(
            _buildShell(
              identity: (ref) => makeTestIdentity(),
              agentState: (ref) => currentState,
              taskAgentService: taskAgentService,
            ),
          );
          await tester.pumpAndSettle();

          // The initial scheduled wake shows the countdown + cancel.
          expect(find.byIcon(Icons.close_rounded), findsOneWidget);
          expect(find.text('0:30'), findsOneWidget);

          // Cancel it → _cancelledManually = true → countdown hidden.
          await tester.tap(find.byIcon(Icons.close_rounded));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.close_rounded), findsNothing);
          expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

          // Reschedule: agentStateProvider re-emits a new nextWakeAt.
          // ref.listen's callback runs with a non-null `prev` value,
          // reading prev.nextWakeAt; the differing future timestamp
          // clears _cancelledManually and the countdown returns.
          final element = tester.element(find.byType(AiSummaryCard));
          final container = ProviderScope.containerOf(element);
          final agentId = makeTestIdentity().agentId;
          currentState = makeTestState(nextWakeAt: rescheduledWake);
          container.invalidate(agentStateProvider(agentId));
          await tester.pumpAndSettle();

          verify(
            () => taskAgentService.cancelScheduledWake(any()),
          ).called(1);
          expect(find.byIcon(Icons.close_rounded), findsOneWidget);
          expect(find.text('1:30'), findsOneWidget);
        });
      },
    );
  });

  group('AiSummaryCard – TLDR content fallback', () {
    testWidgets(
      'falls back to the report content when no explicit tldr is set, '
      'and exposes no extra report body',
      (tester) async {
        // No `tldr` on the report → _resolveTldr returns content.trim(),
        // while _resolveAdditionalReport returns null (no separate body).
        final bench = AgentTestBench(
          report: makeTestReport(
            content: 'Bare content becomes the tldr.',
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        expect(find.text('AI summary'), findsOneWidget);
        // The content surfaces directly as the TLDR line.
        expect(find.text('Bare content becomes the tldr.'), findsOneWidget);

        // The Read more pill is still offered because the TLDR is
        // non-empty, but expanding it reveals no additional report body:
        // because tldr == content, _resolveAdditionalReport is null, so
        // the expanded section renders neither a second markdown body nor
        // the Open-agent-internals pill.
        expect(find.text('Read more'), findsOneWidget);
        await tester.tap(find.text('Read more'));
        await tester.pumpAndSettle();
        expect(find.text('Show less'), findsOneWidget);
        expect(find.text('Open agent internals'), findsNothing);
        // Still exactly one copy of the content — no duplicated report body.
        expect(find.text('Bare content becomes the tldr.'), findsOneWidget);
      },
    );
  });
}
