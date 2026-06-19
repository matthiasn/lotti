import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show Glados3, IntAnys, any;
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_status_presentation.dart';

QueueSummary _summary({
  int pending = 0,
  int sending = 0,
  int failed = 0,
  bool syncEnabled = true,
  bool signedIn = true,
}) => summarizeOutbox(
  pendingCount: pending,
  sendingCount: sending,
  failedCount: failed,
  syncEnabled: syncEnabled,
  signedIn: signedIn,
);

void main() {
  group('presentationStatusOf', () {
    test('maps every raw status to its plain-language presentation', () {
      expect(
        presentationStatusOf(OutboxStatus.pending),
        OutboxPresentationStatus.waiting,
      );
      expect(
        presentationStatusOf(OutboxStatus.sending),
        OutboxPresentationStatus.sending,
      );
      expect(
        presentationStatusOf(OutboxStatus.error),
        OutboxPresentationStatus.failed,
      );
      expect(
        presentationStatusOf(OutboxStatus.sent),
        OutboxPresentationStatus.sent,
      );
    });
  });

  group('retryCapReached', () {
    test('is false below the cap and true at or above it', () {
      expect(retryCapReached(9), isFalse);
      expect(retryCapReached(10), isTrue);
      expect(retryCapReached(11), isTrue);
      expect(retryCapReached(3, maxRetries: 3), isTrue);
    });
  });

  group('summarizeOutbox', () {
    test('an empty queue is synced', () {
      final s = _summary();
      expect(s.state, QueueState.synced);
      expect(s.activeCount, 0);
      expect(s.failedCount, 0);
    });

    test('pending-only work is waiting', () {
      expect(_summary(pending: 3).state, QueueState.waiting);
    });

    test('anything sending is sending', () {
      expect(_summary(pending: 2, sending: 1).state, QueueState.sending);
    });

    test('failures take precedence over in-flight work when signed in', () {
      final s = _summary(sending: 4, failed: 2);
      expect(s.state, QueueState.failed);
      expect(s.activeCount, 4);
      expect(s.failedCount, 2);
    });

    test('not signed in with stranded work reads as offline, not failed', () {
      expect(
        _summary(failed: 5, signedIn: false).state,
        QueueState.offline,
      );
      expect(
        _summary(pending: 3, signedIn: false).state,
        QueueState.offline,
      );
    });

    test('not signed in but with nothing queued is still synced', () {
      expect(_summary(signedIn: false).state, QueueState.synced);
    });

    test('activeCount is pending + sending', () {
      expect(_summary(pending: 5, sending: 7).activeCount, 12);
    });

    test('value equality', () {
      expect(_summary(pending: 1), _summary(pending: 1));
      expect(_summary(pending: 1) == _summary(pending: 2), isFalse);
    });
  });

  group('properties', () {
    Glados3(
      any.intInRange(0, 200),
      any.intInRange(0, 200),
      any.intInRange(0, 200),
    ).test(
      'synced exactly when there is no work (signed in)',
      (pending, sending, failed) {
        final s = _summary(pending: pending, sending: sending, failed: failed);
        expect(
          s.state == QueueState.synced,
          pending + sending + failed == 0,
        );
        expect(s.activeCount, pending + sending);
      },
      tags: 'glados',
    );

    Glados3(
      any.intInRange(0, 200),
      any.intInRange(0, 200),
      any.intInRange(1, 200),
    ).test(
      'stranded work while signed out always reads as offline',
      (pending, sending, failed) {
        // failed is >= 1 here, so there is always work.
        final s = _summary(
          pending: pending,
          sending: sending,
          failed: failed,
          signedIn: false,
        );
        expect(s.state, QueueState.offline);
      },
      tags: 'glados',
    );
  });
}
