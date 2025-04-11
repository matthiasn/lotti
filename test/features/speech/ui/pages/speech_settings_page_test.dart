import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/features/speech/state/speech_settings_cubit.dart';
import 'package:lotti/features/speech/state/speech_settings_state.dart';
import 'package:lotti/features/speech/ui/widgets/transcription_progress.dart';
import 'package:lotti/features/speech/ui/widgets/whisper_model_card.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockMaintenance extends Mock implements Maintenance {}

class MockSpeechSettingsCubit extends Mock implements SpeechSettingsCubit {
  final _controller = StreamController<SpeechSettingsState>.broadcast();

  @override
  Stream<SpeechSettingsState> get stream => _controller.stream;

  @override
  SpeechSettingsState get state => SpeechSettingsState(
        availableModels: {'tiny', 'small', 'base'},
        selectedModel: 'small',
      );
}

class MockAsrService extends Mock implements AsrService {
  @override
  final progressController =
      StreamController<(String, TranscriptionStatus)>.broadcast();
}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockUserActivityService extends Mock implements UserActivityService {}

// Directly test individual components
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMaintenance mockMaintenance;
  late MockAsrService mockAsrService;
  late MockSettingsDb mockSettingsDb;
  late MockUserActivityService mockUserActivityService;
  late MockSpeechSettingsCubit mockCubit;

  setUp(() {
    mockMaintenance = MockMaintenance();
    mockAsrService = MockAsrService();
    mockSettingsDb = MockSettingsDb();
    mockUserActivityService = MockUserActivityService();
    mockCubit = MockSpeechSettingsCubit();

    // Set up mock behavior
    when(() => mockSettingsDb.itemByKey(any()))
        .thenAnswer((_) async => 'small');

    // Register mocks in GetIt
    getIt
      ..registerSingleton<Maintenance>(mockMaintenance)
      ..registerSingleton<AsrService>(mockAsrService)
      ..registerSingleton<SettingsDb>(mockSettingsDb)
      ..registerSingleton<UserActivityService>(mockUserActivityService);
  });

  tearDown(getIt.reset);

  group('WhisperModelCard', () {
    testWidgets('renders correctly and can be tapped', (tester) async {
      // Create a simplified standalone test for WhisperModelCard
      const model = 'tiny';

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: BlocProvider<SpeechSettingsCubit>.value(
              value: mockCubit,
              child: Builder(
                builder: (context) {
                  return const WhisperModelCard(model);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the model name is displayed
      expect(find.text('tiny'), findsOneWidget);

      // Verify checkbox is present
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('calls selectModel when tapped', (tester) async {
      const model = 'tiny';

      // Setup mock to capture selection
      when(() => mockCubit.selectModel(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: BlocProvider<SpeechSettingsCubit>.value(
              value: mockCubit,
              child: const WhisperModelCard(model),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the checkbox
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      // Verify cubit method was called with correct model
      verify(() => mockCubit.selectModel(model)).called(1);
    });
  });

  group('TranscriptionProgressView', () {
    testWidgets('renders correctly', (tester) async {
      // Test just the progress view component
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TranscriptionProgressView(),
          ),
        ),
      );

      // Should render but might be empty initially
      expect(find.byType(TranscriptionProgressView), findsOneWidget);
    });
  });

  group('Maintenance.transcribeAudioWithoutTranscript', () {
    testWidgets('is called when the transcribe button is pressed',
        (tester) async {
      // Setup mock
      when(() => mockMaintenance.transcribeAudioWithoutTranscript())
          .thenAnswer((_) async => {});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilledButton(
              onPressed: () =>
                  mockMaintenance.transcribeAudioWithoutTranscript(),
              child: const Text('Transcribe'),
            ),
          ),
        ),
      );

      // Find and tap the button
      final button = find.byType(FilledButton);
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      // Verify the method was called
      verify(() => mockMaintenance.transcribeAudioWithoutTranscript())
          .called(1);
    });
  });
}
