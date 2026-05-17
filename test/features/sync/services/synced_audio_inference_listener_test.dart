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

  test(
    'serializes consecutive batches — a slow dispatch must complete before '
    'the next batch starts, otherwise runTranscription would overlap inside '
    'the journal writer transaction',
    () {
      fakeAsync((async) {
        final source = StreamController<Set<String>>.broadcast();
        final orderedDispatcher = _MockDispatcher();
        final inFlight = <String>{};
        final concurrentCalls = <String>[];
        when(() => orderedDispatcher.maybeDispatch(any())).thenAnswer(
          (invocation) async {
            final id = invocation.positionalArguments.first as String;
            if (inFlight.isNotEmpty) concurrentCalls.add(id);
            inFlight.add(id);
            // Take an async hop to mimic a real dispatcher's awaited work.
            // Microtask, not `Future.delayed` — fakeAsync doesn't intercept
            // real timers (and AGENTS.md forbids them in tests anyway).
            await Future<void>.microtask(() {});
            inFlight.remove(id);
          },
        );

        final seqListener = SyncedAudioInferenceListener(
          updateNotifications: _FaultySyncNotifications(source),
          dispatcher: orderedDispatcher,
        )..start();

        source
          ..add({'a'})
          ..add({'b'})
          ..add({'c'});

        // Microtasks are sufficient now that the stub uses a microtask hop;
        // no need to advance fake time.
        async.flushMicrotasks();

        // No call should have observed another in flight — `asyncMap` holds
        // the next event until the prior `_onBatch` completes.
        expect(concurrentCalls, isEmpty);
        verify(() => orderedDispatcher.maybeDispatch('a')).called(1);
        verify(() => orderedDispatcher.maybeDispatch('b')).called(1);
        verify(() => orderedDispatcher.maybeDispatch('c')).called(1);

        unawaited(seqListener.dispose());
        unawaited(source.close());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'stream errors are caught by the listener and do NOT terminate the '
    'subscription — a dispatcher loop must survive a transient producer error',
    () {
      // Build a controllable error-emitting source instead of relying on
      // UpdateNotifications (which doesn't expose addError).
      fakeAsync((async) {
        final errorSource = StreamController<Set<String>>.broadcast();
        final errorDispatcher = _MockDispatcher();
        when(() => errorDispatcher.maybeDispatch(any())).thenAnswer(
          (_) async {},
        );
        // Wire a stand-in UpdateNotifications whose syncUpdateStream is the
        // controllable source.
        final faultyNotifications = _FaultySyncNotifications(errorSource);
        final faultyListener = SyncedAudioInferenceListener(
          updateNotifications: faultyNotifications,
          dispatcher: errorDispatcher,
        );

        faultyListener.start();

        errorSource.addError(StateError('upstream broke'));
        async.flushMicrotasks();

        errorSource.add({'audio-after-error'});
        async.flushMicrotasks();

        verify(
          () => errorDispatcher.maybeDispatch('audio-after-error'),
        ).called(1);

        unawaited(faultyListener.dispose());
        unawaited(errorSource.close());
        async.flushMicrotasks();
      });
    },
  );
}

/// Thin pass-through that exposes a caller-controlled `syncUpdateStream`
/// while inheriting the rest of UpdateNotifications' behavior. Used to feed
/// stream errors into the listener.
class _FaultySyncNotifications extends UpdateNotifications {
  _FaultySyncNotifications(this._source);

  final StreamController<Set<String>> _source;

  @override
  Stream<Set<String>> get syncUpdateStream => _source.stream;
}
