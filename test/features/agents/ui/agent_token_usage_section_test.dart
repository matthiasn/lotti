import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_token_usage_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

const _testAgentId = 'test-agent-id';

Widget _buildSubject({
  FutureOr<List<AgentTokenUsageSummary>> Function(Ref, String)?
      summariesOverride,
}) {
  return makeTestableWidget(
    const AgentTokenUsageSection(agentId: _testAgentId),
    overrides: [
      agentTokenUsageSummariesProvider.overrideWith(
        summariesOverride ?? (ref, agentId) async => <AgentTokenUsageSummary>[],
      ),
    ],
  );
}

void main() {
  group('AgentTokenUsageSection', () {
    testWidgets('shows heading text', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      final context = tester.element(find.byType(AgentTokenUsageSection));
      expect(
        find.text(context.messages.agentTokenUsageHeading),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator while data loads', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          summariesOverride: (ref, agentId) =>
              Completer<List<AgentTokenUsageSummary>>().future,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty message when no data', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      final context = tester.element(find.byType(AgentTokenUsageSection));
      expect(
        find.text(context.messages.agentTokenUsageEmpty),
        findsOneWidget,
      );
    });

    testWidgets('shows error message on failure', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const AgentTokenUsageSection(agentId: _testAgentId),
          overrides: [
            agentTokenUsageSummariesProvider(_testAgentId).overrideWithValue(
              AsyncValue<List<AgentTokenUsageSummary>>.error(
                Exception('token fetch failed'),
                StackTrace.current,
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('token fetch failed'),
        findsOneWidget,
      );
    });

    testWidgets('renders single model row with formatted token counts',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          summariesOverride: (ref, agentId) async => [
            const AgentTokenUsageSummary(
              modelId: 'models/gemini-2.5-pro',
              inputTokens: 1500,
              outputTokens: 300,
              thoughtsTokens: 200,
              cachedInputTokens: 100,
              wakeCount: 5,
            ),
          ],
        ),
      );
      await tester.pump();

      // Model name is shortened
      expect(find.text('gemini-2.5-pro'), findsOneWidget);

      // Formatted token counts
      expect(find.text('1,500'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // No total row for single model
      final context = tester.element(find.byType(AgentTokenUsageSection));
      expect(
        find.text(context.messages.agentTokenUsageTotalTokens),
        findsNothing,
      );
    });

    testWidgets('renders Table widget with header row', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          summariesOverride: (ref, agentId) async => [
            const AgentTokenUsageSummary(
              modelId: 'claude-sonnet',
              inputTokens: 100,
              outputTokens: 50,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(Table), findsOneWidget);

      final context = tester.element(find.byType(AgentTokenUsageSection));
      expect(
        find.text(context.messages.agentTokenUsageModel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTokenUsageInputTokens),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTokenUsageOutputTokens),
        findsOneWidget,
      );
    });

    testWidgets('shows grand total row when multiple models', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          summariesOverride: (ref, agentId) async => [
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

      final context = tester.element(find.byType(AgentTokenUsageSection));

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

    testWidgets('displays model name without path prefix', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          summariesOverride: (ref, agentId) async => [
            const AgentTokenUsageSummary(
              modelId: 'providers/anthropic/models/claude-3-opus',
              inputTokens: 10,
            ),
          ],
        ),
      );
      await tester.pump();

      // Should show only the portion after the last slash
      expect(find.text('claude-3-opus'), findsOneWidget);
      expect(
        find.text('providers/anthropic/models/claude-3-opus'),
        findsNothing,
      );
    });

    testWidgets('displays model name as-is when no slash present',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          summariesOverride: (ref, agentId) async => [
            const AgentTokenUsageSummary(
              modelId: 'gpt-4o',
              inputTokens: 10,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('gpt-4o'), findsOneWidget);
    });
  });
}
