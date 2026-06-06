import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_orb.dart';

import '../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Generators for AudioRecordingSignalLevel property tests
// ---------------------------------------------------------------------------

extension _AnyDbfs on glados.Any {
  /// Finite dBFS values spanning well below silence to well above clipping.
  glados.Generator<double> get dbfsFinite =>
      glados.DoubleAnys(this).doubleInRange(-200, 20);

  /// dBFS values strictly above the −3 dBFS clipping threshold.
  glados.Generator<double> get dbfsAboveClipping =>
      glados.DoubleAnys(this).doubleInRange(-2.9999, 20);

  /// dBFS values at or below the −3 dBFS clipping threshold.
  glados.Generator<double> get dbfsBelowClipping =>
      glados.DoubleAnys(this).doubleInRange(-200, -3);
}

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

    test('marks only samples above clipping threshold as clipping', () {
      expect(AudioRecordingSignalLevel.fromDbfs(-4).isClipping, isFalse);
      expect(AudioRecordingSignalLevel.fromDbfs(-3).isClipping, isFalse);
      expect(AudioRecordingSignalLevel.fromDbfs(-2.9).isClipping, isTrue);
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

  // -------------------------------------------------------------------------
  // AudioRecordingSignalLevel.fromDbfs — Glados property tests
  // -------------------------------------------------------------------------

  group('AudioRecordingSignalLevel.fromDbfs — properties', () {
    glados.Glados<double>(
      glados.any.dbfsFinite,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'normalized is always in [0, 1] for any finite dBFS',
      (dbfs) {
        final level = AudioRecordingSignalLevel.fromDbfs(dbfs);
        expect(level.normalized, greaterThanOrEqualTo(0.0));
        expect(level.normalized, lessThanOrEqualTo(1.0));
      },
      tags: 'glados',
    );

    glados.Glados<double>(
      glados.any.dbfsAboveClipping,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'isClipping is true for every dBFS strictly above −3',
      (dbfs) {
        final level = AudioRecordingSignalLevel.fromDbfs(dbfs);
        expect(
          level.isClipping,
          isTrue,
          reason: 'dBFS=$dbfs should be clipping',
        );
      },
      tags: 'glados',
    );

    glados.Glados<double>(
      glados.any.dbfsBelowClipping,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'isClipping is false for every dBFS at or below −3',
      (dbfs) {
        final level = AudioRecordingSignalLevel.fromDbfs(dbfs);
        expect(
          level.isClipping,
          isFalse,
          reason: 'dBFS=$dbfs should not be clipping',
        );
      },
      tags: 'glados',
    );

    glados.Glados<double>(
      glados.any.dbfsFinite,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'two calls with same dBFS produce equal levels (value equality)',
      (dbfs) {
        final first = AudioRecordingSignalLevel.fromDbfs(dbfs);
        final second = AudioRecordingSignalLevel.fromDbfs(dbfs);
        expect(first, second);
        expect(first.hashCode, second.hashCode);
      },
      tags: 'glados',
    );

    glados.Glados<double>(
      glados.DoubleAnys(glados.any).doubleInRange(-63.9, -0.1),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'within the active speech range normalized is strictly between 0 and 1',
      (dbfs) {
        final level = AudioRecordingSignalLevel.fromDbfs(dbfs);
        expect(level.normalized, greaterThan(0.0));
        expect(level.normalized, lessThan(1.0));
      },
      tags: 'glados',
    );
  });
}
