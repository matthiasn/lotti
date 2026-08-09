import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_data.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_session_opening.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_typing_indicator.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  Widget subject() => makeTestableWidgetNoScroll(
    const EvolutionSessionOpening(),
  );

  group('EvolutionSessionOpening', () {
    testWidgets('says what is happening rather than showing a bare spinner', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();

      final context = tester.element(find.byType(EvolutionSessionOpening));
      expect(
        find.text(context.messages.agentRitualOpeningHint),
        findsOneWidget,
      );
      expect(find.byType(EvolutionTypingIndicator), findsOneWidget);
      // The old opening frame was a 16px CircularProgressIndicator beside a
      // literal '...' in the corner of an empty page.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('...'), findsNothing);
    });

    testWidgets('does not announce "composing a reply" — the agent is still '
        'reading, and the visible text says so', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pump();

      final context = tester.element(find.byType(EvolutionSessionOpening));
      final handle = tester.ensureSemantics();

      expect(
        find.bySemanticsLabel(context.messages.agentRitualTypingSemantics),
        findsNothing,
      );
      // The opening line itself carries the status instead.
      expect(
        find.bySemanticsLabel(context.messages.agentRitualOpeningHint),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('is centred in the column the conversation will occupy', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();

      final hint = tester.getCenter(
        find.text(
          tester
              .element(find.byType(EvolutionSessionOpening))
              .messages
              .agentRitualOpeningHint,
        ),
      );
      final page = tester.getCenter(find.byType(EvolutionSessionOpening));
      expect(hint.dx, closeTo(page.dx, 1));
    });
  });

  group('shouldShowSessionOpening', () {
    final at = DateTime(2026, 6, 14, 10);

    EvolutionChatData data({
      String? sessionId,
      List<EvolutionChatMessage> messages = const [],
    }) => EvolutionChatData(sessionId: sessionId, messages: messages);

    test('an empty, session-less state is the opening', () {
      expect(shouldShowSessionOpening(data()), isTrue);
    });

    test('still the opening while only the starting note has arrived', () {
      expect(
        shouldShowSessionOpening(
          data(
            messages: [
              EvolutionChatMessage.system(
                text: 'starting_session',
                timestamp: at,
              ),
            ],
          ),
        ),
        isTrue,
      );
    });

    test('a live session is never the opening', () {
      expect(shouldShowSessionOpening(data(sessionId: 's1')), isFalse);
    });

    test('anyone speaking ends the opening, even with no session id', () {
      expect(
        shouldShowSessionOpening(
          data(
            messages: [
              EvolutionChatMessage.assistant(text: 'Hello', timestamp: at),
            ],
          ),
        ),
        isFalse,
      );
    });

    for (final token in kTerminalSessionTokens) {
      test('a "$token" note ends the opening — a start that failed leaves '
          'sessionId null forever, and the opening state would hide the '
          'localized error behind an indicator implying work in progress', () {
        expect(
          shouldShowSessionOpening(
            data(
              messages: [
                EvolutionChatMessage.system(
                  text: 'starting_session',
                  timestamp: at,
                ),
                EvolutionChatMessage.system(text: token, timestamp: at),
              ],
            ),
          ),
          isFalse,
        );
      });
    }
  });
}
