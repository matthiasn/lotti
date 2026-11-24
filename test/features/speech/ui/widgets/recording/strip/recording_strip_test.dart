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

    testWidgets('grows with the text size, so the caption and the title '
        'never clip', (tester) async {
      await pump(
        tester,
        mediaQueryData: phoneMediaQueryData.copyWith(
          textScaler: const TextScaler.linear(2),
        ),
      );
      final context = tester.element(strip());
      final tokens = context.designTokens;
      final lines = tokens.typography.lineHeight;
      // Stacked: the subject's line over the controls' row.
      expect(RecordingStrip.stacked(context), isTrue);
      expect(
        tester.getSize(strip()).height,
        // The caption and the subject, never shorter than a tap target,
        // over the controls' row.
        math.max(
              tokens.spacing.step9,
              lines.caption * 2 + lines.bodySmall * 2,
            ) +
            tokens.spacing.step2 +
            tokens.spacing.step9 +
            tokens.spacing.step2 * 2,
      );
      expect(
        tester.getCenter(find.byType(RecordingStripLeading)).dy,
        lessThan(tester.getCenter(stop()).dy),
      );
      // Two rows are no capsule: the corners are the tray's.
      final fill = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: strip(), matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(fill.borderRadius, BorderRadius.circular(tokens.radii.xl));
      expect(tester.takeException(), isNull);
    });
  });

  group('the bars', () {
    testWidgets("draw the recorder's level line over a short stretch, where "
        "the subject's name keeps its room", (tester) async {
      await pump(
        tester,
        width: 600,
        mediaQueryData: desktopLayoutMediaQueryData,
      );
      final context = tester.element(strip());
      expect(
        tester.getSize(bars()).width,
        RecordingStrip.barsWidth(context),
      );
      expect(
        find.descendant(of: bars(), matching: find.byType(RecordingLevelLine)),
        findsOneWidget,
      );
    });

    testWidgets("give way on a row too narrow for the subject's name", (
      tester,
    ) async {
      await pump(tester, width: 300);
      expect(bars(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showsBars keeps them exactly while the leading part keeps '
        'step11 beside them', (tester) async {
      await pump(tester);
      final context = tester.element(strip());
      final spacing = context.designTokens.spacing;
      final controls =
          spacing.step9 +
          DesignSystemTimerPill.heldWidth(
            context,
            DesignSystemTimerPill.elapsedWidthTemplate,
          ) +
          spacing.step3 * 6;
      final leading = RecordingStripLeading.glyphSlot + spacing.step3 * 3;
      final boundary =
          controls +
          leading +
          RecordingStrip.barsWidth(context) +
          MediaQuery.textScalerOf(context).scale(spacing.step11);
      expect(RecordingStrip.showsBars(context, boundary), isTrue);
      expect(RecordingStrip.showsBars(context, boundary - 1), isFalse);
      expect(
        RecordingStrip.showsBars(context, boundary * 2, paused: true),
        isFalse,
      );
    });
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

    testWidgets('the way back is only as wide as its words: a tap beside '
        'them opens the tray instead of going back', (tester) async {
      when(() => bench.db.journalEntityById(stripSubjectId)).thenAnswer(
        (_) async => stripSubject.copyWith(
          data: stripSubject.data.copyWith(title: 'Feed'),
        ),
      );
      // Room beside the words: the test font's glyphs are far wider than
      // Inter's.
      await pump(
        tester,
        width: 600,
        mediaQueryData: desktopLayoutMediaQueryData,
      );
      final back = tester.getRect(find.byKey(RecordingStripLeading.backKey));
      final leading = tester.getRect(find.byType(RecordingStripLeading));
      expect(back.width, lessThan(leading.width));

      await tester.tapAt(Offset(back.right + 4, back.center.dy));
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
