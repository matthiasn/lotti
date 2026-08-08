import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
