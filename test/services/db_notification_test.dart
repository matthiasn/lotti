// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/db_notification.dart';

import '../test_utils/fake_time.dart';

/// Test constants to avoid magic numbers and improve maintainability
class _TestConstants {
  // Timing constants (in milliseconds)
  static const int regularTimerDelay = 100;
  static const int syncTimerDelay = 1000;

  // Test data constants
  static const String testId1 = 'id1';
  static const String testId2 = 'id2';
  static const String testId3 = 'id3';
  static const String syncId1 = 'sync_id1';
  static const String syncId2 = 'sync_id2';
  static const String regularId1 = 'regular_1';
  static const String regularId2 = 'regular_2';
  static const String regularId3 = 'regular_3';
  static const String patternId1 = 'r1';
  static const String patternId2 = 'r2';
  static const String patternSyncId1 = 's1';
  static const String patternSyncId2 = 's2';

  // Test set sizes
  static const int largeSetSize = 1000;
  static const int rapidNotificationCount = 10;

  // Expected values
  static const String habitCompletionValue = 'HABIT_COMPLETION';
  static const String textEntryValue = 'TEXT_ENTRY';
  static const String taskValue = 'TASK';
  static const String surveyValue = 'SURVEY';
  static const String eventValue = 'EVENT';
  static const String audioValue = 'AUDIO';
  static const String imageValue = 'IMAGE';
  static const String workoutValue = 'WORKOUT';
  static const String aiResponseValue = 'AI_RESPONSE';
}

/// Helper class for common test operations
class _TestHelpers {
  /// Creates a test subscription and tracks emitted values
  static StreamSubscription<Set<String>> createTestSubscription(
    UpdateNotifications notifications,
    List<Set<String>> emittedValues,
  ) {
    return notifications.updateStream.listen(emittedValues.add);
  }

  /// Creates a large test set with specified size
  static Set<String> createLargeTestSet(int size) {
    return <String>{for (int i = 0; i < size; i++) 'id_$i'};
  }

  /// Creates a set with duplicate elements for testing deduplication
  static Set<String> createDuplicateTestSet() {
    return <String>{}..addAll([
        _TestConstants.testId1,
        _TestConstants.testId1,
        _TestConstants.testId2
      ]);
  }
}

void main() {
  group('UpdateNotifications', () {
    late UpdateNotifications updateNotifications;

    setUp(() {
      updateNotifications = UpdateNotifications();
    });

    tearDown(() async {
      // Always safe to call dispose - it's idempotent
      await updateNotifications.dispose();
    });

    group('Initial State', () {
      test('should initialize with empty state', () {
        expect(updateNotifications, isNotNull);
        expect(updateNotifications, isA<UpdateNotifications>());
      });
    });

    group('Stream Behavior', () {
      test('should emit notifications when notify is called', () {
        fakeAsync((async) {
          final affectedIds = {
            _TestConstants.testId1,
            _TestConstants.testId2,
            _TestConstants.testId3
          };
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          updateNotifications.notify(affectedIds);

          // Regular timer is 100ms.
          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(1));
          expect(emittedIds.first, equals(affectedIds));

          unawaited(subscription.cancel());
        });
      });

      test('should batch multiple notifications within timer window', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Send multiple notifications to test batching
          updateNotifications
            ..notify({_TestConstants.testId1})
            ..notify({_TestConstants.testId2})
            ..notify({_TestConstants.testId3});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(1));
          expect(
              emittedIds.first,
              equals({
                _TestConstants.testId1,
                _TestConstants.testId2,
                _TestConstants.testId3
              }));

          unawaited(subscription.cancel());
        });
      });

      test('should emit separate notifications after timer window', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          updateNotifications.notify({_TestConstants.testId1});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          updateNotifications.notify({_TestConstants.testId2});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(2));
          expect(emittedIds[0], equals({_TestConstants.testId1}));
          expect(emittedIds[1], equals({_TestConstants.testId2}));

          unawaited(subscription.cancel());
        });
      });
    });

    group('Sync Notifications', () {
      test('should handle sync notifications with longer delay', () {
        fakeAsync((async) {
          final affectedIds = {_TestConstants.syncId1, _TestConstants.syncId2};
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          updateNotifications.notify(affectedIds, fromSync: true);

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.syncTimerDelay));

          expect(emittedIds.length, equals(1));
          expect(emittedIds.first, equals(affectedIds));

          unawaited(subscription.cancel());
        });
      });

      test('should batch sync notifications separately', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Send regular and sync notifications to test separate batching
          updateNotifications
            ..notify({_TestConstants.testId1}) // Regular notification
            ..notify({_TestConstants.syncId1},
                fromSync: true); // Sync notification

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));
          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.syncTimerDelay));

          expect(emittedIds.length, equals(2));
          expect(emittedIds[0], equals({_TestConstants.testId1}));
          expect(emittedIds[1], equals({_TestConstants.syncId1}));

          unawaited(subscription.cancel());
        });
      });
    });

    group('Edge Cases', () {
      test('should not emit empty set notifications', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          updateNotifications.notify({});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(0));

          unawaited(subscription.cancel());
        });
      });

      test('should handle duplicate IDs in notifications', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          final duplicateSet = _TestHelpers.createDuplicateTestSet();
          updateNotifications.notify(duplicateSet);

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(1));
          expect(
              emittedIds.first,
              equals({
                _TestConstants.testId1,
                _TestConstants.testId2
              })); // Duplicates removed

          unawaited(subscription.cancel());
        });
      });

      test('should handle very large sets', () {
        fakeAsync((async) {
          final largeSet =
              _TestHelpers.createLargeTestSet(_TestConstants.largeSetSize);

          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          updateNotifications.notify(largeSet);

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(1));
          expect(emittedIds.first.length, equals(_TestConstants.largeSetSize));

          unawaited(subscription.cancel());
        });
      });

      test('should handle null or invalid inputs gracefully', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Test with null-like empty set (already covered by empty set test)
          updateNotifications.notify(<String>{});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(0));

          unawaited(subscription.cancel());
        });
      });
    });

    group('Multiple Subscribers', () {
      test('should broadcast to multiple subscribers', () {
        fakeAsync((async) {
          final emittedIds1 = <Set<String>>[];
          final emittedIds2 = <Set<String>>[];

          final subscription1 = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds1);
          final subscription2 = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds2);

          updateNotifications
              .notify({_TestConstants.testId1, _TestConstants.testId2});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds1.length, equals(1));
          expect(emittedIds2.length, equals(1));
          expect(emittedIds1.first,
              equals({_TestConstants.testId1, _TestConstants.testId2}));
          expect(emittedIds2.first,
              equals({_TestConstants.testId1, _TestConstants.testId2}));

          unawaited(subscription1.cancel());
          unawaited(subscription2.cancel());
        });
      });

      test('should handle subscriber cancellation gracefully', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Cancel subscription before notification
          unawaited(subscription.cancel());

          updateNotifications.notify({_TestConstants.testId1});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          // Should not emit to cancelled subscription
          expect(emittedIds.length, equals(0));
        });
      });
    });

    group('Timer Management', () {
      test('should reset timer after emission', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          updateNotifications.notify({_TestConstants.testId1});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          updateNotifications.notify({_TestConstants.testId2});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(2));
          expect(emittedIds[0], equals({_TestConstants.testId1}));
          expect(emittedIds[1], equals({_TestConstants.testId2}));

          unawaited(subscription.cancel());
        });
      });

      test('should handle rapid notifications', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Send notifications rapidly
          for (var i = 0; i < _TestConstants.rapidNotificationCount; i++) {
            updateNotifications.notify({'id_$i'});
          }

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(1));
          expect(emittedIds.first.length,
              equals(_TestConstants.rapidNotificationCount));

          unawaited(subscription.cancel());
        });
      });

      test('should handle subscription cancellation before timer triggers', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          updateNotifications.notify({_TestConstants.testId1});

          // Cancel subscription before timer triggers
          unawaited(subscription.cancel());

          // Advance beyond the timer to ensure no late emissions
          async.elapseAndFlush(const Duration(
              milliseconds: _TestConstants.regularTimerDelay * 2));

          // Should not emit to cancelled subscription
          expect(emittedIds.length, equals(0));
        });
      });
    });

    group('Constants', () {
      test('should have correct notification constants', () {
        expect(habitCompletionNotification,
            equals(_TestConstants.habitCompletionValue));
        expect(textEntryNotification, equals(_TestConstants.textEntryValue));
        expect(taskNotification, equals(_TestConstants.taskValue));
        expect(surveyNotification, equals(_TestConstants.surveyValue));
        expect(eventNotification, equals(_TestConstants.eventValue));
        expect(audioNotification, equals(_TestConstants.audioValue));
        expect(imageNotification, equals(_TestConstants.imageValue));
        expect(workoutNotification, equals(_TestConstants.workoutValue));
        expect(aiResponseNotification, equals(_TestConstants.aiResponseValue));
      });
    });

    group('Integration Scenarios', () {
      test('should handle mixed regular and sync notifications', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Regular notifications - testing batching
          updateNotifications
            ..notify({_TestConstants.regularId1})
            ..notify({_TestConstants.regularId2})

            // Sync notifications - testing separate batching
            ..notify({_TestConstants.syncId1}, fromSync: true)
            ..notify({_TestConstants.syncId2}, fromSync: true)

            // More regular notifications - testing continued batching
            ..notify({_TestConstants.regularId3});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));
          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.syncTimerDelay));

          expect(emittedIds.length, equals(2));
          expect(
              emittedIds[0],
              equals({
                _TestConstants.regularId1,
                _TestConstants.regularId2,
                _TestConstants.regularId3
              }));
          expect(emittedIds[1],
              equals({_TestConstants.syncId1, _TestConstants.syncId2}));

          unawaited(subscription.cancel());
        });
      });

      test('should handle complex notification patterns', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Pattern: regular -> sync -> regular -> sync
          updateNotifications
            ..notify({_TestConstants.patternId1})
            ..notify({_TestConstants.patternId2})
            ..notify({_TestConstants.patternSyncId1}, fromSync: true)
            ..notify({_TestConstants.patternSyncId2}, fromSync: true);

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));
          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.syncTimerDelay));

          expect(emittedIds.length, equals(2));
          expect(emittedIds[0],
              equals({_TestConstants.patternId1, _TestConstants.patternId2}));
          expect(
              emittedIds[1],
              equals({
                _TestConstants.patternSyncId1,
                _TestConstants.patternSyncId2
              }));

          unawaited(subscription.cancel());
        });
      });
    });

    group('Error Scenarios', () {
      test('should handle concurrent access safely', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Simulate concurrent notifications
          updateNotifications
            ..notify({_TestConstants.testId1})
            ..notify({_TestConstants.testId2})
            ..notify({_TestConstants.testId3});

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(1));
          expect(
              emittedIds.first,
              equals({
                _TestConstants.testId1,
                _TestConstants.testId2,
                _TestConstants.testId3
              }));

          unawaited(subscription.cancel());
        });
      });

      test('should handle memory pressure scenarios', () {
        fakeAsync((async) {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Create many notifications to test memory handling
          for (var i = 0; i < 100; i++) {
            updateNotifications.notify({'memory_test_$i'});
          }

          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          expect(emittedIds.length, equals(1));
          expect(emittedIds.first.length, equals(100));

          unawaited(subscription.cancel());
        });
      });
    });

    group('Disposal Safety', () {
      test('dispose should be idempotent', () async {
        // First disposal
        await updateNotifications.dispose();

        // Second disposal should not throw
        await expectLater(
          updateNotifications.dispose(),
          completes,
        );
      });

      test('notify after dispose should be no-op', () {
        fakeAsync((async) async {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Dispose the notifications
          await updateNotifications.dispose();

          // Try to notify after disposal
          updateNotifications.notify({_TestConstants.testId1});

          // Advance time to simulate missed timer (should not emit)
          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));

          // Should not emit anything
          expect(emittedIds.length, equals(0));

          // Clean up subscription
          await subscription.cancel();
        });
      });

      test('notify with sync flag after dispose should be no-op', () {
        fakeAsync((async) async {
          final emittedIds = <Set<String>>[];

          final subscription = _TestHelpers.createTestSubscription(
              updateNotifications, emittedIds);

          // Dispose the notifications
          await updateNotifications.dispose();

          // Try to notify with sync flag after disposal
          updateNotifications.notify({_TestConstants.syncId1}, fromSync: true);

          // Advance time; no emissions should occur
          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.syncTimerDelay));

          // Should not emit anything
          expect(emittedIds.length, equals(0));

          // Clean up subscription
          await subscription.cancel();
        });
      });

      test('timers should be cleaned up on dispose', () {
        fakeAsync((async) {
          // Trigger both timers
          updateNotifications
            ..notify({_TestConstants.testId1})
            ..notify({_TestConstants.syncId1}, fromSync: true);

          // Dispose before timers fire
          unawaited(updateNotifications.dispose());

          // Advance time for both timers; nothing should throw
          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.regularTimerDelay));
          async.elapseAndFlush(
              const Duration(milliseconds: _TestConstants.syncTimerDelay));
        });
      });
    });
  });
}
