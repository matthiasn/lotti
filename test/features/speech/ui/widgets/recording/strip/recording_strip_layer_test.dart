import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/state/recording_start_guard.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_receipt.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_layer.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_tray.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../widget_test_utils.dart';
import '../../../../../relationships/helpers/check_in_speech_fakes.dart';
import 'strip_test_bench.dart';

/// A recorder whose audio stack failed to load.
class _BrokenRecorder extends FakeAudioRecorderController {
  @override
  AudioRecorderState build() => throw StateError('no audio stack');
}

void main() {
  group('recordingStripContentProvider', () {
    late FakeAudioRecorderController recorder;
    late ProviderContainer container;

    setUp(() {
      recorder = FakeAudioRecorderController();
      // Built up front, as the shell builds it, so the fake can record.
      container = ProviderContainer(
        overrides: [
          audioRecorderControllerProvider.overrideWith(() => recorder),
        ],
      )..read(audioRecorderControllerProvider);
    });
    tearDown(() => container.dispose());

    RecordingStripContent content() =>
        container.read(recordingStripContentProvider);
    RecordingTrayController tray() =>
        container.read(recordingTrayControllerProvider.notifier);

    test('nothing recording, nothing saved: nothing', () {
      expect(content(), RecordingStripContent.none);
    });

    test('a running take: the strip', () async {
      await recorder.record(linkedId: 'task-1');
      expect(content(), RecordingStripContent.strip);
    });

    test('a paused take: still the strip', () async {
      await recorder.record(linkedId: 'task-1');
      await recorder.pause();
      expect(content(), RecordingStripContent.strip);
    });

    test('a take a check-in screen draws in place: nothing, until the '
        'screen closes', () async {
      await recorder.record(linkedId: 'task-1');
      recorder.setInlineHostVisible(visible: true);
      expect(content(), RecordingStripContent.none);
      recorder.setInlineHostVisible(visible: false);
      expect(content(), RecordingStripContent.strip);
    });

    test('the tray open over a take: the tray', () async {
      await recorder.record(linkedId: 'task-1');
      tray().open();
      expect(content(), RecordingStripContent.tray);
    });

    test('the tray open with no take and no failure: nothing to show', () {
      tray().open();
      expect(content(), RecordingStripContent.none);
    });

    test('the tray opened for a failure: the tray, with no take', () {
      tray().openWithFailure(InlineRecordingFailure.microphoneDenied);
      expect(content(), RecordingStripContent.tray);
    });

    test('a receipt wins over everything while it lasts', () async {
      await recorder.record(linkedId: 'task-1');
      tray().open();
      container
          .read(recordingReceiptControllerProvider.notifier)
          .show(entryId: 'audio-1', duration: Duration.zero);
      expect(content(), RecordingStripContent.receipt);
      container.read(recordingReceiptControllerProvider.notifier).commit();
      expect(content(), RecordingStripContent.tray);
    });

    test('a recorder that cannot be built shows nothing rather than '
        'failing', () {
      final broken = ProviderContainer(
        overrides: [
          audioRecorderControllerProvider.overrideWith(_BrokenRecorder.new),
        ],
      );
      addTearDown(broken.dispose);
      expect(
        broken.read(recordingStripContentProvider),
        RecordingStripContent.none,
      );
    });
  });

  group('RecordingStripLayer', () {
    late StripBench bench;

    setUp(() => bench = StripBench());
    tearDown(() => bench.dispose());

    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(RecordingStripLayer)),
        );

    Future<void> pump(
      WidgetTester tester, {
      MediaQueryData mediaQueryData = phoneMediaQueryData,
      Widget? above,
    }) => bench.pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [?above, const RecordingStripLayer()],
      ),
      mediaQueryData: mediaQueryData,
    );

    Finder strip() => find.byType(RecordingStrip);

    /// Lets the switch between two contents run out: the new one in, the
    /// old one gone.
    Future<void> settleSwitch(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(RecordingStripLayer.motion);
      }
    }

    testWidgets('shows nothing while nothing records', (tester) async {
      await pump(tester);
      expect(strip(), findsNothing);
      expect(find.byType(RecordingStripTray), findsNothing);
      expect(find.byType(RecordingReceiptRow), findsNothing);
    });

    testWidgets('a take rises into the strip, the motion taking its tokens '
        'time', (tester) async {
      await pump(tester);
      await bench.startTake(tester);
      expect(strip(), findsOneWidget);

      final opacity = tester.widget<FadeTransition>(
        find.ancestor(of: strip(), matching: find.byType(FadeTransition)).first,
      );
      expect(opacity.opacity.value, lessThan(1));
      await tester.pump(RecordingStripLayer.motion);
      expect(opacity.opacity.value, 1);
    });

    testWidgets('under reduced motion it appears at once', (tester) async {
      await pump(
        tester,
        mediaQueryData: phoneMediaQueryData.copyWith(disableAnimations: true),
      );
      await bench.startTake(tester);

      final opacity = tester.widget<FadeTransition>(
        find.ancestor(of: strip(), matching: find.byType(FadeTransition)).first,
      );
      expect(opacity.opacity.value, 1);
    });

    testWidgets('Stop replaces the strip with the receipt in place; the '
        'receipt goes when its window does', (tester) async {
      await pump(tester);
      await bench.startTake(tester);
      await tester.pump(RecordingStripLayer.motion);
      final stripBottom = tester.getBottomLeft(strip());

      await tester.tap(find.byKey(RecordingStrip.stopKey));
      await tester.pump();
      await tester.pump();
      await settleSwitch(tester);
      expect(find.byType(RecordingReceiptRow), findsOneWidget);
      expect(strip(), findsNothing);
      expect(
        tester.getBottomLeft(find.byType(RecordingReceiptRow)),
        stripBottom,
      );

      await tester.pump(recordingReceiptWindow);
      await settleSwitch(tester);
      expect(find.byType(RecordingReceiptRow), findsNothing);
    });

    testWidgets('tapping the strip opens the tray in its place', (
      tester,
    ) async {
      await pump(tester);
      await bench.startTake(tester);
      await tester.pump(RecordingStripLayer.motion);
      await tester.tap(find.byKey(RecordingStrip.barsKey));
      await tester.pump();
      await settleSwitch(tester);

      expect(find.byType(RecordingStripTray), findsOneWidget);
      expect(strip(), findsNothing);
    });

    testWidgets('the tray folds when a text field takes the focus', (
      tester,
    ) async {
      await pump(tester, above: const SizedBox(width: 200, child: TextField()));
      await bench.startTake(tester);
      container(tester).read(recordingTrayControllerProvider.notifier).open();
      await tester.pump();

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(
        container(tester).read(recordingTrayControllerProvider).open,
        isFalse,
      );
    });

    testWidgets('focus elsewhere leaves the tray open', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pump(
        tester,
        above: Focus(focusNode: node, child: const SizedBox(height: 10)),
      );
      await bench.startTake(tester);
      container(tester).read(recordingTrayControllerProvider.notifier).open();
      await tester.pump();

      node.requestFocus();
      await tester.pump();

      expect(
        container(tester).read(recordingTrayControllerProvider).open,
        isTrue,
      );
    });

    testWidgets('brings its own Material: above the Scaffold, its words '
        'never fall back to the debug underline', (tester) async {
      // No Material above it, as where the shell puts it.
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Align(
            alignment: Alignment.bottomCenter,
            child: RecordingStripLayer(),
          ),
          mediaQueryData: phoneMediaQueryData,
          overrides: bench.overrides,
        ),
      );
      await tester.pump();
      await bench.startTake(tester);
      await settleSwitch(tester);

      final caption = tester.element(find.text('Recording for'));
      expect(
        DefaultTextStyle.of(caption).style.decoration,
        isNot(
          TextDecoration.underline,
        ),
      );
      expect(
        tester.widget<Material>(find.byKey(RecordingStripLayer.layerKey)).type,
        MaterialType.transparency,
      );
    });

    testWidgets('caps itself at the prose measure on a wide window, centred', (
      tester,
    ) async {
      await pump(tester, mediaQueryData: desktopLayoutMediaQueryData);
      await bench.startTake(tester);
      expect(tester.getSize(strip()).width, kProseMeasureWidth);
      expect(
        tester.getCenter(strip()).dx,
        desktopLayoutMediaQueryData.size.width / 2,
      );
    });

    testWidgets('reservedHeight is the strip and its gap while it shows '
        'anything, and nothing otherwise', (tester) async {
      await pump(tester);
      final context = tester.element(find.byType(RecordingStripLayer));
      final strip =
          RecordingStrip.height(context) + RecordingStripLayer.gap(context);
      expect(
        RecordingStripLayer.reservedHeight(
          context,
          RecordingStripContent.none,
        ),
        0,
      );
      for (final content in [
        RecordingStripContent.strip,
        RecordingStripContent.tray,
        RecordingStripContent.receipt,
      ]) {
        expect(RecordingStripLayer.reservedHeight(context, content), strip);
      }
    });
  });
}
