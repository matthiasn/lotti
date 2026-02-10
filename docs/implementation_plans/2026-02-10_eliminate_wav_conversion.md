# Implementation Plan: Eliminate M4A-to-WAV Conversion for Mistral

**Date**: 2026-02-10
**Branch**: TBD (e.g., `feat/mistral-native-m4a`)
**Context**: Mistral's Voxtral Transcribe 2 (released 2026-02-04) now natively supports
`.m4a`, `.mp3`, `.wav`, `.flac`, `.ogg` up to **1 GB** per file and **3 hours** per request.
The forced WAV conversion is no longer needed and can be fully removed.

---

## Problem

| Aspect | Old (current code) | New (after this change) |
|---|---|---|
| Mistral audio format | M4A forced → WAV (8 kHz mono PCM) | M4A sent directly |
| File size for 10 min recording | ~10 MB WAV (hits ~20 MB for longer) | ~1.5 MB M4A |
| Max upload | Bumped into 20 MB quota errors | 1 GB limit — no issues |
| FFmpeg dependency | Required on all platforms | Can be removed entirely |
| Audio quality | Downsampled to 8 kHz mono | Original 48 kHz stereo preserved |

---

## Step-by-step Changes

### Step 1: Remove Mistral WAV conversion in `_prepareAudio()`

**File**: `lib/features/ai/repository/unified_ai_inference_repository.dart`
**Lines**: 505–569

Remove the entire Mistral-specific conversion branch (lines 526–557). The method
simplifies to always reading the original file and labeling it appropriately:

```dart
Future<PreparedAudio?> _prepareAudio(
  AiConfigPrompt promptConfig,
  JournalEntity entity,
  AiConfigInferenceProvider provider,
) async {
  if (promptConfig.aiResponseType.isPromptGenerationType) {
    return null;
  }
  if (!promptConfig.requiredInputData.contains(InputDataType.audioFiles)) {
    return null;
  }
  if (entity is! JournalAudio) return null;

  final fullPath = await AudioUtils.getFullAudioPath(entity);
  final file = File(fullPath);
  final bytes = await file.readAsBytes();

  // All providers now accept M4A natively — label as mp3 (universally accepted)
  return PreparedAudio(
    base64: base64Encode(bytes),
    format: ChatCompletionMessageInputAudioFormat.mp3,
  );
}
```

**Also remove**:
- The `import` of `AudioFormatConverterService` (and `AudioConversionException`)
  from this file if no other references remain.
- The `audioFormatConverterProvider` read (line 539).

---

### Step 2: Delete `AudioFormatConverterService` and related files

**Files to delete**:

| File | Reason |
|---|---|
| `lib/utils/audio_format_converter.dart` | Entire converter — no longer used by any provider |
| `lib/utils/audio_format_converter.g.dart` | Generated Riverpod code for the above |
| `test/utils/audio_format_converter_test.dart` | Tests for the deleted service |

**Verify first**: Grep for `AudioFormatConverter` and `audioFormatConverter` to
confirm no other call sites exist beyond the ones in
`unified_ai_inference_repository.dart` (already confirmed — only 5 files, all
accounted for).

---

### Step 3: Remove FFmpeg dependency

**File**: `pubspec.yaml` (line 43)

Remove:
```yaml
ffmpeg_kit_flutter_new_min: ^3.1.0
```

Then run:
```bash
flutter pub get
```

**Note**: Check if FFmpeg is used anywhere else (e.g., video processing). Current
grep confirms it's only referenced in the audio converter files being deleted and
the Flatpak security test.

**File**: `test/flatpak/flatpak_security_test.dart`
- Update or remove any test assertions that reference `ffmpeg_kit_flutter`.

---

### Step 4: Update Voxtral Small model description

**File**: `lib/features/ai/util/known_models.dart` (lines 531–533)

Change:
```dart
description: 'High-accuracy cloud transcription model. '
    'Supports up to 30 minutes of audio with 9 languages (auto-detected). '
    'Audio is automatically converted to WAV format.',
```

To:
```dart
description: 'High-accuracy cloud transcription model. '
    'Supports M4A, MP3, WAV, FLAC, and OGG up to 1 GB. '
    'Up to 3 hours of audio with 13 languages (auto-detected).',
```

This reflects Voxtral Transcribe 2 capabilities (released 2026-02-04).

---

### Step 5: Update the Mistral FTUE audio model ID

**File**: `lib/features/ai/util/known_models.dart` (line 651)

Evaluate whether the FTUE model should be updated from `voxtral-small-2507`
to a newer Voxtral Transcribe 2 model ID (e.g., `voxtral-mini-2602` for the
transcription endpoint). If using the `/v1/audio/transcriptions` endpoint
instead of `/v1/chat/completions`, add the new model to `mistralModels`:

```dart
KnownModel(
  providerModelId: 'voxtral-mini-latest',
  name: 'Voxtral Mini Transcribe V2',
  inputModalities: [Modality.text, Modality.audio],
  outputModalities: [Modality.text],
  isReasoningModel: false,
  description: 'Fast batch transcription with speaker diarization. '
      'Supports M4A, MP3, WAV, FLAC, OGG up to 1 GB / 3 hours. '
      '13 languages with auto-detection.',
),
```

Update the FTUE constant accordingly:
```dart
const ftueMistralAudioModelId = 'voxtral-mini-latest';
```

---

### Step 6: Update locale strings (all 7 ARB files)

#### 6a. Update Voxtral local description (all locales)

**Key**: `aiProviderVoxtralDescription`

The local Voxtral description should reflect updated language count
(9 → 13 languages in Voxtral 2):

| Locale | File | Current | New |
|---|---|---|---|
| en | `app_en.arb:168` | `"Local Voxtral transcription (up to 30 min audio, 9 languages)"` | `"Local Voxtral transcription (up to 30 min audio, 13 languages)"` |
| de | `app_de.arb:169` | `"Lokale Voxtral-Transkription (bis zu 30 Min. Audio, 9 Sprachen)"` | `"Lokale Voxtral-Transkription (bis zu 30 Min. Audio, 13 Sprachen)"` |
| fr | `app_fr.arb:169` | `"Transcription Voxtral locale (jusqu'à 30 min d'audio, 9 langues)"` | `"Transcription Voxtral locale (jusqu'à 30 min d'audio, 13 langues)"` |
| es | `app_es.arb:169` | `"Transcripción Voxtral local (hasta 30 min de audio, 9 idiomas)"` | `"Transcripción Voxtral local (hasta 30 min de audio, 13 idiomas)"` |
| ro | `app_ro.arb:169` | `"Transcriere Voxtral locală (până la 30 min audio, 9 limbi)"` | `"Transcriere Voxtral locală (până la 30 min audio, 13 limbi)"` |
| cs | `app_cs.arb:169` | `"Lokální přepis Voxtral (až 30 min zvuku, 9 jazyků)"` | `"Lokální přepis Voxtral (až 30 min zvuku, 13 jazyků)"` |
| en_GB | `app_en_GB.arb` | (check — likely same as en) | Same as en |

#### 6b. Update Mistral provider description (all locales)

**Key**: `aiProviderMistralDescription`

Add mention of native audio/M4A support to distinguish from the generic
"cloud API" label:

| Locale | Current | New |
|---|---|---|
| en | `"Mistral AI cloud API"` | `"Mistral AI cloud API with native audio transcription"` |
| de | `"Mistral AI Cloud-API"` | `"Mistral AI Cloud-API mit nativer Audio-Transkription"` |
| fr | `"API cloud de Mistral AI"` | `"API cloud de Mistral AI avec transcription audio native"` |
| es | `"API en la nube de Mistral AI"` | `"API en la nube de Mistral AI con transcripción de audio nativa"` |
| ro | `"API cloud Mistral AI"` | `"API cloud Mistral AI cu transcriere audio nativă"` |
| cs | `"Mistral AI cloudové API"` | `"Mistral AI cloudové API s nativním přepisem zvuku"` |
| en_GB | (check) | Same as en |

---

### Step 7: Update Flatpak metainfo / CHANGELOG

**File**: `flatpak/com.matthiasn.lotti.metainfo.xml`

Add a new release entry describing the removal of WAV conversion and
native M4A support via Voxtral Transcribe 2.

**File**: `CHANGELOG.md`

Add entry under new version:
```
- Removed M4A-to-WAV audio conversion for Mistral — all providers now accept
  M4A natively. Eliminates FFmpeg dependency and file size quota issues.
- Updated Voxtral model to Transcribe V2 with support for 13 languages,
  speaker diarization, and up to 3 hours / 1 GB per file.
```

---

### Step 8: Update tests

#### 8a. `test/features/ai/repository/unified_ai_inference_repository_test.dart`

- Remove / rewrite tests that assert WAV conversion for Mistral provider
- Add test: Mistral provider receives M4A audio labeled as mp3 (same as other providers)
- Remove mocks for `audioFormatConverterProvider`

#### 8b. `test/features/ai/util/known_models_test.dart`

- Update model description assertion for Voxtral Small (line ~406+)
- Update FTUE model ID assertion if changed (line ~461+)

#### 8c. `test/features/ai/ui/settings/services/provider_prompt_setup_service_test.dart`

- Update any assertions referencing the old Voxtral Small model ID if FTUE
  model changes

#### 8d. `test/flatpak/flatpak_security_test.dart`

- Remove/update references to `ffmpeg_kit_flutter` package

---

## Files Changed Summary

| Action | File |
|---|---|
| **Edit** | `lib/features/ai/repository/unified_ai_inference_repository.dart` |
| **Delete** | `lib/utils/audio_format_converter.dart` |
| **Delete** | `lib/utils/audio_format_converter.g.dart` |
| **Delete** | `test/utils/audio_format_converter_test.dart` |
| **Edit** | `lib/features/ai/util/known_models.dart` |
| **Edit** | `pubspec.yaml` |
| **Edit** | `lib/l10n/app_en.arb` |
| **Edit** | `lib/l10n/app_en_GB.arb` |
| **Edit** | `lib/l10n/app_de.arb` |
| **Edit** | `lib/l10n/app_fr.arb` |
| **Edit** | `lib/l10n/app_es.arb` |
| **Edit** | `lib/l10n/app_ro.arb` |
| **Edit** | `lib/l10n/app_cs.arb` |
| **Edit** | `flatpak/com.matthiasn.lotti.metainfo.xml` |
| **Edit** | `CHANGELOG.md` |
| **Edit** | `test/features/ai/repository/unified_ai_inference_repository_test.dart` |
| **Edit** | `test/features/ai/util/known_models_test.dart` |
| **Edit** | `test/features/ai/ui/settings/services/provider_prompt_setup_service_test.dart` |
| **Edit** | `test/flatpak/flatpak_security_test.dart` |

---

## Risks & Considerations

1. **Voxtral Transcribe 2 is 6 days old** (released 2026-02-04). Verify the
   `/v1/audio/transcriptions` endpoint with an actual M4A file before merging.
2. **`voxtral-small-2507` vs `voxtral-mini-latest`**: The old model may still
   work via chat completions. Decide whether to keep backward compat or move
   all Mistral audio to the new transcription endpoint.
3. **FFmpeg removal**: Confirm no other feature (e.g., future video support)
   depends on this package before removing from `pubspec.yaml`.
4. **Local Voxtral service** (`services/voxtral-local/`): This is a separate
   Python service and is unaffected — it already accepts M4A directly.

---

## Verification Checklist

- [ ] `flutter pub get` succeeds after removing `ffmpeg_kit_flutter_new_min`
- [ ] All existing tests pass (minus deleted converter tests)
- [ ] New test: Mistral provider sends M4A without conversion
- [ ] Manual test: Record audio in app → transcribe via Mistral → success
- [ ] Manual test: Record long audio (>10 min) → no quota error
- [ ] Locale strings render correctly in all 7 languages
- [ ] FTUE setup wizard works for new Mistral provider setup
