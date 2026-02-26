import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  String? lastSent;

  Widget buildSubject({
    bool isWaiting = false,
    bool enabled = true,
  }) {
    lastSent = null;
    return makeTestableWidgetWithScaffold(
      EvolutionMessageInput(
        onSend: (text) => lastSent = text,
        isWaiting: isWaiting,
        enabled: enabled,
      ),
    );
  }

  group('EvolutionMessageInput', () {
    testWidgets('shows placeholder text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionMessageInput));
      expect(
        find.text(context.messages.agentEvolutionChatPlaceholder),
        findsOneWidget,
      );
    });

    testWidgets('send button is disabled when text is empty', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('send button enables after entering text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNotNull);
    });

    testWidgets('tapping send calls onSend and clears text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump();

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(lastSent, 'Test message');

      // Text field should be cleared
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
    });

    testWidgets('send button is disabled when isWaiting', (tester) async {
      await tester.pumpWidget(buildSubject(isWaiting: true));
      await tester.pumpAndSettle();

      // Shows hourglass icon when waiting
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    });

    testWidgets('text field is disabled when not enabled', (tester) async {
      await tester.pumpWidget(buildSubject(enabled: false));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('submit via keyboard sends message', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Keyboard send');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      expect(lastSent, 'Keyboard send');
    });

    testWidgets('does not send whitespace-only text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      // Send button should still be disabled for whitespace
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNull);
    });
  });
}
