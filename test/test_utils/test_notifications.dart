import 'dart:async';

import 'package:lotti/services/db_notification.dart';

/// In-memory [UpdateNotifications] double exposing a manual [emit] seam.
///
/// All three streams share one broadcast controller so a test can drive
/// any subscription path with a single call. Pass `sync: true` when the
/// test asserts synchronously after [emit] (e.g. inside `fakeAsync`).
class TestNotifications implements UpdateNotifications {
  TestNotifications({bool sync = false})
    : _controller = StreamController<Set<String>>.broadcast(sync: sync);

  final StreamController<Set<String>> _controller;

  @override
  Stream<Set<String>> get updateStream => _controller.stream;

  @override
  Stream<Set<String>> get localUpdateStream => _controller.stream;

  @override
  Stream<Set<String>> get syncUpdateStream => _controller.stream;

  void emit(Set<String> ids) {
    _controller.add(ids);
  }

  @override
  void notify(Set<String> affectedIds, {bool fromSync = false}) {
    emit(affectedIds);
  }

  @override
  void notifyUiOnly(Set<String> affectedIds) {
    emit(affectedIds);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
