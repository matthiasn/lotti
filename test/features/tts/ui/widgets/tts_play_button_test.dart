import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    required TtsButtonMode mode,
    double? progress,
    MediaQueryData? mediaQueryData,
    VoidCallback? onPlay,
    VoidCallback? onStop,
  }) {
    return tester.pumpWidget(
      makeTestableWidget(
        Center(
          child: TtsPlayButton(
            mode: mode,
            progress: progress,
            onPlay: onPlay ?? () {},
            onStop: onStop ?? () {},
          ),
        ),
        mediaQueryData: mediaQueryData,
      ),
    );
  }

  CircularProgressIndicator? indicator(WidgetTester tester) {
    final finder = find.byType(CircularProgressIndicator);
    if (finder.evaluate().isEmpty) return null;
    return tester.widget<CircularProgressIndicator>(finder);
  }

  testWidgets('idle shows a play triangle, no ring, and plays on tap', (
    tester,
  ) async {
    var played = 0;
    var stopped = 0;
    await pumpButton(
      tester,
      mode: TtsButtonMode.idle,
      onPlay: () => played++,
      onStop: () => stopped++,
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(indicator(tester), isNull);

    await tester.tap(find.byType(TtsPlayButton));
    expect(played, 1);
    expect(stopped, 0);
  });

  testWidgets('playing shows a stop square, a determinate arc, stops on tap', (
    tester,
  ) async {
    var stopped = 0;
    await pumpButton(
      tester,
      mode: TtsButtonMode.playing,
      progress: 0.5,
      onStop: () => stopped++,
    );

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(indicator(tester)?.value, 0.5);

    await tester.tap(find.byType(TtsPlayButton));
    expect(stopped, 1);
  });

  testWidgets('preparing shows an indeterminate ring and cancels on tap', (
    tester,
  ) async {
    var stopped = 0;
    await pumpButton(
      tester,
      mode: TtsButtonMode.preparing,
      onStop: () => stopped++,
    );

    expect(indicator(tester), isNotNull);
    expect(indicator(tester)?.value, isNull); // indeterminate

    await tester.tap(find.byType(TtsPlayButton));
    expect(stopped, 1);
  });

  testWidgets('reduced motion renders the preparing ring static', (
    tester,
  ) async {
    await pumpButton(
      tester,
      mode: TtsButtonMode.preparing,
      mediaQueryData: phoneMediaQueryData.copyWith(disableAnimations: true),
    );
    // A determinate full ring instead of a spinner.
    expect(indicator(tester)?.value, 1.0);
  });

  testWidgets('exposes a button semantics label per mode', (tester) async {
    await pumpButton(tester, mode: TtsButtonMode.idle);
    expect(find.bySemanticsLabel('Play summary'), findsOneWidget);

    await pumpButton(tester, mode: TtsButtonMode.playing, progress: 0.2);
    expect(find.bySemanticsLabel('Stop'), findsOneWidget);
  });

  testWidgets('meets the 44x44 minimum hit target', (tester) async {
    await pumpButton(tester, mode: TtsButtonMode.idle);
    final size = tester.getSize(find.byType(TtsPlayButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
