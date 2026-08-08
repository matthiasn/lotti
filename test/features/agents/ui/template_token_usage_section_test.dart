import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/template_token_usage_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

const _testTemplateId = 'test-template-id';

Widget _buildSubject({
  FutureOr<List<AgentTokenUsageSummary>> Function(Ref, String)?
  summariesOverride,
  // Still overridden even though this widget no longer renders a per-instance
  // breakdown: the provider survives as the token source for the instance list.
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
            templateTokenUsageSummariesProvider(
              _testTemplateId,
            ).overrideWithValue(
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

    testWidgets('renders token table with formatted counts for single model', (
      tester,
    ) async {
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
}
