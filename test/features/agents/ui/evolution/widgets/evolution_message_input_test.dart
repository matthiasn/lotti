import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_realtime_view.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_transcription_progress.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_voice_controls.dart';
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

    testWidgets('shows voice controls when recording', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              RecordingTestController.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionVoiceControls), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('recording cancel calls controller cancel', (tester) async {
      var cancelCalled = false;
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => RecordingCallbackController(
                onCancelCalled: () => cancelCalled = true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionVoiceControls), findsOneWidget);
      // Tap the cancel button (close icon)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(cancelCalled, isTrue);
    });

    testWidgets('recording stop calls stopAndTranscribe', (tester) async {
      var stopCalled = false;
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => RecordingCallbackController(
                onStopCalled: () => stopCalled = true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionVoiceControls), findsOneWidget);
      // Tap the stop button (stop icon)
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(stopCalled, isTrue);
    });

    testWidgets('shows realtime view when realtime recording', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              RealtimeRecordingTestController.new,
            ),
          ],
        ),
      );
      // Use pump() — EvolutionRealtimeView has a CircularProgressIndicator
      // that never settles.
      await tester.pump();
      await tester.pump();

      expect(find.byType(EvolutionRealtimeView), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('realtime view shows partial transcript', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => RealtimeRecordingTestController(
                partialTranscript: 'Hello world',
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(EvolutionRealtimeView), findsOneWidget);
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('realtime cancel calls controller cancel', (tester) async {
      var cancelCalled = false;
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => RealtimeCallbackController(
                onCancelCalled: () => cancelCalled = true,
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(EvolutionRealtimeView), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(cancelCalled, isTrue);
    });

    testWidgets('realtime stop calls stopRealtime', (tester) async {
      var stopCalled = false;
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => RealtimeCallbackController(
                onStopCalled: () => stopCalled = true,
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(EvolutionRealtimeView), findsOneWidget);
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(stopCalled, isTrue);
    });

    testWidgets('shows transcription progress when processing with partial',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => ProcessingTestController(
                partialTranscript: 'Transcribing...',
              ),
            ),
          ],
        ),
      );
      // Use pump() — EvolutionTranscriptionProgress has a
      // CircularProgressIndicator that never settles.
      await tester.pump();
      await tester.pump();

      expect(find.byType(EvolutionTranscriptionProgress), findsOneWidget);
      expect(find.text('Transcribing...'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows idle row with hourglass when processing without partial',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => ProcessingTestController(partialTranscript: null),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Should show idle row (with TextField) and hourglass icon
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      // TextField should be disabled during processing
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('toggle realtime mode switches icons when realtime available',
        (tester) async {
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

      // Default mode: batch. Toggle button shows mic (small), main button
      // shows graphic_eq (or vice versa depending on useRealtimeMode).
      // By default useRealtimeMode=false, so toggle icon=graphic_eq,
      // main mic icon=mic
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);

      // Tap toggle button (the smaller one with graphic_eq)
      await tester.tap(find.byIcon(Icons.graphic_eq));
      await tester.pump();

      // After toggle, useRealtimeMode=true, icons swap
      // Toggle shows mic (small), main shows graphic_eq
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    });

    testWidgets('realtime mode starts realtime recording on main button tap',
        (tester) async {
      var startRealtimeCalled = false;
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => IdleCallbackController(
                onStartRealtimeCalled: () => startRealtimeCalled = true,
              ),
            ),
            realtimeAvailableProvider.overrideWith((_) async => true),
            realtimeTranscriptionServiceProvider
                .overrideWithValue(realtimeServiceWithConfig()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Toggle to realtime mode first
      await tester.tap(find.byIcon(Icons.graphic_eq));
      await tester.pump();

      // Now tap the main button (graphic_eq in realtime mode)
      await tester.tap(find.byIcon(Icons.graphic_eq));
      await tester.pump();

      expect(startRealtimeCalled, isTrue);
    });

    testWidgets('does not send when isWaiting even with text', (tester) async {
      await tester.pumpWidget(buildSubject(isWaiting: true));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Some text');
      await tester.pump();

      // The send button should show but be disabled (canSend = false)
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(lastSent, isNull);
    });
  });
}
