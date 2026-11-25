import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recording_homes.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/action_bar_recording.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_layer.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';
import 'strip/strip_test_bench.dart';

const Key _micKey = ValueKey('test-mic');
const Key _trackKey = ValueKey('test-track');

/// A bar's actions as a task bar lays them out: a wide pill, the mic when
/// it is the bar's, and a round button.
Widget actions(BuildContext context, Widget? mic) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    const SizedBox(key: _trackKey, width: 120, height: 48),
    ?mic,
    const SizedBox(width: 48, height: 48),
  ],
);

/// Actions that never place the mic.
Widget noMic(BuildContext context, Widget? mic) =>
    const SizedBox(key: _trackKey, width: 120, height: 48);

void main() {
  late StripBench bench;

  setUp(() => bench = StripBench(route: stripSubjectRoute));
  tearDown(() => bench.dispose());

  Widget bar({
    String? linkedId,
    Key? key,
    ActionBarActionsBuilder builder = actions,
  }) => ActionBarRecording(
    key: key,
    linkedId: linkedId ?? stripSubjectId,
    route: stripSubjectRoute,
    mic: const SizedBox.square(key: _micKey, dimension: 48),
    actions: builder,
  );

  /// The bar over the strip's layer, as a task page sits over the shell;
  /// [showBar] false takes the page away.
  Widget host({
    String? linkedId,
    bool showBar = true,
    ActionBarActionsBuilder builder = actions,
  }) => SizedBox(
    width: 390,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBar) bar(linkedId: linkedId, builder: builder),
        const RecordingStripLayer(),
      ],
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    String? linkedId,
    MediaQueryData mediaQueryData = phoneMediaQueryData,
    ActionBarActionsBuilder builder = actions,
  }) => bench.pump(
    tester,
    host(linkedId: linkedId, builder: builder),
    mediaQueryData: mediaQueryData,
  );

  Finder band() => find.byKey(ActionBarRecording.bandKey);
  Finder mic() => find.byKey(_micKey);
  Finder stop() => find.byKey(ActionBarRecording.stopKey);
  Finder flight() => find.byKey(ActionBarRecording.flightKey);
  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(RecordingStripLayer)),
  );
  bool home(WidgetTester tester) => container(
    tester,
  ).read(recordingHomesProvider).containsKey(stripSubjectId);

  /// Lets a flight run out: a frame to lay out where it lands, one to
  /// launch, then frames until the disc has landed and cleared.
  Future<void> land(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 10 && flight().evaluate().isNotEmpty; i++) {
      await tester.pump(ActionBarRecording.flight ~/ 4);
    }
    await tester.pump();
  }

  group('at rest', () {
    testWidgets('the mic is among the actions, no row shows, and the page '
        "is its subject's home", (tester) async {
      await pump(tester);
      expect(mic(), findsOneWidget);
      expect(band(), findsNothing);
      expect(home(tester), isTrue);
    });
    testWidgets('with no navigation wired up — a story, a test bench — '
        "the bar counts as on screen: its subject's home, the mic in "
        'place', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Material(child: SizedBox(width: 390, child: bar())),
          overrides: [
            audioRecorderControllerProvider.overrideWith(() => bench.recorder),
          ],
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(mic(), findsOneWidget);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(ActionBarRecording)),
        ).read(recordingHomesProvider),
        {stripSubjectId: 1},
      );
    });
  });

  group("while this page's take runs", () {
    testWidgets('the mic leaves the actions for the row under them: the '
        'dot, the level, the time as words, pause and a round Stop', (
      tester,
    ) async {
      await pump(tester);
      await bench.startTake(tester);
      await land(tester);

      expect(mic(), findsNothing);
      expect(band(), findsOneWidget);
      expect(find.byType(RecordingStripBars), findsOneWidget);
      expect(find.byKey(ActionBarRecording.pauseKey), findsOneWidget);
      expect(tester.widget(stop()), isA<RecordingStopButton>());
      final time = find.byKey(ActionBarRecording.timeKey);
      expect(tester.widget<Text>(time).data, '00:00');
      // Left to right: the time, pause, then Stop at the row's end.
      expect(
        tester.getRect(time).right,
        lessThan(tester.getRect(find.byKey(ActionBarRecording.pauseKey)).left),
      );
      expect(
        tester.getRect(find.byKey(ActionBarRecording.pauseKey)).right,
        lessThan(tester.getRect(stop()).left),
      );
      expect(
        tester.getRect(band()).top,
        greaterThanOrEqualTo(tester.getRect(find.byKey(_trackKey)).bottom),
      );
    });

    testWidgets('the strip never shows the take, not even for a frame', (
      tester,
    ) async {
      await pump(tester);
      await bench.recorder.record(linkedId: stripSubjectId);
      await tester.pump();
      expect(find.byType(RecordingStrip), findsNothing);
      await land(tester);
      expect(find.byType(RecordingStrip), findsNothing);
    });

    testWidgets('the time follows the take in whole seconds; Stop carries '
        'it for a screen reader, the words only for the eye', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await bench.startTake(tester);
      await land(tester);
      bench.recorder.tick(progress: const Duration(seconds: 7));
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(ActionBarRecording.timeKey)).data,
        '00:07',
      );
      final node = tester.getSemantics(stop());
      expect(node.label, 'Stop');
      expect(node.value, '7 seconds');
      expect(find.bySemanticsLabel('00:07'), findsNothing);
      semantics.dispose();
    });

    testWidgets('Stop saves the take and puts up its receipt', (tester) async {
      await pump(tester);
      await bench.startTake(tester);
      await land(tester);
      await tester.tap(stop());
      await tester.pump();
      await tester.pump();

      expect(bench.recorder.stopDeferrals, [true]);
      final receipts = container(tester);
      expect(receipts.read(recordingReceiptControllerProvider), isNotNull);
      receipts.read(recordingReceiptControllerProvider.notifier).commit();
    });

    testWidgets('paused, Stop steps back to the neutral fill', (
      tester,
    ) async {
      await pump(tester);
      await bench.startTake(tester);
      await land(tester);
      await bench.recorder.pause();
      await tester.pump();
      expect(tester.widget<RecordingStopButton>(stop()).paused, isTrue);
    });
  });

  testWidgets("a take for another subject is not this bar's: the mic "
      'stays, no row, and the strip carries it', (tester) async {
    await pump(tester, linkedId: 'another-task');
    await bench.startTake(tester);
    await land(tester);

    expect(mic(), findsOneWidget);
    expect(band(), findsNothing);
    expect(find.byType(RecordingStrip), findsOneWidget);
  });

  testWidgets('a take for the task started on another page is not drawn '
      "until the task's page is on screen", (tester) async {
    bench.route = '/projects/p1';
    await pump(tester);
    await bench.startTake(tester);
    await land(tester);
    expect(band(), findsNothing);
    expect(home(tester), isFalse);
    expect(find.byType(RecordingStrip), findsOneWidget);
  });

  group('the flight', () {
    testWidgets('the mic flies from its place down into Stop, which shows '
        'once it lands', (tester) async {
      await pump(tester);
      final from = tester.getRect(mic());
      await bench.recorder.record(linkedId: stripSubjectId);
      // One frame lays the row out; the next launches from the mic.
      await tester.pump();
      await tester.pump();
      expect(flight(), findsOneWidget);
      // It leaves from the mic's place; the bar has grown upward by the
      // row since, so only across and in size is it where the mic was.
      expect(tester.getRect(flight()).left, from.left);
      expect(tester.getRect(flight()).size, from.size);
      expect(tester.widget<Opacity>(_opacityOver(stop())).opacity, 0);

      await tester.pump(ActionBarRecording.flight ~/ 2);
      final mid = tester.getRect(flight());
      final to = tester.getRect(stop());
      expect(mid.left, greaterThan(from.left));
      expect(mid.left, lessThan(to.left));
      expect(mid.top, greaterThan(tester.getRect(find.byKey(_trackKey)).top));

      await tester.pump(ActionBarRecording.flight);
      await tester.pump();
      expect(flight(), findsNothing);
      expect(tester.widget<Opacity>(_opacityOver(stop())).opacity, 1);
    });

    testWidgets('Stop flies back up into the mic when the take ends, the '
        'row staying until it has', (tester) async {
      await pump(tester);
      await bench.startTake(tester);
      await land(tester);
      final from = tester.getRect(stop());

      await bench.recorder.stop();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(flight(), findsOneWidget);
      expect(tester.getRect(flight()), from);
      expect(band(), findsOneWidget);
      expect(tester.widget<Opacity>(_opacityOver(mic())).opacity, 0);

      await tester.pump(ActionBarRecording.flight ~/ 3);
      final mid = tester.getRect(flight());
      expect(mid.left, lessThan(from.left));
      await tester.pump(ActionBarRecording.flight);
      await tester.pump();
      expect(flight(), findsNothing);
      expect(band(), findsNothing);
      expect(tester.widget<Opacity>(_opacityOver(mic())).opacity, 1);
    });

    testWidgets('does not fly under reduced motion', (tester) async {
      await pump(
        tester,
        mediaQueryData: phoneMediaQueryData.copyWith(disableAnimations: true),
      );
      await bench.startTake(tester);
      expect(flight(), findsNothing);
      expect(tester.widget<Opacity>(_opacityOver(stop())).opacity, 1);
    });

    testWidgets('does not fly where the bar has no mic to leave from or land '
        'on', (tester) async {
      await pump(tester, builder: noMic);
      await bench.startTake(tester);
      expect(flight(), findsNothing);
      expect(band(), findsOneWidget);

      await bench.recorder.stop();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(flight(), findsNothing);
      expect(band(), findsNothing);
    });
  });

  group("the subject's home", () {
    testWidgets('the page kept mounted behind another tab leaves it: the '
        'strip carries the take; back on the page, the row does', (
      tester,
    ) async {
      await pump(tester);
      await bench.startTake(tester);
      await land(tester);

      bench.route = '/calendar';
      await land(tester);
      expect(home(tester), isFalse);
      expect(band(), findsNothing);
      expect(find.byType(RecordingStrip), findsOneWidget);

      bench.route = stripSubjectRoute;
      await land(tester);
      expect(home(tester), isTrue);
      expect(band(), findsOneWidget);
    });

    testWidgets('a page closed mid-take hands the take to the strip', (
      tester,
    ) async {
      await pump(tester);
      await bench.startTake(tester);
      await land(tester);

      await bench.pump(tester, host(showBar: false));
      await tester.pump(RecordingStripLayer.motion);
      expect(tester.takeException(), isNull);
      expect(home(tester), isFalse);
      expect(find.byType(RecordingStrip), findsOneWidget);
    });

    testWidgets('one of two bars for the subject leaving keeps the home '
        'with the one that stays', (tester) async {
      Widget twoBars({required bool both}) => SizedBox(
        width: 390,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bar(key: const ValueKey('a')),
            if (both) bar(key: const ValueKey('b')),
            const RecordingStripLayer(),
          ],
        ),
      );
      await bench.pump(tester, twoBars(both: true));
      await bench.startTake(tester);
      await bench.pump(tester, twoBars(both: false));
      await tester.pump(RecordingStripLayer.motion);
      expect(home(tester), isTrue);
      expect(find.byType(RecordingStrip), findsNothing);
    });
  });
}

/// The [Opacity] right around [finder]'s widget.
Finder _opacityOver(Finder finder) =>
    find.ancestor(of: finder, matching: find.byType(Opacity)).first;
