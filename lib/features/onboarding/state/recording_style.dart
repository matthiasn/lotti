import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/services/app_prefs_service.dart';

/// The two recording "looks" the user can pick in onboarding (and later in
/// Settings). Each is a *pair* of visualizers shown together during capture:
///  * [analogue] — the skeuomorphic analog VU meter + waveform bars.
///  * [modern] — the energy-orb shader + a brand-tinted waveform.
enum RecordingStyle { analogue, modern }

/// SharedPreferences key backing [recordingStyleProvider].
const recordingStylePrefsKey = 'recording_visual_style';

/// The [AppPrefs] used to persist the recording style. A `Provider` (not a
/// hard-coded `makeSharedPrefsService()` call) so tests can override it with an
/// in-memory fake.
final recordingStyleAppPrefsProvider = Provider<AppPrefs>(
  (ref) => makeSharedPrefsService(),
);

RecordingStyle _parseRecordingStyle(String? value) => switch (value) {
  'analogue' => RecordingStyle.analogue,
  'modern' => RecordingStyle.modern,
  // Unknown / unset → the signature orb look.
  _ => RecordingStyle.modern,
};

/// The persisted recording-visual-style preference.
///
/// Loads from [AppPrefs] on build (defaulting to [RecordingStyle.modern] — the
/// signature orb look) and writes through on [setStyle]. Read by the onboarding
/// capture page and the Settings toggle.
class RecordingStyleController extends AsyncNotifier<RecordingStyle> {
  @override
  Future<RecordingStyle> build() async {
    final prefs = ref.read(recordingStyleAppPrefsProvider);
    return _parseRecordingStyle(await prefs.getString(recordingStylePrefsKey));
  }

  /// Persist [style], then reflect it in memory — so the in-memory state and
  /// the stored preference never diverge if the write fails.
  Future<void> setStyle(RecordingStyle style) async {
    final prefs = ref.read(recordingStyleAppPrefsProvider);
    await prefs.setString(key: recordingStylePrefsKey, value: style.name);
    state = AsyncData(style);
  }
}

final recordingStyleProvider =
    AsyncNotifierProvider<RecordingStyleController, RecordingStyle>(
      RecordingStyleController.new,
    );
