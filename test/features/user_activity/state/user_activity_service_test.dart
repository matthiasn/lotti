import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';

void main() {
  group('UserActivityService', () {
    test('lastActivity starts at the epoch sentinel', () {
      final service = UserActivityService();
      addTearDown(service.dispose);

      expect(service.lastActivity, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('updateActivity advances lastActivity and emits it', () async {
      final service = UserActivityService();
      addTearDown(service.dispose);

      final emitted = <DateTime>[];
      final sub = service.activityStream.listen(emitted.add);
      addTearDown(sub.cancel);

      final fixedNow = DateTime(2024, 3, 15, 10, 30);
      await withClock(Clock.fixed(fixedNow), () async {
        service.updateActivity();
        expect(service.lastActivity, fixedNow);

        await pumpEventQueue();
        expect(emitted, [fixedNow]);
      });
    });

    test('activityStream broadcasts to multiple subscribers', () async {
      final service = UserActivityService();
      addTearDown(service.dispose);

      final first = <DateTime>[];
      final second = <DateTime>[];
      final sub1 = service.activityStream.listen(first.add);
      final sub2 = service.activityStream.listen(second.add);
      addTearDown(sub1.cancel);
      addTearDown(sub2.cancel);

      service.updateActivity();
      await pumpEventQueue();

      expect(first, hasLength(1));
      expect(second, first);
    });

    test('updateActivity after dispose is silently ignored', () async {
      final service = UserActivityService();
      await service.dispose();
      final fixedNow = DateTime(2024, 3, 15, 10, 30);

      expect(
        () => withClock(Clock.fixed(fixedNow), service.updateActivity),
        returnsNormally,
      );
      // The timestamp still advances even though nothing is emitted.
      expect(service.lastActivity, fixedNow);
    });
  });
}
