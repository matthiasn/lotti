import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

void main() {
  testWidgets(
      'Chat input shows mic by default, waveform + Cancel/Stop while recording',
      (tester) async {
    const categoryId = 'cat-1';

    // Ensure a clean DI slate for this test
    await getIt.reset();

    // Capture sent messages without static state
    final lastSent = ValueNotifier<String?>(null);

    final overrides = <Override>[
      // Recorder provider overridden with a fake controller we can observe
      chatRecorderControllerProvider.overrideWith(
        _FakeChatRecorderController.new,
      ),

      // Provide a simple chat session state where sending is allowed
      chatSessionControllerProvider(categoryId).overrideWith(
        () => _FakeChatSessionController(sink: lastSent),
      ),

      // No eligible models needed in header for this test
      eligibleChatModelsForCategoryProvider(categoryId)
          .overrideWith((_) async => []),
    ];

    // Minimal DI to satisfy ChatSessionController base class
    getIt.registerSingleton<LoggingService>(_FakeLoggingService());

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: categoryId),
          ),
        ),
      ),
    );

    // Let post-frame init settle
    await tester.pump();

    // Default: mic icon visible
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // Tap mic to start recording
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();

    // Now Cancel (close) and Stop icons should be visible
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);

    // Stop → triggers fake transcription, which auto-sends
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();
    // Allow auto-scroll timer to complete and any queued frames to settle
    // Drive the 100ms delayed scroll + 300ms animateTo without overpumping
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Assert our fake session controller received the sent text
    expect(lastSent.value, 'Hi there');
  });

  testWidgets('Cancel discards recording and returns to mic', (tester) async {
    const categoryId = 'cat-1';
    await getIt.reset();
    getIt.registerSingleton<LoggingService>(_FakeLoggingService());

    final lastSent = ValueNotifier<String?>(null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            _FakeChatRecorderController.new,
          ),
          chatSessionControllerProvider(categoryId).overrideWith(
            () => _FakeChatSessionController(sink: lastSent),
          ),
          eligibleChatModelsForCategoryProvider(categoryId)
              .overrideWith((_) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChatInterface(categoryId: categoryId)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.mic), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    expect(find.byKey(const ValueKey('waveform_bars')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.byIcon(Icons.mic), findsOneWidget);
    // Ensure no message was sent
    expect(lastSent.value, isNull);
  });

  testWidgets('Esc cancels recording', (tester) async {
    const categoryId = 'cat-1';
    await getIt.reset();
    getIt.registerSingleton<LoggingService>(_FakeLoggingService());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            _FakeChatRecorderController.new,
          ),
          chatSessionControllerProvider(categoryId).overrideWith(
            () =>
                _FakeChatSessionController(sink: ValueNotifier<String?>(null)),
          ),
          eligibleChatModelsForCategoryProvider(categoryId)
              .overrideWith((_) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChatInterface(categoryId: categoryId)),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    expect(find.byKey(const ValueKey('waveform_bars')), findsOneWidget);

    // Send escape key
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('When cannot send, mic is hidden and settings opens sheet',
      (tester) async {
    const categoryId = 'cat-1';
    await getIt.reset();
    getIt.registerSingleton<LoggingService>(_FakeLoggingService());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            _FakeChatRecorderController.new,
          ),
          chatSessionControllerProvider(categoryId).overrideWith(
            _NonSendableChatSessionController.new,
          ),
          eligibleChatModelsForCategoryProvider(categoryId)
              .overrideWith((_) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChatInterface(categoryId: categoryId)),
        ),
      ),
    );
    await tester.pump();

    // Mic hidden; header settings present
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byTooltip('Assistant settings'), findsOneWidget);

    // Tapping header settings opens the Assistant Settings sheet
    await tester.tap(find.byTooltip('Assistant settings'));
    await tester.pumpAndSettle();
    expect(find.text('Assistant Settings'), findsOneWidget);
  });

  testWidgets('Processing state shows spinner and disables input',
      (tester) async {
    const categoryId = 'cat-1';
    await getIt.reset();
    getIt.registerSingleton<LoggingService>(_FakeLoggingService());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            _ProcessingChatRecorderController.new,
          ),
          chatSessionControllerProvider(categoryId).overrideWith(
            () =>
                _FakeChatSessionController(sink: ValueNotifier<String?>(null)),
          ),
          eligibleChatModelsForCategoryProvider(categoryId)
              .overrideWith((_) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChatInterface(categoryId: categoryId)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();

    // Spinner while processing
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final textField = tester.widget<TextField>(
      find.byKey(const ValueKey('chat_text_field')),
    );
    expect(textField.enabled, isFalse);

    // No cancel available in processing; finish without teardown actions
  });

  testWidgets('Tooltips reflect state transitions (sendable session)',
      (tester) async {
    const categoryId = 'cat-1';
    await getIt.reset();
    getIt.registerSingleton<LoggingService>(_FakeLoggingService());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            _FakeChatRecorderController.new,
          ),
          // Make session sendable so mic is available
          chatSessionControllerProvider(categoryId).overrideWith(
            () =>
                _FakeChatSessionController(sink: ValueNotifier<String?>(null)),
          ),
          eligibleChatModelsForCategoryProvider(categoryId)
              .overrideWith((_) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChatInterface(categoryId: categoryId)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Idle tooltip
    expect(find.byTooltip('Record voice message'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    expect(find.byTooltip('Cancel recording (Esc)'), findsOneWidget);
    expect(find.byTooltip('Stop and transcribe'), findsOneWidget);
  });

  testWidgets('When cannot send, mic is hidden and settings opens sheet',
      (tester) async {
    const categoryId = 'cat-1';
    await getIt.reset();
    getIt.registerSingleton<LoggingService>(_FakeLoggingService());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRecorderControllerProvider.overrideWith(
            _FakeChatRecorderController.new,
          ),
          // Non-sendable session (no selected model)
          chatSessionControllerProvider(categoryId)
              .overrideWith(_NonSendableChatSessionController.new),
          eligibleChatModelsForCategoryProvider(categoryId)
              .overrideWith((_) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChatInterface(categoryId: categoryId)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Mic hidden; header settings available
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byTooltip('Assistant settings'), findsOneWidget);

    // Tapping header settings opens the Assistant Settings sheet
    await tester.tap(find.byTooltip('Assistant settings'));
    await tester.pumpAndSettle();
    expect(find.text('Assistant Settings'), findsOneWidget);
  });
}

class _FakeChatRecorderController extends ChatRecorderController {
  _FakeChatRecorderController();

  @override
  ChatRecorderState build() => const ChatRecorderState.initial();

  @override
  Future<void> start() async {
    state = state.copyWith(status: ChatRecorderStatus.recording);
  }

  @override
  Future<void> stopAndTranscribe() async {
    state = state.copyWith(status: ChatRecorderStatus.processing);
    // Yield once to simulate async processing without real sleep
    await Future<void>(() {});
    state = const ChatRecorderState(
      status: ChatRecorderStatus.idle,
      amplitudeHistory: <double>[],
      transcript: 'Hi there',
    );
  }

  @override
  Future<void> cancel() async {
    state = const ChatRecorderState.initial();
  }

  @override
  List<double> getNormalizedAmplitudeHistory() => const <double>[0.2, 0.6, 0.9];
}

class _FakeChatSessionController extends ChatSessionController {
  _FakeChatSessionController({required this.sink});

  final ValueNotifier<String?> sink;
  @override
  ChatSessionUiModel build(String categoryId) {
    // Selected model set so sending is allowed
    return const ChatSessionUiModel(
      id: 's',
      title: 't',
      messages: <ChatMessage>[],
      isLoading: false,
      isStreaming: false,
      selectedModelId: 'model-1',
    );
  }

  @override
  Future<void> initializeSession({String? sessionId}) async {}

  @override
  Future<void> sendMessage(String content) async {
    sink.value = content;
  }
}

class _NonSendableChatSessionController extends ChatSessionController {
  @override
  ChatSessionUiModel build(String categoryId) {
    // No selected model -> cannot send
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

  @override
  Future<void> sendMessage(String content) async {}
}

class _ProcessingChatRecorderController extends ChatRecorderController {
  _ProcessingChatRecorderController();

  @override
  ChatRecorderState build() => const ChatRecorderState.initial();

  @override
  Future<void> start() async {
    state = state.copyWith(status: ChatRecorderStatus.recording);
  }

  @override
  Future<void> stopAndTranscribe() async {
    // Stay in processing state for assertions
    state = state.copyWith(status: ChatRecorderStatus.processing);
  }
}

class _FakeLoggingService extends LoggingService {
  @override
  void captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) {}

  @override
  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {}
}
