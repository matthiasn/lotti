import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';
import 'evolution_recorder_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  String? lastSent;

  Widget buildSubject({
    bool isWaiting = false,
    bool enabled = true,
    List<Override> overrides = const [],
  }) {
    lastSent = null;
    return makeTestableWidgetWithScaffold(
      EvolutionMessageInput(
        onSend: (text) => lastSent = text,
        isWaiting: isWaiting,
        enabled: enabled,
      ),
      overrides: overrides.isEmpty
          ? [
              chatRecorderControllerProvider
                  .overrideWith(ChatRecorderController.new),
            ]
          : overrides,
    );
  }

  group('text input', () {
    testWidgets('shows placeholder text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionMessageInput));
      expect(
        find.text(context.messages.agentEvolutionChatPlaceholder),
        findsOneWidget,
      );
    });

    testWidgets('shows mic button when text is empty', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });

    testWidgets('shows send button after entering text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('tapping send calls onSend and clears text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(lastSent, 'Test message');
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
    });

    testWidgets('shows hourglass when isWaiting', (tester) async {
      await tester.pumpWidget(buildSubject(isWaiting: true));
      await tester.pump();

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

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });
  });

  group('voice recording', () {
    testWidgets('mic button starts recording when tapped', (tester) async {
      var startCalled = false;
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => IdleCallbackController(
                onStartCalled: () => startCalled = true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();

      expect(startCalled, isTrue);
    });

    testWidgets('shows mode toggle when realtime available', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider
                .overrideWith(ChatRecorderController.new),
            realtimeAvailableProvider.overrideWith((_) async => true),
            realtimeTranscriptionServiceProvider
                .overrideWithValue(realtimeServiceWithConfig()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    });

    testWidgets('transcript populates text field on completion',
        (tester) async {
      late TranscriptEmittingController controller;
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => controller = TranscriptEmittingController(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      controller.emitTranscript('Transcribed text');
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'Transcribed text');
    });
  });
}
