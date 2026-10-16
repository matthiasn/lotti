import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/playhead_clock.dart';

const _ms = Duration(milliseconds: 1);

void main() {
  test('reads the report itself the moment it arrives', () {
    fakeAsync((async) {
      final clock = PlayheadClock();
      expect(clock.at(_ms * 400), _ms * 400);
    });
  });

  test('carries a report forward by the time since it arrived', () {
    fakeAsync((async) {
      final clock = PlayheadClock()..at(_ms * 400);
      async.elapse(_ms * 100);
      expect(clock.at(_ms * 400), _ms * 500);
    });
  });

  test('scales the time since the report by the playback speed', () {
    fakeAsync((async) {
      final clock = PlayheadClock()..at(_ms * 400, speed: 1.5);
      async.elapse(_ms * 100);
      expect(clock.at(_ms * 400, speed: 1.5), _ms * 550);
    });
  });

  test('starts again from a new report', () {
    fakeAsync((async) {
      final clock = PlayheadClock()..at(_ms * 400);
      async.elapse(_ms * 100);
      // The player reports a little behind where the clock had got to.
      expect(clock.at(_ms * 480), _ms * 480);
      async.elapse(_ms * 20);
      expect(clock.at(_ms * 480), _ms * 500);
    });
  });

  test('a stalled player stops it after maxLead', () {
    fakeAsync((async) {
      final clock = PlayheadClock(maxLead: _ms * 250)..at(_ms * 400);
      async.elapse(const Duration(seconds: 3));
      expect(clock.at(_ms * 400), _ms * 650);
    });
  });

  test('defaults to a quarter of a second of lead', () {
    expect(PlayheadClock().maxLead, _ms * 250);
  });
}
