import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/onboarding/ui/widgets/waveform_text_hero.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // Bounded box around the hero so the CustomPaint has a finite size and the
  // painter's paint() actually runs.
  Widget wrap(Widget child) => SizedBox(width: 360, height: 240, child: child);

  group('WaveformTextHero', () {
    testWidgets('reduced motion renders the full resolved phrase and paints', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          wrap(
            const WaveformTextHero(
              waveColor: Colors.teal,
              textColor: Colors.white,
            ),
          ),
          mediaQueryData: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(WaveformTextHero), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      // Reduced motion reveals the full default phrase at full opacity.
      expect(find.text('Plan my week'), findsOneWidget);

      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Plan my week'),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion renders a custom phrase', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          wrap(
            const WaveformTextHero(
              waveColor: Colors.purple,
              textColor: Colors.black,
              phrase: 'Capture a thought',
            ),
          ),
          mediaQueryData: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Capture a thought'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'animated mode advances the controller through reveal/calm phases',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            wrap(
              // Default phrase ('Plan my week') exercises the phrase default.
              const WaveformTextHero(
                waveColor: Colors.teal,
                textColor: Colors.white,
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(390, 844)),
          ),
        );
        await tester.pump();

        // Advance the repeating controller across several frames so paint()
        // runs at multiple `t` values, driving the reveal/hold/fade phases.
        // The 5s loop means each 400ms step covers a distinct segment.
        for (var i = 0; i < 14; i++) {
          await tester.pump(const Duration(milliseconds: 400));
        }

        expect(find.byType(WaveformTextHero), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
        // The phrase text widget is always present (its visible substring grows
        // as the controller advances).
        expect(
          find.byType(Text),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shouldRepaint: rebuilding with a new waveColor repaints', (
      tester,
    ) async {
      const key = ValueKey('hero');

      Widget build(Color waveColor) => makeTestableWidget(
        wrap(
          WaveformTextHero(
            key: key,
            waveColor: waveColor,
            textColor: Colors.white,
          ),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
      );

      await tester.pumpWidget(build(Colors.teal));
      await tester.pump();
      expect(find.byType(WaveformTextHero), findsOneWidget);

      // Same key, different waveColor -> painter.shouldRepaint compares color.
      await tester.pumpWidget(build(Colors.red));
      await tester.pump();

      expect(find.byType(WaveformTextHero), findsOneWidget);
      expect(find.text('Plan my week'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldRepaint: rebuilding with a new phrase repaints', (
      tester,
    ) async {
      const key = ValueKey('hero');

      Widget build(String phrase) => makeTestableWidget(
        wrap(
          WaveformTextHero(
            key: key,
            waveColor: Colors.teal,
            textColor: Colors.white,
            phrase: phrase,
          ),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
      );

      await tester.pumpWidget(build('Plan my week'));
      await tester.pump();
      expect(find.text('Plan my week'), findsOneWidget);

      await tester.pumpWidget(build('Log my run'));
      await tester.pump();

      expect(find.text('Log my run'), findsOneWidget);
      expect(find.text('Plan my week'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'toggling from animated to reduced motion stops the controller',
      (tester) async {
        const key = ValueKey('hero');

        Widget build({required bool reduceMotion}) => makeTestableWidget(
          wrap(
            const WaveformTextHero(
              key: key,
              waveColor: Colors.teal,
              textColor: Colors.white,
            ),
          ),
          mediaQueryData: MediaQueryData(
            size: const Size(390, 844),
            disableAnimations: reduceMotion,
          ),
        );

        // Start animated so _controller.repeat() runs.
        await tester.pumpWidget(build(reduceMotion: false));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Now toggle reduced motion on (didChangeDependencies stops controller).
        await tester.pumpWidget(build(reduceMotion: true));
        await tester.pump();

        // Reduced motion resolves the full phrase.
        expect(find.text('Plan my week'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
