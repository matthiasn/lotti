import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/ui/chat/chat_amplitude_history.dart';

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
}
