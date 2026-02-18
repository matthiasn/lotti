import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/input_area.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockRealtimeService extends Mock
    implements RealtimeTranscriptionService {}

void main() {
  Widget wrap(Widget child, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
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

  testWidgets(
      'TranscriptionProgress shows partial transcript during processing',
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
  testWidgets('shows Listening indicator during realtimeRecording',
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
            _RealtimeRecordingController.new,
          ),
        ],
      ),
    );

    // Use pump() due to CircularProgressIndicator animation
    await tester.pump();

    expect(find.text('Listening...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // No text field during realtime recording
    expect(find.byType(TextField), findsNothing);
    // Stop and cancel buttons visible
    expect(find.byIcon(Icons.stop), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('shows live transcript text during realtimeRecording',
      (tester) async {
    final controller = _RealtimeRecordingController(
      partialTranscript: 'Hello world',
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

    await tester.pump();

    // Shows the live transcript text
    expect(find.text('Hello world'), findsOneWidget);
    // Does NOT show "Listening..." when there's text
    expect(find.textContaining('Listening'), findsNothing);
  });

  testWidgets('shows spinner when isLoading is true', (tester) async {
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
          scrollController: ScrollController(),
          isLoading: true,
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

    // Use pump() because CircularProgressIndicator animates
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.send), findsNothing);
  });

  testWidgets('disables text field when canSend is false', (tester) async {
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
          scrollController: ScrollController(),
          isLoading: false,
          canSend: false,
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

    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);
  });

  testWidgets('shows disabled send button when canSend is false and has text',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(text: 'hello'),
          scrollController: ScrollController(),
          isLoading: false,
          canSend: false,
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

    await tester.pumpAndSettle();

    // Send icon should be visible
    expect(find.byIcon(Icons.send), findsOneWidget);

    // The IconButton should be disabled (onPressed null)
    final iconButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.send),
        matching: find.byType(IconButton),
      ),
    );
    expect(iconButton.onPressed, isNull);
  });

  testWidgets('shows tune icon when requiresModelSelection is true',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
          scrollController: ScrollController(),
          isLoading: false,
          canSend: true,
          requiresModelSelection: true,
          categoryId: 'cat',
          onSendMessage: (_) {},
        ),
        overrides: [
          chatRecorderControllerProvider
              .overrideWith(ChatRecorderController.new),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.tune), findsOneWidget);
    // No mic button when model selection required
    expect(find.byIcon(Icons.mic), findsNothing);
  });

  testWidgets('shows correct hint text for requiresModelSelection',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
          scrollController: ScrollController(),
          isLoading: false,
          canSend: true,
          requiresModelSelection: true,
          categoryId: 'cat',
          onSendMessage: (_) {},
        ),
        overrides: [
          chatRecorderControllerProvider
              .overrideWith(ChatRecorderController.new),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Select a model to start chatting'),
      findsOneWidget,
    );
  });

  testWidgets('does not send when message is empty', (tester) async {
    String? sent;
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
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

    // No send button visible (mic is shown instead when empty)
    expect(find.byIcon(Icons.send), findsNothing);
    expect(sent, isNull);
  });

  testWidgets('cancel button during recording calls cancel', (tester) async {
    var cancelCalled = false;
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
            () => _RecordingControllerWithCallbacks(
              onCancelCalled: () => cancelCalled = true,
            ),
          ),
        ],
      ),
    );

    await tester.pump();

    // Find and tap the close (cancel) button
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(cancelCalled, isTrue);
  });

  testWidgets('stop button during recording calls stop', (tester) async {
    var stopCalled = false;
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
            () => _RecordingControllerWithCallbacks(
              onStopCalled: () => stopCalled = true,
            ),
          ),
        ],
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.stop), findsOneWidget);
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();

    expect(stopCalled, isTrue);
  });

  testWidgets('cancel button during realtime recording calls cancel',
      (tester) async {
    var cancelCalled = false;
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
            () => _RealtimeControllerWithCallbacks(
              onCancelCalled: () => cancelCalled = true,
            ),
          ),
        ],
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(cancelCalled, isTrue);
  });

  testWidgets('stop button during realtime recording calls stopRealtime',
      (tester) async {
    var stopCalled = false;
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
            () => _RealtimeControllerWithCallbacks(
              onStopCalled: () => stopCalled = true,
            ),
          ),
        ],
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.stop), findsOneWidget);
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();

    expect(stopCalled, isTrue);
  });

  testWidgets('escape key during recording calls cancel', (tester) async {
    var cancelCalled = false;
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
            () => _RecordingControllerWithCallbacks(
              onCancelCalled: () => cancelCalled = true,
            ),
          ),
        ],
      ),
    );

    await tester.pump();

    // Simulate pressing Escape
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(cancelCalled, isTrue);
  });

  testWidgets('mode toggle switches between realtime and batch',
      (tester) async {
    final mockRealtime = _MockRealtimeService();
    when(mockRealtime.resolveRealtimeConfig).thenAnswer(
      (_) async => (
        provider: const _FakeProvider(),
        model: const _FakeModel(),
      ),
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
          chatRecorderControllerProvider
              .overrideWith(ChatRecorderController.new),
          realtimeTranscriptionServiceProvider.overrideWithValue(mockRealtime),
        ],
      ),
    );

    await tester.pumpAndSettle();

    // Initially in batch mode: graphic_eq toggle + mic button
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // Tap toggle to switch to realtime mode
    await tester.tap(find.byIcon(Icons.graphic_eq));
    await tester.pumpAndSettle();

    // Now in realtime mode: mic toggle + graphic_eq button
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
  });

  testWidgets('text field has send action configured', (tester) async {
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

    await tester.pumpAndSettle();

    // Verify the text field has correct textInputAction
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.textInputAction, TextInputAction.send);
    // Verify onSubmitted is wired when canSend is true
    expect(textField.onSubmitted, isNotNull);
  });

  testWidgets('text field onSubmitted is null when canSend is false',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
          scrollController: ScrollController(),
          isLoading: false,
          canSend: false,
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

    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.onSubmitted, isNull);
  });

  testWidgets('shows realtime mode toggle when available', (tester) async {
    final mockRealtime = _MockRealtimeService();
    when(mockRealtime.resolveRealtimeConfig).thenAnswer(
      (_) async => (
        provider: const _FakeProvider(),
        model: const _FakeModel(),
      ),
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
          chatRecorderControllerProvider
              .overrideWith(ChatRecorderController.new),
          realtimeTranscriptionServiceProvider.overrideWithValue(mockRealtime),
        ],
      ),
    );

    await tester.pumpAndSettle();

    // Should show both mic and waveform toggle
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
  });

  testWidgets('mic tap in realtime mode calls startRealtime', (tester) async {
    var startRealtimeCalled = false;
    final mockRealtime = _MockRealtimeService();
    when(mockRealtime.resolveRealtimeConfig).thenAnswer(
      (_) async => (
        provider: const _FakeProvider(),
        model: const _FakeModel(),
      ),
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
          chatRecorderControllerProvider.overrideWith(
            () => _IdleControllerWithCallbacks(
              onStartRealtimeCalled: () => startRealtimeCalled = true,
            ),
          ),
          realtimeTranscriptionServiceProvider.overrideWithValue(mockRealtime),
        ],
      ),
    );

    await tester.pumpAndSettle();

    // Toggle to realtime mode
    await tester.tap(find.byIcon(Icons.graphic_eq));
    await tester.pumpAndSettle();

    // Tap the mic/graphic_eq button (now in realtime mode)
    // In realtime mode the filled button shows graphic_eq icon
    find.byType(IconButton);
    // Find the filled IconButton.filled — it has the graphic_eq icon
    await tester.tap(find.byIcon(Icons.graphic_eq).last);
    await tester.pumpAndSettle();

    expect(startRealtimeCalled, isTrue);
  });

  testWidgets('escape key during realtime recording calls cancel',
      (tester) async {
    var cancelCalled = false;
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
            () => _RealtimeControllerWithCallbacks(
              onCancelCalled: () => cancelCalled = true,
            ),
          ),
        ],
      ),
    );

    await tester.pump();

    // Simulate pressing Escape during realtime recording
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(cancelCalled, isTrue);
  });

  testWidgets('transcript auto-sends when canSend is true', (tester) async {
    String? sentMessage;
    final textController = TextEditingController();
    final controller = _TranscriptEmittingController();

    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: textController,
          scrollController: ScrollController(),
          isLoading: false,
          canSend: true,
          requiresModelSelection: false,
          categoryId: 'cat',
          onSendMessage: (msg) => sentMessage = msg,
        ),
        overrides: [
          chatRecorderControllerProvider.overrideWith(() => controller),
        ],
      ),
    );

    await tester.pumpAndSettle();

    // Simulate a transcript being produced (e.g., after stopRealtime)
    controller.emitTranscript('Hello from realtime');
    await tester.pumpAndSettle();

    expect(sentMessage, 'Hello from realtime');
    // Text field should be cleared after send
    expect(textController.text, isEmpty);
  });

  testWidgets('transcript fills text field when canSend is false',
      (tester) async {
    String? sentMessage;
    final textController = TextEditingController();
    final controller = _TranscriptEmittingController();

    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: textController,
          scrollController: ScrollController(),
          isLoading: false,
          canSend: false,
          requiresModelSelection: false,
          categoryId: 'cat',
          onSendMessage: (msg) => sentMessage = msg,
        ),
        overrides: [
          chatRecorderControllerProvider.overrideWith(() => controller),
        ],
      ),
    );

    await tester.pumpAndSettle();

    // Simulate a transcript being produced
    controller.emitTranscript('Transcript text');
    await tester.pumpAndSettle();

    // Should NOT have sent a message
    expect(sentMessage, isNull);
    // Should have filled the text controller instead
    expect(textController.text, 'Transcript text');
  });
}

/// Test controller in recording state that tracks cancel/stop callbacks
class _RecordingControllerWithCallbacks extends ChatRecorderController {
  _RecordingControllerWithCallbacks({
    this.onCancelCalled,
    this.onStopCalled,
  });

  final VoidCallback? onCancelCalled;
  final VoidCallback? onStopCalled;

  @override
  ChatRecorderState build() {
    return const ChatRecorderState(
      status: ChatRecorderStatus.recording,
      amplitudeHistory: [],
    );
  }

  @override
  Future<void> cancel() async {
    onCancelCalled?.call();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }

  @override
  Future<void> stopAndTranscribe() async {
    onStopCalled?.call();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }

  @override
  List<double> getNormalizedAmplitudeHistory() => [];
}

/// Test controller in realtimeRecording state that tracks cancel/stop callbacks
class _RealtimeControllerWithCallbacks extends ChatRecorderController {
  _RealtimeControllerWithCallbacks({
    this.onCancelCalled,
    this.onStopCalled,
  });

  final VoidCallback? onCancelCalled;
  final VoidCallback? onStopCalled;

  @override
  ChatRecorderState build() {
    return const ChatRecorderState(
      status: ChatRecorderStatus.realtimeRecording,
      amplitudeHistory: [],
    );
  }

  @override
  Future<void> cancel() async {
    onCancelCalled?.call();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }

  @override
  Future<void> stopRealtime() async {
    onStopCalled?.call();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }
}

/// Test controller for realtime recording state
class _RealtimeRecordingController extends ChatRecorderController {
  _RealtimeRecordingController({String? partialTranscript})
      : _partialTranscript = partialTranscript;

  final String? _partialTranscript;

  @override
  ChatRecorderState build() {
    return ChatRecorderState(
      status: ChatRecorderStatus.realtimeRecording,
      amplitudeHistory: const [],
      partialTranscript: _partialTranscript,
    );
  }
}

/// Minimal fake for provider used in toggle visibility test
class _FakeProvider implements AiConfigInferenceProvider {
  const _FakeProvider();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeModel implements AiConfigModel {
  const _FakeModel();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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

/// Test controller that starts idle and tracks startRealtime calls
class _IdleControllerWithCallbacks extends ChatRecorderController {
  _IdleControllerWithCallbacks({
    this.onStartRealtimeCalled,
  });

  final VoidCallback? onStartRealtimeCalled;

  @override
  ChatRecorderState build() {
    return const ChatRecorderState(
      status: ChatRecorderStatus.idle,
      amplitudeHistory: [],
    );
  }

  @override
  Future<void> startRealtime() async {
    onStartRealtimeCalled?.call();
  }

  @override
  Future<void> start() async {}
}

/// Test controller that can emit a transcript to trigger the subscription
class _TranscriptEmittingController extends ChatRecorderController {
  @override
  ChatRecorderState build() {
    return const ChatRecorderState(
      status: ChatRecorderStatus.idle,
      amplitudeHistory: [],
    );
  }

  void emitTranscript(String transcript) {
    state = state.copyWith(
      status: ChatRecorderStatus.idle,
      transcript: transcript,
    );
  }

  @override
  void clearResult() {
    state = ChatRecorderState(
      status: state.status,
      amplitudeHistory: state.amplitudeHistory,
    );
  }
}
