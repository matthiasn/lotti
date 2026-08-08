import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_chat_bubble.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_list.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_typing_indicator.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

final _at = DateTime(2026, 6, 14, 10);

void main() {
  Widget subject({
    required List<EvolutionChatMessage> messages,
    bool isWaiting = false,
    EvolutionSystemTextResolver resolver = resolveTemplateSystemText,
  }) => makeTestableWidgetNoScroll(
    EvolutionMessageList(
      messages: messages,
      isWaiting: isWaiting,
      resolveSystemText: resolver,
    ),
  );

  AppLocalizations messagesOf(WidgetTester tester) =>
      tester.element(find.byType(EvolutionMessageList)).messages;

  group('EvolutionMessageList', () {
    testWidgets('renders one bubble per turn', (tester) async {
      await tester.pumpWidget(
        subject(
          messages: [
            EvolutionChatMessage.assistant(text: 'Hello', timestamp: _at),
            EvolutionChatMessage.user(text: 'Hi', timestamp: _at),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionChatBubble), findsNWidgets(2));
      expect(find.byType(EvolutionTypingIndicator), findsNothing);
    });

    testWidgets('appends the typing indicator while waiting, after the last '
        'turn rather than in place of it', (tester) async {
      await tester.pumpWidget(
        subject(
          messages: [
            EvolutionChatMessage.assistant(text: 'Hello', timestamp: _at),
          ],
          isWaiting: true,
        ),
      );
      await tester.pump();

      expect(find.byType(EvolutionChatBubble), findsOneWidget);
      expect(find.byType(EvolutionTypingIndicator), findsOneWidget);
      expect(
        tester.getCenter(find.byType(EvolutionTypingIndicator)).dy,
        greaterThan(tester.getCenter(find.byType(EvolutionChatBubble)).dy),
      );
    });

    group('system token resolution', () {
      testWidgets('the template resolver localizes its own token set', (
        tester,
      ) async {
        await tester.pumpWidget(
          subject(
            messages: [
              EvolutionChatMessage.system(
                text: 'session_completed:4',
                timestamp: _at,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(messagesOf(tester).agentEvolutionSessionCompleted(4)),
          findsOneWidget,
        );
      });

      testWidgets('the soul resolver strips the v-prefix its workflow emits — '
          'the one behaviour that differs between the two conversations', (
        tester,
      ) async {
        await tester.pumpWidget(
          subject(
            messages: [
              EvolutionChatMessage.system(
                text: 'soul_version_created:v4',
                timestamp: _at,
              ),
            ],
            resolver: resolveSoulSystemText,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(messagesOf(tester).agentEvolutionSessionCompleted(4)),
          findsOneWidget,
        );
      });

      testWidgets('an unrecognised token is shown verbatim rather than '
          'swallowed', (tester) async {
        await tester.pumpWidget(
          subject(
            messages: [
              EvolutionChatMessage.system(
                text: 'something_new',
                timestamp: _at,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('something_new'), findsOneWidget);
      });

      testWidgets('the template resolver does not answer soul tokens, and '
          'vice versa — the sets overlap but are not equal', (tester) async {
        await tester.pumpWidget(
          subject(
            messages: [
              EvolutionChatMessage.system(
                text: 'soul_proposal_rejected',
                timestamp: _at,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Template resolver has no entry for it, so it falls through raw.
        expect(find.text('soul_proposal_rejected'), findsOneWidget);
      });
    });

    testWidgets('a surface message with no processor renders nothing rather '
        'than throwing', (tester) async {
      await tester.pumpWidget(
        subject(
          messages: [
            EvolutionChatMessage.surface(surfaceId: 's1', timestamp: _at),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionChatBubble), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
