import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/template_token_usage_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

const _testTemplateId = 'test-template-id';

Widget _buildSubject({
  FutureOr<List<AgentTokenUsageSummary>> Function(Ref, String)?
      summariesOverride,
  FutureOr<List<InstanceTokenBreakdown>> Function(Ref, String)?
      breakdownOverride,
}) {
  return makeTestableWidgetWithScaffold(
    const TemplateTokenUsageSection(templateId: _testTemplateId),
    overrides: [
      templateTokenUsageSummariesProvider.overrideWith(
        summariesOverride ?? (ref, id) async => <AgentTokenUsageSummary>[],
      ),
      templateInstanceTokenBreakdownProvider.overrideWith(
        breakdownOverride ?? (ref, id) async => <InstanceTokenBreakdown>[],
      ),
    ],
  );
}

void main() {
  group('TemplateTokenUsageSection – aggregate section', () {
    testWidgets('shows aggregate heading text', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      final context = tester.element(find.byType(TemplateTokenUsageSection));
      expect(
        find.text(context.messages.agentTemplateAggregateTokenUsageHeading),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator while data loads', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          summariesOverride: (ref, id) =>
              Completer<List<AgentTokenUsageSummary>>().future,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows empty message when no summaries', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      final context = tester.element(find.byType(TemplateTokenUsageSection));
      // Both aggregate and breakdown are empty, so the empty message
      // appears at least twice (once per section).
      expect(
        find.text(context.messages.agentTokenUsageEmpty),
        findsWidgets,
      );
    });

    testWidgets('shows error message on failure', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TemplateTokenUsageSection(templateId: _testTemplateId),
          overrides: [
            templateTokenUsageSummariesProvider(_testTemplateId)
                .overrideWithValue(
              AsyncValue<List<AgentTokenUsageSummary>>.error(
                Exception('aggregate fetch failed'),
                StackTrace.current,
              ),
            ),
            templateInstanceTokenBreakdownProvider.overrideWith(
              (ref, id) async => <InstanceTokenBreakdown>[],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('aggregate fetch failed'),
        findsOneWidget,
      );
    });

    testWidgets('renders token table with formatted counts for single model',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          summariesOverride: (ref, id) async => [
            const AgentTokenUsageSummary(
              modelId: 'models/gemini-2.5-pro',
              inputTokens: 2500,
              outputTokens: 750,
              thoughtsTokens: 400,
              cachedInputTokens: 200,
              wakeCount: 8,
            ),
          ],
        ),
      );
      await tester.pump();

      // Model name shortened to last segment
      expect(find.text('gemini-2.5-pro'), findsOneWidget);

      // Formatted token counts
      expect(find.text('2,500'), findsOneWidget);
      expect(find.text('750'), findsOneWidget);
      expect(find.text('400'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      // No total row for a single model
      final context = tester.element(find.byType(TemplateTokenUsageSection));
      expect(
        find.text(context.messages.agentTokenUsageTotalTokens),
        findsNothing,
      );
    });

    testWidgets('shows grand total row with multiple models', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          summariesOverride: (ref, id) async => [
            const AgentTokenUsageSummary(
              modelId: 'models/gemini-2.5-pro',
              inputTokens: 1000,
              outputTokens: 200,
              thoughtsTokens: 100,
              cachedInputTokens: 50,
              wakeCount: 3,
            ),
            const AgentTokenUsageSummary(
              modelId: 'claude-sonnet',
              inputTokens: 500,
              outputTokens: 100,
              thoughtsTokens: 50,
              cachedInputTokens: 25,
              wakeCount: 2,
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(TemplateTokenUsageSection));

      // Total row label is present
      expect(
        find.text(context.messages.agentTokenUsageTotalTokens),
        findsOneWidget,
      );

      // Grand totals: 1500, 300, 150, 75, 5
      expect(find.text('1,500'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);

      // Both model rows
      expect(find.text('gemini-2.5-pro'), findsOneWidget);
      expect(find.text('claude-sonnet'), findsOneWidget);
    });
  });

  group('TemplateTokenUsageSection – instance breakdown section', () {
    testWidgets('shows breakdown heading text', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      final context = tester.element(find.byType(TemplateTokenUsageSection));
      expect(
        find.text(context.messages.agentTemplateInstanceBreakdownHeading),
        findsOneWidget,
      );
    });

    testWidgets('shows empty message when no instances', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      final context = tester.element(find.byType(TemplateTokenUsageSection));
      expect(
        find.text(context.messages.agentTokenUsageEmpty),
        findsWidgets,
      );
    });

    testWidgets('renders expansion tiles for each instance', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          breakdownOverride: (ref, id) async => [
            const InstanceTokenBreakdown(
              agentId: 'agent-1',
              displayName: 'Laura-1',
              lifecycle: AgentLifecycle.active,
              summaries: [
                AgentTokenUsageSummary(
                  modelId: 'models/gemini-2.5-pro',
                  inputTokens: 1000,
                  outputTokens: 500,
                  wakeCount: 3,
                ),
              ],
            ),
            const InstanceTokenBreakdown(
              agentId: 'agent-2',
              displayName: 'Laura-2',
              lifecycle: AgentLifecycle.dormant,
              summaries: [],
            ),
          ],
        ),
      );
      await tester.pump();

      // Two expansion tiles rendered
      expect(find.byType(ExpansionTile), findsNWidgets(2));

      // Instance display names visible
      expect(find.text('Laura-1'), findsOneWidget);
      expect(find.text('Laura-2'), findsOneWidget);
    });

    testWidgets('shows lifecycle badge on each instance tile', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          breakdownOverride: (ref, id) async => [
            const InstanceTokenBreakdown(
              agentId: 'agent-1',
              displayName: 'Laura-1',
              lifecycle: AgentLifecycle.active,
              summaries: [
                AgentTokenUsageSummary(
                  modelId: 'gpt-4o',
                  inputTokens: 100,
                  outputTokens: 50,
                ),
              ],
            ),
            const InstanceTokenBreakdown(
              agentId: 'agent-2',
              displayName: 'Laura-2',
              lifecycle: AgentLifecycle.dormant,
              summaries: [],
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(TemplateTokenUsageSection));

      // Active badge on first tile
      expect(
        find.text(context.messages.agentLifecycleActive),
        findsOneWidget,
      );

      // Dormant badge on second tile
      expect(
        find.text(context.messages.agentLifecycleDormant),
        findsOneWidget,
      );
    });

    testWidgets('expands to show per-model token table', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          breakdownOverride: (ref, id) async => [
            const InstanceTokenBreakdown(
              agentId: 'agent-1',
              displayName: 'Laura-1',
              lifecycle: AgentLifecycle.active,
              summaries: [
                AgentTokenUsageSummary(
                  modelId: 'models/gemini-2.5-pro',
                  inputTokens: 1200,
                  outputTokens: 600,
                  thoughtsTokens: 300,
                  cachedInputTokens: 150,
                  wakeCount: 4,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pump();

      // Before expanding, the token table inside the expansion tile
      // should not be visible.
      expect(find.text('1,200'), findsNothing);

      // Tap the expansion tile to expand it
      await tester.tap(find.byType(ExpansionTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After expanding, the per-model token table is visible
      expect(find.text('gemini-2.5-pro'), findsOneWidget);
      expect(find.text('1,200'), findsOneWidget);
      expect(find.text('600'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('shows empty message inside expanded tile with no summaries',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          // Provide a non-empty aggregate summary so only the expanded
          // tile's empty message is from the instance.
          summariesOverride: (ref, id) async => [
            const AgentTokenUsageSummary(
              modelId: 'models/test',
              inputTokens: 100,
            ),
          ],
          breakdownOverride: (ref, id) async => [
            const InstanceTokenBreakdown(
              agentId: 'agent-1',
              displayName: 'Empty-Agent',
              lifecycle: AgentLifecycle.created,
              summaries: [],
            ),
          ],
        ),
      );
      await tester.pump();

      // Tap to expand
      await tester.tap(find.byType(ExpansionTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(TemplateTokenUsageSection));
      // The empty message inside the expanded tile
      expect(
        find.text(context.messages.agentTokenUsageEmpty),
        findsOneWidget,
      );
    });

    testWidgets('shows error message when breakdown fails', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TemplateTokenUsageSection(templateId: _testTemplateId),
          overrides: [
            templateTokenUsageSummariesProvider.overrideWith(
              (ref, id) async => <AgentTokenUsageSummary>[],
            ),
            templateInstanceTokenBreakdownProvider(_testTemplateId)
                .overrideWithValue(
              AsyncValue<List<InstanceTokenBreakdown>>.error(
                Exception('breakdown fetch failed'),
                StackTrace.current,
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('breakdown fetch failed'),
        findsOneWidget,
      );
    });

    testWidgets('shows created lifecycle badge', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          breakdownOverride: (ref, id) async => [
            const InstanceTokenBreakdown(
              agentId: 'agent-1',
              displayName: 'New-Agent',
              lifecycle: AgentLifecycle.created,
              summaries: [],
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(TemplateTokenUsageSection));
      expect(
        find.text(context.messages.agentLifecycleCreated),
        findsOneWidget,
      );
    });

    testWidgets('shows destroyed lifecycle badge', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          breakdownOverride: (ref, id) async => [
            const InstanceTokenBreakdown(
              agentId: 'agent-1',
              displayName: 'Dead-Agent',
              lifecycle: AgentLifecycle.destroyed,
              summaries: [],
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(TemplateTokenUsageSection));
      expect(
        find.text(context.messages.agentLifecycleDestroyed),
        findsOneWidget,
      );
    });
  });
}
