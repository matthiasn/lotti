import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_page.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_chat_bubble.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_dashboard_header.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

/// Fake [EvolutionChatState] that returns a pre-configured [EvolutionChatData].
class _FakeEvolutionChatState extends EvolutionChatState {
  _FakeEvolutionChatState(this._buildFn);

  final Future<EvolutionChatData> Function(String) _buildFn;

  @override
  Future<EvolutionChatData> build(String templateId) => _buildFn(templateId);
}

void main() {
  setUpAll(registerAllFallbackValues);

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String templateId = kTestTemplateId,
    Future<EvolutionChatData> Function(String)? chatStateBuilder,
    FutureOr<AgentDomainEntity?> Function(Ref, String)? templateOverride,
    List<Override> extraOverrides = const [],
  }) {
    final tpl = makeTestTemplate(id: templateId, agentId: templateId);

    final defaultChatData = EvolutionChatData(
      sessionId: 'session-1',
      messages: [
        EvolutionChatMessage.system(
          text: 'starting_session',
          timestamp: DateTime(2024, 3, 15),
        ),
        EvolutionChatMessage.assistant(
          text: 'Welcome! How can I help improve this template?',
          timestamp: DateTime(2024, 3, 15),
        ),
      ],
    );

    return makeTestableWidgetNoScroll(
      EvolutionChatPage(templateId: templateId),
      overrides: [
        agentTemplateProvider.overrideWith(
          templateOverride ?? (ref, id) async => tpl,
        ),
        templatePerformanceMetricsProvider.overrideWith(
          (ref, id) async => makeTestMetrics(templateId: templateId),
        ),
        evolutionChatStateProvider.overrideWith(
          () => _FakeEvolutionChatState(
            chatStateBuilder ?? (_) async => defaultChatData,
          ),
        ),
        ...extraOverrides,
      ],
    );
  }

  group('EvolutionChatPage', () {
    testWidgets('shows template name in app bar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Test Template'), findsOneWidget);
    });

    testWidgets('shows dashboard header', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionDashboardHeader), findsOneWidget);
    });

    testWidgets('shows message input', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionMessageInput), findsOneWidget);
    });

    testWidgets('renders chat bubbles for messages', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionChatBubble), findsNWidgets(2));
    });

    testWidgets('shows loading indicator when chat state is loading',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) => Completer<EvolutionChatData>().future,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when session fails', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) =>
              Future<EvolutionChatData>.error(Exception('fail')),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionError),
        findsOneWidget,
      );
    });

    testWidgets('resolves system message tokens to localized text',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'starting_session',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionStarting),
        findsOneWidget,
      );
    });

    testWidgets('disables message input when sessionId is null',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            messages: [
              EvolutionChatMessage.system(
                text: 'session_error',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = tester.widget<EvolutionMessageInput>(
        find.byType(EvolutionMessageInput),
      );
      expect(input.enabled, isFalse);
    });

    testWidgets('shows waiting indicator when isWaiting is true',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.assistant(
                text: 'Thinking...',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
            isWaiting: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Loading indicator with ellipsis should appear.
      expect(find.text('...'), findsOneWidget);
      // The waiting indicator in the message list (there may be more from
      // the input widget).
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('resolves session_completed token with version number',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'session_completed:3',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionCompleted(3)),
        findsOneWidget,
      );
    });

    testWidgets('resolves session_error system token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'session_error',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionError),
        findsOneWidget,
      );
    });

    testWidgets('resolves session_abandoned system token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'session_abandoned',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionAbandoned),
        findsOneWidget,
      );
    });

    testWidgets('resolves proposal_rejected system token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'proposal_rejected',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionProposalRejected),
        findsOneWidget,
      );
    });

    testWidgets('shows unrecognized system token as-is', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'unknown_token_xyz',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('unknown_token_xyz'), findsOneWidget);
    });

    testWidgets('surface message renders SizedBox.shrink when no processor',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.surface(
                surfaceId: 'surf-1',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The surface message should render (no crash) but as SizedBox.shrink.
      expect(find.byType(EvolutionChatBubble), findsNothing);
    });

    testWidgets('shows empty template name when template is not loaded',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          templateOverride: (ref, id) async => null,
        ),
      );
      await tester.pumpAndSettle();

      // Template name area should be empty (not crash).
      expect(find.text('Test Template'), findsNothing);
    });

    testWidgets('hides message input during loading state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) => Completer<EvolutionChatData>().future,
        ),
      );
      await tester.pump();
      await tester.pump();

      // bottomNavigationBar uses whenOrNull which returns null during loading.
      expect(find.byType(EvolutionMessageInput), findsNothing);
    });

    testWidgets('hides message input during error state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) =>
              Future<EvolutionChatData>.error(Exception('fail')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionMessageInput), findsNothing);
    });
  });
}
