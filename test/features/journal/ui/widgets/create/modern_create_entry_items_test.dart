import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_items.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/modern_modal_entry_type_item.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' show Amplitude;

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class TestAudioRecorderController extends AudioRecorderController {
  TestAudioRecorderController();

  String? capturedCategoryId;

  @override
  AudioRecorderState build() => AudioRecorderState(
        status: AudioRecorderStatus.initializing,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

  @override
  void setCategoryId(String? categoryId) {
    capturedCategoryId = categoryId;
  }

  @override
  void setModalVisible({required bool modalVisible}) {
    state = state.copyWith(modalVisible: modalVisible);
  }
}

void main() {
  group('ModernCreateTaskItem Tests', () {
    testWidgets('renders task item correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateTaskItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the task item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    });

    testWidgets('shows task item in modal', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => const CreateTaskItem(
                        'linked-id',
                        categoryId: 'category-id',
                      ),
                    );
                  },
                  child: const Text('Show Modal'),
                ),
              ],
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify the task item is shown
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    });
  });

  group('ModernCreateEventItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateEventItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the event item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });
  });

  group('ModernCreateAudioItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateAudioItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the audio item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('passes categoryId to AudioRecordingModal.show',
        (tester) async {
      // Set up required dependencies
      late MockJournalDb mockJournalDb;
      late MockNavService mockNavService;
      late MockAudioRecorderRepository mockRecorderRepository;
      late MockLoggingService mockLoggingService;
      late TestAudioRecorderController testController;

      mockJournalDb = MockJournalDb();
      mockNavService = MockNavService();
      mockRecorderRepository = MockAudioRecorderRepository();
      mockLoggingService = MockLoggingService();
      testController = TestAudioRecorderController();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<LoggingService>(mockLoggingService);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => false);
      when(() => mockNavService.beamBack()).thenReturn(null);
      when(() => mockRecorderRepository.amplitudeStream)
          .thenAnswer((_) => const Stream<Amplitude>.empty());
      when(() => mockRecorderRepository.dispose()).thenAnswer((_) async {});

      // Create the widget with proper provider scope
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            audioRecorderControllerProvider.overrideWith(() => testController),
          ],
          child: makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) => const CreateAudioItem(
                'test-linked-id',
                categoryId: 'test-category-id',
              ),
            ),
          ),
        ),
      );

      // Tap the audio item to trigger the modal
      await tester.tap(find.byType(CreateAudioItem));
      await tester.pump();

      // Verify that setCategoryId was called with the correct value
      expect(testController.capturedCategoryId, 'test-category-id');

      // Clean up
      await getIt.reset();
    });
  });

  // ModernCreateTimerItem requires GetIt services and EntryController
  // which makes it more complex to test. Consider integration tests
  // or a more complete test setup for this widget.

  group('ModernCreateTextItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateTextItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the text item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    });
  });

  group('ModernImportImageItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ImportImageItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the import image item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Import Image'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
    });
  });

  group('ModernCreateScreenshotItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateScreenshotItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the screenshot item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Screenshot'), findsOneWidget);
      expect(find.byIcon(Icons.screenshot_monitor_rounded), findsOneWidget);
    });
  });
}
