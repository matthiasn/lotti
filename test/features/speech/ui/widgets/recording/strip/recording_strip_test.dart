import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_timer_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_leading.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../widget_test_utils.dart';
import 'strip_test_bench.dart';

void main() {
  late StripBench bench;

  setUp(() => bench = StripBench());
  tearDown(() => bench.dispose());

  Future<void> pump(
    WidgetTester tester, {
    // The full phone width: the test font's digits are far wider than
    // Inter's, so a narrower row already gives the bars up.
    double width = 390,
    MediaQueryData mediaQueryData = phoneMediaQueryData,
  }) async {
    await bench.pump(
      tester,
      // A runtime key, so the constructor runs rather than being a constant.
      SizedBox(
        width: width,
        child: RecordingStrip(key: UniqueKey()),
      ),
      mediaQueryData: mediaQueryData,
    );
    await bench.startTake(tester);
  }

  Finder strip() => find.byKey(RecordingStrip.stripKey);
  Finder stop() => find.byKey(RecordingStrip.stopKey);
  Finder pause() => find.byKey(RecordingStrip.pauseKey);
  Finder bars() => find.byKey(RecordingStrip.barsKey);

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(strip()));

  group('height', () {
    testWidgets('is 56 at the default text size: the controls with a step '
        'of air above and below', (tester) async {
      await pump(tester);
      expect(tester.getSize(strip()).height, 56);
    });

    testWidgets('grows with the text size, as the receipt it turns into '
        'does, and stays one capsule row', (tester) async {
      await pump(
        tester,
        mediaQueryData: phoneMediaQueryData.copyWith(
          textScaler: const TextScaler.linear(2),
        ),
      );
      final context = tester.element(strip());
      final tokens = context.designTokens;
      final lines = tokens.typography.lineHeight;
      final height =
          math.max(
            tokens.spacing.step9,
            lines.caption * 2 + lines.bodySmall * 2,
          ) +
          tokens.spacing.step2 * 2;
      expect(tester.getSize(strip()).height, height);
      expect(
        tester.getCenter(find.byType(RecordingStripLeading)).dy,
        closeTo(tester.getCenter(stop()).dy, 0.5),
      );
      final fill = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: strip(), matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(fill.borderRadius, BorderRadius.circular(height / 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('the bars', () {
    testWidgets("draw the recorder's level line over all the room between "
        'the way back and pause', (tester) async {
      await pump(tester);
      final context = tester.element(strip());
      final gap = context.designTokens.spacing.step3;
      final level = tester.getRect(bars());
      expect(
        level.left,
        tester.getRect(find.byType(RecordingStripLeading)).right + gap,
      );
      expect(level.right, tester.getRect(pause()).left - gap);
      expect(
        tester
            .getSize(
              find.descendant(
                of: bars(),
                matching: find.byType(RecordingLevelLine),
              ),
            )
            .width,
        level.width,
      );
    });

    testWidgets('stay, held still, while the take is paused', (tester) async {
      await pump(tester);
      await tester.tap(pause());
      await tester.pump();
      expect(bars(), findsOneWidget);
    });

    testWidgets('keep a row on the narrowest phone whole', (tester) async {
      await pump(tester, width: 300);
      expect(bars(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets("no words on the row: the subject's title is what a screen "
      'reader hears for the way back', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text(stripSubject.data.title), findsNothing);
    expect(find.text('Recording for'), findsNothing);
    expect(
      find.bySemanticsLabel('Back to ${stripSubject.data.title}'),
      findsOneWidget,
    );
  });

  testWidgets('a level tick and a sub-second tick never rebuild the row; a '
      'new second does', (tester) async {
    await pump(tester);
    final before = tester.widget(stop());

    bench.recorder.tick(
      progress: const Duration(milliseconds: 480),
      dBFS: -12,
    );
    await tester.pump();
    expect(identical(tester.widget(stop()), before), isTrue);

    bench.recorder.tick(progress: const Duration(seconds: 1), dBFS: -20);
    await tester.pump();
    expect(identical(tester.widget(stop()), before), isFalse);
    expect(find.text('00:01'), findsOneWidget);
  });

  group('pause', () {
    testWidgets('pauses the take, and resumes it', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      expect(tester.getSemantics(pause()).label, 'Pause');

      await tester.tap(pause());
      await tester.pump();
      expect(bench.recorder.pauseCalls, 1);
      expect(tester.getSemantics(pause()).label, 'Resume');

      await tester.tap(pause());
      await tester.pump();
      expect(bench.recorder.resumeCalls, 1);
      semantics.dispose();
    });

    testWidgets('while paused, resume is the filled accent disc', (
      tester,
    ) async {
      await pump(tester);
      RecordingRingButton ring() => tester.widget(pause());
      expect(ring().emphasized, isFalse);
      await tester.tap(pause());
      await tester.pump();
      expect(ring().emphasized, isTrue);
    });

    testWidgets('greys Stop while paused, the time held', (tester) async {
      await pump(tester);
      bench.recorder.tick(progress: const Duration(seconds: 7));
      await tester.pump();
      DesignSystemTimerPill pill() => tester.widget(
        find.descendant(
          of: stop(),
          matching: find.byType(DesignSystemTimerPill),
        ),
      );
      expect(pill().paused, isFalse);

      await tester.tap(pause());
      await tester.pump();
      expect(pill().paused, isTrue);
      expect(pill().label, '00:07');
    });
  });

  testWidgets('Stop saves the take and puts up its receipt', (tester) async {
    await pump(tester);
    await tester.tap(stop());
    await tester.pump();
    await tester.pump();

    expect(bench.recorder.stopDeferrals, [true]);
    final receipt = containerOf(
      tester,
    ).read(recordingReceiptControllerProvider);
    expect(receipt?.entryId, 'audio-1');
    // Commit it so no timer outlives the test.
    containerOf(
      tester,
    ).read(recordingReceiptControllerProvider.notifier).commit();
  });

  testWidgets('Stop is one button named Stop whose value is the time in '
      'words', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    bench.recorder.tick(progress: const Duration(seconds: 23));
    await tester.pump();

    final node = tester.getSemantics(stop());
    expect(node.label, 'Stop');
    expect(node.value, '23 seconds');
    semantics.dispose();
  });

  group('the tray', () {
    testWidgets('opens on a tap on the body, outside the buttons', (
      tester,
    ) async {
      await pump(
        tester,
        width: 600,
        mediaQueryData: desktopLayoutMediaQueryData,
      );
      // The bars take no tap of their own: the body's.
      await tester.tap(bars());
      await tester.pump();
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isTrue,
      );
    });

    testWidgets('opens on a swipe up', (tester) async {
      await pump(tester);
      await tester.fling(strip(), const Offset(0, -80), 800);
      await tester.pump();
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isTrue,
      );
    });

    testWidgets('stays folded on a swipe down', (tester) async {
      await pump(tester);
      await tester.fling(strip(), const Offset(0, 80), 800);
      await tester.pump();
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isFalse,
      );
    });

    testWidgets('the way back is the arrow alone, a full tap target; a tap '
        'on the level opens the tray instead of going back', (tester) async {
      await pump(tester);
      final back = tester.getSize(find.byKey(RecordingStripLeading.backKey));
      final step9 = tester.element(strip()).designTokens.spacing.step9;
      expect(back, Size.square(step9));

      await tester.tap(bars());
      await tester.pump();
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isTrue,
      );
      verifyNever(() => bench.nav.beamToNamed(any()));
    });

    testWidgets('a tap on pause does not open it', (tester) async {
      await pump(tester);
      await tester.tap(pause());
      await tester.pump();
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isFalse,
      );
    });

    testWidgets('the body tells a screen reader it opens the recorder', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.descendant(
          of: strip(),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.hintOverrides?.onTapHint == 'Open recorder',
          ),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('a screen reader meets the leading part, then pause, then '
      'Stop', (tester) async {
    await pump(tester);
    final leading = tester.getCenter(find.byType(RecordingStripLeading)).dx;
    expect(leading, lessThan(tester.getCenter(pause()).dx));
    expect(tester.getCenter(pause()).dx, lessThan(tester.getCenter(stop()).dx));
  });

  group('surface', () {
    testWidgets("wears the island's glass as a full capsule", (
      tester,
    ) async {
      await pump(tester);
      final fill = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: strip(), matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(
        fill.borderRadius,
        BorderRadius.circular(tester.getSize(strip()).height / 2),
      );
    });
  });
}
