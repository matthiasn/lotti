import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_timer_pill.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
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

  /// The row inside the glass: the strip's height without its hairline
  /// and the bottom safe area.
  Finder row() => find.byKey(RecordingStrip.rowKey);

  group('height', () {
    testWidgets('the row is 56 at the default text size: the controls with '
        'a step of air above and below', (tester) async {
      await pump(tester);
      expect(tester.getSize(row()).height, 56);
    });

    testWidgets('the row grows with the text size, as the receipt it turns '
        'into does, and stays one row', (tester) async {
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
      expect(tester.getSize(row()).height, height);
      expect(
        tester.getCenter(find.byType(RecordingStripLeading)).dy,
        closeTo(tester.getCenter(stop()).dy, 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('extent is the hairline, the row and the bottom safe area '
        'the glass reaches into', (tester) async {
      const inset = 34.0;
      await pump(
        tester,
        mediaQueryData: phoneMediaQueryData.copyWith(
          padding: const EdgeInsets.only(bottom: inset),
        ),
      );
      final context = tester.element(strip());
      final extent = RecordingStrip.extent(context);
      expect(
        extent,
        DesignSystemGlassStrip.hairlineHeight +
            RecordingStrip.height(context) +
            inset,
      );
      expect(tester.getSize(strip()).height, extent);
      // The row sits above the inset, the glass runs into it.
      expect(
        tester.getRect(strip()).bottom - tester.getRect(row()).bottom,
        inset,
      );
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
      RecordingRingButton ring() => tester.widget(
        find.descendant(
          of: pause(),
          matching: find.byType(RecordingRingButton),
        ),
      );
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

  group('a tap on the body', () {
    testWidgets('away from where the take started, takes the user back '
        'there, and leaves the tray folded', (tester) async {
      await pump(
        tester,
        width: 600,
        mediaQueryData: desktopLayoutMediaQueryData,
      );
      // The bars take no tap of their own: the body's.
      await tester.tap(bars());
      await tester.pump();
      verify(() => bench.nav.beamToNamed(stripSubjectRoute)).called(1);
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isFalse,
      );
    });

    testWidgets('on the page where the take started, opens the tray', (
      tester,
    ) async {
      bench.route = stripSubjectRoute;
      await pump(tester);
      await tester.tap(bars());
      await tester.pump();
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isTrue,
      );
      verifyNever(() => bench.nav.beamToNamed(any()));
    });

    testWidgets('of a take with no way back, opens the tray', (tester) async {
      await bench.pump(
        tester,
        SizedBox(width: 390, child: RecordingStrip(key: UniqueKey())),
      );
      await bench.recorder.record(linkedId: stripSubjectId);
      await tester.pump();
      await tester.pump();
      await tester.tap(bars());
      await tester.pump();
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isTrue,
      );
      verifyNever(() => bench.nav.beamToNamed(any()));
    });

    testWidgets('where the way back finds nowhere to go, opens the tray '
        'rather than doing nothing', (tester) async {
      when(() => bench.nav.canBeamTo(any())).thenReturn(false);
      await pump(tester);
      await tester.tap(bars());
      await tester.pump();
      await tester.pump();
      verifyNever(() => bench.nav.beamToNamed(any()));
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isTrue,
      );
    });

    testWidgets('on pause does neither', (tester) async {
      await pump(tester);
      await tester.tap(pause());
      await tester.pump();
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isFalse,
      );
      verifyNever(() => bench.nav.beamToNamed(any()));
    });
  });

  group('the tray', () {
    testWidgets('opens on a swipe up, away from the origin too', (
      tester,
    ) async {
      await pump(tester);
      await tester.fling(strip(), const Offset(0, -80), 800);
      await tester.pump();
      expect(
        containerOf(tester).read(recordingTrayControllerProvider).open,
        isTrue,
      );
      verifyNever(() => bench.nav.beamToNamed(any()));
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
  });

  testWidgets('the way back is the arrow alone, a full tap target', (
    tester,
  ) async {
    await pump(tester);
    final back = tester.getSize(find.byKey(RecordingStripLeading.backKey));
    final step9 = tester.element(strip()).designTokens.spacing.step9;
    expect(back, Size.square(step9));
  });

  testWidgets('a screen reader meets the leading part, then pause, then '
      'Stop', (tester) async {
    await pump(tester);
    final leading = tester.getCenter(find.byType(RecordingStripLeading)).dx;
    expect(leading, lessThan(tester.getCenter(pause()).dx));
    expect(tester.getCenter(pause()).dx, lessThan(tester.getCenter(stop()).dx));
  });

  testWidgets('on a wide window the glass runs edge to edge while the row '
      'stays at the prose measure, centred', (tester) async {
    await pump(
      tester,
      width: desktopLayoutMediaQueryData.size.width,
      mediaQueryData: desktopLayoutMediaQueryData,
    );
    final width = desktopLayoutMediaQueryData.size.width;
    expect(tester.getSize(strip()).width, width);
    expect(tester.getSize(row()).width, kProseMeasureWidth);
    expect(tester.getCenter(row()).dx, tester.getCenter(strip()).dx);
  });

  testWidgets('keeps the row clear of a landscape notch, the glass running '
      'into it', (tester) async {
    const notch = 44.0;
    await pump(
      tester,
      width: 667,
      mediaQueryData: phoneMediaQueryData.copyWith(
        size: const Size(667, 375),
        padding: const EdgeInsets.only(left: notch, right: notch),
      ),
    );
    final gutter = tester.element(strip()).designTokens.spacing.step5;
    expect(tester.getRect(strip()).left, 0);
    expect(tester.getRect(row()).left, greaterThanOrEqualTo(notch + gutter));
    expect(
      tester.getRect(row()).right,
      lessThanOrEqualTo(667 - notch - gutter),
    );
  });

  group('surface', () {
    testWidgets("wears the sticky action bar's glass, edge to edge, with no "
        'capsule around it', (tester) async {
      await pump(tester);
      expect(
        find.descendant(
          of: strip(),
          matching: find.byType(DesignSystemGlassStrip),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: strip(), matching: find.byType(DsGlassChipSurface)),
        findsNothing,
      );
      expect(tester.getSize(strip()).width, 390);
    });

    testWidgets('surface() draws a card as a full capsule; a radius rounds '
        'it less', (tester) async {
      late BuildContext context;
      await bench.pump(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      );
      BorderRadius? radiusOf(Widget surface) =>
          (surface as DsGlassChipSurface).radius;
      final capsule = RecordingStrip.surface(
        context,
        child: const SizedBox.shrink(),
      );
      expect(
        radiusOf(capsule),
        BorderRadius.circular(RecordingStrip.height(context) / 2),
      );
      final rounded = RecordingStrip.surface(
        context,
        radius: 12,
        child: const SizedBox.shrink(),
      );
      expect(radiusOf(rounded), BorderRadius.circular(12));
    });
  });
}
