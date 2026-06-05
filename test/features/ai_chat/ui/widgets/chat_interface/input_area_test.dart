import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/assistant_settings_sheet.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/input_area.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../widget_test_utils.dart';

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
}) => InputArea(
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

// ignore: comment_references
/// Override that makes [realtimeAvailableProvider] return [true].
Override _realtimeAvailableOverride() =>
    realtimeAvailableProvider.overrideWith((_) async => true);

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

  testWidgets('InputArea shows mic when empty and not requiresModelSelection', (
    tester,
  ) async {
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
    },
  );

  testWidgets('TranscriptionProgress updates as transcript grows', (
    tester,
  ) async {
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
    },
  );

  testWidgets('shows Listening indicator during realtimeRecording', (
    tester,
  ) async {
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

  testWidgets('shows live transcript text during realtimeRecording', (
    tester,
  ) async {
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

  testWidgets('shows disabled send button when canSend is false and has text', (
    tester,
  ) async {
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

  testWidgets('shows tune icon when requiresModelSelection is true', (
    tester,
  ) async {
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

  testWidgets('shows correct hint text for requiresModelSelection', (
    tester,
  ) async {
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

  testWidgets('cancel button during realtime recording calls cancel', (
    tester,
  ) async {
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

  testWidgets('stop button during realtime recording calls stopRealtime', (
    tester,
  ) async {
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

  testWidgets('hides realtime mode toggle while realtime UI is disabled', (
    tester,
  ) async {
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
    expect(find.byIcon(Icons.graphic_eq), findsNothing);
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

  testWidgets('text field onSubmitted is null when canSend is false', (
    tester,
  ) async {
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

  testWidgets('keeps batch mic when realtime model is configured', (
    tester,
  ) async {
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
    expect(find.byIcon(Icons.graphic_eq), findsNothing);
  });

  testWidgets('mic tap starts batch while realtime UI is disabled', (
    tester,
  ) async {
    var startCalled = false;
    var startRealtimeCalled = false;
    final mockRealtime = _realtimeServiceWithConfig();

    await tester.pumpWidget(
      _wrap(
        _inputArea(),
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            () => _IdleControllerWithCallbacks(
              onStartCalled: () => startCalled = true,
              onStartRealtimeCalled: () => startRealtimeCalled = true,
            ),
          ),
          realtimeTranscriptionServiceProvider.overrideWithValue(mockRealtime),
        ],
      ),
    );

    await tester.pump();

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    expect(startCalled, isTrue);
    expect(startRealtimeCalled, isFalse);
  });

  testWidgets('escape key during realtime recording calls cancel', (
    tester,
  ) async {
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

  testWidgets('transcript fills text field when canSend is false', (
    tester,
  ) async {
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

  // ---------------------------------------------------------------------------
  // Tune button / requiresModelSelection dialog (lines 234-241)
  // ---------------------------------------------------------------------------

  testWidgets(
    'tapping tune button opens AssistantSettingsSheet dialog',
    (tester) async {
      ensureDomainLoggerRegistered();
      await tester.pumpWidget(
        _wrap(
          _inputArea(requiresModelSelection: true),
          overrides: [
            _defaultRecorderOverride(),
            eligibleChatModelsForCategoryProvider('cat').overrideWith(
              (ref) async => <AiConfigModel>[],
            ),
            chatSessionControllerProvider('cat').overrideWith(
              _StaticChatController.new,
            ),
          ],
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.tune), findsOneWidget);
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Dialog with AssistantSettingsSheet should be open.
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(AssistantSettingsSheet), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Realtime available — two-button row (lines 253-295)
  // ---------------------------------------------------------------------------

  testWidgets(
    'shows mode-toggle and mic buttons when realtimeAvailable is true',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _inputArea(),
          overrides: [
            _defaultRecorderOverride(),
            _realtimeAvailableOverride(),
          ],
        ),
      );

      // Wait for the FutureProvider to resolve.
      await tester.pumpAndSettle();

      // Two icon buttons appear: mode-toggle (graphic_eq) and main mic.
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    },
  );

  testWidgets(
    'when useRealtimeMode=false toggle shows graphic_eq and main button shows mic',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _inputArea(),
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => _IdleControllerWithRealtimeMode(useRealtimeMode: false),
            ),
            _realtimeAvailableOverride(),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Toggle icon = graphic_eq (tap to switch TO realtime).
      final toggleButton = find.ancestor(
        of: find.byIcon(Icons.graphic_eq),
        matching: find.byType(IconButton),
      );
      expect(toggleButton, findsOneWidget);
      // Main button icon = mic.
      expect(find.byIcon(Icons.mic), findsOneWidget);
    },
  );

  testWidgets(
    'when useRealtimeMode=true toggle shows mic and main button shows graphic_eq',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _inputArea(),
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => _IdleControllerWithRealtimeMode(useRealtimeMode: true),
            ),
            _realtimeAvailableOverride(),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Toggle icon = mic (tap to switch BACK to batch).
      final toggleButton = find.ancestor(
        of: find.byIcon(Icons.mic),
        matching: find.byType(IconButton),
      );
      expect(toggleButton, findsOneWidget);
      // Main button icon = graphic_eq.
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    },
  );

  testWidgets(
    'tapping mode-toggle button calls toggleRealtimeMode',
    (tester) async {
      var toggleCalled = false;
      await tester.pumpWidget(
        _wrap(
          _inputArea(),
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => _IdleControllerWithCallbacks(
                onToggleRealtimeModeCalled: () => toggleCalled = true,
              ),
            ),
            _realtimeAvailableOverride(),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // The mode toggle has the smaller size (36×36) and shows graphic_eq.
      final toggleButton = find.ancestor(
        of: find.byIcon(Icons.graphic_eq),
        matching: find.byType(IconButton),
      );
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pump();

      expect(toggleCalled, isTrue);
    },
  );

  testWidgets(
    'tapping main mic starts batch recording when useRealtimeMode=false',
    (tester) async {
      var startCalled = false;
      var startRealtimeCalled = false;
      await tester.pumpWidget(
        _wrap(
          _inputArea(),
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => _IdleControllerWithCallbacks(
                onStartCalled: () => startCalled = true,
                onStartRealtimeCalled: () => startRealtimeCalled = true,
              ),
            ),
            _realtimeAvailableOverride(),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Main filled mic button (useRealtimeMode defaults to false → mic icon).
      final mainMicButton = find
          .ancestor(
            of: find.byIcon(Icons.mic),
            matching: find.byType(IconButton),
          )
          .last;
      await tester.tap(mainMicButton);
      await tester.pump();

      expect(startCalled, isTrue);
      expect(startRealtimeCalled, isFalse);
    },
  );

  testWidgets(
    'tapping main button starts realtime recording when useRealtimeMode=true',
    (tester) async {
      var startCalled = false;
      var startRealtimeCalled = false;
      await tester.pumpWidget(
        _wrap(
          _inputArea(),
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => _IdleControllerWithCallbacks(
                useRealtimeMode: true,
                onStartCalled: () => startCalled = true,
                onStartRealtimeCalled: () => startRealtimeCalled = true,
              ),
            ),
            _realtimeAvailableOverride(),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // When useRealtimeMode=true, main button shows graphic_eq.
      final mainButton = find
          .ancestor(
            of: find.byIcon(Icons.graphic_eq),
            matching: find.byType(IconButton),
          )
          .last;
      await tester.tap(mainButton);
      await tester.pump();

      expect(startRealtimeCalled, isTrue);
      expect(startCalled, isFalse);
    },
  );

  testWidgets(
    'send button clears text field after message sent',
    (tester) async {
      final textController = TextEditingController(text: 'hello world');
      String? sent;

      await tester.pumpWidget(
        _wrap(
          _inputArea(
            controller: textController,
            onSendMessage: (msg) => sent = msg,
          ),
          overrides: [_defaultRecorderOverride()],
        ),
      );

      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      // One pump runs the post-frame scroll callback in _sendMessage.
      await tester.pump();

      expect(sent, 'hello world');
      expect(textController.text, isEmpty);
    },
  );

  testWidgets(
    'onSubmitted sends message and clears text field',
    (tester) async {
      final textController = TextEditingController(text: 'typed message');
      String? sent;

      await tester.pumpWidget(
        _wrap(
          _inputArea(
            controller: textController,
            onSendMessage: (msg) => sent = msg,
          ),
          overrides: [_defaultRecorderOverride()],
        ),
      );

      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      textField.onSubmitted!('typed message');
      // One pump runs the post-frame scroll callback in _sendMessage.
      await tester.pump();

      expect(sent, 'typed message');
      expect(textController.text, isEmpty);
    },
  );
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
  _RealtimeRecordingController({this._partialTranscript});

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
    required this._partialTranscript,
  });

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
    this.onStartCalled,
    this.onStartRealtimeCalled,
    this.onToggleRealtimeModeCalled,
    this.useRealtimeMode = false,
  });

  final VoidCallback? onStartCalled;
  final VoidCallback? onStartRealtimeCalled;
  final VoidCallback? onToggleRealtimeModeCalled;
  final bool useRealtimeMode;

  @override
  ChatRecorderState build() {
    return ChatRecorderState(
      status: ChatRecorderStatus.idle,
      amplitudeHistory: const [],
      useRealtimeMode: useRealtimeMode,
    );
  }

  @override
  Future<void> startRealtime() async {
    onStartRealtimeCalled?.call();
  }

  @override
  Future<void> start() async {
    onStartCalled?.call();
  }

  @override
  void toggleRealtimeMode() {
    onToggleRealtimeModeCalled?.call();
    state = state.copyWith(useRealtimeMode: !state.useRealtimeMode);
  }
}

/// Test controller that starts idle with a configurable [useRealtimeMode].
class _IdleControllerWithRealtimeMode extends ChatRecorderController {
  _IdleControllerWithRealtimeMode({required this.useRealtimeMode});

  final bool useRealtimeMode;

  @override
  ChatRecorderState build() {
    return ChatRecorderState(
      status: ChatRecorderStatus.idle,
      amplitudeHistory: const [],
      useRealtimeMode: useRealtimeMode,
    );
  }
}

/// Minimal fake [ChatSessionController] that returns a non-streaming state.
class _StaticChatController extends ChatSessionController {
  @override
  ChatSessionUiModel build(String categoryId) {
    return const ChatSessionUiModel(
      id: 's',
      title: 't',
      messages: <ChatMessage>[],
      isLoading: false,
      isStreaming: false,
    );
  }

  @override
  Future<void> initializeSession({String? sessionId}) async {}
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
