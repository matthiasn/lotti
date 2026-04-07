import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_page.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_chat_bubble.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

/// Fake [SoulEvolutionChatState] that returns pre-configured data.
class _FakeSoulEvolutionChatState extends SoulEvolutionChatState {
  _FakeSoulEvolutionChatState(this._buildFn);

  final Future<EvolutionChatData> Function(String) _buildFn;

  @override
  Future<EvolutionChatData> build(String soulId) => _buildFn(soulId);
}

void main() {
  setUpAll(registerAllFallbackValues);

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String soulId = kTestSoulId,
    Future<EvolutionChatData> Function(String)? chatStateBuilder,
    FutureOr<AgentDomainEntity?> Function(Ref, String)? soulOverride,
    List<Override> extraOverrides = const [],
  }) {
    final defaultSoul = makeTestSoulDocument(
      id: soulId,
      displayName: 'Laura',
    );

    final defaultChatData = EvolutionChatData(
      sessionId: 'session-1',
      messages: [
        EvolutionChatMessage.system(
          text: 'starting_session',
          timestamp: DateTime(2024, 3, 15),
        ),
        EvolutionChatMessage.assistant(
          text: 'Hi! I am Laura. How has my communication been?',
          timestamp: DateTime(2024, 3, 15),
        ),
      ],
    );

    return makeTestableWidgetNoScroll(
      SoulEvolutionChatPage(soulId: soulId),
      overrides: [
        soulDocumentProvider.overrideWith(
          soulOverride ?? (ref, id) async => defaultSoul,
        ),
        soulEvolutionChatStateProvider.overrideWith(
          () => _FakeSoulEvolutionChatState(
            chatStateBuilder ?? (_) async => defaultChatData,
          ),
        ),
        ...extraOverrides,
      ],
    );
  }

  group('SoulEvolutionChatPage', () {
    testWidgets('shows soul name in app bar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Laura'), findsOneWidget);
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

    testWidgets('resolves system message tokens', (tester) async {
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

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionStarting),
        findsOneWidget,
      );
    });

    testWidgets('resolves soul_version_created token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            messages: [
              EvolutionChatMessage.system(
                text: 'soul_version_created:v3',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionCompleted(3)),
        findsOneWidget,
      );
    });

    testWidgets('resolves session_abandoned token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
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

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionAbandoned),
        findsOneWidget,
      );
    });

    testWidgets('resolves soul_proposal_rejected token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            messages: [
              EvolutionChatMessage.system(
                text: 'soul_proposal_rejected',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionProposalRejected),
        findsOneWidget,
      );
    });

    testWidgets('shows loading state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) => Completer<EvolutionChatData>().future,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) =>
              Future<EvolutionChatData>.error(Exception('fail')),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionError),
        findsOneWidget,
      );
    });

    testWidgets('disables input when session is null', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => const EvolutionChatData(
            messages: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = tester.widget<EvolutionMessageInput>(
        find.byType(EvolutionMessageInput),
      );
      expect(input.enabled, isFalse);
    });

    testWidgets('resolves session_error token', (tester) async {
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

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionError),
        findsOneWidget,
      );
    });

    testWidgets('renders unknown system token as-is', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'some_unknown_token',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('some_unknown_token'), findsOneWidget);
    });

    testWidgets(
      'renders SizedBox.shrink for surface message without processor',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            chatStateBuilder: (_) async => EvolutionChatData(
              sessionId: 'session-1',
              messages: [
                EvolutionChatMessage.surface(
                  surfaceId: 'test-surface-1',
                  timestamp: DateTime(2024, 3, 15),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // With no processor, surface messages render as SizedBox.shrink
        // and no EvolutionChatBubble should be present for it.
        expect(find.byType(EvolutionChatBubble), findsNothing);
      },
    );

    testWidgets('shows loading indicator when waiting', (tester) async {
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
            isWaiting: true,
          ),
        ),
      );
      // Use pump() — pumpAndSettle will timeout on the spinner animation.
      await tester.pump();
      await tester.pump();

      expect(find.text('...'), findsOneWidget);
    });
  });
}
