import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_orb.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecordingSignalLevel', () {
    test('maps silence, speech, and hot input into an emphasized signal', () {
      expect(AudioRecordingSignalLevel.fromDbfs(-160).normalized, 0);
      expect(AudioRecordingSignalLevel.fromDbfs(-64).normalized, 0);
      expect(
        AudioRecordingSignalLevel.fromDbfs(-60).normalized,
        closeTo(0.08, 0.01),
      );
      expect(
        AudioRecordingSignalLevel.fromDbfs(-30).normalized,
        closeTo(0.57, 0.01),
      );
      expect(
        AudioRecordingSignalLevel.fromDbfs(-12).normalized,
        closeTo(0.82, 0.01),
      );
      expect(
        AudioRecordingSignalLevel.fromDbfs(-8).normalized,
        closeTo(0.89, 0.01),
      );
      expect(
        AudioRecordingSignalLevel.fromDbfs(-3).normalized,
        closeTo(0.96, 0.01),
      );
      expect(AudioRecordingSignalLevel.fromDbfs(12).normalized, 1);
    });

    test('marks only near-full-scale samples as clipping', () {
      expect(AudioRecordingSignalLevel.fromDbfs(-4).isClipping, isFalse);
      expect(AudioRecordingSignalLevel.fromDbfs(-3).isClipping, isTrue);
      expect(AudioRecordingSignalLevel.fromDbfs(0).isClipping, isTrue);
    });

    test('treats non-finite input as silence', () {
      final level = AudioRecordingSignalLevel.fromDbfs(double.nan);

      expect(level.normalized, 0);
      expect(level.isClipping, isFalse);
    });

    test('uses value equality for repaint comparisons', () {
      final first = AudioRecordingSignalLevel.fromDbfs(-30);
      final second = AudioRecordingSignalLevel.fromDbfs(-30);
      final third = AudioRecordingSignalLevel.fromDbfs(-12);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(third));
    });
  });

  testWidgets('paints from live dBFS level and advances pulse phase', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const AudioRecordingOrb(dBFS: -30),
      ),
    );
    await tester.pump();

    final orbPaint = find.descendant(
      of: find.byType(AudioRecordingOrb),
      matching: find.byType(CustomPaint),
    );
    final firstPainter =
        tester
                .widget<CustomPaint>(
                  orbPaint,
                )
                .painter!
            as AudioRecordingOrbPainter;
    expect(firstPainter.signalLevel.normalized, closeTo(0.57, 0.01));
    expect(firstPainter.signalLevel.isClipping, isFalse);

    await tester.pump(AudioRecordingOrbConstants.pulseDuration ~/ 2);

    final secondPainter =
        tester
                .widget<CustomPaint>(
                  orbPaint,
                )
                .painter!
            as AudioRecordingOrbPainter;
    expect(secondPainter.phase, isNot(equals(firstPainter.phase)));
  });

  testWidgets('uses warning color when dBFS reaches clipping threshold', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const AudioRecordingOrb(dBFS: -1),
      ),
    );
    await tester.pump();

    final tokens = tester.element(find.byType(AudioRecordingOrb)).designTokens;
    final orbPaint = find.descendant(
      of: find.byType(AudioRecordingOrb),
      matching: find.byType(CustomPaint),
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  orbPaint,
                )
                .painter!
            as AudioRecordingOrbPainter;

    expect(painter.signalLevel.isClipping, isTrue);
    expect(painter.clippingColor, tokens.colors.alert.warning.defaultColor);
  });
}
