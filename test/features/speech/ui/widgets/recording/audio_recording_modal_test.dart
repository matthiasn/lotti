import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/widgets/ui/lotti_animated_checkbox.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockAudioPlayerCubit extends Mock implements AudioPlayerCubit {}

class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class FakeCategoryDefinition extends Fake implements CategoryDefinition {
  FakeCategoryDefinition({
    this.includeTranscriptionPrompts = true,
    this.includeChecklistPrompts = true,
    this.includeTaskSummaryPrompts = true,
  });

  final bool includeTranscriptionPrompts;
  final bool includeChecklistPrompts;
  final bool includeTaskSummaryPrompts;

  @override
  String get id => 'test-category';

  @override
  String get name => 'Test Category';

  @override
  DateTime get createdAt => DateTime.now();

  @override
  DateTime get updatedAt => DateTime.now();

  @override
  bool get private => false;

  @override
  String? get color => '#000000';

  @override
  bool get active => true;

  @override
  bool get favorite => false;

  @override
  String? get defaultLanguageCode => null;

  @override
  List<String>? get allowedPromptIds => null;

  @override
  Map<AiResponseType, List<String>>? get automaticPrompts {
    final prompts = <AiResponseType, List<String>>{};

    if (includeTranscriptionPrompts) {
      prompts[AiResponseType.audioTranscription] = ['transcription-prompt'];
    }

    if (includeTaskSummaryPrompts) {
      prompts[AiResponseType.taskSummary] = ['summary-prompt'];
    }

    if (includeChecklistPrompts) {
      prompts[AiResponseType.checklistUpdates] = ['checklist-prompt'];
    }

    return prompts.isEmpty ? null : prompts;
  }

  @override
  CategoryIcon? get icon => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoggingService mockLoggingService;
  late MockAudioPlayerCubit mockAudioPlayerCubit;
  late MockAudioRecorderRepository mockAudioRecorderRepository;
  late MockCategoryRepository mockCategoryRepository;

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockAudioPlayerCubit = MockAudioPlayerCubit();
    mockAudioRecorderRepository = MockAudioRecorderRepository();
    mockCategoryRepository = MockCategoryRepository();

    // Setup default mock behavior for AudioPlayerCubit
    when(() => mockAudioPlayerCubit.state).thenReturn(
      AudioPlayerState(
        status: AudioPlayerStatus.stopped,
        totalDuration: Duration.zero,
        progress: Duration.zero,
        pausedAt: Duration.zero,
        speed: 1,
        showTranscriptsList: false,
      ),
    );
    when(() => mockAudioPlayerCubit.pause()).thenAnswer((_) async {});

    // Setup default mock behavior for AudioRecorderRepository
    when(() => mockAudioRecorderRepository.amplitudeStream).thenAnswer(
      (_) => const Stream<Amplitude>.empty(),
    );
    when(() => mockAudioRecorderRepository.hasPermission())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.isPaused())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.isRecording())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.stopRecording())
        .thenAnswer((_) async {});
    when(() => mockAudioRecorderRepository.startRecording())
        .thenAnswer((_) async => null);
    when(() => mockAudioRecorderRepository.pauseRecording())
        .thenAnswer((_) async {});
    when(() => mockAudioRecorderRepository.resumeRecording())
        .thenAnswer((_) async {});

    // Register mocks with GetIt
    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<AudioPlayerCubit>(mockAudioPlayerCubit);
  });

  tearDown(getIt.reset);

  Widget createTestWidget({
    AudioRecorderState? state,
    CategoryDefinition? category,
    String? linkedTaskId,
    bool provideCategory = true,
  }) {
    final categoryToUse = category ?? FakeCategoryDefinition();

    // Mock the repository to return our test category
    when(() => mockCategoryRepository.watchCategory('test-category'))
        .thenAnswer(
      (_) => provideCategory ? Stream.value(categoryToUse) : Stream.value(null),
    );

    // Create a provider container with the mocked dependencies
    return ProviderScope(
      overrides: [
        audioRecorderRepositoryProvider.overrideWithValue(
          mockAudioRecorderRepository,
        ),
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
      ],
      child: Builder(
        builder: (context) {
          // If we have a specific state to set, update the controller
          if (state != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ProviderScope.containerOf(context)
                  .read(audioRecorderControllerProvider.notifier)
                ..setEnableSpeechRecognition(
                  enable: state.enableSpeechRecognition,
                )
                ..setEnableChecklistUpdates(
                  enable: state.enableChecklistUpdates,
                )
                ..setEnableTaskSummary(
                  enable: state.enableTaskSummary,
                );
            });
          }

          return MaterialApp(
            home: Scaffold(
              body: AudioRecordingModalContent(
                categoryId: provideCategory ? 'test-category' : null,
                linkedId: linkedTaskId,
              ),
            ),
          );
        },
      ),
    );
  }

  group('AudioRecordingModal - Speech Recognition Checkbox', () {
    testWidgets('shows checkbox when transcription prompts exist',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsOneWidget,
      );
    });

    testWidgets('hides checkbox when transcription prompts are absent',
        (tester) async {
      final category =
          FakeCategoryDefinition(includeTranscriptionPrompts: false);

      await tester.pumpWidget(createTestWidget(category: category));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Speech Recognition'),
        findsNothing,
      );
    });
  });

  group('AudioRecordingModal - Checklist Updates Checkbox', () {
    testWidgets(
        'should show checklist updates checkbox when linked to task and speech recognition is enabled',
        (tester) async {
      // Enable speech recognition to make checklist updates visible
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();

      // Find the checklist updates checkbox by looking for the LottiAnimatedCheckbox
      // with the 'Checklist Updates' label
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      expect(checkboxFinder, findsOneWidget);
    });

    testWidgets(
        'should NOT show checklist updates checkbox when not linked to task',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should not find the checklist updates checkbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      expect(checkboxFinder, findsNothing);
    });

    testWidgets(
        'should NOT show checklist updates checkbox when speech recognition is disabled',
        (tester) async {
      // Disable speech recognition to hide checklist updates
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: false,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();

      // Should not find the checklist updates checkbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      expect(checkboxFinder, findsNothing);
    });

    testWidgets('should be enabled when category has automatic prompts',
        (tester) async {
      final category = FakeCategoryDefinition();
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
        category: category,
      ));
      await tester.pumpAndSettle();

      // Find the LottiAnimatedCheckbox for checklist updates
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      expect(checkboxFinder, findsOneWidget);

      // The checkbox should be enabled
      final checkboxWidget =
          tester.widget<LottiAnimatedCheckbox>(checkboxFinder);
      expect(checkboxWidget.enabled, isTrue);
    });

    testWidgets('should be checked by default when preference is null',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();

      // Find the LottiAnimatedCheckbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      final checkboxWidget =
          tester.widget<LottiAnimatedCheckbox>(checkboxFinder);

      // Should be checked (true) when category has automatic prompts
      expect(checkboxWidget.value, isTrue);
    });

    testWidgets('should reflect user preference when set to false',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
        enableChecklistUpdates: false,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();

      // Find the LottiAnimatedCheckbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      final checkboxWidget =
          tester.widget<LottiAnimatedCheckbox>(checkboxFinder);

      // Should be unchecked
      expect(checkboxWidget.value, isFalse);
    });

    testWidgets(
        'should not render when category lacks transcription prompts despite having checklist prompts',
        (tester) async {
      final category = FakeCategoryDefinition(
        includeTranscriptionPrompts: false,
      );

      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
        category: category,
      ));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Checklist Updates'),
        findsNothing,
      );
    });

    testWidgets('should call setEnableChecklistUpdates when toggled',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
        enableChecklistUpdates: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();

      // Find and tap the checkbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Verify the state was updated (the checkbox toggles from true to false)
      final updatedState = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(audioRecorderControllerProvider);
      expect(updatedState.enableChecklistUpdates, isFalse);
    });

    testWidgets('should not render when category has no checklist prompts',
        (tester) async {
      // Create a category without checklist prompts
      final category = FakeCategoryDefinition(includeChecklistPrompts: false);
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
        category: category,
      ));
      await tester.pumpAndSettle();

      // Checkbox should not be rendered without prompts
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      expect(checkboxFinder, findsNothing);
    });

    testWidgets('should show correct label text', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();

      // Find the label
      expect(find.text('Checklist Updates'), findsOneWidget);
    });

    testWidgets('should maintain state during recording lifecycle',
        (tester) async {
      // Start with recording state
      var state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
        enableChecklistUpdates: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();

      // Verify initial state
      var checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      var checkboxWidget = tester.widget<LottiAnimatedCheckbox>(checkboxFinder);
      expect(checkboxWidget.value, isTrue);

      // Simulate state change to paused - rebuild widget with new state
      state = state.copyWith(status: AudioRecorderStatus.paused);
      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();

      // Checkbox should still be checked
      checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      checkboxWidget = tester.widget<LottiAnimatedCheckbox>(checkboxFinder);
      expect(checkboxWidget.value, isTrue);
    });
  });

  group('AudioRecordingModal - Task Summary Checkbox', () {
    testWidgets('shows checkbox when prompts exist and task is linked',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsOneWidget,
      );
    });

    testWidgets('hides checkbox when category has no task summary prompts',
        (tester) async {
      final category = FakeCategoryDefinition(
        includeTaskSummaryPrompts: false,
      );

      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
        category: category,
      ));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });

    testWidgets('hides checkbox when speech recognition is disabled',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: false,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
      ));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });

    testWidgets('hides checkbox when not linked to task', (tester) async {
      // Category has summary prompts but no linked task id provided
      final category = FakeCategoryDefinition(
        includeTaskSummaryPrompts: true,
      );

      await tester.pumpWidget(createTestWidget(
        category: category,
        linkedTaskId: null,
      ));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });

    testWidgets('hides checkbox when summary prompts exist but no transcription',
        (tester) async {
      final category = FakeCategoryDefinition(
        includeTranscriptionPrompts: false,
        includeTaskSummaryPrompts: true,
      );
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-123',
        enableSpeechRecognition: true,
      );

      await tester.pumpWidget(createTestWidget(
        state: state,
        linkedTaskId: 'task-123',
        category: category,
      ));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(LottiAnimatedCheckbox, 'Task Summary'),
        findsNothing,
      );
    });
  });

  group('AudioRecordingModal - Visibility Integration', () {
    testWidgets('hides entire section when no categoryId provided',
        (tester) async {
      await tester.pumpWidget(createTestWidget(provideCategory: false));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('speech_recognition_checkbox')), findsNothing);
      expect(find.byKey(const Key('checklist_updates_checkbox')), findsNothing);
      expect(find.byKey(const Key('task_summary_checkbox')), findsNothing);
      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });

    testWidgets('hides when category stream returns null', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          provideCategory: false,
          linkedTaskId: 'task-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });

    testWidgets('shows keys and hides dependents when Speech toggled off',
        (tester) async {
      final category = FakeCategoryDefinition();
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: true,
        language: 'en',
        linkedId: 'task-1',
        enableSpeechRecognition: true,
        enableChecklistUpdates: true,
        enableTaskSummary: true,
      );

      await tester.pumpWidget(
        createTestWidget(
          state: state,
          category: category,
          linkedTaskId: 'task-1',
        ),
      );
      await tester.pumpAndSettle();

      // Initially all three should be present
      expect(
          find.byKey(const Key('speech_recognition_checkbox')), findsOneWidget);
      expect(
          find.byKey(const Key('checklist_updates_checkbox')), findsOneWidget);
      expect(find.byKey(const Key('task_summary_checkbox')), findsOneWidget);

      // Toggle speech off
      await tester.tap(find.byKey(const Key('speech_recognition_checkbox')));
      await tester.pumpAndSettle();

      // Speech remains (can re-enable), dependents are hidden
      expect(
          find.byKey(const Key('speech_recognition_checkbox')), findsOneWidget);
      expect(find.byKey(const Key('checklist_updates_checkbox')), findsNothing);
      expect(find.byKey(const Key('task_summary_checkbox')), findsNothing);
    });

    testWidgets('hides section when automaticPrompts is empty', (tester) async {
      final category = FakeCategoryDefinition(
        includeTranscriptionPrompts: false,
        includeChecklistPrompts: false,
        includeTaskSummaryPrompts: false,
      );

      await tester.pumpWidget(
        createTestWidget(
          category: category,
          linkedTaskId: 'task-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LottiAnimatedCheckbox), findsNothing);
    });
  });
}
