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

/// Wraps [child] in [ProviderScope] + [MaterialApp] with localization.
Widget _wrap(Widget child, {List<Override> overrides = const []}) =>
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

/// Creates an [InputArea] with sensible defaults.  Only the varying parts
/// need to be passed.
Widget _inputArea({
  TextEditingController? controller,
  bool isLoading = false,
  bool canSend = true,
  bool requiresModelSelection = false,
  void Function(String)? onSendMessage,
}) =>
    InputArea(
      controller: controller ?? TextEditingController(),
      scrollController: ScrollController(),
      isLoading: isLoading,
      canSend: canSend,
      requiresModelSelection: requiresModelSelection,
      categoryId: 'cat',
      onSendMessage: onSendMessage ?? (_) {},
    );

/// Override that uses the real [ChatRecorderController].
Override _defaultRecorderOverride() =>
    chatRecorderControllerProvider.overrideWith(ChatRecorderController.new);

/// Creates a [_MockRealtimeService] that reports realtime config available.
_MockRealtimeService _realtimeServiceWithConfig() {
  final mock = _MockRealtimeService();
  when(mock.resolveRealtimeConfig).thenAnswer(
    (_) async => (
      provider: const _FakeProvider(),
      model: const _FakeModel(),
    ),
  );
  return mock;
}

void main() {
  testWidgets('InputArea sends message when send tapped', (tester) async {
    String? sent;
    await tester.pumpWidget(
      _wrap(
        _inputArea(
          controller: TextEditingController(text: 'hello'),
          onSendMessage: (msg) => sent = msg,
        ),
        overrides: [_defaultRecorderOverride()],
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(sent, 'hello');
  });

  testWidgets('InputArea shows mic when empty and not requiresModelSelection',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(),
        overrides: [_defaultRecorderOverride()],
      ),
    );

    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets(
      'TranscriptionProgress shows partial transcript during processing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(),
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            () => _ProcessingRecorderController(
              partialTranscript: 'Transcribing audio...',
            ),
          ),
        ],
      ),
    );

    await tester.pump();

    expect(find.text('Transcribing audio...'), findsOneWidget);
    expect(find.byIcon(Icons.transcribe), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('TranscriptionProgress updates as transcript grows',
      (tester) async {
    final controller = _ProcessingRecorderController(
      partialTranscript: 'First chunk',
    );

    await tester.pumpWidget(
      _wrap(
        _inputArea(),
        overrides: [
          chatRecorderControllerProvider.overrideWith(() => controller),
        ],
      ),
    );

    await tester.pump();
    expect(find.text('First chunk'), findsOneWidget);

    controller.updatePartialTranscript('First chunk Second chunk');
    await tester.pump();

    expect(find.text('First chunk Second chunk'), findsOneWidget);
  });

  testWidgets(
      'InputArea shows TextField when processing without partialTranscript',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(),
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            () => _ProcessingRecorderController(partialTranscript: null),
          ),
        ],
      ),
    );

    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows Listening indicator during realtimeRecording',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(),
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            _RealtimeRecordingController.new,
          ),
        ],
      ),
    );

    await tester.pump();

    expect(find.text('Listening...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.stop), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('shows live transcript text during realtimeRecording',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(),
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            () =>
                _RealtimeRecordingController(partialTranscript: 'Hello world'),
          ),
        ],
      ),
    );

    await tester.pump();

    expect(find.text('Hello world'), findsOneWidget);
    expect(find.textContaining('Listening'), findsNothing);
  });

  testWidgets('shows spinner when isLoading is true', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(isLoading: true),
        overrides: [_defaultRecorderOverride()],
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.send), findsNothing);
  });

  testWidgets('disables text field when canSend is false', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(canSend: false),
        overrides: [_defaultRecorderOverride()],
      ),
    );

    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);
  });

  testWidgets('shows disabled send button when canSend is false and has text',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(
          controller: TextEditingController(text: 'hello'),
          canSend: false,
        ),
        overrides: [_defaultRecorderOverride()],
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.send), findsOneWidget);

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
      _wrap(
        _inputArea(requiresModelSelection: true),
        overrides: [_defaultRecorderOverride()],
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsNothing);
  });

  testWidgets('shows correct hint text for requiresModelSelection',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(requiresModelSelection: true),
        overrides: [_defaultRecorderOverride()],
      ),
    );

    await tester.pump();

    expect(find.text('Select a model to start chatting'), findsOneWidget);
  });

  testWidgets('does not send when message is empty', (tester) async {
    String? sent;
    await tester.pumpWidget(
      _wrap(
        _inputArea(onSendMessage: (msg) => sent = msg),
        overrides: [_defaultRecorderOverride()],
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.send), findsNothing);
    expect(sent, isNull);
  });

  testWidgets('cancel button during recording calls cancel', (tester) async {
    var cancelCalled = false;
    await tester.pumpWidget(
      _wrap(
        _inputArea(),
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

    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(cancelCalled, isTrue);
  });

  testWidgets('stop button during recording calls stop', (tester) async {
    var stopCalled = false;
    await tester.pumpWidget(
      _wrap(
        _inputArea(),
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
      _wrap(
        _inputArea(),
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
      _wrap(
        _inputArea(),
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
      _wrap(
        _inputArea(),
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

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(cancelCalled, isTrue);
  });

  testWidgets('mode toggle switches between realtime and batch',
      (tester) async {
    final mockRealtime = _realtimeServiceWithConfig();

    await tester.pumpWidget(
      _wrap(
        _inputArea(),
        overrides: [
          _defaultRecorderOverride(),
          realtimeTranscriptionServiceProvider.overrideWithValue(mockRealtime),
        ],
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    await tester.tap(find.byIcon(Icons.graphic_eq));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
  });

  testWidgets('text field has send action configured', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(),
        overrides: [_defaultRecorderOverride()],
      ),
    );

    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.textInputAction, TextInputAction.send);
    expect(textField.onSubmitted, isNotNull);
  });

  testWidgets('text field onSubmitted is null when canSend is false',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        _inputArea(canSend: false),
        overrides: [_defaultRecorderOverride()],
      ),
    );

    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.onSubmitted, isNull);
  });

  testWidgets('shows realtime mode toggle when available', (tester) async {
    final mockRealtime = _realtimeServiceWithConfig();

    await tester.pumpWidget(
      _wrap(
        _inputArea(),
        overrides: [
          _defaultRecorderOverride(),
          realtimeTranscriptionServiceProvider.overrideWithValue(mockRealtime),
        ],
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
  });

  testWidgets('mic tap in realtime mode calls startRealtime', (tester) async {
    var startRealtimeCalled = false;
    final mockRealtime = _realtimeServiceWithConfig();

    await tester.pumpWidget(
      _wrap(
        _inputArea(),
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

    await tester.pump();

    // Toggle to realtime mode
    await tester.tap(find.byIcon(Icons.graphic_eq));
    await tester.pumpAndSettle();

    // In realtime mode the filled button shows graphic_eq icon
    await tester.tap(find.byIcon(Icons.graphic_eq).last);
    await tester.pumpAndSettle();

    expect(startRealtimeCalled, isTrue);
  });

  testWidgets('escape key during realtime recording calls cancel',
      (tester) async {
    var cancelCalled = false;
    await tester.pumpWidget(
      _wrap(
        _inputArea(),
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

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(cancelCalled, isTrue);
  });

  testWidgets('transcript auto-sends when canSend is true', (tester) async {
    String? sentMessage;
    final textController = TextEditingController();
    final controller = _TranscriptEmittingController();

    await tester.pumpWidget(
      _wrap(
        _inputArea(
          controller: textController,
          onSendMessage: (msg) => sentMessage = msg,
        ),
        overrides: [
          chatRecorderControllerProvider.overrideWith(() => controller),
        ],
      ),
    );

    await tester.pump();

    controller.emitTranscript('Hello from realtime');
    await tester.pumpAndSettle();

    expect(sentMessage, 'Hello from realtime');
    expect(textController.text, isEmpty);
  });

  testWidgets('transcript fills text field when canSend is false',
      (tester) async {
    String? sentMessage;
    final textController = TextEditingController();
    final controller = _TranscriptEmittingController();

    await tester.pumpWidget(
      _wrap(
        _inputArea(
          controller: textController,
          canSend: false,
          onSendMessage: (msg) => sentMessage = msg,
        ),
        overrides: [
          chatRecorderControllerProvider.overrideWith(() => controller),
        ],
      ),
    );

    await tester.pump();

    controller.emitTranscript('Transcript text');
    await tester.pumpAndSettle();

    expect(sentMessage, isNull);
    expect(textController.text, 'Transcript text');
  });
}

// ---------------------------------------------------------------------------
// Fake controllers
// ---------------------------------------------------------------------------

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

/// Test controller that returns a processing state with optional
/// partialTranscript
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
