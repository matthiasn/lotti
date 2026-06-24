import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/services/app_prefs_service.dart';

/// In-memory [AppPrefs] backed by [store] so the provider can be exercised
/// without SharedPreferences.
AppPrefs _fakePrefs(Map<String, String> store) => AppPrefs(
  getBool: (_) async => null,
  setBool: ({required key, required value}) async => true,
  getString: (key) async => store[key],
  setString: ({required key, required value}) async {
    store[key] = value;
    return true;
  },
);

ProviderContainer _container(Map<String, String> store) {
  final container = ProviderContainer(
    overrides: [
      recordingStyleAppPrefsProvider.overrideWithValue(_fakePrefs(store)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('recordingStyleProvider', () {
    test('defaults to modern when nothing is stored', () async {
      final container = _container({});
      expect(
        await container.read(recordingStyleProvider.future),
        RecordingStyle.modern,
      );
    });

    test('reads a previously stored style', () async {
      final container = _container({recordingStylePrefsKey: 'analogue'});
      expect(
        await container.read(recordingStyleProvider.future),
        RecordingStyle.analogue,
      );
    });

    test('an unrecognised stored value falls back to modern', () async {
      final container = _container({recordingStylePrefsKey: 'bogus'});
      expect(
        await container.read(recordingStyleProvider.future),
        RecordingStyle.modern,
      );
    });

    test(
      'setStyle updates state immediately and persists the choice',
      () async {
        final store = <String, String>{};
        final container = _container(store);
        // Build first so the notifier is alive.
        await container.read(recordingStyleProvider.future);

        await container
            .read(recordingStyleProvider.notifier)
            .setStyle(RecordingStyle.analogue);

        expect(
          container.read(recordingStyleProvider).asData?.value,
          RecordingStyle.analogue,
        );
        expect(store[recordingStylePrefsKey], 'analogue');
      },
    );
  });
}
