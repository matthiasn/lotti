import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_indicator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' show Amplitude;

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

// Mock classes
class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

// Test controller that provides a fixed state
class TestAudioRecorderController extends AudioRecorderController {
  TestAudioRecorderController(this._testState);

  final AudioRecorderState _testState;

  @override
  AudioRecorderState build() => _testState;
}

// Mock EntryController for testing
class MockEntryController extends EntryController {
  MockEntryController({required this.mockEntry});

  final JournalEntity mockEntry;

  @override
  Future<EntryState?> build({required String id}) async {
    // Return the mock entry state
    return EntryState.saved(
      entryId: id,
      entry: mockEntry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockNavService mockNavService;
  late MockAudioRecorderRepository mockRecorderRepository;
  late MockLoggingService mockLoggingService;
  late MockEditorStateService mockEditorStateService;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockNavService = MockNavService();
    mockRecorderRepository = MockAudioRecorderRepository();
    mockLoggingService = MockLoggingService();
    mockEditorStateService = MockEditorStateService();
    mockPersistenceLogic = MockPersistenceLogic();
    mockUpdateNotifications = MockUpdateNotifications();

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    when(() => mockJournalDb.getConfigFlag(any()))
        .thenAnswer((_) async => false);
    when(() => mockNavService.beamBack()).thenReturn(null);
    when(() => mockRecorderRepository.amplitudeStream)
        .thenAnswer((_) => const Stream<Amplitude>.empty());
    when(() => mockRecorderRepository.dispose()).thenAnswer((_) async {});
  });

  tearDown(getIt.reset);

  Widget makeTestableWidget(AudioRecorderState state,
      {JournalEntity? linkedEntry}) {
    return makeTestableWidgetWithScaffold(
      const AudioRecordingIndicator(),
      overrides: [
        audioRecorderRepositoryProvider
            .overrideWithValue(mockRecorderRepository),
        audioRecorderControllerProvider.overrideWith(() {
          return TestAudioRecorderController(state);
        }),
        if (state.linkedId != null && linkedEntry != null)
          entryControllerProvider(id: state.linkedId!).overrideWith(() {
            return MockEntryController(mockEntry: linkedEntry);
          }),
      ],
    );
  }

  group('AudioRecordingIndicator Tests', () {
    testWidgets('shows nothing when not recording', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.initializing,
        dBFS: -160,
        vu: -20,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      await tester.pumpWidget(makeTestableWidget(state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('audio_recording_indicator')), findsNothing);
    });

    testWidgets('shows nothing when modal is visible', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        dBFS: -160,
        vu: -20,
        progress: const Duration(seconds: 10),
        showIndicator: true,
        modalVisible: true,
        language: 'en',
      );

      await tester.pumpWidget(makeTestableWidget(state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('audio_recording_indicator')), findsNothing);
    });

    testWidgets('shows indicator when recording and modal not visible',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        dBFS: -160,
        vu: -20,
        progress: const Duration(seconds: 10),
        showIndicator: true,
        modalVisible: false,
        language: 'en',
      );

      await tester.pumpWidget(makeTestableWidget(state));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('audio_recording_indicator')), findsOneWidget);
      expect(find.byIcon(Icons.mic_outlined), findsOneWidget);

      // FittedBox might be scaling the text, so let's find it within the widget tree
      final textFinder = find.descendant(
        of: find.byKey(const Key('audio_recording_indicator')),
        matching: find.byType(Text),
      );
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.data, '00:00:10');
    });

    testWidgets('indicator has correct styling', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        dBFS: -160,
        vu: -20,
        progress: const Duration(minutes: 1, seconds: 23),
        showIndicator: true,
        modalVisible: false,
        language: 'en',
      );

      await tester.pumpWidget(makeTestableWidget(state));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('audio_recording_indicator')),
          matching: find.byType(Container).last,
        ),
      );

      expect(container.color, isNotNull);

      // FittedBox might be scaling the text, so let's find it within the widget tree
      final textFinder = find.descendant(
        of: find.byKey(const Key('audio_recording_indicator')),
        matching: find.byType(Text),
      );
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.data, '00:01:23');
    });

    testWidgets('indicator has correct interaction behavior', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        dBFS: -160,
        vu: -20,
        progress: const Duration(seconds: 30),
        showIndicator: true,
        modalVisible: false,
        language: 'en',
      );

      await tester.pumpWidget(makeTestableWidget(state));
      await tester.pumpAndSettle();

      // Verify the indicator exists
      expect(
          find.byKey(const Key('audio_recording_indicator')), findsOneWidget);

      // The indicator uses a GestureDetector with the key, verify it exists
      final indicatorWidget =
          tester.widget(find.byKey(const Key('audio_recording_indicator')));
      expect(indicatorWidget, isA<GestureDetector>());

      // Find MouseRegion in the widget tree that has the click cursor
      final mouseRegionFinder = find.byWidgetPredicate(
        (widget) =>
            widget is MouseRegion && widget.cursor == SystemMouseCursors.click,
      );
      expect(mouseRegionFinder, findsOneWidget);

      // Verify MouseRegion has correct cursor
      final mouseRegion = tester.widget<MouseRegion>(mouseRegionFinder);
      expect(mouseRegion.cursor, SystemMouseCursors.click);

      // Verify it has the expected content
      expect(find.byIcon(Icons.mic_outlined), findsOneWidget);
    });

    testWidgets('indicator shows correct duration format', (tester) async {
      final testCases = [
        (const Duration(seconds: 5), '00:00:05'),
        (const Duration(minutes: 1, seconds: 30), '00:01:30'),
        (const Duration(hours: 1, minutes: 15, seconds: 45), '01:15:45'),
      ];

      for (final (duration, expectedText) in testCases) {
        final state = AudioRecorderState(
          status: AudioRecorderStatus.recording,
          dBFS: -160,
          vu: -20,
          progress: duration,
          showIndicator: true,
          modalVisible: false,
          language: 'en',
        );

        await tester.pumpWidget(makeTestableWidget(state));
        await tester.pumpAndSettle();

        // FittedBox might be scaling the text, so let's find it within the widget tree
        final textFinder = find.descendant(
          of: find.byKey(const Key('audio_recording_indicator')),
          matching: find.byType(Text),
        );
        expect(textFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(textFinder);
        expect(textWidget.data, expectedText, reason: 'Duration: $duration');

        // Clear the widget tree before the next iteration
        await tester.pumpWidget(Container());
      }
    });

    testWidgets('indicator has correct dimensions', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        progress: const Duration(seconds: 10),
        dBFS: -160,
        vu: -20,
        showIndicator: true,
        modalVisible: false,
        language: 'en',
      );

      await tester.pumpWidget(makeTestableWidget(state));
      await tester.pumpAndSettle();

      final indicatorSize = tester.getSize(
        find.byKey(const Key('audio_recording_indicator')),
      );

      expect(
        indicatorSize.height,
        AudioRecordingIndicatorConstants.indicatorHeight,
      );
    });

    testWidgets('indicator width remains stable across durations',
        (tester) async {
      const durations = [
        Duration(seconds: 5),
        Duration(seconds: 18),
        Duration(minutes: 1, seconds: 1),
      ];

      Size? previousSize;

      for (final d in durations) {
        final state = AudioRecorderState(
          status: AudioRecorderStatus.recording,
          dBFS: -160,
          vu: -20,
          progress: d,
          showIndicator: true,
          modalVisible: false,
          language: 'en',
        );

        await tester.pumpWidget(makeTestableWidget(state));
        await tester.pumpAndSettle();

        final size = tester.getSize(
          find.byKey(const Key('audio_recording_indicator')),
        );

        // Height fixed by constants
        expect(size.height, AudioRecordingIndicatorConstants.indicatorHeight);

        if (previousSize != null) {
          expect(size, equals(previousSize));
        }

        previousSize = size;

        // Clear tree before next iteration
        await tester.pumpWidget(Container());
      }
    });

    testWidgets('indicator has onTap callback configured', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        dBFS: -160,
        vu: -20,
        progress: const Duration(seconds: 10),
        showIndicator: true,
        modalVisible: false,
        language: 'en',
        linkedId: 'test-id',
      );

      // Mock entry for linked ID
      final testDate = DateTime(2024);
      final mockEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'test-id',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          categoryId: 'test-category',
        ),
      );

      await tester
          .pumpWidget(makeTestableWidget(state, linkedEntry: mockEntry));
      await tester.pumpAndSettle();

      // Verify indicator exists
      expect(
          find.byKey(const Key('audio_recording_indicator')), findsOneWidget);

      // Verify it has a GestureDetector with an onTap handler
      final gestureDetector = tester.widget<GestureDetector>(
        find.byKey(const Key('audio_recording_indicator')),
      );
      expect(gestureDetector.onTap, isNotNull);
    });

    testWidgets('indicator has onTap callback configured without linked entry',
        (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        dBFS: -160,
        vu: -20,
        progress: const Duration(seconds: 10),
        showIndicator: true,
        modalVisible: false,
        language: 'en',
      );

      await tester.pumpWidget(makeTestableWidget(state));
      await tester.pumpAndSettle();

      // Verify indicator exists
      expect(
          find.byKey(const Key('audio_recording_indicator')), findsOneWidget);

      // Verify it has a GestureDetector with an onTap handler
      final gestureDetector = tester.widget<GestureDetector>(
        find.byKey(const Key('audio_recording_indicator')),
      );
      expect(gestureDetector.onTap, isNotNull);
    });

    testWidgets('handles exceptions gracefully', (tester) async {
      // Create a controller that throws an exception
      final badController = audioRecorderControllerProvider.overrideWith(() {
        throw Exception('Test exception');
      });

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const AudioRecordingIndicator(),
          overrides: [
            audioRecorderRepositoryProvider
                .overrideWithValue(mockRecorderRepository),
            badController,
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Should show empty widget when exception occurs
      expect(find.byKey(const Key('audio_recording_indicator')), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('indicator has correct border radius', (tester) async {
      final state = AudioRecorderState(
        status: AudioRecorderStatus.recording,
        dBFS: -160,
        vu: -20,
        progress: const Duration(seconds: 10),
        showIndicator: true,
        modalVisible: false,
        language: 'en',
      );

      await tester.pumpWidget(makeTestableWidget(state));
      await tester.pumpAndSettle();

      final clipRRect = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byKey(const Key('audio_recording_indicator')),
          matching: find.byType(ClipRRect),
        ),
      );

      expect(clipRRect.borderRadius, isA<BorderRadius>());
      final borderRadius = clipRRect.borderRadius as BorderRadius;
      expect(borderRadius.topLeft, const Radius.circular(8));
      expect(borderRadius.topRight, const Radius.circular(8));
      expect(borderRadius.bottomLeft, Radius.zero);
      expect(borderRadius.bottomRight, Radius.zero);
    });
  });
}
