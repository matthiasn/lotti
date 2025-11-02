import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:lotti/utils/platform.dart';
import 'package:media_kit/media_kit.dart';

void ensureMpvInitialized() {
  if (isMacOS) {
    MediaKit.ensureInitialized(libmpv: '/opt/homebrew/bin/mpv');
  }
  if (isLinux || isWindows) {
    MediaKit.ensureInitialized();
  }
}

/// Wait until a synchronous [condition] becomes true.
///
/// - If [fake] is provided, advances fake time in [poll] increments and
///   flushes microtasks between steps without consuming real time.
/// - Otherwise, polls using real async delays of [poll].
Future<void> waitUntil(
  bool Function() condition, {
  FakeAsync? fake,
  Duration poll = const Duration(milliseconds: 100),
  Duration timeout = const Duration(seconds: 1),
}) async {
  if (fake != null) {
    var elapsed = Duration.zero;
    // Drive microtasks and timers deterministically.
    while (!condition()) {
      if (elapsed >= timeout) {
        throw TimeoutException('waitUntil timed out after $timeout');
      }
      fake
        ..flushMicrotasks()
        ..elapse(poll);
      elapsed += poll;
    }
    return;
  }

  // Real-time fallback
  final start = DateTime.now();
  while (!condition()) {
    if (DateTime.now().difference(start) >= timeout) {
      throw TimeoutException('waitUntil timed out after $timeout');
    }
    await Future<void>.delayed(poll);
  }
}

/// Wait until an asynchronous [condition] resolves to true.
///
/// - If [fake] is provided, repeatedly evaluates [condition] by flushing
///   microtasks and advancing fake time by [poll] as needed.
/// - Otherwise, polls using real async delays of [poll].
Future<void> waitUntilAsync(
  Future<bool> Function() condition, {
  FakeAsync? fake,
  Duration poll = const Duration(milliseconds: 100),
  Duration timeout = const Duration(seconds: 1),
}) async {
  if (fake != null) {
    var elapsed = Duration.zero;
    while (true) {
      var done = false;
      unawaited(condition().then((v) => done = v));
      fake.flushMicrotasks();
      if (done) return;
      if (elapsed >= timeout) {
        throw TimeoutException('waitUntilAsync timed out after $timeout');
      }
      fake.elapse(poll);
      elapsed += poll;
    }
  }

  // Real-time fallback
  final start = DateTime.now();
  while (!await condition()) {
    if (DateTime.now().difference(start) >= timeout) {
      throw TimeoutException('waitUntilAsync timed out after $timeout');
    }
    await Future<void>.delayed(poll);
  }
}

/// Wait for [seconds] amount of time.
/// If [fake] is provided, advances fake time instead of consuming real time.
Future<void> waitSeconds(int seconds, {FakeAsync? fake}) async {
  if (fake != null) {
    fake
      ..elapse(Duration(seconds: seconds))
      ..flushMicrotasks();
    return;
  }
  await Future<void>.delayed(Duration(seconds: seconds));
}
