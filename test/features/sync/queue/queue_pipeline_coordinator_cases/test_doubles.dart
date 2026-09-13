part of '../queue_pipeline_coordinator_test.dart';

/// Test double for [AttachmentIngestor] that records every `process()`
/// call and optionally throws, without needing mocktail fallbacks for
/// every named-argument type (Function, DomainLogger, nullable refs).
class _FakeAttachmentIngestor implements AttachmentIngestor {
  _FakeAttachmentIngestor({
    this.shouldThrow = false,
    this.firstProcessed,
    this.processGate,
  });

  bool shouldThrow;
  final Completer<Event>? firstProcessed;
  final Future<void>? processGate;
  final List<Map<Symbol, Object?>> processCalls = <Map<Symbol, Object?>>[];

  @override
  Future<bool> process({
    required Event event,
    required DomainLogger logging,
    required AttachmentIndex? attachmentIndex,
    bool scheduleDownload = false,
  }) async {
    processCalls.add({
      #event: event,
      #scheduleDownload: scheduleDownload,
    });
    if (firstProcessed case final completer? when !completer.isCompleted) {
      completer.complete(event);
    }
    await processGate;
    if (shouldThrow) {
      throw StateError('ingestor boom');
    }
    return false;
  }

  @override
  Future<void> whenIdle() => Future<void>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [AttachmentIndex] whose `pathRecorded` stream is driven by an
/// owned controller so a test can push a stream *error* through it and
/// exercise the subscription's `onError` handler — the real index never
/// adds errors to its controller, so a subclass is the only way in.
class _ErroringAttachmentIndex extends AttachmentIndex {
  _ErroringAttachmentIndex() : super(logging: null);

  final StreamController<String> errorCtl =
      StreamController<String>.broadcast();

  @override
  Stream<String> get pathRecorded => errorCtl.stream;

  @override
  Future<void> dispose() async {
    if (!errorCtl.isClosed) {
      await errorCtl.close();
    }
    await super.dispose();
  }
}

/// [UpdateNotifications] whose `updateStream` is driven by an owned
/// controller so a test can push a stream *error* through it and exercise
/// the journal-update subscription's `onError` handler.
class _ErroringUpdateNotifications extends UpdateNotifications {
  final StreamController<Set<String>> errorCtl =
      StreamController<Set<String>>.broadcast();

  @override
  Stream<Set<String>> get updateStream => errorCtl.stream;

  @override
  Future<void> dispose() async {
    if (!errorCtl.isClosed) {
      await errorCtl.close();
    }
    await super.dispose();
  }
}

/// [AttachmentIndex] with a synchronous controller so a test can land a
/// path in the coordinator's pending-resurrection set at an exact point
/// in the start() sequence (the real index delivers asynchronously).
class _SyncPathAttachmentIndex extends AttachmentIndex {
  _SyncPathAttachmentIndex() : super(logging: null);

  final StreamController<String> ctl = StreamController<String>.broadcast(
    sync: true,
  );

  @override
  Stream<String> get pathRecorded => ctl.stream;
}

/// Stream whose [listen] throws — fails the journal-updates subscription
/// inside coordinator.start(). The central MockUpdateNotifications getter
/// swallows exceptions thrown by stubbed answers (it falls back to an
/// empty stream), so a throwing `listen` is the reliable injection point.
class _ThrowingSubscribeStream extends Stream<Set<String>> {
  @override
  StreamSubscription<Set<String>> listen(
    void Function(Set<String> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => throw StateError('updateStream wiring failed');
}
