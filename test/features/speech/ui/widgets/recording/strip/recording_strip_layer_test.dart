import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_homes.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
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

    test("a take whose subject's home is on screen — its task's action "
        'bar — shows nothing, from its first frame', () async {
      container.read(recordingHomesProvider.notifier).enter('task-1');
      await recorder.record(linkedId: 'task-1');
      expect(content(), RecordingStripContent.none);
      container.read(recordingHomesProvider.notifier).leave('task-1');
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

    test("while a take saves, the strip's place is held", () async {
      await recorder.record(linkedId: 'task-1');
      await recorder.stop();
      container.read(recordingSavingProvider.notifier).saving = true;
      expect(content(), RecordingStripContent.saving);
      container.read(recordingSavingProvider.notifier).saving = false;
      expect(content(), RecordingStripContent.none);
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
      bool showsTake = true,
    }) => bench.pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?above,
          RecordingStripLayer(showsTake: showsTake),
        ],
      ),
      mediaQueryData: mediaQueryData,
    );

    Finder layer() => find.byType(RecordingStripLayer);

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

    testWidgets('Stop replaces the strip with the receipt, a card above the '
        'bottom edge; the receipt goes when its window does', (tester) async {
      await pump(tester);
      await bench.startTake(tester);
      // Taps land once the strip has fully risen.
      await settleSwitch(tester);
      expect(
        tester.getBottomLeft(strip()).dy,
        tester.getBottomLeft(layer()).dy,
      );

      await tester.tap(find.byKey(RecordingStrip.stopKey));
      await tester.pump();
      await tester.pump();
      await settleSwitch(tester);
      expect(find.byType(RecordingReceiptRow), findsOneWidget);
      expect(strip(), findsNothing);
      final context = tester.element(layer());
      final receipt = tester.getRect(find.byType(RecordingReceiptRow));
      expect(
        receipt.bottom,
        tester.getRect(layer()).bottom -
            RecordingStripLayer.bottomOffset(context),
      );
      expect(
        receipt.left,
        tester.getRect(layer()).left + context.designTokens.spacing.step5,
      );

      await tester.pump(recordingReceiptWindow);
      await settleSwitch(tester);
      expect(find.byType(RecordingReceiptRow), findsNothing);
    });

    testWidgets("while a take saves, empty glass holds the strip's whole "
        'place and takes no tap', (tester) async {
      await pump(tester);
      container(tester).read(recordingSavingProvider.notifier).saving = true;
      await tester.pump();
      await settleSwitch(tester);

      final held = find.byKey(const ValueKey('recording-strip-content-saving'));
      expect(held, findsOneWidget);
      expect(tester.widget<AbsorbPointer>(held).absorbing, isTrue);
      final context = tester.element(held);
      expect(tester.getSize(held).height, RecordingStrip.extent(context));
      expect(
        find.descendant(
          of: held,
          matching: find.byType(DesignSystemGlassStrip),
        ),
        findsOneWidget,
      );
      container(tester).read(recordingSavingProvider.notifier).saving = false;
    });

    testWidgets('a swipe up on the strip opens the tray in its place', (
      tester,
    ) async {
      await pump(tester);
      await bench.startTake(tester);
      await settleSwitch(tester);
      await tester.fling(strip(), const Offset(0, -80), 800);
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
      // The strip has no words of its own; the tray opened from it does.
      container(tester).read(recordingTrayControllerProvider.notifier).open();
      await settleSwitch(tester);

      final caption = tester.element(find.text(stripSubject.data.title));
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

    testWidgets('the strip runs edge to edge on a wide window; the tray is '
        'a card at the prose measure, centred', (tester) async {
      await pump(tester, mediaQueryData: desktopLayoutMediaQueryData);
      await bench.startTake(tester);
      await settleSwitch(tester);
      final width = desktopLayoutMediaQueryData.size.width;
      expect(tester.getSize(strip()).width, width);

      container(tester).read(recordingTrayControllerProvider.notifier).open();
      await tester.pump();
      await settleSwitch(tester);
      final tray = find.byType(RecordingStripTray);
      expect(tester.getSize(tray).width, kProseMeasureWidth);
      expect(tester.getCenter(tray).dx, width / 2);
    });

    group('handing the take to someone else (showsTake false)', () {
      testWidgets('draws no strip while a take runs', (tester) async {
        await pump(tester, showsTake: false);
        await bench.startTake(tester);
        await settleSwitch(tester);
        expect(strip(), findsNothing);
        expect(tester.getSize(layer()).height, 0);
      });

      testWidgets('nor the held place while a take saves', (tester) async {
        await pump(tester, showsTake: false);
        container(tester).read(recordingSavingProvider.notifier).saving = true;
        await tester.pump();
        await settleSwitch(tester);
        expect(
          find.byKey(const ValueKey('recording-strip-content-saving')),
          findsNothing,
        );
        container(tester).read(recordingSavingProvider.notifier).saving = false;
      });

      testWidgets('still opens the tray over the take', (tester) async {
        await pump(tester, showsTake: false);
        await bench.startTake(tester);
        container(tester).read(recordingTrayControllerProvider.notifier).open();
        await tester.pump();
        await settleSwitch(tester);
        expect(find.byType(RecordingStripTray), findsOneWidget);
      });

      testWidgets("still puts up a stopped take's receipt", (tester) async {
        await pump(tester, showsTake: false);
        await bench.startTake(tester);
        await container(tester).read(recordingSessionProvider).stop();
        await tester.pump();
        await settleSwitch(tester);
        expect(find.byType(RecordingReceiptRow), findsOneWidget);
        container(
          tester,
        ).read(recordingReceiptControllerProvider.notifier).commit();
      });
    });

    test('visible() drops only the strip and its held place, and only when '
        'the take is shown elsewhere', () {
      for (final content in RecordingStripContent.values) {
        expect(
          RecordingStripLayer.visible(content, showsTake: true),
          content,
        );
      }
      expect(
        RecordingStripLayer.visible(
          RecordingStripContent.strip,
          showsTake: false,
        ),
        RecordingStripContent.none,
      );
      expect(
        RecordingStripLayer.visible(
          RecordingStripContent.saving,
          showsTake: false,
        ),
        RecordingStripContent.none,
      );
      for (final content in [
        RecordingStripContent.none,
        RecordingStripContent.tray,
        RecordingStripContent.receipt,
      ]) {
        expect(
          RecordingStripLayer.visible(content, showsTake: false),
          content,
        );
      }
    });

    testWidgets("lift is nothing for nothing; the strip's whole extent for "
        'the strip and its held place; a card, its gap and its offset from '
        'the edge for the tray and the receipt', (tester) async {
      await pump(
        tester,
        mediaQueryData: phoneMediaQueryData.copyWith(
          padding: const EdgeInsets.only(bottom: 34),
        ),
      );
      final context = tester.element(layer());
      expect(
        RecordingStripLayer.lift(context, RecordingStripContent.none),
        0,
      );
      for (final content in [
        RecordingStripContent.strip,
        RecordingStripContent.saving,
      ]) {
        expect(
          RecordingStripLayer.lift(context, content),
          RecordingStrip.extent(context),
        );
      }
      final card =
          RecordingStripLayer.bottomOffset(context) +
          RecordingStrip.height(context) +
          RecordingStripLayer.gap(context);
      for (final content in [
        RecordingStripContent.tray,
        RecordingStripContent.receipt,
      ]) {
        expect(RecordingStripLayer.lift(context, content), card);
      }
    });

    testWidgets('bottomOffset is the safe area, never less than a step3 '
        'off the edge', (tester) async {
      await pump(
        tester,
        mediaQueryData: phoneMediaQueryData.copyWith(padding: EdgeInsets.zero),
      );
      var context = tester.element(layer());
      expect(
        RecordingStripLayer.bottomOffset(context),
        context.designTokens.spacing.step3,
      );
      await pump(
        tester,
        mediaQueryData: phoneMediaQueryData.copyWith(
          padding: const EdgeInsets.only(bottom: 34),
        ),
      );
      context = tester.element(layer());
      expect(RecordingStripLayer.bottomOffset(context), 34);
    });
  });
}
