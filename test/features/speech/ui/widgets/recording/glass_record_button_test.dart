import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_return.dart';
import 'package:lotti/features/speech/ui/widgets/recording/glass_record_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';

const _linkedId = 'entry-under-test';

AudioRecorderState _state({
  required AudioRecorderStatus status,
  String? linkedId,
}) => AudioRecorderState(
  status: status,
  progress: Duration.zero,
  dBFS: -160,
  inlineHostVisible: false,
  linkedId: linkedId,
);

/// A recorder controller the test drives by hand, so it can push a new state
/// and observe what the button does with it.
class _DrivenRecorderController extends AudioRecorderController {
  _DrivenRecorderController(this._initial);

  final AudioRecorderState _initial;

  @override
  AudioRecorderState build() => _initial;

  // ignore: use_setters_to_change_properties
  void emit(AudioRecorderState next) => state = next;
}

void main() {
  late _DrivenRecorderController controller;
  late int pressed;

  Future<void> pumpButton(
    WidgetTester tester, {
    AudioRecorderState? initial,
    MediaQueryData? mediaQueryData,
  }) async {
    controller = _DrivenRecorderController(
      initial ?? _state(status: AudioRecorderStatus.stopped),
    );
    pressed = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          child: GlassRecordButton(
            linkedId: _linkedId,
            onPressed: () => pressed++,
          ),
        ),
        mediaQueryData: mediaQueryData,
        overrides: [
          audioRecorderControllerProvider.overrideWith(() => controller),
        ],
      ),
    );
    await tester.pump();
  }

  double scale(WidgetTester tester) => tester
      .widget<ScaleTransition>(
        find.ancestor(
          of: find.byType(DsGlassRoundButton),
          matching: find.byType(ScaleTransition),
        ),
      )
      .scale
      .value;

  void arriveAt(WidgetTester tester, String subjectId) =>
      ProviderScope.containerOf(
        tester.element(find.byType(GlassRecordButton)),
      ).read(recordingArrivalProvider.notifier).arrive(subjectId);

  DsGlassRoundButton button(WidgetTester tester) =>
      tester.widget<DsGlassRoundButton>(find.byType(DsGlassRoundButton));

  DsTokens tokens(WidgetTester tester) =>
      tester.element(find.byType(GlassRecordButton)).designTokens;

  testWidgets('idle: the mic wears the accent as a ring and as its glyph ink', (
    tester,
  ) async {
    await pumpButton(tester);

    final mic = button(tester);
    expect(mic.icon, LottiIcons.mic);
    expect(mic.backgroundColor, isNull);
    expect(mic.outlineColor, tokens(tester).colors.interactive.enabled);
    expect(mic.iconColor, tokens(tester).colors.interactive.enabled);
    expect(find.bySemanticsLabel('Record a voice note'), findsOneWidget);
  });

  testWidgets(
    'recording for the linked id: alert fill, white glyph, no ring, and the '
    'in-progress announcement',
    (tester) async {
      await pumpButton(
        tester,
        initial: _state(
          status: AudioRecorderStatus.recording,
          linkedId: _linkedId,
        ),
      );

      final mic = button(tester);
      expect(
        mic.backgroundColor,
        tokens(tester).colors.alert.error.defaultColor,
      );
      expect(mic.iconColor, Colors.white);
      expect(mic.outlineColor, isNull);
      expect(
        find.bySemanticsLabel('Audio recording in progress'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Record a voice note'), findsNothing);
    },
  );

  testWidgets('a paused session for the linked id still counts as active', (
    tester,
  ) async {
    await pumpButton(
      tester,
      initial: _state(
        status: AudioRecorderStatus.paused,
        linkedId: _linkedId,
      ),
    );

    expect(
      button(tester).backgroundColor,
      tokens(tester).colors.alert.error.defaultColor,
    );
  });

  testWidgets('a recording linked elsewhere leaves the mic idle', (
    tester,
  ) async {
    await pumpButton(
      tester,
      initial: _state(
        status: AudioRecorderStatus.recording,
        linkedId: 'someone-else',
      ),
    );

    expect(button(tester).backgroundColor, isNull);
    expect(find.bySemanticsLabel('Record a voice note'), findsOneWidget);
  });

  testWidgets('a stopped session for the linked id leaves the mic idle', (
    tester,
  ) async {
    await pumpButton(
      tester,
      initial: _state(
        status: AudioRecorderStatus.stopped,
        linkedId: _linkedId,
      ),
    );

    expect(button(tester).backgroundColor, isNull);
  });

  testWidgets('follows the session as it starts and stops', (tester) async {
    await pumpButton(tester);
    expect(button(tester).backgroundColor, isNull);

    controller.emit(
      _state(status: AudioRecorderStatus.recording, linkedId: _linkedId),
    );
    await tester.pump();
    expect(
      button(tester).backgroundColor,
      tokens(tester).colors.alert.error.defaultColor,
    );

    controller.emit(
      _state(status: AudioRecorderStatus.stopped, linkedId: _linkedId),
    );
    await tester.pump();
    expect(button(tester).backgroundColor, isNull);
  });

  testWidgets(
    'level updates during a recording do not rebuild the button; a change of '
    'session does',
    (tester) async {
      await pumpButton(
        tester,
        initial: _state(
          status: AudioRecorderStatus.recording,
          linkedId: _linkedId,
        ),
      );
      final element = tester.element(find.byType(GlassRecordButton));
      expect(element.dirty, isFalse);

      // The VU meter ticks: same session, new level. The selector reports
      // the same boolean, so the button is not marked for rebuild.
      controller.emit(
        _state(
          status: AudioRecorderStatus.recording,
          linkedId: _linkedId,
        ),
      );
      expect(element.dirty, isFalse);

      // The session ends: the boolean flips and the button rebuilds.
      controller.emit(
        _state(status: AudioRecorderStatus.stopped, linkedId: _linkedId),
      );
      expect(element.dirty, isTrue);
      await tester.pump();
      expect(button(tester).backgroundColor, isNull);
    },
  );

  testWidgets('tapping fires onPressed', (tester) async {
    await pumpButton(tester);

    await tester.tap(find.byType(GlassRecordButton));
    await tester.pump();

    expect(pressed, 1);
  });

  group('arriving back from the recording strip', () {
    testWidgets('swells once and settles for its own subject', (tester) async {
      await pumpButton(tester);
      expect(scale(tester), 1);

      arriveAt(tester, _linkedId);
      await tester.pump();
      await tester.pump(GlassRecordButton.arrivalDuration ~/ 2);
      expect(scale(tester), greaterThan(1));

      await tester.pump(GlassRecordButton.arrivalDuration);
      expect(scale(tester), 1);
    });

    testWidgets('swells again on a second arrival', (tester) async {
      await pumpButton(tester);
      arriveAt(tester, _linkedId);
      await tester.pump();
      await tester.pump(GlassRecordButton.arrivalDuration);

      arriveAt(tester, _linkedId);
      await tester.pump();
      await tester.pump(GlassRecordButton.arrivalDuration ~/ 2);
      expect(scale(tester), greaterThan(1));
      await tester.pump(GlassRecordButton.arrivalDuration);
    });

    testWidgets("stays still for another subject's arrival", (tester) async {
      await pumpButton(tester);
      arriveAt(tester, 'another-entry');
      await tester.pump();
      await tester.pump(GlassRecordButton.arrivalDuration ~/ 2);
      expect(scale(tester), 1);
    });

    testWidgets('stays still under reduced motion', (tester) async {
      await pumpButton(
        tester,
        mediaQueryData: const MediaQueryData(disableAnimations: true),
      );
      arriveAt(tester, _linkedId);
      await tester.pump();
      await tester.pump(GlassRecordButton.arrivalDuration ~/ 2);
      expect(scale(tester), 1);
    });
  });
}
