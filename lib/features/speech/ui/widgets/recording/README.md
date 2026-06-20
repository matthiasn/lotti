# Audio Recording UI Components

This directory contains the UI components for audio recording functionality in
Lotti. The recording system provides a visual VU meter, recording controls, and
status indicators driven by the same live dBFS stream.

## Components Overview

### 1. AnalogVuMeter Widget

The `AnalogVuMeter` is a custom-drawn widget that displays audio levels in real-time using a traditional analog VU (Volume Unit) meter design.

**Features:**
- Needle animation showing current audio level
- Peak hold indicator that tracks maximum levels
- Clip LED indicator that lights up when audio is too loud (instantaneous dBFS > -3 dBFS)
- Non-linear scale matching traditional VU meter response (-20 to +3 dB)
- Dark/light theme support

**Usage:**
```dart
AnalogVuMeter(
  vu: vuLevel,           // -20 to +3 VU range (RMS-based)
  dBFS: dBFSLevel,       // Instantaneous dBFS for clipping detection
  size: 400,             // Width (height is automatically size * 0.4)
  colorScheme: theme.colorScheme,
)
```

### 2. AudioRecordingModal

The main recording interface presented as a modal bottom sheet.

**Features:**
- Displays the VU meter for visual audio feedback
- Shows recording duration in H:MM:SS format
- Standard/Realtime transcription mode toggle (shown when realtime transcription
  is available and recording has not started)
- Record/Stop button with recording status indicator
- Integrates with Riverpod state management via `AudioRecorderController`
- Automatically pauses any playing audio when recording starts

**Usage:**
```dart
AudioRecordingModal.show(
  context,
  linkedId: entryId,      // Optional: Link recording to existing entry
  categoryId: categoryId, // Optional: Assign category
)
```

### 3. AudioRecordingOrb

The `AudioRecordingOrb` is the compact signal visualization used by persistent
recording surfaces.

**Features:**
- Maps live dBFS into a clamped 0-1 signal intensity with a speech-weighted
  response curve so normal microphone input remains visually obvious
- Keeps a slow pulse running so the microphone state remains visible even
  during silence
- Expands glow, outer wave, ring, and core radius with louder input
- Switches to the warning token when the signal reaches the clipping threshold

**Usage:**
```dart
AudioRecordingOrb(
  dBFS: state.dBFS,
  size: tokens.spacing.step6,
)
```

### 4. Persistent Recording Indicators

Persistent indicators appear when recording is active and the modal is not
visible.

**Features:**
- Desktop: `SidebarAudioRecordingSection` renders a red accent-tinted live card
  (via `SidebarLiveCard`, alongside the teal running-timer card and the quieter
  agent-queue card) with a microphone glyph + a gentle pulsing record dot, the
  linked task title (up to two lines, full value via hover tooltip), a prominent
  red elapsed time, and a stop button. It uses **no** `AudioRecordingOrb` and no
  dBFS-reactive frame — the red accent plus the pulsing dot carry "recording"
  without the reactive orb, and the pulse respects the platform reduce-motion
  setting.
- Mobile: `AudioRecordingIndicator` renders the compact bottom-nav pill with a
  live `AudioRecordingOrb` and duration; it reads `AudioRecorderState.dBFS`
  directly so the orb animation follows the same audio stream as the VU meter.
- Clicking the non-stop body reopens the recording modal.
- Auto-hides when modal is visible or recording stops

## Architecture

### File Structure
```
recording/
├── analog_vu_meter.dart       # Main VU meter widget
├── vu_meter_painter.dart      # Custom painter for VU meter visuals
├── vu_meter_constants.dart    # Animation durations and constants
├── audio_recording_orb.dart   # Compact dBFS-reactive orb visualization
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
   - Triggers when instantaneous dBFS > -3 dBFS
   - Glowing effect when active
   - "PEAK" label below

5. **VU Text**: Centered "VU" label in meter face

### VU Meter Signal Processing

#### RMS Calculation for VU Values

The VU meter uses RMS (Root Mean Square) calculation to display average signal levels, which provides a perceptually accurate representation of loudness:

1. **Why RMS?**
   - Audio signals oscillate around zero with positive and negative values
   - Simple averaging would cancel out to near zero
   - RMS measures the average power/energy of the signal
   - Matches human perception of loudness better than peak values

2. **Calculation Process:**
   ```
   1. Convert dBFS to linear amplitude: linear = 10^(dBFS/20)
   2. Square each sample: squared = linear²
   3. Calculate mean of squares over 300ms window
   4. Take square root: RMS = √(mean of squares)
   5. Convert back to dB: RMS_dB = 20 * log10(RMS)
   6. Apply VU reference: VU = RMS_dB - (-18)
   ```

3. **Why Square Values?**
   - Squaring ensures all values are positive (no cancellation)
   - Relates to power (Power ∝ Amplitude²)
   - Emphasizes louder parts of the signal
   - Standard approach in audio metering

4. **VU vs dBFS:**
   - **VU (Volume Units)**: RMS-based, averaged over 300ms, smooth response
   - **dBFS (Decibels Full Scale)**: Instantaneous peak values
   - 0 VU is calibrated to -18 dBFS RMS (standard broadcast level)
   - Clipping detection uses instantaneous dBFS (> -3 dBFS)

5. **Rolling Average Window:**
   - Fixed: 300ms (15 samples at 20ms intervals), set by the
     `defaultVuWindowMs` constant in `state/vu_meter.dart`. The RMS math itself
     lives in the standalone `VuMeter` class there; `recorder_controller.dart`
     only constructs `VuMeter(windowSamples: defaultVuWindowMs ~/ intervalMs)`
   - Provides smooth, stable meter movement
   - Reduces nervousness from transient peaks

### VU Meter Scale Mapping

The VU values (-20 to +3 dB) are mapped to meter positions using non-linear scaling:

- **-20 to -10 VU**: First 15% of scale (compressed)
- **-10 to -7 VU**: Next 10% of scale
- **-7 to -5 VU**: Next 10% of scale
- **-5 to -3 VU**: Next 10% of scale
- **-3 to 0 VU**: Next 15% of scale
- **0 to +3 VU**: Last 40% of scale (expanded, red zone)

This creates the characteristic VU meter appearance where:
- 0 VU sits at 60% position (not center)
- Negative values are compressed
- Positive values are expanded for better visibility
- Matches traditional analog VU meter calibration

## Testing

All components have comprehensive test coverage:

- **VU Meter Tests**: Animation, sizing, theme handling, painter logic
- **Modal Tests**: User interactions, state management, recording mode toggle
- **Indicator Tests**: Visibility states, duration display

Run tests with:
```bash
flutter test test/features/speech/ui/widgets/recording/
```

## State Management

The recording system uses:
- `AudioRecorderController` (Riverpod) for recording state management
- `AudioRecorderRepository` for encapsulating recording operations
- Flutter animations for smooth visual updates
- Reactive UI updates through Riverpod providers

## Usage Flow

1. User taps "Audio Recording" in create entry modal
2. `AudioRecordingModal` opens showing VU meter
3. User taps record button to start
4. VU meter shows real-time audio levels
5. Persistent indicators appear if user navigates away: the desktop sidebar
   card sits above the running timer card; the mobile pill sits in the bottom
   navigation overlay
6. User taps stop to end recording
7. If auto-transcribe enabled, transcription begins
8. Audio entry is created and saved
