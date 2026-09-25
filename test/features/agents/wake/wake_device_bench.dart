import 'dart:async';

import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/wake/scheduled_wake_manager.dart';
import 'package:lotti/features/agents/wake/wake_intent_store.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../sync/agent_replica_bench.dart';

/// Settings storage that outlives a process, whose writes land only when a
/// trace says so.
///
/// `WakeIntentStore` writes the intents with a coalesced write to the
/// settings database. A write is in flight until the first [land] puts it on
/// disk (`FlushIntent` in `specs/tla/ScheduledWakeLease.tla`), and its caller
/// resumes only at the next [land]: a process can die in between, with the
/// write durable and nothing that awaited it done. A process death drops
/// what is still in flight ([drop]).
class GatedSettings {
  GatedSettings({this.held = true});

  /// Whether writes wait for [land]; otherwise every write lands at once.
  final bool held;

  final durable = <String, String>{};
  final _inFlight = <({String key, String? value, Completer<void> done})>[];
  final _onDisk = <Completer<void>>[];

  bool get hasPending => _inFlight.isNotEmpty || _onDisk.isNotEmpty;

  MockSettingsDb database() {
    final db = MockSettingsDb();
    when(() => db.itemByKey(any())).thenAnswer(
      (invocation) async => durable[invocation.positionalArguments.first],
    );
    when(() => db.saveSettingsItem(any(), any())).thenAnswer((invocation) {
      if (!held) {
        durable[invocation.positionalArguments[0] as String] =
            invocation.positionalArguments[1] as String;
        return Future.value(1);
      }
      final done = Completer<void>();
      _inFlight.add((
        key: invocation.positionalArguments[0] as String,
        value: invocation.positionalArguments[1] as String,
        done: done,
      ));
      return done.future.then((_) => 1);
    });
    when(() => db.removeSettingsItem(any())).thenAnswer((invocation) {
      if (!held) {
        durable.remove(invocation.positionalArguments.first);
        return Future.value();
      }
      final done = Completer<void>();
      _inFlight.add((
        key: invocation.positionalArguments.first as String,
        value: null,
        done: done,
      ));
      return done.future;
    });
    return db;
  }

  /// The writes already on disk return to their callers; the writes in
  /// flight reach the disk, in order.
  void land() {
    final written = [..._onDisk];
    _onDisk.clear();
    for (final done in written) {
      done.complete();
    }
    final writes = [..._inFlight];
    _inFlight.clear();
    for (final write in writes) {
      final value = write.value;
      if (value == null) {
        durable.remove(write.key);
      } else {
        durable[write.key] = value;
      }
      _onDisk.add(write.done);
    }
  }

  /// The process died: the writes in flight never land, and no caller of a
  /// landed one resumes.
  void drop() {
    _inFlight.clear();
    _onDisk.clear();
  }
}

/// A `WakeIntentStore` that tells the bench which scheduled-wake windows each
/// run key carries — the windows [markWindow] tags and [adopt] moves onto a
/// restored job — so a finished run can be attributed to its window.
class TracingIntentStore extends WakeIntentStore {
  TracingIntentStore({required super.settingsDb, required this.windowsOf});

  final Map<String, Set<String>> windowsOf;

  @override
  void markWindow(String runKey, String window) {
    (windowsOf[runKey] ??= {}).add(window);
    super.markWindow(runKey, window);
  }

  /// The restored job fires what the intent's job fired — including a
  /// window the store has already let go of, because its record was
  /// consumed (`acknowledgeWindow`) while the run was still going.
  @override
  void adopt(WakeIntent intent, {required String runKey}) {
    (windowsOf[runKey] ??= {}).addAll({
      ...intent.windows,
      ...?windowsOf[intent.runKey],
    });
    super.adopt(intent, runKey: runKey);
  }
}

enum DeviceStatus { up, down, dead }

/// One device of a wake-runtime trace: its agent store (an [AgentReplica]),
/// its settings database, and a process — a real [WakeOrchestrator] with a
/// real [WakeIntentStore], and a real [ScheduledWakeManager] leasing the
/// records [requiresLease] names.
///
/// With [holdSteps], the host lookup the lease awaits is held until
/// [answerHostLookups], so a trace can deliver sync between it and the
/// re-read before firing — the window the manager's re-reads exist for — and
/// the wake-intent writes wait for [GatedSettings.land]. [crash] ends the
/// process; [boot] starts the next one over the same stores.
class WakeDevice {
  WakeDevice(
    this.replica, {
    required this.executor,
    required this.requiresLease,
    this.beforeCheck,
    this.leaseSettle = const Duration(minutes: 3),
    this.leaseDuration = const Duration(minutes: 5),
    this.holdSteps = true,
  }) : settings = GatedSettings(held: holdSteps) {
    boot();
  }

  final AgentReplica replica;

  /// The wake executor of each process, given the device.
  final WakeExecutor Function(WakeDevice device) executor;
  final bool Function(ScheduledWakeEntity record) requiresLease;
  final Future<void> Function(WakeDevice device)? beforeCheck;
  final Duration leaseSettle;
  final Duration leaseDuration;
  final bool holdSteps;
  final GatedSettings settings;

  /// Run key to the scheduled-wake windows the job fires, for the life of
  /// the device (a restored job keeps its windows).
  final windowsOf = <String, Set<String>>{};
  final _hostLookups = <Completer<String?>>[];
  DeviceStatus status = DeviceStatus.up;
  late WakeOrchestrator orchestrator;
  late ScheduledWakeManager manager;

  /// Whether a restarted process still owes `restoreWakeIntents`.
  bool restorePending = false;

  String get host => replica.host;

  /// The process holds a step the trace has to release.
  bool get blocked => hasHostLookups || settings.hasPending;

  bool get hasHostLookups => _hostLookups.isNotEmpty;

  void boot() {
    replica.reboot();
    orchestrator = WakeOrchestrator(
      repository: replica.repository,
      queue: WakeQueue(),
      runner: WakeRunner(),
      maxConcurrentWakes: () => 3,
      intentStore: TracingIntentStore(
        settingsDb: settings.database(),
        windowsOf: windowsOf,
      ),
    );
    orchestrator.wakeExecutor = executor(this);
    final before = beforeCheck;
    manager = ScheduledWakeManager(
      repository: replica.repository,
      orchestrator: orchestrator,
      syncService: replica.syncService,
      requiresLease: requiresLease,
      localHostId: () {
        if (!holdSteps) return Future.value(host);
        final lookup = Completer<String?>();
        _hostLookups.add(lookup);
        return lookup.future;
      },
      beforeCheck: before == null ? null : () => before(this),
      leaseSettle: leaseSettle,
      leaseDuration: leaseDuration,
    )..start();
  }

  void answerHostLookups() {
    final lookups = [..._hostLookups];
    _hostLookups.clear();
    for (final lookup in lookups) {
      lookup.complete(host);
    }
  }

  /// Process death: the manager's timers stop, the settings writes in
  /// flight are lost, and so is everything that only lived in memory — the
  /// queue, the running executors (which never settle), the host lookups.
  void crash() {
    manager.stop();
    unawaited(orchestrator.stop());
    settings.drop();
    _hostLookups.clear();
    status = DeviceStatus.down;
  }

  /// The next process over the same stores. Its intents are restored by a
  /// later [restore], as the runtime does once its other startup passes ran.
  void restart() {
    status = DeviceStatus.up;
    restorePending = true;
    boot();
  }

  void restore() {
    restorePending = false;
    unawaited(orchestrator.restoreWakeIntents());
  }

  /// A device gone for good.
  void die() {
    manager.stop();
    unawaited(orchestrator.stop());
    status = DeviceStatus.dead;
  }
}
