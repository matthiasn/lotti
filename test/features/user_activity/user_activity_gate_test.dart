import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserActivityGate.waitUntilIdle', () {
    test('returns immediately when already idle', () async {
      final service = UserActivityService();
      final gate = UserActivityGate(
        activityService: service,
        idleThreshold: const Duration(milliseconds: 50),
      );

      final sw = Stopwatch()..start();
      await gate.waitUntilIdle();
      sw.stop();

      // Should finish quickly since lastActivity is epoch → already idle.
      expect(sw.elapsed.inMilliseconds, lessThan(50));
      await gate.dispose();
      await service.dispose();
    });

    test('waits until threshold elapses when recently active', () async {
      // Mark user as recently active before constructing the gate so initial
      // state is non‑idle.
      final service = UserActivityService()..updateActivity();
      final gate = UserActivityGate(
        activityService: service,
        idleThreshold: const Duration(milliseconds: 120),
      );

      final sw = Stopwatch()..start();
      await gate.waitUntilIdle();
      sw.stop();

      // Expect we waited at least ~idleThreshold (with a small margin).
      expect(sw.elapsed.inMilliseconds, greaterThanOrEqualTo(100));
      await gate.dispose();
      await service.dispose();
    });

    test('returns after hard deadline when continuously active', () async {
      // Mark as recently active before creating the gate so it starts non‑idle.
      final service = UserActivityService()..updateActivity();
      // Create gate with a reasonable idle threshold; we will keep activity
      // happening to force the hard deadline path (~2s).
      final gate = UserActivityGate(
        activityService: service,
        idleThreshold: const Duration(milliseconds: 300),
      );

      // Continuously report activity for ~2.2s to keep the gate non‑idle.
      final endAt = DateTime.now().add(const Duration(milliseconds: 2300));
      final ticker = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (DateTime.now().isBefore(endAt)) {
          service.updateActivity();
        }
      });
      addTearDown(ticker.cancel);

      final sw = Stopwatch()..start();
      await gate.waitUntilIdle();
      sw.stop();

      // Should be close to the internal hard deadline (~2000ms).
      expect(sw.elapsed.inMilliseconds, greaterThanOrEqualTo(1800));
      expect(sw.elapsed.inMilliseconds, lessThan(3500));

      await gate.dispose();
      await service.dispose();
    });
  });
}
