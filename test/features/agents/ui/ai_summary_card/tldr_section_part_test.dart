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
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

/// Builds a minimal AiSummaryCard test scope with a fixed-width parent so
/// the LayoutBuilder inside the TLDR header sees the requested width.
/// The shared `RiverpodWidgetTestBench` enforces a 800px min-width which
/// would force the wide-layout branch.
///
/// Pass [nextWakeAt] to seed an active wake countdown — when present the
/// header should render the play / countdown / cancel cluster, which is
/// the only group the narrow branch actually stacks below the title.
Widget _narrowScope({required double width, DateTime? nextWakeAt}) {
  return ProviderScope(
    overrides: [
      taskAgentProvider.overrideWith(
        (ref, id) async => makeTestIdentity(),
      ),
      configFlagProvider.overrideWith(
        (ref, flagName) => Stream.value(false),
      ),
      agentReportProvider.overrideWith(
        (ref, agentId) async => makeTestReport(tldr: 'Tldr line.'),
      ),
      templateForAgentProvider.overrideWith((ref, agentId) async => null),
      agentIsRunningProvider.overrideWith(
        (ref, agentId) => Stream.value(false),
      ),
      agentStateProvider.overrideWith(
        (ref, agentId) async =>
            nextWakeAt == null ? null : makeTestState(nextWakeAt: nextWakeAt),
      ),
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

    testWidgets('hides the summary playback affordance while the flag is off', (
      tester,
    ) async {
      final bench = AgentTestBench(
        report: makeTestReport(tldr: 'Tldr line.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets('shows the summary playback affordance when the flag is on', (
      tester,
    ) async {
      final bench = AgentTestBench(
        enableSummaryTts: true,
        report: makeTestReport(tldr: 'Tldr line.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('plays the TLDR through the MLX TTS model', (tester) async {
      final mlxAudioChannel = _RecordingMlxAudioChannel();
      final bench = AgentTestBench(
        enableSummaryTts: true,
        mlxAudioChannel: mlxAudioChannel,
        report: makeTestReport(tldr: 'Tldr line.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();

      expect(mlxAudioChannel.spokenTexts, ['Tldr line.']);
      expect(mlxAudioChannel.modelIds, [mlxAudioDefaultTtsModelId]);
    });

    testWidgets(
      'lays the header out as a Wrap so the leading block and controls '
      'sit in a single run with the controls right-aligned via '
      'WrapAlignment.spaceBetween whenever there is room',
      (tester) async {
        await tester.pumpWidget(_narrowScope(width: 800));
        await tester.pumpAndSettle();

        // Two Wraps in the tree: the header's space-between Wrap and
        // the proposals section's title-row Wrap.
        expect(find.byType(Wrap), findsNWidgets(2));
        expect(find.text('AI summary'), findsOneWidget);
        expect(find.text('Test Agent'), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

        // Single run → leading block + controls share a Y coordinate.
        final titleY = tester.getCenter(find.text('AI summary')).dy;
        final refreshY = tester
            .getCenter(find.byIcon(Icons.refresh_rounded))
            .dy;
        expect((titleY - refreshY).abs() < 24, isTrue);

        // The refresh affordance is pushed to the right edge of the
        // card by WrapAlignment.spaceBetween rather than sitting flush
        // against the title.
        final titleRight = tester.getTopRight(find.text('AI summary')).dx;
        final refreshLeft = tester
            .getTopLeft(find.byIcon(Icons.refresh_rounded))
            .dx;
        expect(refreshLeft, greaterThan(titleRight + 100));
      },
    );

    testWidgets(
      'lets the control cluster fall to a second Wrap run only when the '
      'row truly cannot fit, instead of stacking it pre-emptively',
      (tester) async {
        // Pathologically narrow card forces the leading block + controls
        // to overflow a single run, exercising the wrap-to-second-row
        // branch the previous threshold-based stacking always took.
        // Wide enough that each cluster on its own still fits in its
        // run — only the combined width spills.
        await tester.pumpWidget(_narrowScope(width: 260));
        await tester.pumpAndSettle();

        expect(find.byType(Wrap), findsNWidgets(2));
        expect(find.text('AI summary'), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

        final titleY = tester.getCenter(find.text('AI summary')).dy;
        final refreshY = tester
            .getCenter(find.byIcon(Icons.refresh_rounded))
            .dy;
        expect(
          refreshY,
          greaterThan(titleY),
          reason:
              'controls should drop to a second run when they no longer fit',
        );
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
          // Bounded pumps to flush async providers (taskAgent /
          // agentState / unifiedSuggestionList all resolve via Futures)
          // without advancing into the WakeCountdownState 1s timer
          // boundary. Stay below 1000ms total so the timer never fires.
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }

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

class _RecordingMlxAudioChannel extends MlxAudioChannel {
  final spokenTexts = <String>[];
  final modelIds = <String>[];

  @override
  Future<void> speakText({
    required String text,
    required String modelId,
    String? language,
  }) async {
    spokenTexts.add(text);
    modelIds.add(modelId);
  }
}
