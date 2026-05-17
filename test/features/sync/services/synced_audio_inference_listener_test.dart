// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/services/synced_audio_inference_dispatcher.dart';
import 'package:lotti/features/sync/services/synced_audio_inference_listener.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

class _MockDispatcher extends Mock implements SyncedAudioInferenceDispatcher {}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  late UpdateNotifications notifications;
  late _MockDispatcher dispatcher;
  late SyncedAudioInferenceListener listener;

  setUp(() {
    notifications = UpdateNotifications();
    dispatcher = _MockDispatcher();
    when(() => dispatcher.maybeDispatch(any())).thenAnswer((_) async {});
    listener = SyncedAudioInferenceListener(
      updateNotifications: notifications,
      dispatcher: dispatcher,
    );
  });

  tearDown(() async {
    await listener.dispose();
    await notifications.dispose();
  });

  test(
    'forwards every id in a fromSync: true batch to the dispatcher',
    () {
      fakeAsync((async) {
        listener.start();

        notifications.notify({'audio-1', 'audio-2'}, fromSync: true);

        // UpdateNotifications batches sync emissions on a 1s timer.
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verify(() => dispatcher.maybeDispatch('audio-1')).called(1);
        verify(() => dispatcher.maybeDispatch('audio-2')).called(1);
      });
    },
  );

  test(
    'does NOT forward local (non-sync) notifications — those go to '
    'localUpdateStream only',
    () {
      fakeAsync((async) {
        listener.start();

        notifications.notify({'audio-1'});

        // Regular notifications fire after ~100ms.
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        verifyNever(() => dispatcher.maybeDispatch(any()));
      });
    },
  );

  test(
    'does NOT forward notifyUiOnly emissions',
    () {
      fakeAsync((async) {
        listener.start();

        notifications.notifyUiOnly({'agent-ui-refresh'});

        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        verifyNever(() => dispatcher.maybeDispatch(any()));
      });
    },
  );

  test(
    'coalesces multiple sync notifications inside the 1s window into one '
    'dispatcher pass',
    () {
      fakeAsync((async) {
        listener.start();

        notifications
          ..notify({'a'}, fromSync: true)
          ..notify({'b'}, fromSync: true)
          ..notify({'a', 'c'}, fromSync: true); // duplicate 'a' deduped.

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verify(() => dispatcher.maybeDispatch('a')).called(1);
        verify(() => dispatcher.maybeDispatch('b')).called(1);
        verify(() => dispatcher.maybeDispatch('c')).called(1);
      });
    },
  );

  test(
    'start() is idempotent — calling twice does not double-deliver',
    () {
      fakeAsync((async) {
        listener
          ..start()
          ..start();

        notifications.notify({'audio-1'}, fromSync: true);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verify(() => dispatcher.maybeDispatch('audio-1')).called(1);
      });
    },
  );

  test(
    'dispose() cancels the subscription — later sync emissions do not fire',
    () {
      fakeAsync((async) {
        listener.start();

        // Schedule the dispose to land inside fakeAsync so its microtasks
        // drain deterministically.
        unawaited(listener.dispose());
        async.flushMicrotasks();

        notifications.notify({'audio-late'}, fromSync: true);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verifyNever(() => dispatcher.maybeDispatch(any()));
      });
    },
  );
}
