import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recording_start_guard.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_failure_callout.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  var settingsOpened = 0;
  var stopsAsked = 0;
  setUp(() {
    settingsOpened = 0;
    stopsAsked = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    InlineRecordingFailure failure, {
    bool stopping = false,
    String? Function(InlineRecordingFailure failure)? bodyOf,
    Widget? leadingAction,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      RecordingFailureCallout(
        failure: failure,
        stopping: stopping,
        onOpenSettings: () => settingsOpened++,
        onStopRunning: () => stopsAsked++,
        bodyOf: bodyOf,
        leadingAction: leadingAction,
      ),
    ),
  );

  Finder key(Key key) => find.byKey(key);

  for (final (failure, title, body, icon, warning) in [
    (
      InlineRecordingFailure.microphoneDenied,
      'Allow microphone access',
      "Lotti can't use the microphone. Enable microphone access for Lotti "
          'in your system settings.',
      LottiIcons.micIdle,
      false,
    ),
    (
      InlineRecordingFailure.startFailed,
      "Recording didn't start",
      'Recording failed. Please try again.',
      LottiIcons.micIdle,
      false,
    ),
    (
      InlineRecordingFailure.recorderBusy,
      'A recording is already running',
      'Stop it here and it is saved where it was started. Then you can '
          'speak.',
      // The microphone is fine — it is in use: a caution, not an error.
      LottiIcons.mic,
      true,
    ),
    (
      InlineRecordingFailure.notSaved,
      "Recording couldn't be saved",
      'Recording failed. Please try again.',
      LottiIcons.micIdle,
      false,
    ),
  ]) {
    testWidgets('${failure.name}: its reason in plain words, announced, in '
        'the right tone', (tester) async {
      await pump(tester, failure);

      expect(find.text(title), findsOneWidget);
      expect(find.text(body), findsOneWidget);
      final callout = tester.widget<DesignSystemInlineCallout>(
        key(ValueKey('recording-failure-${failure.name}')),
      );
      final alert = tester
          .element(find.byType(RecordingFailureCallout))
          .designTokens
          .colors
          .alert;
      expect(callout.icon, icon);
      expect(
        callout.tone,
        warning ? alert.warning.defaultColor : alert.error.defaultColor,
      );
      expect(callout.announce, isTrue);
      // Each door only where it leads somewhere.
      expect(
        key(RecordingFailureCallout.openSettingsKey),
        failure == InlineRecordingFailure.microphoneDenied
            ? findsOneWidget
            : findsNothing,
      );
      expect(
        key(RecordingFailureCallout.stopRunningKey),
        failure == InlineRecordingFailure.recorderBusy
            ? findsOneWidget
            : findsNothing,
      );
    });
  }

  testWidgets('Open settings and Stop that recording reach the host', (
    tester,
  ) async {
    await pump(tester, InlineRecordingFailure.microphoneDenied);
    await tester.tap(key(RecordingFailureCallout.openSettingsKey));
    expect(settingsOpened, 1);

    await pump(tester, InlineRecordingFailure.recorderBusy);
    await tester.tap(key(RecordingFailureCallout.stopRunningKey));
    expect(stopsAsked, 1);
  });

  testWidgets('while the running take is being stopped, the button says so '
      'and takes no second tap', (tester) async {
    await pump(tester, InlineRecordingFailure.recorderBusy, stopping: true);

    expect(
      tester
          .widget<DesignSystemButton>(
            key(RecordingFailureCallout.stopRunningKey),
          )
          .isLoading,
      isTrue,
    );
    await tester.tap(
      key(RecordingFailureCallout.stopRunningKey),
      warnIfMissed: false,
    );
    expect(stopsAsked, 0);
  });

  testWidgets("a host's own words replace the recorder's where it has any, "
      'and its own way forward leads the actions', (tester) async {
    await pump(
      tester,
      InlineRecordingFailure.microphoneDenied,
      bodyOf: (failure) => failure == InlineRecordingFailure.microphoneDenied
          ? 'Turn it on, then tap Speak.'
          : null,
      leadingAction: const Text('Write instead'),
    );
    expect(find.text('Turn it on, then tap Speak.'), findsOneWidget);
    expect(find.textContaining("Lotti can't use"), findsNothing);
    expect(
      tester.getRect(find.text('Write instead')).left,
      lessThan(
        tester.getRect(key(RecordingFailureCallout.openSettingsKey)).left,
      ),
    );

    // Where the host has no words of its own, the recorder's stand.
    await pump(
      tester,
      InlineRecordingFailure.recorderBusy,
      bodyOf: (failure) => null,
    );
    expect(find.textContaining('Stop it here'), findsOneWidget);
  });
}
