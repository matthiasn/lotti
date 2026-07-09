import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/settings/ui/pages/recording_style_settings_page.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' show Amplitude;

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../onboarding/state/recording_style_test_utils.dart';

/// A [AppPrefs.getString] that never resolves, to simulate the pref still
/// loading.
AppPrefs _neverResolvingPrefs() => AppPrefs(
  getBool: (_) async => null,
  setBool: ({required key, required value}) async => true,
  getString: (_) => Completer<String?>().future,
  setString: ({required key, required value}) async => true,
);

void main() {
  setUp(
    () => setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<UserActivityService>(
        UserActivityService(),
      ),
    ),
  );
  tearDown(tearDownTestGetIt);

  Future<void> pumpPage(
    WidgetTester tester, {
    Map<String, String>? store,
    AppPrefs? prefs,
    AudioRecorderRepository? repo,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const RecordingStyleSettingsPage(),
        overrides: [
          recordingStyleAppPrefsProvider.overrideWithValue(
            prefs ?? fakeRecordingStylePrefs(store ?? {}),
          ),
          if (repo != null)
            audioRecorderRepositoryProvider.overrideWithValue(repo),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    // Flush SliverBoxAdapterPage's 500ms fade-in (flutter_animate) so no
    // timer is left pending when the test tears down.
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('renders the page title and delegates to the body', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Recording Style'), findsOneWidget);
    expect(find.byType(RecordingStyleSettingsBody), findsOneWidget);
  });

  testWidgets('the persisted style pre-selects the matching card', (
    tester,
  ) async {
    await pumpPage(tester, store: {recordingStylePrefsKey: 'analogue'});

    expect(find.text('Analogue — VU meter'), findsOneWidget);
    expect(find.text('Modern — energy orb'), findsOneWidget);
    // Exactly one card carries the checked radio cue.
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);

    final row = find.ancestor(
      of: find.text('Analogue — VU meter'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(
        of: row.first,
        matching: find.byIcon(Icons.radio_button_checked_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a card persists immediately with no Continue button', (
    tester,
  ) async {
    final store = <String, String>{};
    await pumpPage(tester, store: store);

    expect(find.byType(DesignSystemButton), findsNothing);

    await tester.tap(find.text('Analogue — VU meter'));
    await tester.pump();
    await tester.pump();

    expect(store[recordingStylePrefsKey], 'analogue');
  });

  testWidgets('tapping re-renders the picker selection in place', (
    tester,
  ) async {
    final store = <String, String>{};
    await pumpPage(tester, store: store); // default: modern selected

    await tester.tap(find.text('Analogue — VU meter'));
    await tester.pump();
    await tester.pump();

    final row = find.ancestor(
      of: find.text('Analogue — VU meter'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(
        of: row.first,
        matching: find.byIcon(Icons.radio_button_checked_rounded),
      ),
      findsOneWidget,
      reason: 'Analogue becomes checked after the tap, without remounting',
    );
  });

  testWidgets('try with voice starts and stops the mic', (tester) async {
    final repo = MockAudioRecorderRepository();
    final amps = StreamController<Amplitude>.broadcast();
    addTearDown(amps.close);
    when(repo.startRecording).thenAnswer(
      (_) async => AudioNote(
        createdAt: DateTime(2024, 3, 15),
        audioFile: 'tryout.m4a',
        audioDirectory: '/audio/2024-03-15/',
        duration: Duration.zero,
      ),
    );
    when(() => repo.amplitudeStream).thenAnswer((_) => amps.stream);
    when(repo.stopRecording).thenAnswer((_) async {});

    await pumpPage(tester, repo: repo);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();
    verify(repo.startRecording).called(1);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    verify(repo.stopRecording).called(1);
  });

  testWidgets(
    'a never-resolving pref load defaults to Modern selected without '
    'throwing',
    (tester) async {
      await pumpPage(tester, prefs: _neverResolvingPrefs());

      expect(tester.takeException(), isNull);
      final row = find.ancestor(
        of: find.text('Modern — energy orb'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(
          of: row.first,
          matching: find.byIcon(Icons.radio_button_checked_rounded),
        ),
        findsOneWidget,
      );
    },
  );
}
