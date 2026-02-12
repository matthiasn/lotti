# Integrate Voxtral Real-Time Transcription via WebSockets

## Context

The app currently supports batch transcription: record audio to M4A, stop, then send the file to a transcription API. This introduces a delay between speaking and seeing the text. The user wants **real-time transcription** — live subtitles appearing ~2 seconds after speaking — using Mistral's Voxtral real-time WebSocket API (`voxtral-mini-transcribe-realtime-2602`).

**Key finding: Diarization is NOT supported on the real-time endpoint.** It is only available on the batch endpoint (`voxtral-mini-transcribe-v2-2602`). The two modes must coexist.

## API Protocol Summary (Mistral Hosted)

- **WebSocket URL:** `wss://api.mistral.ai/v1/audio/transcriptions/realtime`
- **Auth:** `Authorization: Bearer <key>` header during WebSocket handshake
- **Audio format:** PCM 16-bit signed LE, 16kHz, mono, base64-encoded chunks
- **Client → Server messages:**
  - `{"type": "input_audio.append", "audio": "<base64>"}` — send audio chunk
  - `{"type": "input_audio.end"}` — signal end of audio
- **Server → Client messages:**
  - `session.created` — handshake confirmation
  - `transcription.text.delta` — incremental text (the `delta` field contains text)
  - `transcription.language` — detected language
  - `transcription.done` — final transcript + usage
  - `error` — error event

## Provider Configuration & Model Routing

### How users configure the realtime model

Users configure models through the existing settings UI (`inference_model_edit_page.dart`). The realtime model uses the existing `InferenceProviderType.mistral` provider type — no new provider type is needed. The user:

1. Adds (or already has) a Mistral inference provider with their API key
2. Adds a model with `providerModelId: "voxtral-mini-transcribe-realtime-2602"` and `inputModalities: [Modality.audio]`

The model appears alongside other audio-capable models in the configuration.

### How realtime vs batch is decided

The `RealtimeTranscriptionService` does **not** go through `CloudInferenceRepository.generateWithAudio()` — that routing chain is HTTP request-response only. Instead, the service directly queries `AiConfigRepository` for audio-capable models, filters for realtime models using `MistralRealtimeTranscriptionRepository.isRealtimeModel()`, and uses the matched provider's API key and base URL to open a WebSocket.

The UI shows recording mode options based on what is actually configured:
- **Both batch and realtime models configured:** User can toggle between modes (default: batch).
- **Only batch model(s) configured:** Only batch mic shown (current behavior, no toggle).
- **Only realtime model configured:** Only realtime mic shown. Batch mode is **not** available — the toggle is hidden. This is correct because `AudioTranscriptionService` excludes realtime models, so it would throw on an empty model set.
- **No audio models configured:** Show the tune/settings icon (existing `requiresModelSelection` behavior).

### WebSocket endpoint URL

The WS URL is **derived from the provider's `baseUrl`**, not hardcoded. The default Mistral base URL is `https://api.mistral.ai/v1` (from `provider_config.dart:21`), which already includes the `/v1` path segment.

**Derivation rules:**
1. Strip any trailing `/v1` or `/v1/` from the base URL to get the host root (e.g. `https://api.mistral.ai/v1` → `https://api.mistral.ai`)
2. Replace scheme: `https` → `wss`, `http` → `ws`
3. Append the fixed realtime path: `/v1/audio/transcriptions/realtime`

**Examples:**
- `https://api.mistral.ai/v1` → `wss://api.mistral.ai/v1/audio/transcriptions/realtime`
- `https://api.mistral.ai` → `wss://api.mistral.ai/v1/audio/transcriptions/realtime`
- `http://localhost:8080/v1` → `ws://localhost:8080/v1/audio/transcriptions/realtime`
- `https://my-proxy.example.com` → `wss://my-proxy.example.com/v1/audio/transcriptions/realtime`

This avoids double `/v1/v1/` paths and supports HTTPS (hosted) and HTTP (local/proxy) endpoints.

### Recording API differences

- **Batch mode (existing):** `recorder.start(RecordConfig(sampleRate: 48000, autoGain: true), path: filePath)` — records to M4A file at 48kHz. Amplitude via `recorder.onAmplitudeChanged()`.
- **Realtime mode (new):** `recorder.startStream(RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000))` — returns `Stream<Uint8List>` of raw PCM at 16kHz. No built-in amplitude callback; dBFS must be computed manually from PCM samples.

These are fundamentally different `record` package APIs. The controller must use the correct one based on mode.

## Transcript Finalization

`transcription.done` is the **sole authoritative source** for the final transcript. Accumulated deltas are used strictly for live UI preview (`partialTranscript`). On stop:

1. Cancel PCM stream subscription (stop forwarding audio to WebSocket)
2. **Stop the recorder** (release microphone immediately — user expects mic off at stop intent)
3. Send `input_audio.end`
4. **Wait for `transcription.done`** (with a timeout, e.g. 10 seconds)
5. Use the `text` field from `transcription.done` as the final `transcript`
6. Write temp WAV, convert to M4A, delete temp WAV
7. **Then** disconnect

If the timeout expires without `transcription.done`, fall back to the accumulated deltas as the best-effort final transcript and log a warning. This prevents token loss at the end of a recording.

## Resource Ownership

Clear single-owner boundaries prevent double-cleanup races:

- **Controller owns the recorder lifecycle.** It creates the `AudioRecorder`, calls `startStream()`, and is solely responsible for `recorder.dispose()` via `_cleanupInternal()`.
- **Service borrows the PCM stream, not the recorder.** The service receives the `Stream<Uint8List>` returned by `startStream()` — it never holds a reference to the recorder itself. The service manages: the stream subscription (listening to PCM chunks), the WebSocket connection, the `BytesBuilder`, WAV → M4A conversion, and final audio file output.
- **Stop sequence:** Controller calls `service.stop(stopRecorder: () => recorder.stop())`. The service cancels the stream subscription, invokes the callback to stop the recorder (mic off immediately), sends `endAudio`, awaits `transcription.done`, writes temp WAV, converts to M4A, deletes temp WAV. Then controller calls `_cleanupInternal()` to dispose the recorder instance. The `stopRecorder` callback pattern preserves single ownership — the controller provides the action, the service controls the timing.
- **Service `dispose()`** only tears down what it owns: cancels stream subscription, closes WebSocket, writes any buffered audio (WAV → M4A if possible, WAV fallback otherwise). It does **not** touch the recorder.

## Audio File Pipeline: WAV → M4A Conversion

The `record` package's `startStream()` produces raw PCM, not M4A. But we don't want to store or sync WAV files — only M4A. The pipeline:

1. **During recording:** PCM chunks accumulate in a `BytesBuilder` in memory
2. **On stop:** Write WAV to a **temp file** (controller's temp directory, not app support)
3. **Convert:** Call a native platform channel to transcode WAV → M4A using system frameworks (no FFmpeg needed)
4. **Save:** The M4A is the final artifact — written to the same location batch recordings use
5. **Delete:** The temp WAV is deleted immediately after successful conversion
6. **Sync:** Only the M4A gets synced, consistent with batch mode

### Native conversion (platform channel)

iOS and macOS ship with `AVFoundation` which can transcode WAV → M4A natively:

- **Recommended API:** `AVAudioFile` (read WAV) + `AVAudioConverter` (PCM → AAC) + `AVAudioFile` (write M4A). This gives control over bitrate and is available on both iOS and macOS.
- **Alternative:** `AVAssetExportSession` with `AVAssetExportPresetAppleM4A` — simpler but less control.
- **Hardware-accelerated** AAC encoding on Apple Silicon makes this fast (sub-second for 2 minutes of audio).

The project has no existing platform channels (AppDelegate is minimal on both platforms), so this introduces a new `MethodChannel` named e.g. `com.matthiasn.lotti/audio_converter`.

**Dart side:**
```dart
class AudioConverterChannel {
  static const _channel = MethodChannel('com.matthiasn.lotti/audio_converter');

  /// Converts WAV at [inputPath] to M4A at [outputPath].
  /// Returns true on success, false if conversion is unsupported or fails.
  static Future<bool> convertWavToM4a({
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('convertWavToM4a', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return result ?? false;
    } on MissingPluginException {
      // Platform has no native implementation — fall back to WAV
      return false;
    }
  }
}
```

**Swift side (shared between iOS and macOS):**
- Register the channel in `AppDelegate`
- Implement `convertWavToM4a`: open input WAV as `AVAudioFile`, create output M4A `AVAudioFile` with AAC settings, use `AVAudioConverter` to transcode, return success/failure
- Error cases: file not found, unsupported format, disk full → return `FlutterError`

**Fallback for other platforms (Linux, Windows, Android):**
- For this plan: return the WAV path as-is (no conversion). WAV is still valid for batch APIs.
- Follow-up: implement native conversion on Android (via `MediaCodec` AAC encoder) and Linux (via GStreamer or platform-equivalent). Same `MethodChannel` contract, platform-specific implementations.

### Error during conversion

If WAV → M4A conversion fails:
- Keep the WAV file as fallback (don't delete it)
- Log the error
- The WAV is still usable for batch reprocessing — just larger and not in the preferred format

## Error Handling & Recovery

### WebSocket disconnection mid-recording

If the WebSocket drops during recording:

1. **Save accumulated PCM** — the `BytesBuilder` already has all audio data up to the disconnect point. Write temp WAV, convert to M4A, delete temp WAV (or keep WAV if conversion fails)
2. **Surface error to user** — emit a `TranscriptionException` with `provider: 'Mistral Realtime'` via the `errors` stream; the controller updates state with an error message
3. **No automatic retry** — reconnecting mid-stream would lose context and produce a discontinuous transcript. The saved WAV file is available for future batch reprocessing (out of scope for this plan)
4. **Controller stops recorder** — controller calls `_cleanupInternal()` which disposes the recorder (service does not touch it)

### App backgrounding (iOS/Android lifecycle)

When the app is backgrounded during realtime recording:

- **iOS:** Audio recording may continue briefly but the WebSocket will likely be suspended. On resume, treat as a disconnect — stop recorder, service saves audio, controller disposes recorder.
- **Android:** Similar behavior. The controller should listen for lifecycle events and trigger a graceful stop (`recorder.stop()` then `service.stop()` then cleanup) rather than letting the OS kill the connection ungracefully.
- **macOS/Desktop:** No lifecycle suspension concerns.

**Implementation:** The controller mixes in `WidgetsBindingObserver` and overrides `didChangeAppLifecycleState`. On `AppLifecycleState.paused` (or `inactive` on iOS), if `status == realtimeRecording`, call `stopRealtime()`. This is a simple addition to the controller — no new files needed.

## Implementation Plan

### Step 1: Add `web_socket_channel` dependency

**File:** `pubspec.yaml`

Promote `web_socket_channel` from transitive to direct dependency. It is already in the lockfile at version `3.0.1`, so adding `web_socket_channel: ^3.0.0` is safe. Run `fvm flutter pub get`.

---

### Step 2: Create data models for real-time events

**New file:** `lib/features/ai/model/realtime_transcription_event.dart`

Plain Dart classes (not Freezed — these are small, read-only value types that don't benefit from code generation overhead):

```dart
class RealtimeTranscriptionDone {
  const RealtimeTranscriptionDone({required this.text, this.usage});
  final String text;
  final Map<String, dynamic>? usage;
}

class RealtimeTranscriptionError {
  const RealtimeTranscriptionError({
    required this.message,
    this.code,
    this.type,
  });
  final String message;
  final String? code;
  final String? type;
}

/// Returned by RealtimeTranscriptionService.stop().
class RealtimeStopResult {
  const RealtimeStopResult({
    required this.transcript,
    this.audioFilePath,
    this.usedTranscriptFallback = false,
  });
  final String transcript;          // From transcription.done, or deltas on timeout
  final String? audioFilePath;      // M4A path (or WAV path if conversion failed)
  final bool usedTranscriptFallback; // True if done timed out and deltas were used
}
```

---

### Step 3: Create `MistralRealtimeTranscriptionRepository`

**New file:** `lib/features/ai/repository/mistral_realtime_transcription_repository.dart`

A standalone class (not extending `TranscriptionRepository`, since the base class is designed for HTTP request-response, not WebSocket streams).

```
class MistralRealtimeTranscriptionRepository {
  // Constructor accepts optional WebSocketChannel factory for testability

  // --- Model detection (consistent with MistralTranscriptionRepository pattern) ---
  // Matches the known realtime model ID pattern: contains 'transcribe-realtime'
  // (e.g. 'voxtral-mini-transcribe-realtime-2602'). This is more specific than
  // just 'realtime' to avoid false positives on unrelated model IDs.
  static bool isRealtimeModel(String model) {
    return model.contains('transcribe-realtime');
  }

  // --- Connection lifecycle ---
  Future<void> connect({required String apiKey, required String baseUrl, String? model})
    // Derives WS URL from baseUrl:
    //   1. Strip trailing /v1 or /v1/ to normalize
    //   2. Replace scheme (https -> wss, http -> ws)
    //   3. Append /v1/audio/transcriptions/realtime
    // Sends Authorization header
    // Waits for session.created event
    // Throws TranscriptionException on connection failure

  void sendAudioChunk(Uint8List pcmBytes)
    // Base64-encodes the PCM data
    // Sends {"type": "input_audio.append", "audio": "<base64>"}

  Future<void> endAudio()
    // Sends {"type": "input_audio.end"}

  Future<void> disconnect()
    // Closes WebSocket cleanly

  // --- Output streams ---
  Stream<String> get transcriptionDeltas
    // Emits text from transcription.text.delta events

  Stream<String> get detectedLanguage
    // Emits from transcription.language events

  Stream<RealtimeTranscriptionDone> get transcriptionDone
    // Emits final result from transcription.done

  Stream<RealtimeTranscriptionError> get errors
    // Emits from error events

  // --- State ---
  bool get isConnected

  void dispose()
}
```

**Key design decisions:**
- Uses `WebSocketChannel` from `web_socket_channel` package
- All incoming messages parsed from JSON, dispatched to typed `StreamController`s
- Connection errors surface via the `errors` stream and throw `TranscriptionException`
- Testable via injected `WebSocketChannel` factory
- `isRealtimeModel()` lives here (consistent with `MistralTranscriptionRepository.isMistralTranscriptionModel()`)

**New test file:** `test/features/ai/repository/mistral_realtime_transcription_repository_test.dart`
- Mock WebSocket channel via injected factory
- Test connect/disconnect lifecycle (including `session.created` handshake)
- Test WS URL derivation from baseUrl with `/v1` suffix (`https://api.mistral.ai/v1` → `wss://api.mistral.ai/v1/audio/transcriptions/realtime`)
- Test WS URL derivation from baseUrl without `/v1` (`https://api.mistral.ai` → same result, no double `/v1/v1/`)
- Test WS URL derivation with `http` scheme (`http://localhost:8080/v1` → `ws://localhost:8080/v1/...`)
- Test WS URL derivation with custom baseUrl (e.g. `https://my-proxy.example.com`)
- Test sending audio chunks (verify base64 encoding, JSON structure)
- Test receiving transcription deltas, done, language, errors
- Test connection error handling (throws `TranscriptionException`)
- Test `input_audio.end` message on stop
- Test `isRealtimeModel()` static method

---

### Step 4: Create PCM amplitude utility

**New file:** `lib/features/ai/util/pcm_amplitude.dart`

Extract dBFS computation into a standalone, testable function:

```dart
/// Computes dBFS (decibels relative to full scale) from a PCM 16-bit
/// signed little-endian audio chunk.
///
/// Returns a value typically in the range [-80, 0] where 0 is maximum
/// amplitude and -80 is near-silence.
double computeDbfsFromPcm16(Uint8List pcmBytes) {
  // 1. Interpret bytes as Int16 samples (little-endian)
  // 2. Compute RMS: sqrt(sum(sample^2) / numSamples)
  // 3. Convert to dBFS: 20 * log10(rms / 32768)
  // 4. Clamp to [-80, 0]
}
```

This keeps the algorithm isolated from recording/controller concerns and makes it straightforward to test with known sample data.

**New test file:** `test/features/ai/util/pcm_amplitude_test.dart`
- Test with silence (all zeros) → returns -80 (or clamped floor)
- Test with max amplitude → returns ~0
- Test with known sine wave samples → returns expected dBFS
- Test with odd byte count (truncated sample) → handles gracefully
- Test with empty input → returns floor value

---

### Step 5: Create `AudioConverterChannel` (platform channel for WAV → M4A)

**New files:**
- `lib/features/ai/util/audio_converter_channel.dart` — Dart `MethodChannel` wrapper
- `macos/Runner/AudioConverter.swift` — macOS native implementation
- `ios/Runner/AudioConverter.swift` — iOS native implementation (shared logic)

**Dart side:** `AudioConverterChannel` class with a single static method `convertWavToM4a({required String inputPath, required String outputPath})` returning `Future<bool>`. Channel name: `com.matthiasn.lotti/audio_converter`. The method **catches `MissingPluginException`** and returns `false` — this is how unsupported platforms (Linux, Windows, Android) gracefully fall back to keeping the WAV file without crashing.

**Swift side (shared logic for iOS and macOS):**
1. Register the channel in `AppDelegate.swift` (both platforms)
2. Handle `convertWavToM4a` method call:
   - Open input WAV as `AVAudioFile`
   - Create output `AVAudioFile` with AAC/M4A format settings (`kAudioFormatMPEG4AAC`)
   - Use `AVAudioConverter` to transcode buffers
   - Return `true` on success, `FlutterError` on failure

**Fallback:** On platforms without a native implementation (Linux, Windows, Android for now), `invokeMethod` throws `MissingPluginException`. The Dart wrapper catches this and returns `false`. The service keeps the WAV as-is. Follow-up plans will add Android (`MediaCodec`) and Linux (GStreamer) implementations using the same channel contract.

**New test file:** `test/features/ai/util/audio_converter_channel_test.dart`
- Mock the `MethodChannel` using `TestDefaultBinaryMessengerBinding`
- Test successful conversion returns `true`
- Test native failure (FlutterError) returns `false`
- Test `MissingPluginException` (unsupported platform) returns `false`, no crash
- Test null result returns `false`

**Register in AppDelegate:**
- `macos/Runner/AppDelegate.swift` — register channel, call `AudioConverter.register(with:)`
- `ios/Runner/AppDelegate.swift` — same pattern

---

### Step 6: Create `RealtimeTranscriptionService` and guard batch selection

**New file:** `lib/features/ai_chat/services/realtime_transcription_service.dart`

Orchestrates the recording + WebSocket streaming. Riverpod provider. This service bypasses `CloudInferenceRepository` entirely — realtime streaming is a different paradigm from the HTTP batch flow.

**Also modify:** `lib/features/ai_chat/services/audio_transcription_service.dart`

The existing `AudioTranscriptionService` selects transcription models by filtering for `inputModalities.contains(Modality.audio)`. The new realtime model also has `Modality.audio` as input. Without a guard, the batch service could accidentally select the realtime model — which won't work since `CloudInferenceRepository.generateWithAudio()` has no WebSocket path. Add an exclusion filter:

```dart
final audioModels = models
    .whereType<AiConfigModel>()
    .where((m) => m.inputModalities.contains(Modality.audio))
    .where((m) => !MistralRealtimeTranscriptionRepository.isRealtimeModel(
        m.providerModelId))
    .toList();
```

**Test:** Update `test/features/ai_chat/services/audio_transcription_service_test.dart` to verify that a configured realtime model is excluded from batch selection.

```
class RealtimeTranscriptionService {
  RealtimeTranscriptionService(this.ref);

  // --- Provider resolution ---
  // Queries AiConfigRepository for audio-capable models
  // Filters for models where MistralRealtimeTranscriptionRepository.isRealtimeModel()
  // Resolves the matching provider's API key and base URL

  Stream<String> startRealtimeTranscription({
    required Stream<Uint8List> pcmStream,
  }) async* {
    // Service receives the PCM stream, NOT the recorder.
    // The controller owns the recorder and calls startStream() itself.
    //
    // 1. Resolve Mistral provider with realtime model
    // 2. Connect WebSocket via MistralRealtimeTranscriptionRepository
    //    (passing provider.baseUrl for URL derivation)
    // 3. Listen to pcmStream:
    //    a. Send each chunk to WebSocket via sendAudioChunk()
    //    b. Accumulate in BytesBuilder for WAV file saving
    //    c. Compute dBFS via computeDbfsFromPcm16() for amplitude display
    // 4. Yield transcription deltas as they arrive
  }

  /// Stream of amplitude values (dBFS) computed from PCM chunks.
  /// Fed into the controller's amplitudeHistory for waveform display.
  Stream<double> get amplitudeStream

  Future<RealtimeStopResult> stop({required Future<void> Function() stopRecorder})
    // 1. Cancels pcmStream subscription (stops forwarding audio)
    // 2. Calls stopRecorder() — controller passes recorder.stop() here so the
    //    mic is released immediately at stop intent. Service does not own the
    //    recorder but needs the mic off before waiting for the server.
    // 3. Sends input_audio.end
    // 4. Awaits transcription.done (with 10s timeout)
    //    - On success: uses done.text as authoritative final transcript
    //    - On timeout: falls back to accumulated deltas, logs warning
    // 5. Writes accumulated PCM to temp WAV file (16kHz, 16-bit, mono, 44-byte header)
    // 6. Converts temp WAV → M4A via AudioConverterChannel.convertWavToM4a()
    //    - On success: deletes temp WAV, returns M4A path
    //    - On failure: keeps WAV as fallback, logs error
    // 7. Disconnects WebSocket
    // 8. Returns RealtimeStopResult(transcript, audioFilePath)

  void dispose()
    // Defensive cleanup: cancel pcmStream subscription, send input_audio.end
    // if connected, save any accumulated audio to WAV, close WebSocket.
    // Does NOT touch the recorder — that's the controller's responsibility.
}
```

**Audio file pipeline:** Accumulate PCM bytes in a `BytesBuilder`. On stop, prepend a 44-byte WAV header (RIFF + fmt + data chunks for PCM16 mono 16kHz) and write to a temp file. Then convert to M4A via `AudioConverterChannel.convertWavToM4a()` and delete the temp WAV. The final M4A is written to the same location batch recordings use, consistent with the sync pipeline.

**New test file:** `test/features/ai_chat/services/realtime_transcription_service_test.dart`
- Mock repository, PCM stream, and AiConfigRepository
- Test provider resolution (finds realtime model, resolves provider with baseUrl)
- Test stream forking (WebSocket receives chunks + BytesBuilder accumulates)
- Test amplitude stream emits dBFS values
- Test WAV file writing (correct header + PCM data) and M4A conversion call
- Test WAV deleted after successful M4A conversion
- Test WAV retained as fallback when M4A conversion fails
- Test stop sequence: cancel stream → stopRecorder callback → endAudio → await `transcription.done` → temp WAV → M4A convert → delete temp WAV → disconnect
- Test stop with `transcription.done` timeout: falls back to accumulated deltas
- Test `RealtimeStopResult` contains authoritative transcript from `done` event
- Test error handling on WebSocket disconnect mid-recording (audio saved, error surfaced)
- Test dispose is defensive (no crash if called when not connected, does not touch recorder)
- Use `fakeAsync` per test/README.md

---

### Step 7: Add real-time recording mode to `ChatRecorderController`

**File:** `lib/features/ai_chat/ui/controllers/chat_recorder_controller.dart`

Split into two sub-concerns:

#### 7a: Status enum, lifecycle methods, operation ID, safety timer, and app lifecycle

1. Add `realtimeRecording` to `ChatRecorderStatus` enum:
   ```dart
   enum ChatRecorderStatus { idle, recording, realtimeRecording, processing }
   ```

2. Add `startRealtime()` method:
   - Guard with `_isStarting` flag (same as `start()`) to prevent concurrent operations
   - Increment `_operationId` and capture locally — check `currentOpId == _operationId && ref.mounted` before every state update, matching the existing pattern in `start()` and `stopAndTranscribe()`
   - Checks permissions (reuse existing `recorder.hasPermission()` logic)
   - Creates `AudioRecorder`, calls `recorder.startStream(RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000))` — controller owns the recorder
   - Creates `RealtimeTranscriptionService`, passes the `Stream<Uint8List>` (not the recorder)
   - Updates `partialTranscript` as deltas arrive (same state field as batch mode)
   - Sets status to `ChatRecorderStatus.realtimeRecording`
   - Sets `_maxTimer` to call `stopRealtime()` (not `stopAndTranscribe()`) after `_config.maxSeconds`. The same 120-second default applies — realtime sessions are chat input, not long-form dictation, so the same limit is appropriate. This can be revisited if users need longer sessions.

3. Add `stopRealtime()` method:
   - Calls `service.stop(stopRecorder: () => _recorder!.stop())` which: cancels stream subscription, **stops the recorder immediately** (mic off), sends `endAudio`, awaits `transcription.done` (10s timeout), writes temp WAV, converts to M4A, deletes temp WAV, disconnects WS
   - Sets `transcript` from `RealtimeStopResult.transcript` (authoritative `done` text, or fallback to deltas on timeout)
   - Then calls `_cleanupInternal()` to dispose the recorder instance
   - Cancels `_maxTimer`
   - Returns to idle

4. Modify `cancel()` to handle `realtimeRecording` status:
   - Increments `_operationId` to invalidate in-flight state updates (same as existing cancel)
   - Cancels amplitude subscription
   - Calls `_recorder?.stop()` explicitly (mic off — matching existing cancel pattern at line 344)
   - Calls `service.dispose()` (cancels stream, writes audio, closes WS — no waiting for `done`)
   - Calls `_cleanupInternal()` to dispose recorder instance
   - Discards transcript, cancels `_maxTimer`, returns to idle

5. Add app lifecycle handling:
   - Mix in `WidgetsBindingObserver`, register in `build()`/`dispose()`
   - Override `didChangeAppLifecycleState`: on `paused`/`inactive`, if `status == realtimeRecording`, call `stopRealtime()`
   - No-op for batch `recording` status (existing file-based recording handles backgrounding fine)

#### 7b: Amplitude integration

- Subscribe to `RealtimeTranscriptionService.amplitudeStream`
- Feed dBFS values into existing `amplitudeHistory` list
- Reuse `getNormalizedAmplitudeHistory()` — the normalization logic (mapping dBFS -80...-10 to 0.05...1.0) works identically for both recording modes
- Same 200-sample max history, same 100ms-ish update cadence

**Update test file:** `test/features/ai_chat/ui/controllers/chat_recorder_controller_test.dart`
- Test `startRealtime()` and `stopRealtime()` lifecycle
- Test `realtimeRecording` status transitions (idle → realtimeRecording → idle)
- Test `partialTranscript` updates during real-time mode (deltas for UI preview)
- Test `stopRealtime()` sets `transcript` from `RealtimeStopResult.transcript` (authoritative `done` text)
- Test `stopRealtime()` calls `service.stop()` before `_cleanupInternal()` (service finalizes first, then recorder disposed)
- Test cancel during real-time recording (verifies `_operationId` increment invalidates in-flight updates)
- Test cancel calls `service.dispose()` then `_cleanupInternal()` (correct teardown order)
- Test amplitude history populated from PCM-derived dBFS
- Test error state when WebSocket disconnects mid-recording
- Test safety timer fires `stopRealtime()` (not `stopAndTranscribe()`) after `maxSeconds`
- Test concurrent operation guard (`_isStarting` prevents double `startRealtime()`)
- Test operation ID prevents stale state updates from previous session
- Test app lifecycle: `paused` during `realtimeRecording` triggers `stopRealtime()`
- Test app lifecycle: `paused` during batch `recording` is no-op
- Use `fakeAsync` per test/README.md

---

### Step 8: Update UI — show live transcript below waveform during recording

**File:** `lib/features/ai_chat/ui/widgets/chat_interface/input_area.dart`

Changes to `InputArea.build()`:

1. When `status == realtimeRecording`, show a **Column** containing:
   - `WaveformBars` (existing, top)
   - `_TranscriptionProgress` (existing widget, repurposed) — shows `partialTranscript` live during recording, not just during processing
   - Cancel and Stop buttons (existing `ChatVoiceControls` pattern)

2. Add a mode toggle for the mic button:
   - When idle with no text: show mic icon (batch) or a "live mic" icon (real-time)
   - Toggle between modes via long-press or a small switch/chip near the input area
   - **Only show toggle when both batch and realtime models are configured.** If only one type exists, show just that mode's icon (no toggle). If neither exists, show the tune icon (existing `requiresModelSelection` behavior).
   - Store preference in a **separate `keepAlive` Riverpod provider** (e.g. `realtimeModePreferenceProvider`), not in the `autoDispose` controller state. This ensures the preference survives widget rebuilds and navigation. For cross-session persistence, back it with `SharedPreferences`.

3. Modify `ChatVoiceControls` to accept optional `partialTranscript` and render text below waveform when in real-time mode.

**Widget tests:** `test/features/ai_chat/ui/widgets/chat_interface/input_area_test.dart`
- Test real-time recording mode shows waveform + transcript simultaneously
- Test mode toggle visible only when both batch and realtime models configured
- Test mode toggle hidden when only one type configured (shows that mode's icon directly)
- Test toggle persists across widget rebuilds (backed by `keepAlive` provider)
- Test cancel/stop buttons in realtime mode

---

### Step 9: Register realtime model in known models

**File:** `lib/features/ai/util/known_models.dart`

Add `voxtral-mini-transcribe-realtime-2602` to the `mistralModels` list (alongside existing `voxtral-mini-latest`):

```dart
const KnownModel(
  providerModelId: 'voxtral-mini-transcribe-realtime-2602',
  name: 'Voxtral Realtime',
  inputModalities: [Modality.audio],
  outputModalities: [Modality.text],
  description: 'Real-time streaming transcription via WebSocket. '
      'Low-latency live subtitles (~2s delay). No diarization.',
),
```

No standalone `isMistralRealtimeModel()` here — that method lives on `MistralRealtimeTranscriptionRepository` as `isRealtimeModel()` (see Step 3), consistent with how `MistralTranscriptionRepository.isMistralTranscriptionModel()` is a static method on its own repository class.

---

### Step 10: Add localization strings

**Files:** `lib/l10n/app_en.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_ro.arb`

New keys (examples for English):
```json
"aiRealtimeTranscribing": "Live transcription...",
"aiRealtimeTranscriptionError": "Live transcription disconnected. Audio saved for batch processing.",
"aiRealtimeToggleTooltip": "Switch to live transcription",
"aiBatchToggleTooltip": "Switch to standard recording"
```

Add equivalent translations in all ARB files. Run `make l10n` and `make sort_arb_files`.

---

### Step 11: Update CHANGELOG, metainfo, and feature READMEs

**File:** `CHANGELOG.md` — add under current version (`[0.9.857]` or next):
```markdown
### Added
- Real-time transcription via Mistral Voxtral WebSocket API with live subtitles during recording
```

**File:** `flatpak/com.matthiasn.lotti.metainfo.xml` — add matching release description.

**File:** `lib/features/ai/README.md` — update transcription repositories section to document `MistralRealtimeTranscriptionRepository` alongside the existing batch repositories.

**File:** `lib/features/ai_chat/README.md` — update voice input section to document both batch and realtime modes.

---

### Step 12: Run analyzer, formatter, and tests

- `dart-mcp.analyze_files` — zero warnings for entire project
- `dart-mcp.dart_format` — all files formatted
- `dart-mcp.run_tests` on all new and modified test files
- Full project analysis to ensure no regressions

---

## Files to Create
| File | Purpose |
|------|---------|
| `lib/features/ai/model/realtime_transcription_event.dart` | Plain Dart data models for WS events |
| `lib/features/ai/repository/mistral_realtime_transcription_repository.dart` | WebSocket client for Mistral realtime API |
| `lib/features/ai/util/pcm_amplitude.dart` | dBFS computation from PCM16 samples |
| `lib/features/ai/util/audio_converter_channel.dart` | Dart MethodChannel wrapper for WAV → M4A |
| `macos/Runner/AudioConverter.swift` | macOS native WAV → M4A via AVAudioConverter |
| `ios/Runner/AudioConverter.swift` | iOS native WAV → M4A via AVAudioConverter |
| `lib/features/ai_chat/services/realtime_transcription_service.dart` | Orchestration service |
| `test/features/ai/repository/mistral_realtime_transcription_repository_test.dart` | Repository tests |
| `test/features/ai/util/pcm_amplitude_test.dart` | Amplitude utility tests |
| `test/features/ai/util/audio_converter_channel_test.dart` | Platform channel tests (mocked) |
| `test/features/ai_chat/services/realtime_transcription_service_test.dart` | Service tests |

## Files to Modify
| File | Changes |
|------|---------|
| `pubspec.yaml` | Promote `web_socket_channel` to direct dependency |
| `macos/Runner/AppDelegate.swift` | Register AudioConverter platform channel |
| `ios/Runner/AppDelegate.swift` | Register AudioConverter platform channel |
| `lib/features/ai_chat/services/audio_transcription_service.dart` | Exclude realtime models from batch model selection |
| `lib/features/ai_chat/ui/controllers/chat_recorder_controller.dart` | Add `realtimeRecording` status, `startRealtime()`, `stopRealtime()`, operation ID guards, safety timer routing, amplitude from PCM |
| `lib/features/ai_chat/ui/widgets/chat_interface/input_area.dart` | Real-time recording UI layout (waveform + live transcript), mode toggle |
| `lib/features/ai/util/known_models.dart` | Add realtime model to `mistralModels` list |
| `lib/l10n/app_en.arb` (and de, es, fr, ro) | New localization keys for realtime mode |
| `CHANGELOG.md` | Document new feature |
| `flatpak/com.matthiasn.lotti.metainfo.xml` | Matching release entry |
| `lib/features/ai/README.md` | Document realtime repository |
| `lib/features/ai_chat/README.md` | Document realtime vs batch modes |
| `test/features/ai_chat/services/audio_transcription_service_test.dart` | Test that realtime models are excluded from batch selection |
| `test/features/ai_chat/ui/controllers/chat_recorder_controller_test.dart` | New tests for real-time mode, operation ID, safety timer |

## Existing Code to Reuse
- `TranscriptionException` from `lib/features/ai/repository/transcription_exception.dart` — for error types
- `_TranscriptionProgress` widget in `input_area.dart:301-363` — live text display
- `WaveformBars` widget — amplitude visualization
- `ChatRecorderConfig` — recording configuration
- `AiConfigRepository` / `AiConfigInferenceProvider` — API key and provider access
- `LoggingService` — consistent logging pattern
- `AudioRecorder` from `record` package — `startStream()` with `AudioEncoder.pcm16bits`
- `getNormalizedAmplitudeHistory()` pattern — amplitude normalization (dBFS -80...-10 → 0.05...1.0)

## Verification
1. Run `dart-mcp.analyze_files` — must be zero warnings for entire project
2. Run `dart-mcp.dart_format` — all files formatted
3. Run targeted tests on all new and modified test files
4. Manual test: configure Mistral provider with API key, add `voxtral-mini-transcribe-realtime-2602` model with audio input modality, tap live mic, speak, verify text appears ~2s after speech
5. Verify final transcript matches `transcription.done` text (not just accumulated deltas)
6. Verify M4A file is produced after recording stops (temp WAV deleted after conversion)
7. Verify batch mode still works unaffected
8. Verify WebSocket disconnect mid-recording saves audio file (M4A or WAV fallback) and shows error to user
9. Verify mode toggle between batch and realtime persists across navigation (SharedPreferences-backed)
10. Verify batch transcription does not accidentally pick the realtime model when both are configured
11. Verify safety timer calls `stopRealtime()` in realtime mode (not `stopAndTranscribe()`)
12. Verify with only realtime model configured: batch mic hidden, no toggle, realtime mic shown directly
13. Verify recorder is disposed by controller only (service never touches it)
