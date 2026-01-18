import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/input_area.dart';

void main() {
  Widget wrap(Widget child, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('InputArea sends message when send tapped', (tester) async {
    String? sent;
    final controller = TextEditingController(text: 'hello');
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: controller,
          scrollController: ScrollController(),
          isLoading: false,
          canSend: true,
          requiresModelSelection: false,
          categoryId: 'cat',
          onSendMessage: (msg) => sent = msg,
        ),
        overrides: [
          chatRecorderControllerProvider
              .overrideWith(ChatRecorderController.new),
        ],
      ),
    );

    await tester.pumpAndSettle();
    // Tap the send button (IconButton.filled with send icon since there is text)
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(sent, 'hello');
  });

  testWidgets('InputArea shows mic when empty and not requiresModelSelection',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
          scrollController: ScrollController(),
          isLoading: false,
          canSend: true,
          requiresModelSelection: false,
          categoryId: 'cat',
          onSendMessage: (_) {},
        ),
        overrides: [
          chatRecorderControllerProvider
              .overrideWith(ChatRecorderController.new),
        ],
      ),
    );

    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('TranscriptionProgress shows partial transcript during processing',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
          scrollController: ScrollController(),
          isLoading: false,
          canSend: true,
          requiresModelSelection: false,
          categoryId: 'cat',
          onSendMessage: (_) {},
        ),
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            () => _ProcessingRecorderController(
              partialTranscript: 'Transcribing audio...',
            ),
          ),
        ],
      ),
    );

    // Use pump() instead of pumpAndSettle() because CircularProgressIndicator
    // animates continuously and would cause pumpAndSettle to timeout
    await tester.pump();

    // Should show the partial transcript text
    expect(find.text('Transcribing audio...'), findsOneWidget);
    // Should show the transcribe icon
    expect(find.byIcon(Icons.transcribe), findsOneWidget);
    // Should show a progress indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Should not show the text field
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('TranscriptionProgress updates as transcript grows',
      (tester) async {
    final controller = _ProcessingRecorderController(
      partialTranscript: 'First chunk',
    );

    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
          scrollController: ScrollController(),
          isLoading: false,
          canSend: true,
          requiresModelSelection: false,
          categoryId: 'cat',
          onSendMessage: (_) {},
        ),
        overrides: [
          chatRecorderControllerProvider.overrideWith(() => controller),
        ],
      ),
    );

    // Use pump() due to CircularProgressIndicator animation
    await tester.pump();
    expect(find.text('First chunk'), findsOneWidget);

    // Update the partial transcript
    controller.updatePartialTranscript('First chunk Second chunk');
    await tester.pump();

    expect(find.text('First chunk Second chunk'), findsOneWidget);
  });

  testWidgets(
      'InputArea shows TextField when processing without partialTranscript',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
          scrollController: ScrollController(),
          isLoading: false,
          canSend: true,
          requiresModelSelection: false,
          categoryId: 'cat',
          onSendMessage: (_) {},
        ),
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            () => _ProcessingRecorderController(
              partialTranscript: null,
            ),
          ),
        ],
      ),
    );

    // Use pump() due to CircularProgressIndicator animation
    await tester.pump();

    // Should show the text field (disabled) since no partialTranscript
    expect(find.byType(TextField), findsOneWidget);
    // Should show progress indicator in the button
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

/// Test controller that returns a processing state with optional partialTranscript
class _ProcessingRecorderController extends ChatRecorderController {
  _ProcessingRecorderController({
    required String? partialTranscript,
  }) : _partialTranscript = partialTranscript;

  String? _partialTranscript;

  @override
  ChatRecorderState build() {
    return ChatRecorderState(
      status: ChatRecorderStatus.processing,
      amplitudeHistory: const [],
      partialTranscript: _partialTranscript,
    );
  }

  void updatePartialTranscript(String newValue) {
    _partialTranscript = newValue;
    state = ChatRecorderState(
      status: ChatRecorderStatus.processing,
      amplitudeHistory: const [],
      partialTranscript: _partialTranscript,
    );
  }
}
