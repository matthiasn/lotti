import 'dart:isolate';

import 'package:clock/clock.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';

/// The function a sync isolate starts in, handed the port that reaches the
/// host. Injectable on `SyncIsolateHost` so tests can spawn workers that
/// crash, hang or answer wrongly.
typedef SyncIsolateEntry = void Function(SendPort host);

/// Production entry point of the sync isolate.
///
/// It answers the host's commands one at a time, in order. Today that is
/// liveness and shutdown only: the Matrix client, admission and sending move
/// in behind the same port in later steps (ADR 0142). After answering
/// [SyncIsolateShutdown] it closes its only port, which ends the isolate.
///
/// Runs without Flutter plugins: nothing here may reach a platform channel,
/// so whatever the worker needs from the platform the host passes in.
void syncIsolateEntry(SendPort host) {
  final startedAt = clock.now();
  final commands = ReceivePort();
  var handled = 0;

  Object? handle(SyncIsolateCommand command) => switch (command) {
    SyncIsolatePing() => SyncIsolateHealth(
      uptime: clock.now().difference(startedAt),
      handled: handled,
    ),
    SyncIsolateShutdown() => null,
  };

  commands.listen((message) {
    if (message is! SyncIsolateRequest) return;
    handled++;
    final command = message.command;
    host.send(SyncIsolateReply.success(message.requestId, handle(command)));
    if (command is SyncIsolateShutdown) commands.close();
  });

  host
    ..send(SyncIsolateReady(commands.sendPort))
    ..send(const SyncIsolateLog('sync isolate started'));
}
