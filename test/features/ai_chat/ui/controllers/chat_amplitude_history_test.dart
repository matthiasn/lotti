import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_chat/ui/controllers/chat_amplitude_history.dart';

void main() {
  group('appendAmplitudeSample', () {
    test('appends to a short history without trimming', () {
      expect(
        appendAmplitudeSample(const [-40, -30], -20),
        [-40, -30, -20],
      );
    });

    test('does not mutate the input list', () {
      final input = <double>[-40, -30];
      appendAmplitudeSample(input, -20);
      expect(input, [-40, -30]);
    });

    test('drops the oldest sample once the window overflows', () {
      final full = List<double>.generate(
        chatAmplitudeHistoryMax,
        (i) => -i.toDouble(),
      );
      final next = appendAmplitudeSample(full, 1);

      expect(next.length, chatAmplitudeHistoryMax);
      // Oldest (-0) dropped from the front, newest (1) appended at the end.
      expect(next.first, -1);
      expect(next.last, 1);
    });

    test('honours a custom max window', () {
      expect(
        appendAmplitudeSample(const [-3, -2, -1], 0, max: 3),
        [-2, -1, 0],
      );
    });

    glados.Glados2<List<double>, double>(
      // A history that fits the window — mirrors how the controller feeds it
      // (it only ever appends one sample at a time, so the list never starts
      // out over the max).
      glados.any.listWithLengthInRange(
        0,
        chatAmplitudeHistoryMax,
        glados.any.doubleInRange(-100, 10),
      ),
      glados.any.doubleInRange(-100, 10),
    ).test('caps at the window and ends with the new sample', (
      history,
      dbfs,
    ) {
      final next = appendAmplitudeSample(history, dbfs);
      final reason = 'len=${history.length} dbfs=$dbfs';

      expect(
        next.length,
        lessThanOrEqualTo(chatAmplitudeHistoryMax),
        reason: reason,
      );
      expect(next.last, dbfs, reason: reason);
      expect(
        next.length,
        history.length < chatAmplitudeHistoryMax
            ? history.length + 1
            : chatAmplitudeHistoryMax,
        reason: reason,
      );
    }, tags: 'glados');
  });

  group('normalizeAmplitudeSample', () {
    test('clamps below the floor to the minimum height', () {
      expect(normalizeAmplitudeSample(-100), closeTo(0.05, 1e-9));
      expect(
        normalizeAmplitudeSample(chatAmplitudeMinDbfs.toDouble()),
        closeTo(0.05, 1e-9),
      );
    });

    test('clamps at/above the ceiling to the maximum height', () {
      expect(
        normalizeAmplitudeSample(chatAmplitudeMaxDbfs.toDouble()),
        closeTo(1, 1e-9),
      );
      expect(normalizeAmplitudeSample(0), closeTo(1, 1e-9));
    });

    test('maps a mid-range reading onto the scaled band', () {
      // Matches the controller-level worked example for -50 dBFS.
      expect(normalizeAmplitudeSample(-50), closeTo(0.4571428571, 1e-9));
    });

    glados.Glados<double>(
      glados.any.doubleInRange(-200, 50),
    ).test('always returns a value within [min, max] normalized range', (dbfs) {
      final result = normalizeAmplitudeSample(dbfs);
      expect(
        result,
        inInclusiveRange(
          chatAmplitudeMinNormalized,
          chatAmplitudeMaxNormalized,
        ),
        reason: 'dbfs=$dbfs',
      );
    }, tags: 'glados');

    glados.Glados2<double, double>(
      glados.any.doubleInRange(
        chatAmplitudeMinDbfs.toDouble(),
        chatAmplitudeMaxDbfs.toDouble(),
      ),
      glados.any.doubleInRange(
        chatAmplitudeMinDbfs.toDouble(),
        chatAmplitudeMaxDbfs.toDouble(),
      ),
    ).test('is monotonically non-decreasing across the active band', (a, b) {
      final lo = a < b ? a : b;
      final hi = a < b ? b : a;
      expect(
        normalizeAmplitudeSample(hi),
        greaterThanOrEqualTo(normalizeAmplitudeSample(lo) - 1e-9),
        reason: 'lo=$lo hi=$hi',
      );
    }, tags: 'glados');
  });

  group('normalizeAmplitudeHistory', () {
    test('normalizes each entry, preserving order and length', () {
      final result = normalizeAmplitudeHistory(
        const <double>[-100, -80, -50, -10, 0],
      );

      expect(result, [
        closeTo(0.05, 1e-9),
        closeTo(0.05, 1e-9),
        closeTo(0.4571428571, 1e-9),
        closeTo(1, 1e-9),
        closeTo(1, 1e-9),
      ]);
    });
  });
}
