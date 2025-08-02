import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/consts.dart';
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
  FakeCategoryDefinition({this.includeChecklistPrompts = true});

  final bool includeChecklistPrompts;

  @override
  String get id => 'test-category';

  @override
  String get name => 'Test Category';

  bool get deleted => false;

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
  Map<AiResponseType, List<String>>? get automaticPrompts => {
        AiResponseType.audioTranscription: ['transcription-prompt'],
        AiResponseType.taskSummary: ['summary-prompt'],
        if (includeChecklistPrompts)
          AiResponseType.checklistUpdates: ['checklist-prompt'],
      };
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
  }) {
    final categoryToUse = category ?? FakeCategoryDefinition();

    // Mock the repository to return our test category
    when(() => mockCategoryRepository.watchCategory('test-category'))
        .thenAnswer((_) => Stream.value(categoryToUse));

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
              final container = ProviderScope.containerOf(context);
              final controller = container.read(
                audioRecorderControllerProvider.notifier,
              );
              // Set the specific state properties we care about
              if (state.enableSpeechRecognition != null) {
                controller.setEnableSpeechRecognition(
                  enable: state.enableSpeechRecognition,
                );
              }
              if (state.enableChecklistUpdates != null) {
                controller.setEnableChecklistUpdates(
                  enable: state.enableChecklistUpdates,
                );
              }
              if (state.enableTaskSummary != null) {
                controller.setEnableTaskSummary(
                  enable: state.enableTaskSummary,
                );
              }
            });
          }

          return MaterialApp(
            home: Scaffold(
              body: AudioRecordingModalContent(
                categoryId: 'test-category',
                linkedId: linkedTaskId,
              ),
            ),
          );
        },
      ),
    );
  }

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

    testWidgets('should be disabled when category has no checklist prompts',
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

      // Find the LottiAnimatedCheckbox
      final checkboxFinder = find.widgetWithText(
        LottiAnimatedCheckbox,
        'Checklist Updates',
      );
      final checkboxWidget =
          tester.widget<LottiAnimatedCheckbox>(checkboxFinder);

      // Should be disabled
      expect(checkboxWidget.enabled, isFalse);
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
}
