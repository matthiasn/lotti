# Speech Feature

This feature provides comprehensive audio recording and speech-to-text capabilities for the Lotti journaling app. It allows users to create audio journal entries with automatic transcription support.

## Architecture Overview

The speech feature follows clean architecture principles with clear separation of concerns:

```
speech/
├── repository/           # Data layer - External service integration
├── state/               # State management layer
├── ui/                  # Presentation layer
└── README.md           # This file
```

## Core Components

### State Management

#### AudioRecorderController (`state/recorder_controller.dart`)
The main Riverpod controller managing the recording lifecycle and state.

**Responsibilities:**
- Controls recording operations (start, stop, pause, resume)
- Manages recording state including progress, audio levels, and status
- Handles UI state (modal visibility, indicator visibility)
- Integrates with audio player to pause playback when recording starts
- Creates audio entries through SpeechRepository

**Key Methods:**
```dart
// Start or toggle recording
Future<void> record({String? linkedId})

// Stop recording and create audio entry
Future<String?> stop()

// Pause/resume recording
Future<void> pause()
Future<void> resume()

// UI state management
void setModalVisible({required bool modalVisible})
void setIndicatorVisible({required bool showIndicator})
void setLanguage(String language)
void setCategoryId(String? categoryId)
```

#### AudioRecorderState (`state/recorder_state.dart`)
Immutable state model using Freezed for the recording feature.

**Properties:**
- `status`: Recording status (initializing, initialized, recording, paused, stopped)
- `decibels`: Current audio level for VU meter display
- `progress`: Recording duration
- `showIndicator`: Whether to show the floating indicator
- `modalVisible`: Whether the recording modal is open
- `language`: Selected language for transcription
- `linkedId`: Optional ID to link recording to existing entry

#### AudioPlayerCubit (`state/player_cubit.dart`)
Bloc wrapper around `media_kit` playback. It keeps audio progress, buffering, speed, and play state
in sync with the UI.

**Responsibilities:**
- Loads the selected `JournalAudio` asset (`setAudioNote`) and hydrates total duration
- Drives playback (`play`, `pause`, `seek`, `setSpeed`) while clamping progress updates
- Exposes buffer progress for the custom progress bar
- Emits robust error logging through `LoggingService`

### Repositories

#### AudioRecorderRepository (`repository/audio_recorder_repository.dart`)
Encapsulates all interactions with the `record` package.

**Features:**
- Permission management
- Recording lifecycle management
- Audio file creation and directory management
- Real-time amplitude monitoring
- Error handling and logging

**Key Methods:**
```dart
Future<bool> hasPermission()
Future<bool> isRecording()
Future<bool> isPaused()
Future<AudioNote?> startRecording()
Future<void> stopRecording()
Future<void> pauseRecording()
Future<void> resumeRecording()
Stream<Amplitude> get amplitudeStream
```

#### SpeechRepository (`repository/speech_repository.dart`)
Handles audio entry persistence and transcription management.

**Features:**
- Creates journal entries for audio recordings
- Manages transcription operations
- Updates language preferences
- Integrates with ASR (Automatic Speech Recognition) service

### UI Components

For detailed documentation of UI components, see [recording/README.md](ui/widgets/recording/README.md).

**Key Components:**
- `AudioRecordingModal`: Main recording interface with VU meter
- `AudioRecordingIndicator`: Floating indicator for active recordings
- `AnalogVuMeter`: Visual audio level display
- `AudioPlayerWidget`: Minimal playback card with play/pause ring, progress bar, and speed toggle

#### AudioPlayerWidget (`ui/widgets/audio_player.dart`)
The compact playback card focuses on a single row of controls:

- Circular play/pause button with animated progress ring
- Custom `AudioProgressBar` showing buffered vs. played segments and supporting scrubbing
- Tabular progress/total timestamps plus an inline speed toggle pill

The layout keeps the same structure below 360 px with tightened spacing. Supporting painter logic
remains in `ui/widgets/progress/audio_progress_bar.dart`.

The progress bar resolves its palette through `resolveAudioProgressColors`, which aligns the scrub
fill and thumb with contrast-adjusted variants of `ColorScheme.primary`, and removes the scrubbing
glow for better contrast in high-contrast palettes. In light mode the player card renders on a flat
surface color instead of the dark-mode gradient to keep the card feeling clean.

## Integration Points

### Dependencies
- **GetIt**: Service locator for dependency injection
- **Riverpod**: State management
- **record**: Audio recording functionality
- **media_kit**: Audio playback (via AudioPlayerCubit)
- **AudioPlayerRepository**: Audio playback management

### Services Used
- `LoggingService`: Error and event logging
- `AudioPlayerCubit`: Pauses playback when recording starts
- `AsrService`: Automatic speech recognition
- `PersistenceLogic`: Journal entry persistence

## Recording Flow

1. **Initiation**: User taps audio recording option
2. **Modal Display**: `AudioRecordingModal.show()` opens the recording interface
3. **Permission Check**: Repository verifies microphone permissions
4. **Audio Pause**: Any playing audio is automatically paused
5. **Recording Start**: Audio capture begins, VU meter shows levels
6. **Progress Tracking**: Duration updates in real-time
7. **Modal Dismissal**: If user navigates away, floating indicator appears
8. **Recording Stop**: User taps stop button
9. **Entry Creation**: Audio file is saved and journal entry created
10. **Transcription**: If enabled, ASR service processes the audio
11. **Linked Entity Support**: If recording is linked to a task, both entities track the transcription progress
12. **Provider Selection**: Transcription can use Whisper or Gemma 3n (local) providers based on configuration

## Testing

The feature has comprehensive test coverage:

### Unit Tests
- `recorder_controller_test.dart`: State management and recording logic
- `audio_recorder_repository_test.dart`: Repository functionality
- `speech_repository_test.dart`: Data persistence and transcription
- `audio_waveform_service_test.dart`: Waveform extraction, caching lifecycle, cache pruning, and filesystem resilience

### Widget Tests
- `audio_recording_modal_test.dart`: Modal UI and interactions
- `audio_recording_indicator_test.dart`: Indicator behavior
- `analog_vu_meter_test.dart`: VU meter rendering and animations
- `audio_player_widget_test.dart`: Compact/wide layout, semantics, speed cycling, and scrub-to-seek
- `audio_waveform_scrubber_test.dart`: Scrubbing gestures, throttled seeking, semantics, and painter edge cases

### Test Execution
```bash
# Run all speech feature tests
flutter test test/features/speech/

# Run specific test categories
flutter test test/features/speech/state/
flutter test test/features/speech/repository/
flutter test test/features/speech/ui/
```

## Error Handling

The feature implements robust error handling:
- Permission denied scenarios
- Recording failures
- File system errors
- Transcription failures

All errors are logged through `LoggingService` with appropriate domain tags for debugging.

## Performance Considerations

- VU meter updates at 100ms intervals to balance responsiveness and performance
- Amplitude stream is properly disposed to prevent memory leaks
- File operations use async methods to avoid blocking UI
- Modal visibility state prevents unnecessary widget rebuilds

## Linked Entity Transcription

When an audio recording is linked to another entity (e.g., a task), the speech feature integrates with the AI system to provide context-aware transcription:

### Features
- **Task Context**: When linked to a task, the transcription uses task context for better accuracy with names and concepts
- **Dual Progress Tracking**: Both the audio entry and the linked task show transcription progress indicators
- **Automatic Inference**: The AI system automatically triggers transcription when an audio entry is created with a linked entity
- **Visual Indicators**: Both entities display inference animations during transcription

### Implementation
The speech feature coordinates with the AI system's linked entity tracking:
- Creates audio entry with `linkedId` parameter
- AI system creates active inference entries for both entities
- Both entities receive status updates (running, complete, error)
- UI components on both entities show appropriate indicators

## Transcription Providers

The speech feature supports multiple transcription providers:

### Whisper
- Locally running Whisper server for privacy
- High accuracy with various audio formats
- Context-aware transcription when linked to tasks

### Gemma 3n (Local)
- New local Gemma model with audio transcription capabilities
- No API key required - runs entirely locally
- Provides high-quality transcription with streaming support
- Automatically selected when configured as a provider

## Future Enhancements

Potential improvements to consider:
- Waveform visualization during playback
- Multiple language support for simultaneous transcription
- Voice activity detection for auto-stop
- Audio enhancement filters
- Export capabilities for audio files
