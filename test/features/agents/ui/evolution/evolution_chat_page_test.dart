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
import 'evolution_chat_test_utils.dart';

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
          () => FakeEvolutionChatState(
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

    EvolutionChatData chatWith(int count) => EvolutionChatData(
      sessionId: 'session-1',
      messages: [
        for (var i = 0; i < count; i++)
          EvolutionChatMessage.assistant(
            text: 'Message $i with enough text to take real vertical space.',
            timestamp: DateTime(2024, 3, 15),
          ),
      ],
    );

    ScrollPosition listPosition(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    // Mounts the page with a mutable chat state we can push new messages into.
    // (buildSubject already overrides evolutionChatStateProvider, so we build
    // directly rather than override the same family twice.)
    Future<void> pumpWith(
      WidgetTester tester,
      MutableEvolutionChatState chatState,
    ) async {
      final tpl = makeTestTemplate();
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const EvolutionChatPage(templateId: kTestTemplateId),
          overrides: [
            agentTemplateProvider.overrideWith((ref, id) async => tpl),
            templatePerformanceMetricsProvider.overrideWith(
              (ref, id) async => makeTestMetrics(),
            ),
            evolutionChatStateProvider.overrideWith(() => chatState),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a new message does not yank the view down when scrolled up', (
      tester,
    ) async {
      final chatState = MutableEvolutionChatState(chatWith(30));
      await pumpWith(tester, chatState);

      // Scroll up toward older messages, well clear of the bottom.
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      final position = listPosition(tester);
      final offsetWhileReading = position.pixels;
      expect(
        position.maxScrollExtent - offsetWhileReading,
        greaterThan(120),
        reason: 'precondition: the user is reading well above the bottom',
      );

      // A new reply lands.
      chatState.pushData(chatWith(31));
      await tester.pumpAndSettle();

      // The view stayed where the user was reading — it was NOT yanked down.
      expect(position.pixels, closeTo(offsetWhileReading, 4));
      expect(position.pixels, lessThan(position.maxScrollExtent));
    });

    testWidgets('a new message follows to the bottom when already there', (
      tester,
    ) async {
      final chatState = MutableEvolutionChatState(chatWith(30));
      await pumpWith(tester, chatState);

      // The chat opens pinned to the latest message.
      final position = listPosition(tester);
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));

      chatState.pushData(chatWith(31));
      await tester.pumpAndSettle();

      // It followed the new message down to the new bottom.
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));
    });

    testWidgets('shows loading indicator when chat state is loading', (
      tester,
    ) async {
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

    testWidgets('resolves system message tokens to localized text', (
      tester,
    ) async {
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

    testWidgets('disables message input when sessionId is null', (
      tester,
    ) async {
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

    testWidgets('shows waiting indicator when isWaiting is true', (
      tester,
    ) async {
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

    testWidgets('resolves session_completed token with version number', (
      tester,
    ) async {
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

    testWidgets('resolves approval_failed system token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'approval_failed',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionProposalApprovalFailed),
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

    testWidgets('surface message renders SizedBox.shrink when no processor', (
      tester,
    ) async {
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

    testWidgets('shows empty template name when template is not loaded', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          templateOverride: (ref, id) async => null,
        ),
      );
      await tester.pumpAndSettle();

      // Template name area should be empty (not crash).
      expect(find.text('Test Template'), findsNothing);
    });
  });
}
