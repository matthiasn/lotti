# Audio Recording UI Components

This directory contains the UI components for audio recording functionality in Lotti. The recording system provides a visual VU meter, recording controls, and status indicators.

## Components Overview

### 1. AnalogVuMeter Widget

The `AnalogVuMeter` is a custom-drawn widget that displays audio levels in real-time using a traditional analog VU (Volume Unit) meter design.

**Features:**
- Needle animation showing current audio level
- Peak hold indicator that tracks maximum levels
- Clip LED indicator that lights up when audio is too loud (>90% of scale)
- Non-linear scale matching traditional VU meter response (-20 to +3 dB)
- Dark/light theme support

**Usage:**
```dart
AnalogVuMeter(
  decibels: audioLevel,  // 0-160 range
  size: 400,             // Width (height is automatically size * 0.5)
  colorScheme: theme.colorScheme,
)
```

### 2. AudioRecordingModal

The main recording interface presented as a modal bottom sheet.

**Features:**
- Displays the VU meter for visual audio feedback
- Shows recording duration in MM:SS format
- Language selector for transcription
- Record/Stop button with auto-transcribe option
- Integrates with `AudioRecorderCubit` for state management

**Usage:**
```dart
AudioRecordingModal.show(
  context,
  linkedId: entryId,      // Optional: Link recording to existing entry
  categoryId: categoryId, // Optional: Assign category
)
```

### 3. AudioRecordingIndicator

A small floating indicator that appears when recording is active and the modal is not visible.

**Features:**
- Shows microphone icon and recording duration
- Clicking reopens the recording modal
- Positioned at bottom-right of screen
- Auto-hides when modal is visible or recording stops

## Architecture

### File Structure
```
recording/
├── analog_vu_meter.dart       # Main VU meter widget
├── vu_meter_painter.dart      # Custom painter for VU meter visuals
├── vu_meter_constants.dart    # Animation durations and constants
├── audio_recording_modal.dart # Recording modal interface
├── audio_recording_indicator.dart # Small recording indicator
└── README.md                  # This file
```

### VU Meter Details

The VU meter consists of several visual elements:

1. **Scale Arc**: Curved scale from -20 to +3 dB
   - Normal range (-20 to 0 dB) in theme color
   - Red zone (0 to +3 dB) for hot signals

2. **Needle**: Animated pointer showing current level
   - Smooth easing animation (100ms response)
   - Shadow effect for depth

3. **Peak Indicator**: Orange line showing recent maximum
   - Holds for 800ms then decays over 1500ms
   - Falls back to current level, not zero

4. **Clip LED**: Red indicator for signal clipping
   - Triggers when level > 90% of scale
   - Glowing effect when active
   - "PEAK" label below

5. **VU Text**: Centered "VU" label in meter face

### Decibel Normalization

The input range (0-160) is mapped to VU meter scale positions using non-linear scaling to match traditional VU meter ballistics:

- Input 130 = 0 VU (reference level)
- Scale uses different slopes for different ranges
- 0 dB appears at 60% of scale width
- Red zone starts at 0 dB position

## Testing

All components have comprehensive test coverage:

- **VU Meter Tests**: Animation, sizing, theme handling, painter logic
- **Modal Tests**: User interactions, state management, language selection
- **Indicator Tests**: Visibility states, duration display

Run tests with:
```bash
flutter test test/features/speech/ui/widgets/
flutter test test/widgets/audio/
```

## State Management

The recording system uses:
- `AudioRecorderCubit` for recording state
- Flutter animations for smooth visual updates
- BLoC pattern for reactive UI updates

## Usage Flow

1. User taps "Audio Recording" in create entry modal
2. `AudioRecordingModal` opens showing VU meter
3. User taps record button to start
4. VU meter shows real-time audio levels
5. `AudioRecordingIndicator` appears if user navigates away
6. User taps stop to end recording
7. If auto-transcribe enabled, transcription begins
8. Audio entry is created and saved