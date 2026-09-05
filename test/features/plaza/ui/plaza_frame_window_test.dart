import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/plaza_frame_window.dart';

void main() {
  test('averages only live samples and expires the old peak on wrap', () {
    final window = PlazaFrameWindow(capacity: 3)
      ..add(90)
      ..add(10);
    expect(window.average, 50);
    expect(window.worst, 90);
    window
      ..add(20)
      ..add(30);
    expect(window.count, 3);
    expect(window.average, 20);
    expect(window.worst, 30);
    window
      ..add(40)
      ..add(50)
      ..add(60);
    expect(window.average, 50);
    expect(window.worst, 60);
  });

  test('invalid durations do not poison subsequent statistics', () {
    final window = PlazaFrameWindow()
      ..add(double.nan)
      ..add(double.infinity)
      ..add(-1)
      ..add(0);
    expect((window.count, window.average, window.worst), (0, 0, 0));
    window.add(16);
    expect((window.count, window.average, window.worst), (1, 16, 16));
    for (final capacity in [0, -1]) {
      expect(
        () => PlazaFrameWindow(capacity: capacity),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'capacity')
              .having((error) => error.invalidValue, 'invalidValue', capacity),
        ),
      );
    }
  });
}
