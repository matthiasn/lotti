import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../widget_test_utils.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

/// Builds a minimal AiSummaryCard test scope with a fixed-width parent so
/// the LayoutBuilder inside the TLDR header sees the requested width.
/// The shared `RiverpodWidgetTestBench` enforces a 800px min-width which
/// would force the wide-layout branch.
Widget _narrowScope({required double width}) {
  return ProviderScope(
    overrides: [
      configFlagProvider.overrideWith(
        (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
      ),
      taskAgentProvider.overrideWith(
        (ref, id) async => makeTestIdentity(),
      ),
      agentReportProvider.overrideWith(
        (ref, agentId) async => makeTestReport(tldr: 'Tldr line.'),
      ),
      templateForAgentProvider.overrideWith((ref, agentId) async => null),
      agentIsRunningProvider.overrideWith(
        (ref, agentId) => Stream.value(false),
      ),
      agentStateProvider.overrideWith((ref, agentId) async => null),
      unifiedSuggestionListProvider.overrideWith(
        (ref, taskId) async => const UnifiedSuggestionList.empty(),
      ),
    ],
    child: MaterialApp(
      theme: resolveTestTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: const AiSummaryCard(taskId: AgentTestBench.taskId),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiSummaryCard – TLDR header', () {
    testWidgets(
      'shows a spinner instead of the refresh affordance while the agent is running',
      (tester) async {
        final bench = AgentTestBench(
          isRunning: true,
          report: makeTestReport(tldr: 'Tldr line.'),
        );

        await tester.pumpWidget(bench.build());
        // The spinner animates indefinitely, so pumpAndSettle would
        // time out. Pump until the async providers (taskAgent, report)
        // have all resolved and the header has rebuilt with isRunning.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsNothing);
      },
    );

    testWidgets(
      'stacks controls under the title block on narrow viewports (Wrap layout)',
      (tester) async {
        await tester.pumpWidget(_narrowScope(width: 320));
        await tester.pumpAndSettle();

        // The narrow branch stacks the wake / read-more controls in a
        // Wrap run below the title block. Three Wraps are now in the
        // tree: the narrow-layout one + the two in the proposals
        // section header (outer spaceBetween + inner title row).
        expect(find.byType(Wrap), findsNWidgets(3));
        expect(find.text('AI summary'), findsOneWidget);
        expect(find.text('Test Agent'), findsOneWidget);
        // The refresh affordance lives inside the narrow-layout Wrap
        // below the title.
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'keeps controls inline alongside the title on wide viewports (Row layout)',
      (tester) async {
        // 800px ≥ 360px stacked threshold → LayoutBuilder picks the
        // Row branch, no narrow-layout Wrap is built.
        await tester.pumpWidget(_narrowScope(width: 800));
        await tester.pumpAndSettle();

        // In the wide layout the TLDR header uses a Row, so the only
        // Wraps are the two in the proposals section header.
        expect(find.byType(Wrap), findsNWidgets(2));
        expect(find.text('AI summary'), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'countdown pill expiry collapses the wake cluster back to refresh',
      (tester) async {
        final start = DateTime(2026, 5, 4, 12);
        var now = start;
        final nextWakeAt = start.add(const Duration(seconds: 2));

        await withClock(Clock(() => now), () async {
          final bench = AgentTestBench(
            state: makeTestState(nextWakeAt: nextWakeAt),
            report: makeTestReport(tldr: 'Tldr line.'),
          );

          await tester.pumpWidget(bench.build());
          await tester.pumpAndSettle();

          // Initial: countdown pill visible, no refresh affordance.
          expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
          expect(find.byIcon(Icons.close_rounded), findsOneWidget);
          expect(find.byIcon(Icons.refresh_rounded), findsNothing);

          // Advance wall-clock past nextWakeAt and let the periodic
          // timer fire; the mixin should call onCountdownExpired which
          // forwards to the parent's setState callback.
          now = start.add(const Duration(seconds: 3));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();

          // Wake cluster gone, refresh affordance back.
          expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
          expect(find.byIcon(Icons.close_rounded), findsNothing);
          expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        });
      },
    );
  });
}
